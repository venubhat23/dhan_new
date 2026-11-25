class Admin::SalesReceiptsController < Admin::ApplicationController
  before_action :set_sales_receipt, only: [:show, :update_bank_info]

  def index
    scope = SalesReceipt.includes(:booking, :store)
    if params[:search].present?
      q = "%#{params[:search].strip}%"
      scope = scope.where('sales_receipts.receipt_number ILIKE :q OR sales_receipts.booking_number ILIKE :q OR ' \
                          'sales_receipts.invoice_number ILIKE :q OR sales_receipts.customer_name ILIKE :q OR ' \
                          'sales_receipts.customer_phone ILIKE :q OR sales_receipts.reference_number ILIKE :q', q: q)
    end
    scope = scope.where(payment_mode: params[:payment_mode]) if SalesReceipt::PAYMENT_MODES.key?(params[:payment_mode].to_s)
    scope = scope.where('sales_receipts.receipt_date >= ?', params[:from]) if params[:from].present?
    scope = scope.where('sales_receipts.receipt_date <= ?', params[:to]) if params[:to].present?
    case params[:bank]
    when 'done'    then scope = scope.where.not(bank_date: nil).where.not(bank_opening_balance: nil).where.not(bank_closing_balance: nil).where("COALESCE(bank_narration, '') <> ''")
    when 'pending' then scope = scope.where("bank_date IS NULL OR bank_opening_balance IS NULL OR bank_closing_balance IS NULL OR COALESCE(bank_narration, '') = ''")
    end

    @total_count  = scope.count
    @total_amount = scope.sum(:amount).to_f
    @mode_totals  = scope.group(:payment_mode).sum(:amount)
    month_scope   = SalesReceipt.where(receipt_date: Date.current.all_month)
    @month_amount = month_scope.sum(:amount).to_f
    @month_count  = month_scope.count

    @per_page = 25
    @page = [params[:page].to_i, 1].max
    @total_pages = [(@total_count.to_f / @per_page).ceil, 1].max
    @sales_receipts = scope.recent.offset((@page - 1) * @per_page).limit(@per_page)
  end

  def show; end

  def new
    @sales_receipt = SalesReceipt.new(receipt_date: Date.current, payment_mode: 'upi')
    if params[:booking].present? && (booking = find_booking(params[:booking]))
      @sales_receipt.assign_attributes(SalesReceipt.attributes_from_booking(booking).merge(receipt_date: Date.current))
    end
  end

  def create
    @sales_receipt = SalesReceipt.new(sales_receipt_params.merge(created_by: current_user, source: 'manual'))
    if params[:booking_number].present?
      booking = find_booking(params[:booking_number])
      if booking.nil?
        @sales_receipt.errors.add(:base, "Booking #{params[:booking_number]} not found")
        return render :new, status: :unprocessable_entity
      end
      if (existing = SalesReceipt.find_by(booking_id: booking.id))
        return redirect_to admin_sales_receipt_path(existing), alert: "Booking ##{booking.booking_number} already has receipt #{existing.receipt_number}."
      end
      # Booking details fill anything the form left blank (items always come from the booking).
      SalesReceipt.attributes_from_booking(booking).except(:booking).each do |k, v|
        @sales_receipt[k] = v if @sales_receipt[k].blank? || k == :items
      end
      @sales_receipt.booking = booking
    end

    if @sales_receipt.save
      redirect_to admin_sales_receipt_path(@sales_receipt), notice: "Sales receipt #{@sales_receipt.receipt_number} created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # GET /admin/sales_receipts/lookup_booking?q=... → booking details to prefill the form
  def lookup_booking
    booking = find_booking(params[:q])
    return render(json: { found: false }) unless booking

    attrs = SalesReceipt.attributes_from_booking(booking)
    render json: {
      found: true, booking_number: booking.booking_number,
      existing_receipt: SalesReceipt.where(booking_id: booking.id).pick(:receipt_number),
      customer_name: attrs[:customer_name], customer_phone: attrs[:customer_phone], customer_email: attrs[:customer_email],
      amount: attrs[:amount].to_f, payment_mode: attrs[:payment_mode], invoice_number: attrs[:invoice_number],
      payment_status: booking.payment_status_display, items: attrs[:items]
    }
  end

  def update_bank_info
    attrs = params.require(:sales_receipt).permit(*SalesReceipt::BANK_FIELDS)
    if @sales_receipt.update(attrs)
      redirect_back fallback_location: admin_sales_receipts_path,
                    notice: "Bank info updated for #{@sales_receipt.receipt_number}#{' ✓ complete' if @sales_receipt.bank_info_complete?}."
    else
      redirect_back fallback_location: admin_sales_receipts_path, alert: @sales_receipt.errors.full_messages.to_sentence
    end
  end

  private

  def set_sales_receipt
    @sales_receipt = SalesReceipt.includes(:booking, :store, :created_by).find(params[:id])
  end

  def find_booking(q)
    q = q.to_s.strip.delete_prefix('#')
    return if q.blank?

    Booking.find_by(booking_number: q) || (q.match?(/\A\d+\z/) ? Booking.find_by(id: q) : nil)
  end

  def sales_receipt_params
    params.require(:sales_receipt).permit(:receipt_date, :customer_name, :customer_phone, :customer_email,
                                          :amount, :payment_mode, :reference_number, :notes, :invoice_number,
                                          *SalesReceipt::BANK_FIELDS)
  end
end

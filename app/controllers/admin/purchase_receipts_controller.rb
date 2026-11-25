class Admin::PurchaseReceiptsController < Admin::ApplicationController
  before_action :set_purchase_receipt, only: [:show, :update_bank_info]

  def index
    scope = PurchaseReceipt.includes(:vendor_purchase)
    if params[:search].present?
      q = "%#{params[:search].strip}%"
      scope = scope.where('purchase_receipts.receipt_number ILIKE :q OR purchase_receipts.purchase_number ILIKE :q OR ' \
                          'purchase_receipts.vendor_name ILIKE :q OR purchase_receipts.vendor_phone ILIKE :q OR ' \
                          'purchase_receipts.reference_number ILIKE :q', q: q)
    end
    scope = scope.where(payment_mode: params[:payment_mode]) if PurchaseReceipt::PAYMENT_MODES.key?(params[:payment_mode].to_s)
    scope = scope.where('purchase_receipts.receipt_date >= ?', params[:from]) if params[:from].present?
    scope = scope.where('purchase_receipts.receipt_date <= ?', params[:to]) if params[:to].present?
    case params[:bank]
    when 'done'    then scope = scope.bank_complete
    when 'pending' then scope = scope.bank_pending
    end

    @total_count  = scope.count
    @total_amount = scope.sum(:amount).to_f
    @mode_totals  = scope.group(:payment_mode).sum(:amount)
    month_scope   = PurchaseReceipt.where(receipt_date: Date.current.all_month)
    @month_amount = month_scope.sum(:amount).to_f
    @month_count  = month_scope.count

    @per_page = 25
    @page = [params[:page].to_i, 1].max
    @total_pages = [(@total_count.to_f / @per_page).ceil, 1].max
    @purchase_receipts = scope.recent.offset((@page - 1) * @per_page).limit(@per_page)
  end

  def show; end

  def new
    @purchase_receipt = PurchaseReceipt.new(receipt_date: Date.current, payment_mode: 'bank')
    if params[:vendor_purchase_id].present? && (purchase = VendorPurchase.find_by(id: params[:vendor_purchase_id]))
      if (existing = purchase.purchase_receipt)
        return redirect_to admin_purchase_receipt_path(existing), alert: "#{purchase.purchase_number} already has receipt #{existing.receipt_number}."
      end
      @purchase_receipt.assign_attributes(PurchaseReceipt.attributes_from_vendor_purchase(purchase))
    end
    load_form_options
  end

  def create
    @purchase_receipt = PurchaseReceipt.new(purchase_receipt_params.merge(created_by: current_user, source: 'manual'))
    if params[:vendor_purchase_id].present?
      purchase = VendorPurchase.find_by(id: params[:vendor_purchase_id])
      if purchase.nil?
        @purchase_receipt.errors.add(:base, 'Vendor purchase not found')
        load_form_options
        return render :new, status: :unprocessable_entity
      end
      if (existing = purchase.purchase_receipt)
        return redirect_to admin_purchase_receipt_path(existing), alert: "#{purchase.purchase_number} already has receipt #{existing.receipt_number}."
      end
      # Purchase details fill anything the form left blank (items always come from the purchase).
      PurchaseReceipt.attributes_from_vendor_purchase(purchase).except(:vendor_purchase).each do |k, v|
        @purchase_receipt[k] = v if @purchase_receipt[k].blank? || k == :items
      end
      @purchase_receipt.vendor_purchase = purchase
    elsif @purchase_receipt.vendor_id.present? && (vendor = Vendor.find_by(id: @purchase_receipt.vendor_id))
      @purchase_receipt.vendor_name = vendor.name if @purchase_receipt.vendor_name.blank?
      @purchase_receipt.vendor_phone ||= vendor.phone
      @purchase_receipt.vendor_email ||= vendor.email
      @purchase_receipt.vendor_address ||= vendor.address
      @purchase_receipt.vendor_gst_no ||= vendor.gst_no
    end

    if @purchase_receipt.save
      redirect_to admin_purchase_receipt_path(@purchase_receipt), notice: "Purchase receipt #{@purchase_receipt.receipt_number} created."
    else
      load_form_options
      render :new, status: :unprocessable_entity
    end
  end

  def update_bank_info
    attrs = params.require(:purchase_receipt).permit(*PurchaseReceipt::BANK_FIELDS)
    if @purchase_receipt.update(attrs)
      redirect_back fallback_location: admin_purchase_receipts_path,
                    notice: "Bank info updated for #{@purchase_receipt.receipt_number}#{' ✓ complete' if @purchase_receipt.bank_info_complete?}."
    else
      redirect_back fallback_location: admin_purchase_receipts_path, alert: @purchase_receipt.errors.full_messages.to_sentence
    end
  end

  private

  def set_purchase_receipt
    @purchase_receipt = PurchaseReceipt.includes(:vendor_purchase, :vendor, :created_by).find(params[:id])
  end

  def load_form_options
    @vendors = Vendor.order(:name)
    @open_purchases = VendorPurchase.includes(:vendor).where.missing(:purchase_receipt).order(purchase_date: :desc, id: :desc).limit(200)
  end

  def purchase_receipt_params
    params.require(:purchase_receipt).permit(:receipt_date, :vendor_id, :vendor_name, :vendor_phone, :amount,
                                             :payment_mode, :reference_number, :notes, *PurchaseReceipt::BANK_FIELDS)
  end
end

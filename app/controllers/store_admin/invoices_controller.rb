class StoreAdmin::InvoicesController < StoreAdmin::ApplicationController
  before_action :set_invoice, only: [:show, :edit, :update, :destroy, :mark_as_paid]

  # Only invoices generated from bookings placed at the current store.
  def index
    scope = store_invoices.includes(:customer)

    if params[:search].present?
      term = "%#{params[:search].strip}%"
      scope = scope.left_joins(:customer)
                   .where('invoices.invoice_number ILIKE ? OR customers.full_name ILIKE ?', term, term)
    end

    scope = scope.where(payment_status: params[:payment_status]) if params[:payment_status].present?

    if params[:date_from].present? && params[:date_to].present?
      scope = scope.where(invoice_date: params[:date_from].to_date..params[:date_to].to_date)
    end

    @invoices = scope.order(created_at: :desc)
    @invoices = @invoices.page(params[:page]).per(20) if @invoices.respond_to?(:page)

    base = store_invoices
    @stats = {
      count: base.count,
      total: base.sum(:total_amount),
      paid: base.where(payment_status: Invoice.payment_statuses[:fully_paid]).sum(:total_amount),
      outstanding: base.where.not(payment_status: Invoice.payment_statuses[:fully_paid])
                       .sum('COALESCE(total_amount, 0) - COALESCE(paid_amount, 0)')
    }
    @booking_numbers = booking_numbers_lookup(@invoices)
  end

  def show
    @invoice_items = @invoice.invoice_items.includes(product: :product_variants)
    @booking = related_booking
  end

  def edit
    @invoice_items = @invoice.invoice_items.includes(product: :product_variants)
  end

  def update
    if @invoice.update(invoice_params)
      redirect_to store_admin_invoice_path(@invoice), notice: 'Invoice updated successfully.'
    else
      @invoice_items = @invoice.invoice_items.includes(product: :product_variants)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @invoice.destroy
    redirect_to store_admin_invoices_path, notice: 'Invoice deleted successfully.'
  rescue => e
    redirect_to store_admin_invoice_path(@invoice), alert: "Error deleting invoice: #{e.message}"
  end

  def mark_as_paid
    @invoice.update!(
      payment_status: :fully_paid,
      status: :paid,
      paid_at: Time.current,
      paid_amount: @invoice.total_amount
    )
    redirect_to store_admin_invoice_path(@invoice), notice: 'Invoice marked as paid.'
  rescue => e
    redirect_to store_admin_invoice_path(@invoice), alert: "Error marking invoice as paid: #{e.message}"
  end

  private

  def store_invoice_numbers
    @current_store.bookings.where.not(invoice_number: [nil, '']).select(:invoice_number)
  end

  def store_invoices
    Invoice.where(invoice_number: store_invoice_numbers)
  end

  def set_invoice
    @invoice = store_invoices.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to store_admin_invoices_path, alert: 'Invoice not found for this store.'
  end

  def related_booking
    return nil if @invoice.invoice_number.blank?
    @current_store.bookings.find_by(invoice_number: @invoice.invoice_number)
  end

  def booking_numbers_lookup(invoices)
    numbers = invoices.map(&:invoice_number).compact
    return {} if numbers.empty?
    Booking.where(invoice_number: numbers).pluck(:invoice_number, :booking_number).to_h
  end

  def invoice_params
    params.require(:invoice).permit(
      :invoice_date, :due_date, :status, :payment_status, :delivery_charge,
      invoice_items_attributes: [:id, :description, :quantity, :unit_price, :_destroy]
    )
  end
end

class Admin::BookingInvoicesController < Admin::ApplicationController
  before_action :authenticate_user!
  before_action :set_booking_invoice, only: [:show, :edit, :update, :destroy, :download_pdf, :mark_paid]

  def index
    # Get pagination settings from system settings
    @per_page = SystemSetting.default_pagination_per_page

    @booking_invoices = BookingInvoice.includes(:booking, :customer)
                                     .recent
                                     .page(params[:page])
                                     .per(@per_page)

    # Apply filters
    if params[:search].present?
      @booking_invoices = @booking_invoices.where(
        "invoice_number LIKE ? OR notes LIKE ?",
        "%#{params[:search]}%", "%#{params[:search]}%"
      )
    end

    if params[:payment_status].present?
      @booking_invoices = @booking_invoices.where(payment_status: params[:payment_status])
    end

    if params[:status].present?
      @booking_invoices = @booking_invoices.where(status: params[:status])
    end
  end

  def show
    @booking = @booking_invoice.booking
    @customer = @booking_invoice.customer || @booking.customer
    @invoice_items = @booking_invoice.parsed_invoice_items
  end

  def edit
  end

  def update
    if @booking_invoice.update(booking_invoice_params)
      redirect_to admin_booking_invoice_path(@booking_invoice),
                  notice: 'Invoice updated successfully!'
    else
      render :edit
    end
  end

  def destroy
    @booking_invoice.destroy
    redirect_to admin_booking_invoices_path,
                notice: 'Invoice deleted successfully!'
  end

  def mark_paid
    @booking_invoice.mark_as_paid!
    redirect_to admin_booking_invoice_path(@booking_invoice),
                notice: 'Invoice marked as paid!'
  end

  def download_pdf
    respond_to do |format|
      format.pdf do
        render pdf: "invoice-#{@booking_invoice.invoice_number}",
               template: 'admin/booking_invoices/pdf',
               layout: 'pdf',
               show_as_html: params[:debug].present?
      end
    end
  end

  private

  def set_booking_invoice
    @booking_invoice = BookingInvoice.includes(:booking, :customer).find(params[:id])
  end

  def booking_invoice_params
    params.require(:booking_invoice).permit(
      :invoice_date, :due_date, :notes, :payment_status, :status
    )
  end
end

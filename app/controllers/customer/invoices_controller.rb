class Customer::InvoicesController < Customer::BaseController
  before_action :set_booking_invoice, only: [:show, :download]

  def index
    # Get current customer
    customer = current_customer

    # Get all bookings with invoices
    @all_invoices = customer.bookings
      .where.not(invoice_number: [nil, ''])
      .includes(:customer, :user, :booking_items, :franchise)

    @invoices = @all_invoices.recent

    # Apply filters
    if params[:search].present?
      @invoices = @invoices.where(
        "invoice_number LIKE ? OR booking_number LIKE ? OR customer_name LIKE ?",
        "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%"
      )
    end

    if params[:payment_status].present? && params[:payment_status].strip != ''
      @invoices = @invoices.where(payment_status: params[:payment_status])
    end

    if params[:status].present? && params[:status].strip != ''
      @invoices = @invoices.where(status: params[:status])
    end

    if params[:date_from].present? && params[:date_to].present?
      @invoices = @invoices.where(created_at: params[:date_from]..params[:date_to])
    end

    # Get pagination settings
    @per_page = SystemSetting.default_pagination_per_page || 20

    # Paginate the filtered results
    @invoices = @invoices.page(params[:page]).per(@per_page)

    # Use all_invoices for statistics
    @invoices_for_stats = @all_invoices
  end

  def show
    @invoice_items = @invoice.booking_items.includes(product: [:category, image_attachment: :blob])
  end

  def download
    respond_to do |format|
      format.pdf do
        pdf = WickedPdf.new.pdf_from_string(
          render_to_string('customer/invoices/show', layout: 'invoice_pdf'),
          page_size: 'A4',
          margin: {
            top: '0.75in',
            bottom: '0.75in',
            left: '0.75in',
            right: '0.75in'
          },
          dpi: 300,
          encoding: 'UTF-8',
          disable_smart_shrinking: true,
          print_media_type: true,
          orientation: 'Portrait'
        )

        invoice_filename = "invoice-#{@invoice.invoice_number}-#{Date.current.strftime('%Y%m%d')}.pdf"

        send_data pdf,
                  filename: invoice_filename,
                  type: 'application/pdf',
                  disposition: 'attachment'
      end
    end
  end

  private

  def set_booking_invoice
    # Ensure customer can only access their own invoice bookings
    @invoice = current_customer.bookings.where.not(invoice_number: [nil, '']).find(params[:id])
    @business_settings = SystemSetting.business_settings
  rescue ActiveRecord::RecordNotFound
    redirect_to customer_invoices_path, alert: 'Invoice not found.'
  end
end
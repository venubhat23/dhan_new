class Customer::OrdersController < Customer::BaseController
  before_action :set_booking, only: [:show, :invoice]

  def index
    # Get current customer
    customer = current_customer

    # Start with customer's bookings only - same as admin but filtered by customer
    @all_bookings = customer.bookings.includes(:customer, :user, :booking_items, :franchise)
    @bookings = @all_bookings.recent

    # Apply filters (same as admin but for customer's bookings only)
    if params[:search].present?
      @bookings = @bookings.where(
        "booking_number LIKE ? OR customer_name LIKE ? OR customer_email LIKE ? OR customer_phone LIKE ?",
        "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%"
      )
    end

    if params[:status].present? && params[:status].strip != ''
      @bookings = @bookings.where(status: params[:status])
    end

    if params[:date_from].present? && params[:date_to].present?
      @bookings = @bookings.where(created_at: params[:date_from]..params[:date_to])
    end

    # Get pagination settings from system settings
    @per_page = SystemSetting.default_pagination_per_page || 20

    # Paginate the filtered results
    @bookings = @bookings.page(params[:page]).per(@per_page)

    # Use all_bookings for statistics cards to show customer's complete picture
    @bookings_for_stats = @all_bookings
  end

  def show
    @booking_items = @booking.booking_items.includes(product: [:category, image_attachment: :blob, additional_images_attachments: :blob])
  end

  def invoice
    respond_to do |format|
      format.html { render template: 'customer/orders/invoice', layout: 'invoice' }
      format.pdf do
        pdf = WickedPdf.new.pdf_from_string(
          render_to_string('customer/orders/invoice', formats: [:html], layout: 'invoice_pdf'),
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

        invoice_filename = "invoice-#{@booking.invoice_number || @booking.booking_number}-#{Date.current.strftime('%Y%m%d')}.pdf"

        send_data pdf,
                  filename: invoice_filename,
                  type: 'application/pdf',
                  disposition: 'attachment'
      end
    end
  end

  private

  def set_booking
    # Ensure customer can only access their own bookings
    @booking = current_customer.bookings.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to customer_orders_path, alert: 'Order not found.'
  end
end
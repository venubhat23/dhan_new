class BookingInvoicesController < ActionController::Base
  # Public controller - no authentication required
  layout false
  protect_from_forgery with: :exception

  before_action :load_invoice, only: [:public_view, :public_download_pdf]

  # The figures always come from the live booking, never the BookingInvoice's
  # snapshot taken at creation, so this matches the admin invoice after edits.
  def public_view
    return render(template: 'booking_invoices/not_found') unless @invoice

    @business = SystemSetting.business_settings
    @pdf_url = public_invoice_download_url(token: @invoice.share_token)
    render template: 'public_bookings/show', layout: 'invoice'
  end

  def test
    render plain: "BookingInvoicesController is working! Time: #{Time.current}"
  end

  def public_download_pdf
    return redirect_to(root_path, alert: 'Invoice not found') unless @invoice

    # Same template and PDF settings as the admin "Download PDF".
    @public_view = true
    pdf = WickedPdf.new.pdf_from_string(
      render_to_string(template: 'admin/bookings/invoice', formats: [:html], layout: 'invoice_pdf'),
      page_size: 'A4',
      margin: { top: '0.75in', bottom: '0.75in', left: '0.75in', right: '0.75in' },
      dpi: 300,
      encoding: 'UTF-8',
      disable_smart_shrinking: true,
      print_media_type: true,
      orientation: 'Portrait'
    )

    send_data pdf,
              filename: "invoice-#{@invoice.invoice_number}.pdf",
              type: 'application/pdf',
              disposition: 'attachment'
  end

  private

  def load_invoice
    @invoice = BookingInvoice.find_by(share_token: params[:token])
    @booking = Booking.includes(:customer, booking_items: [:product, :product_variant]).find_by(id: @invoice.booking_id) if @invoice
  end
end

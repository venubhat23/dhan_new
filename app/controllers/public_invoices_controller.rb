# app/controllers/public_invoices_controller.rb
class PublicInvoicesController < ApplicationController
  include ActionController::MimeResponds

  # Skip authentication for all actions in this controller
  skip_before_action :authenticate_user!
  # Skip CanCan load_and_authorize_resource since this controller doesn't follow standard resource naming
  skip_load_and_authorize_resource
  layout false

  before_action :find_invoice, only: [:show]

  private

  def find_invoice
    @invoice = Invoice.find_by!(share_token: params[:token])
    @customer = @invoice.customer
    @business_settings = SystemSetting.business_settings
  end

  public

  def show
    respond_to do |format|
      format.html do
        # Same invoice template as the admin page and the PDF, so totals match.
        @invoice_items = @invoice.invoice_items.includes(:product, :product_variant, :milk_delivery_task)
        @public_view = true
        render template: 'admin/invoices/show'
      end
      format.pdf do
        # Same full invoice as the admin "Download PDF".
        @invoice_items = @invoice.invoice_items.includes(:product, :product_variant, :milk_delivery_task)
        pdf = WickedPdf.new.pdf_from_string(
          render_to_string(template: 'admin/invoices/show', formats: [:html], layout: false),
          page_size: 'A4',
          margin: { top: '0.25in', bottom: '0.25in', left: '0.25in', right: '0.25in' },
          dpi: 300,
          encoding: 'UTF-8',
          disable_smart_shrinking: true,
          print_media_type: true,
          orientation: 'Portrait',
          zoom: 1.2 # fill the A4 page instead of a small block at the top
        )

        send_data pdf,
                  filename: "invoice-#{@invoice.invoice_number}.pdf",
                  type: 'application/pdf',
                  disposition: 'attachment'
      end
    end
  rescue ActiveRecord::RecordNotFound
    render template: 'public_invoices/not_found', status: :not_found
  end

  def index
    # Start with optimized base query for regular invoices - include all needed associations
    @invoices = Invoice.includes(:customer)

    # Apply filters
    if params[:customer_name].present?
      # Use case-insensitive search that works across databases
      search_term = "%#{params[:customer_name].downcase}%"
      @invoices = @invoices.joins(:customer)
                          .where("LOWER(customers.full_name) LIKE ?", search_term)
    end

    if params[:month].present? && params[:month] != 'all'
      @invoices = @invoices.where("EXTRACT(MONTH FROM invoice_date) = ?", params[:month].to_i)
    end

    if params[:status].present? && params[:status] != 'all'
      @invoices = @invoices.where(status: params[:status])
    end

    # Apply sorting
    case params[:sort_by]
    when 'amount_high_to_low'
      @invoices = @invoices.order(total_amount: :desc, created_at: :desc)
    when 'amount_low_to_high'
      @invoices = @invoices.order(total_amount: :asc, created_at: :desc)
    when 'date_newest'
      @invoices = @invoices.order(created_at: :desc)
    when 'date_oldest'
      @invoices = @invoices.order(created_at: :asc)
    else
      # Default: sort by highest amount first
      @invoices = @invoices.order(total_amount: :desc, created_at: :desc)
    end

    # Execute query and get results
    @invoices = @invoices.to_a

    # Batch update share tokens for invoices that don't have them
    invoices_without_tokens = @invoices.select { |invoice| invoice.share_token.blank? }
    if invoices_without_tokens.any?
      Invoice.transaction do
        invoices_without_tokens.each do |invoice|
          invoice.generate_share_token!
        end
      end
    end

    # Cache total count to avoid repeated queries
    @total_invoice_count = @invoices.size
  end

  def complete
    @invoice = Invoice.find(params[:id])

    if @invoice.update(status: 'paid', payment_status: 'fully_paid', paid_at: Time.current)
      render json: {
        success: true,
        message: "Invoice ##{@invoice.invoice_number} marked as completed successfully!"
      }
    else
      render json: {
        success: false,
        message: "Failed to complete invoice: #{@invoice.errors.full_messages.join(', ')}"
      }
    end
  rescue ActiveRecord::RecordNotFound
    render json: {
      success: false,
      message: "Invoice not found"
    }, status: :not_found
  end

  def destroy
    @invoice = Invoice.find(params[:id])
    invoice_number = @invoice.invoice_number

    # Delete the invoice
    @invoice.destroy!

    render json: {
      success: true,
      message: "Invoice ##{invoice_number} and all associated items deleted successfully!"
    }
  rescue ActiveRecord::RecordNotFound
    render json: {
      success: false,
      message: "Invoice not found"
    }, status: :not_found
  rescue => e
    render json: {
      success: false,
      message: "Failed to delete invoice: #{e.message}"
    }, status: :unprocessable_entity
  end
end
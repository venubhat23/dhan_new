class VendorInvoicesController < ApplicationController
  skip_before_action :authenticate_user!
  skip_authorization_check
  layout false

  def public_view
    @vendor_invoice = VendorInvoice.find_by!(share_token: params[:token])
    @vendor_purchase = @vendor_invoice.vendor_purchase
    @vendor = @vendor_invoice.vendor
    @purchase_items = @vendor_invoice.purchase_items.includes(:product)

    respond_to do |format|
      format.html
      format.pdf do
        render pdf: "vendor_invoice_#{@vendor_invoice.invoice_number}",
               page_size: 'A4',
               template: 'vendor_invoices/public_view.html.erb',
               layout: false,
               show_as_html: params[:debug].present?
      end
    end
  rescue ActiveRecord::RecordNotFound
    render plain: "Invoice not found", status: :not_found
  end
end

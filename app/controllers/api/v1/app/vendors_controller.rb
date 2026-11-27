# Admin app — vendors and vendor purchases (same VendorPurchase model logic as
# /admin/vendor_purchases: saving a purchase creates its stock batches).
class Api::V1::App::VendorsController < Api::V1::App::BaseController
  before_action :require_admin!

  # GET /vendors?q=&active=1
  def index
    scope = Vendor.all
    scope = scope.where(status: true) if params[:active] == '1'
    if params[:q].present?
      q = "%#{Vendor.sanitize_sql_like(params[:q].strip)}%"
      scope = scope.where('name ILIKE :q OR phone ILIKE :q', q: q)
    end
    rows, meta = paginate(scope.order(:name))
    render_success(rows.map { |v| vendor_json(v) }, meta: meta)
  end

  # POST /vendors { "vendor": { "name": "", "phone": "", "email": "", "address": "", "gst_no": "", "payment_type": "Paid" } }
  def create
    vendor = Vendor.new(params.require(:vendor).permit(:name, :phone, :email, :address, :gst_no, :payment_type, :opening_balance))
    vendor.payment_type = 'Paid' if vendor.payment_type.blank?
    vendor.status = true if vendor.status.nil?
    vendor.save!
    render_success(vendor_json(vendor), message: 'Vendor created', status: :created)
  end

  # GET /vendor_purchases?vendor_id=&payment_status=unpaid&page=
  def purchases
    scope = VendorPurchase.includes(:vendor)
    scope = scope.where(vendor_id: params[:vendor_id]) if params[:vendor_id].present?
    scope = scope.where(status: params[:status]) if params[:status].present?
    rows, meta = paginate(scope.order(purchase_date: :desc, id: :desc))
    data = rows.map { |vp| vendor_purchase_json(vp) }
    data = data.select { |h| h[:payment_status].to_s == params[:payment_status] } if params[:payment_status].present?
    render_success(data, meta: meta)
  end

  # GET /vendor_purchases/:id
  def purchase
    vp = VendorPurchase.includes(:vendor, vendor_purchase_items: [:product, :product_variant]).find(params[:id])
    render_success(vendor_purchase_json(vp, full: true))
  end

  # POST /vendor_purchases
  # { "vendor_purchase": { "vendor_id": 1, "purchase_date": "2026-11-27", "paid_amount": 0, "payment_mode": "cash",
  #   "notes": "", "items": [{ "product_id": 5, "product_variant_id": null, "quantity": 10, "purchase_price": 40, "selling_price": 60 }] } }
  def create_purchase
    vp_params = params.require(:vendor_purchase)
    items = Array(vp_params[:items])
    return render_error('Add at least one item') if items.empty?

    vp = VendorPurchase.new(vp_params.permit(:vendor_id, :purchase_date, :notes, :paid_amount, :payment_mode))
    vp.purchase_date ||= Date.current
    vp.paid_amount ||= 0
    vp.status = 'pending'
    items.each do |it|
      product = Product.find(it[:product_id])
      variant = product.product_variants.find(it[:product_variant_id]) if it[:product_variant_id].present?
      vp.vendor_purchase_items.build(
        product: product, product_variant: variant, quantity: it[:quantity],
        purchase_price: it[:purchase_price].presence || (variant || product).try(:buying_price),
        selling_price: it[:selling_price].presence || (variant ? variant.selling_price : product.price)
      )
    end
    vp.save!
    render_success(vendor_purchase_json(vp.reload, full: true), message: 'Purchase created and stock added', status: :created)
  end

  # POST /vendor_purchases/:id/mark_paid  { "payment_mode": "upi" }  — pays the full balance
  def mark_purchase_paid
    vp = VendorPurchase.find(params[:id])
    return render_error('Purchase is already fully paid') if vp.payment_status == 'paid'

    attrs = { paid_amount: vp.total_amount }
    attrs[:payment_mode] = params[:payment_mode] if VendorPurchase::PAYMENT_MODES.key?(params[:payment_mode].to_s)
    vp.update!(attrs)
    render_success(vendor_purchase_json(vp.reload), message: 'Purchase marked as fully paid')
  end
end

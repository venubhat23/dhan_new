# Admin app — products: type-ahead search, edit, stock adjustment, price list.
class Api::V1::App::ProductsController < Api::V1::App::BaseController
  before_action :require_admin!
  before_action :set_product, only: [:show, :update, :adjust_stock, :stock_history]

  # GET /products?q=tom&category_id=&status=active&in_stock=1&low_stock=1&page=&per_page=
  # q matches name / SKU / barcode, so the app can search as the user types.
  def index
    scope = Product.includes(:category, :product_variants)
                   .select("products.*, (#{Product::REAL_STOCK_SQL}) AS cached_stock")
    scope = scope.where(status: params[:status]) if params[:status].present?
    scope = scope.where(category_id: params[:category_id]) if params[:category_id].present?
    if params[:q].present?
      q = "%#{Product.sanitize_sql_like(params[:q].strip)}%"
      scope = scope.where('products.name ILIKE :q OR products.sku ILIKE :q OR products.barcode ILIKE :q', q: q)
    end
    scope = scope.where("(#{Product::REAL_STOCK_SQL}) > 0") if params[:in_stock] == '1'
    if params[:low_stock] == '1'
      scope = scope.where("(#{Product::REAL_STOCK_SQL}) <= COALESCE(products.low_stock_threshold, 0)")
    end
    rows, meta = paginate(scope.order('products.name'))
    render_success(rows.map { |p| product_json(p) }, meta: meta)
  end

  # GET /products/:id
  def show
    render_success(product_json(@product, full: true))
  end

  # PATCH /products/:id
  # { "product": { "name": "...", "price": 120, "buying_price": 90, "b2b_price": 110,
  #   "low_stock_threshold": 5, "status": "active", "category_id": 2, "description": "...",
  #   "variants": [{ "id": 7, "selling_price": 60, "buying_price": 45, "b2b_price": 55, "low_stock_threshold": 3 }] } }
  # Stock is not edited here — use POST /products/:id/stock.
  def update
    pp = params.require(:product)
    attrs = pp.permit(:name, :description, :category_id, :price, :buying_price, :purchase_price, :b2b_price,
                      :low_stock_threshold, :status, :sku, :hsn_code, :unit_type, :gst_enabled, :gst_percentage, :barcode).to_h
    ActiveRecord::Base.transaction do
      @product.update!(attrs) if attrs.any?
      Array(pp[:variants]).each do |v|
        variant = @product.product_variants.find(v[:id])
        variant.update!(v.permit(:selling_price, :buying_price, :purchase_price, :b2b_price, :low_stock_threshold, :weight, :unit).to_h)
      end
    end
    render_success(product_json(@product.reload, full: true), message: 'Product updated')
  end

  # POST /products/:id/stock
  # { "mode": "set" | "add" | "remove", "quantity": 25, "product_variant_id": null,
  #   "cost_price": 40, "note": "recount" }
  def adjust_stock
    variant = @product.product_variants.find(params[:product_variant_id]) if params[:product_variant_id].present?
    result = StockAdjustment.new(product: @product, variant: variant, mode: params[:mode].presence || 'set',
                                 quantity: params[:quantity], cost_price: params[:cost_price],
                                 selling_price: params[:selling_price], note: params[:note]).call
    render_success(result.merge(product: product_json(@product.reload)),
                   message: result[:change].zero? ? 'No change' : "Stock updated to #{result[:new_stock]}")
  rescue StockAdjustment::Error => e
    render_error(e.message, :unprocessable_entity)
  end

  # GET /products/:id/stock_history
  def stock_history
    rows = @product.stock_movements.order(created_at: :desc).limit(50).map do |m|
      { id: m.id, type: m.movement_type, reference: m.reference_type, quantity: m.quantity.to_f,
        stock_before: m.stock_before.to_f, stock_after: m.stock_after.to_f, notes: m.notes, at: m.created_at.iso8601 }
    end
    render_success(rows)
  end

  # GET /price_list?category_id=&q=   — active products grouped by category
  def price_list
    scope = Product.active.includes(:category, :product_variants)
                   .select("products.*, (#{Product::REAL_STOCK_SQL}) AS cached_stock")
    scope = scope.where(category_id: params[:category_id]) if params[:category_id].present?
    if params[:q].present?
      q = "%#{Product.sanitize_sql_like(params[:q].strip)}%"
      scope = scope.where('products.name ILIKE :q OR products.sku ILIKE :q', q: q)
    end
    grouped = scope.order('products.name').group_by(&:category)
    data = grouped.sort_by { |cat, _| cat&.name.to_s }.map do |cat, products|
      { category_id: cat&.id, category: cat&.name || 'Uncategorised',
        products: products.map do |p|
          { id: p.id, name: p.name, unit: p.unit_type, price: money(p.price), b2b_price: p.b2b_price&.to_f,
            stock: product_stock(p),
            variants: p.has_multiple_quantities? ? p.sorted_variants.map { |v| { id: v.id, label: v.label, price: money(v.selling_price), b2b_price: v.b2b_price&.to_f, stock: v.available_stock.to_f } } : [] }
        end }
    end
    render_success(data)
  end

  # GET /categories
  def categories
    render_success(Category.order(:name).map { |c| { id: c.id, name: c.name, status: c.status } })
  end

  private

  def set_product
    @product = Product.includes(:category, :product_variants).find(params[:id])
  end
end

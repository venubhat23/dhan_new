class StoreAdmin::StoreInventoryController < StoreAdmin::ApplicationController
  before_action :ensure_can_manage_inventory!

  # Product-by-product (and variant-by-variant) stock picture for the current
  # store, with a low-stock flag per row.
  def index
    @products = store_products.includes(:category, :product_variants).order(:name)

    if params[:search].present?
      term = "%#{params[:search].to_s.strip}%"
      # Pushed into SQL (was loading every store product into Ruby and
      # filtering with String#include?) — uses the existing trigram indexes
      # on products.name / products.sku.
      @products = @products.where('products.name ILIKE :q OR products.sku ILIKE :q', q: term)
    end

    all_rows = build_rows(@products)
    @low_stock_count = all_rows.count { |r| r[:low_stock] }
    # The table itself renders one page at a time — this store's full history
    # of stocked/sold products could otherwise mean rendering thousands of
    # rows on a single request.
    @rows = Kaminari.paginate_array(all_rows).page(params[:page]).per(100)
  end

  # CSV of the current store's low-stock rows (quantity <= threshold).
  def low_stock_csv
    products = store_products.includes(:category, :product_variants).order(:name)
    rows = build_rows(products).select { |r| r[:low_stock] }

    require 'csv'
    csv = CSV.generate do |csv|
      csv << ['Product', 'SKU', 'Category', 'Variant', 'Current Stock', 'Unit', 'Low Stock Threshold']
      rows.each do |row|
        product = row[:product]
        variant = row[:variant]
        csv << [
          product.name,
          product.sku,
          product.category&.name,
          variant&.label,
          row[:quantity].round(2),
          variant&.unit || product.unit_type,
          row[:threshold].round(2)
        ]
      end
    end

    send_data csv,
              filename: "low-stock-#{@current_store.name.parameterize}-#{Date.current}.csv",
              type: 'text/csv'
  end

  private

  # Builds low-stock-flagged rows (one per product, or per variant for
  # products with variants) for the given product scope in the current store.
  def build_rows(products)
    inv_by_key = @current_store.store_inventories.each_with_object({}) do |row, h|
      h[[row.product_id, row.product_variant_id]] = row
    end

    # Active batch stock per product (store + unassigned batches) — fallback
    # for products with no store_inventories row.
    batch_stock = @current_store.stock_batches
                                .where(status: 'active')
                                .group(:product_id).sum(:quantity_remaining)

    default_threshold = @current_store.auto_transfer_threshold || 10

    rows = []
    products.each do |product|
      if product.product_variants.any?
        product.sorted_variants.each do |variant|
          row = inv_by_key[[product.id, variant.id]]
          qty = row ? row.quantity.to_f : variant.available_stock.to_f
          threshold = row&.low_stock_threshold || product.low_stock_threshold || default_threshold
          rows << build_row(product, variant, qty, threshold)
        end
      else
        row = inv_by_key[[product.id, nil]]
        qty = row ? row.quantity.to_f : batch_stock[product.id].to_f
        threshold = row&.low_stock_threshold || product.low_stock_threshold || default_threshold
        rows << build_row(product, nil, qty, threshold)
      end
    end
    rows
  end

  def build_row(product, variant, qty, threshold)
    { product: product, variant: variant, quantity: qty,
      threshold: threshold.to_f, low_stock: qty <= threshold.to_f }
  end

  def ensure_can_manage_inventory!
    unless current_user.can_manage_inventory?
      flash[:alert] = 'You do not have permission to manage inventory.'
      redirect_to store_admin_root_path
    end
  end
end

class StoreAdmin::StoreInventoryController < StoreAdmin::ApplicationController
  before_action :ensure_can_manage_inventory!

  # Product-by-product (and variant-by-variant) stock picture for the current
  # store, with a low-stock flag per row.
  def index
    @products = store_products.includes(:category, :product_variants).order(:name)

    if params[:search].present?
      term = params[:search].to_s.strip.downcase
      @products = @products.select do |p|
        p.name.to_s.downcase.include?(term) || p.sku.to_s.downcase.include?(term)
      end
    end

    # Store-inventory rows for this store, keyed by [product_id, variant_id].
    @inv_by_key = @current_store.store_inventories.each_with_object({}) do |row, h|
      h[[row.product_id, row.product_variant_id]] = row
    end

    # Active batch stock per product (store + unassigned batches) — fallback
    # for products with no store_inventories row.
    @batch_stock = @current_store.stock_batches
                                 .where(status: 'active')
                                 .group(:product_id).sum(:quantity_remaining)

    @default_threshold = @current_store.auto_transfer_threshold || 10

    @rows = []
    @products.each do |product|
      if product.has_multiple_quantities? && product.product_variants.any?
        product.sorted_variants.each do |variant|
          row = @inv_by_key[[product.id, variant.id]]
          qty = row ? row.quantity.to_f : variant.available_stock.to_f
          threshold = row&.low_stock_threshold || product.low_stock_threshold || @default_threshold
          @rows << build_row(product, variant, qty, threshold)
        end
      else
        row = @inv_by_key[[product.id, nil]]
        qty = row ? row.quantity.to_f : @batch_stock[product.id].to_f
        threshold = row&.low_stock_threshold || product.low_stock_threshold || @default_threshold
        @rows << build_row(product, nil, qty, threshold)
      end
    end

    @low_stock_count = @rows.count { |r| r[:low_stock] }
  end

  private

  def build_row(product, variant, qty, threshold)
    { product: product, variant: variant, quantity: qty,
      threshold: threshold.to_f, low_stock: qty <= threshold.to_f }
  end

  # Products with an active stock batch or store inventory row for this store,
  # plus anything this store has actually sold. Mirrors StoreAdmin::ProductsController.
  def store_products
    product_ids = @current_store.stock_batches.where(status: 'active').pluck(:product_id)
    product_ids |= @current_store.store_inventories.pluck(:product_id)
    product_ids |= BookingItem.where(booking_id: @current_store.bookings.select(:id)).pluck(:product_id)
    Product.where(id: product_ids.compact.uniq)
  end

  def ensure_can_manage_inventory!
    unless current_user.can_manage_inventory?
      flash[:alert] = 'You do not have permission to manage inventory.'
      redirect_to store_admin_root_path
    end
  end
end

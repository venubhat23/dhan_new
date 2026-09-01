class StoreAdmin::ProductsController < StoreAdmin::ApplicationController
  before_action :set_product, only: [:show, :edit, :update, :destroy]
  before_action :load_categories, only: [:new, :create, :edit, :update]

  # Products that are stocked at (or have been sold by) the current store.
  def index
    scope = store_products

    if params[:search].present?
      term = "%#{params[:search].strip}%"
      scope = scope.where('products.name ILIKE ? OR products.sku ILIKE ?', term, term)
    end

    scope = scope.where(status: params[:status]) if params[:status].present?

    @products = scope.includes(:category).order(:name)
    @products = @products.page(params[:page]).per(20) if @products.respond_to?(:page)

    # Store on-hand per product: prefer store_inventories, fall back to active batches.
    inv_stock = @current_store.store_inventories.group(:product_id).sum(:quantity)
    batch_stock = @current_store.stock_batches.where(status: 'active')
                                .group(:product_id).sum(:quantity_remaining)
    @store_stock = batch_stock.merge(inv_stock)
    @total_products = store_products.count
  end

  def show
    @store_quantity = @current_store.available_stock_for(@product.id)
    @recent_bookings = @current_store.bookings
                                     .joins(:booking_items)
                                     .where(booking_items: { product_id: @product.id })
                                     .distinct.order(created_at: :desc).limit(10)
  end

  def new
    @product = Product.new(status: 'active')
  end

  def create
    @product = Product.new(product_params)

    if @product.save
      carry_product_at_store(@product, initial_stock: @product.stock.to_f)
      redirect_to store_admin_product_path(@product), notice: 'Product created successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @product.update(product_params)
      carry_product_at_store(@product)
      redirect_to store_admin_product_path(@product), notice: 'Product updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @product.destroy
      redirect_to store_admin_products_path, notice: 'Product deleted successfully.'
    else
      redirect_to store_admin_product_path(@product),
                  alert: @product.errors.full_messages.to_sentence.presence || 'Unable to delete product.'
    end
  rescue ActiveRecord::InvalidForeignKey
    redirect_to store_admin_product_path(@product),
                alert: 'Cannot delete a product that is referenced by bookings or invoices.'
  end

  private

  # Products with an active stock batch or store inventory row for this store,
  # plus anything this store has actually sold.
  def store_products
    product_ids = @current_store.stock_batches.where(status: 'active').pluck(:product_id)
    product_ids |= @current_store.store_inventories.pluck(:product_id)
    product_ids |= BookingItem.where(booking_id: @current_store.bookings.select(:id)).pluck(:product_id)
    Product.where(id: product_ids.compact.uniq)
  end

  def set_product
    @product = store_products.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to store_admin_products_path, alert: 'Product not found for this store.'
  end

  # Make sure a product created/edited here shows up under this store: attribute any
  # unassigned stock batches (the ones Product's own callbacks just created for the
  # entered stock) to this store, and keep a store_inventories row in sync.
  def carry_product_at_store(product, initial_stock: nil)
    # Only the batches Product's own callbacks just created in this request — never
    # pre-existing unassigned (website) stock.
    product.stock_batches.where(store_id: nil).where('created_at > ?', 2.minutes.ago)
           .update_all(store_id: @current_store.id)

    row = @current_store.store_inventories
                        .find_or_initialize_by(product_id: product.id, product_variant_id: nil)
    row.low_stock_threshold = product.low_stock_threshold if row.new_record?
    on_hand = @current_store.stock_batches
                            .where(product_id: product.id, status: 'active')
                            .sum(:quantity_remaining)
    row.quantity = on_hand.positive? ? on_hand : (initial_stock.to_f.positive? ? initial_stock.to_f : row.quantity.to_f)
    row.save
  rescue => e
    Rails.logger.error "carry_product_at_store failed for product #{product.id}: #{e.message}"
  end

  def load_categories
    @categories = Category.order(:display_order, :name)
  end

  def product_params
    params.require(:product).permit(
      :name, :sku, :barcode, :category_id, :description,
      :price, :buying_price, :purchase_price, :discount_price,
      :unit_type, :status, :low_stock_threshold, :stock, :hsn_code
    )
  end
end

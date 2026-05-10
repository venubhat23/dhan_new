class StoreAdmin::InventoryController < StoreAdmin::ApplicationController
  before_action :ensure_can_manage_inventory!

  def index
    @batches = @current_store.stock_batches
                             .includes(:product)
                             .where(status: 'active')
                             .where('quantity_remaining > 0')
                             .order('products.name ASC')
                             .joins(:product)

    # Group by product for display
    @inventory = @batches.group_by(&:product)

    # Low stock products
    threshold = @current_store.auto_transfer_threshold || 10
    @low_stock_product_ids = @current_store.stock_batches
                                           .where(status: 'active')
                                           .group(:product_id)
                                           .having('SUM(quantity_remaining) <= ?', threshold)
                                           .pluck(:product_id)

    @summary = @current_store.store_inventory_summary
  end

  def new
    @products = Product.active.by_stock_availability
    @vendors = Vendor.order(:name) rescue []
  end

  def create
    product = Product.find(params[:product_id])
    quantity = params[:quantity].to_f
    purchase_price = params[:purchase_price].to_f
    selling_price = params[:selling_price].to_f.nonzero? || product.price.to_f
    vendor_id = params[:vendor_id].presence || Vendor.first&.id

    if quantity <= 0
      flash[:alert] = 'Quantity must be greater than 0.'
      redirect_to new_store_admin_inventory_path and return
    end

    batch = StockBatch.new(
      product: product,
      vendor_id: vendor_id,
      store_id: @current_store.id,
      quantity_purchased: quantity,
      quantity_remaining: quantity,
      purchase_price: purchase_price.nonzero? || product.buying_price || 1,
      selling_price: selling_price,
      batch_date: Date.current,
      status: 'active'
    )

    if batch.save
      flash[:notice] = "#{quantity} units of #{product.name} added to #{@current_store.name} inventory."
      redirect_to store_admin_inventory_index_path
    else
      flash[:alert] = "Failed: #{batch.errors.full_messages.join(', ')}"
      redirect_to new_store_admin_inventory_path
    end
  end

  def movements
    product_ids = @current_store.stock_batches.pluck(:product_id).uniq
    @movements = StockMovement.where(product_id: product_ids)
                              .includes(:product)
                              .order(created_at: :desc)
                              .limit(100)

    if params[:product_id].present?
      @movements = @movements.where(product_id: params[:product_id])
    end

    if params[:date_from].present?
      @movements = @movements.where('created_at >= ?', params[:date_from].to_date.beginning_of_day)
    end

    if params[:date_to].present?
      @movements = @movements.where('created_at <= ?', params[:date_to].to_date.end_of_day)
    end

    @products_in_store = Product.where(id: product_ids).order(:name)
  end

  def search_products
    q = params[:q].to_s.strip
    products = Product.active.where('name ILIKE ?', "%#{q}%").limit(15)

    render json: products.map { |p|
      store_stock = @current_store.available_stock_for(p.id)
      {
        id: p.id,
        name: p.name,
        sku: p.sku,
        price: p.price.to_f,
        store_stock: store_stock.to_f,
        unit_type: p.unit_type,
        has_variants: p.has_multiple_quantities?,
        variants: p.has_multiple_quantities? ? p.product_variants.order(:display_order, :weight).map { |v|
          { id: v.id, label: "#{v.weight} #{v.unit}", price: v.selling_price.to_f, stock: v.available_stock.to_f }
        } : []
      }
    }
  end

  def adjust
    @product = Product.find(params[:product_id])
    @current_stock = @current_store.available_stock_for(@product.id)
  end

  def update_adjustment
    product = Product.find(params[:product_id])
    adjustment = params[:adjustment].to_f
    reason = params[:reason].to_s.strip

    if adjustment == 0
      flash[:alert] = 'Adjustment cannot be zero.'
      redirect_to store_admin_inventory_index_path and return
    end

    if adjustment > 0
      # Add stock as a new batch
      vendor_id = Vendor.first&.id
      StockBatch.create!(
        product: product,
        vendor_id: vendor_id,
        store_id: @current_store.id,
        quantity_purchased: adjustment,
        quantity_remaining: adjustment,
        purchase_price: product.buying_price || 1,
        selling_price: product.price || 1,
        batch_date: Date.current,
        status: 'active'
      )
      flash[:notice] = "Added #{adjustment} units of #{product.name}."
    else
      # Remove stock via FIFO
      remove_qty = adjustment.abs
      available = @current_store.available_stock_for(product.id)
      if remove_qty > available
        flash[:alert] = "Cannot remove #{remove_qty}. Only #{available} available in this store."
        redirect_to store_admin_inventory_index_path and return
      end

      batches = @current_store.stock_batches.where(product: product, status: 'active')
                              .where('quantity_remaining > 0').order(:batch_date, :created_at)
      remaining = remove_qty
      batches.each do |batch|
        break if remaining <= 0
        deduct = [batch.quantity_remaining, remaining].min
        batch.reduce_stock!(deduct)
        remaining -= deduct
      end
      flash[:notice] = "Removed #{remove_qty} units of #{product.name}."
    end

    redirect_to store_admin_inventory_index_path
  end

  private

  def ensure_can_manage_inventory!
    unless current_user.can_manage_inventory?
      flash[:alert] = 'You do not have permission to manage inventory.'
      redirect_to store_admin_root_path
    end
  end
end

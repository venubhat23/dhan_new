class InventoryService
  class InsufficientStockError < StandardError; end
  class AllocationError < StandardError; end

  def self.allocate_stock(product_id, requested_quantity, store_id: nil)
    new.allocate_stock(product_id, requested_quantity, store_id: store_id)
  end

  def self.reduce_stock(allocations)
    new.reduce_stock(allocations)
  end

  def self.check_availability(product_id, requested_quantity, store_id: nil)
    new.check_availability(product_id, requested_quantity, store_id: store_id)
  end

  def allocate_stock(product_id, requested_quantity, store_id: nil)
    Product.find(product_id)

    allocation_result = StockBatch.fifo_allocation(product_id, requested_quantity, store_id: store_id)

    unless allocation_result[:fulfilled]
      available = total_available_stock(product_id, store_id: store_id)
      raise InsufficientStockError, "Insufficient stock. Available: #{available}, Requested: #{requested_quantity}, Shortage: #{allocation_result[:shortage]}"
    end

    allocation_result[:allocation]
  end

  def reduce_stock(allocations)
    ActiveRecord::Base.transaction do
      products_to_update = Set.new

      allocations.each do |allocation|
        batch = allocation[:batch]
        quantity = allocation[:quantity]

        unless batch.can_fulfill?(quantity)
          raise AllocationError, "Batch #{batch.batch_number} cannot fulfill quantity #{quantity}"
        end

        batch.reduce_stock!(quantity)
        products_to_update.add(batch.product)
      end

      # Update product stock for all affected products
      products_to_update.each do |product|
        product.update_column(:stock, product.total_batch_stock)
      end
    end
  rescue => e
    Rails.logger.error "Stock reduction failed: #{e.message}"
    raise AllocationError, "Failed to reduce stock: #{e.message}"
  end

  def check_availability(product_id, requested_quantity, store_id: nil)
    available_stock = total_available_stock(product_id, store_id: store_id)

    {
      available: available_stock >= requested_quantity,
      available_stock: available_stock,
      requested_quantity: requested_quantity,
      shortage: [requested_quantity - available_stock, 0].max
    }
  end

  def create_sale_items(order, allocations)
    sale_items = []

    allocations.each do |allocation|
      sale_item = SaleItem.create!(
        order: order,
        product: allocation[:batch].product,
        stock_batch: allocation[:batch],
        quantity: allocation[:quantity],
        selling_price: allocation[:selling_price],
        purchase_price: allocation[:purchase_price]
      )
      sale_items << sale_item
    end

    sale_items
  end

  def get_fifo_batches(product_id, store_id: nil)
    StockBatch.available_for_product(product_id, store_id: store_id)
  end

  def total_available_stock(product_id, store_id: nil)
    get_fifo_batches(product_id, store_id: store_id).sum(:quantity_remaining)
  end

  # Get stock summary for a product
  def product_stock_summary(product_id)
    product = Product.find(product_id)
    batches = get_fifo_batches(product_id)

    {
      product_id: product_id,
      product_name: product.name,
      total_available: batches.sum(:quantity_remaining),
      total_batches: batches.count,
      oldest_batch: batches.first&.batch_date,
      newest_batch: batches.last&.batch_date,
      batches: batches.map do |batch|
        {
          id: batch.id,
          batch_number: batch.batch_number,
          vendor_name: batch.vendor.name,
          quantity_remaining: batch.quantity_remaining,
          purchase_price: batch.purchase_price,
          selling_price: batch.selling_price,
          batch_date: batch.batch_date,
          status: batch.status
        }
      end
    }
  end

  # Get low stock products based on minimum stock alert
  def get_low_stock_products
    Product.joins(:stock_batches)
           .where.not(minimum_stock_alert: nil)
           .group('products.id')
           .having('SUM(CASE WHEN stock_batches.status = ? THEN stock_batches.quantity_remaining ELSE 0 END) < products.minimum_stock_alert', 'active')
           .includes(:stock_batches)
  end

  # Simulate stock allocation without actually reducing stock (for preview)
  def simulate_allocation(items)
    simulations = []

    items.each do |item|
      product_id = item[:product_id]
      quantity = item[:quantity]

      allocation_result = StockBatch.fifo_allocation(product_id, quantity)

      simulations << {
        product_id: product_id,
        product_name: Product.find(product_id).name,
        requested_quantity: quantity,
        can_fulfill: allocation_result[:fulfilled],
        shortage: allocation_result[:shortage],
        allocation_details: allocation_result[:allocation].map do |alloc|
          {
            batch_id: alloc[:batch].id,
            batch_number: alloc[:batch].batch_number,
            vendor_name: alloc[:batch].vendor.name,
            allocated_quantity: alloc[:quantity],
            purchase_price: alloc[:purchase_price],
            selling_price: alloc[:selling_price]
          }
        end
      }
    end

    simulations
  end

  # Get expiring batches (if expiry logic is added later)
  def get_expiring_batches(days = 30)
    # Placeholder for future expiry date functionality
    # For now, return old batches based on creation date
    StockBatch.active
              .where('created_at < ?', days.days.ago)
              .includes(:product, :vendor)
              .order(:created_at)
  end

  # Get vendor stock summary
  def vendor_stock_summary(vendor_id)
    vendor = Vendor.find(vendor_id)
    batches = vendor.stock_batches.active

    {
      vendor_id: vendor_id,
      vendor_name: vendor.name,
      total_products: batches.joins(:product).distinct.count('products.id'),
      total_quantity: batches.sum(:quantity_remaining),
      total_value: batches.sum { |b| b.quantity_remaining * b.purchase_price },
      batches_count: batches.count,
      products_summary: batches.joins(:product)
                              .group('products.id', 'products.name')
                              .sum(:quantity_remaining)
                              .map do |product_data, quantity|
        product_id, product_name = product_data
        {
          product_id: product_id,
          product_name: product_name,
          total_quantity: quantity
        }
      end
    }
  end
end
# Sets / adds / removes central (main store) stock for one product or variant,
# with the same rules as the Product Summary grid (Admin::ProductSummaryController):
# * an increase creates a StockBatch (needs a cost price) from "System Default"
# * a decrease draws central active batches down FIFO
# * simple products keep products.stock in step; variants keep available_stock
# * every change logs a StockMovement ('adjustment').
#
#   StockAdjustment.new(product:, variant: nil, mode: 'set'|'add'|'remove',
#                       quantity: 10, cost_price: nil, note: nil).call
#   # => { old_stock:, new_stock:, change: } or raises StockAdjustment::Error
class StockAdjustment
  class Error < StandardError; end

  MODES = %w[set add remove].freeze

  def initialize(product:, variant: nil, mode:, quantity:, cost_price: nil, selling_price: nil, note: nil)
    @product = product
    @variant = variant
    @mode = mode.to_s
    @quantity = quantity.to_f
    @cost_price = cost_price
    @selling_price = selling_price
    @note = note
  end

  def call
    raise Error, "mode must be one of #{MODES.join(', ')}" unless MODES.include?(@mode)
    raise Error, 'quantity must be 0 or more' if @quantity.negative?
    if @product.has_multiple_quantities? && @variant.nil?
      raise Error, 'This product has variants — pass product_variant_id'
    end

    old_stock = current_stock
    new_stock = case @mode
                when 'set' then @quantity
                when 'add' then old_stock + @quantity
                else old_stock - @quantity
                end
    raise Error, "Stock can't go below 0 (current #{fmt(old_stock)})" if new_stock.negative?

    delta = new_stock - old_stock
    return { old_stock: old_stock, new_stock: old_stock, change: 0 } if delta.zero?

    ActiveRecord::Base.transaction do
      applied = delta.positive? ? add_batch(delta) : -reduce_batches(delta.abs)
      final = old_stock + applied
      if @variant
        @variant.update_column(:available_stock, final.to_i)
      else
        @product.update_column(:stock, final)
      end
      log_movement(applied, final)
      { old_stock: old_stock, new_stock: final, change: applied }
    end
  end

  private

  def current_stock
    if @variant
      @variant.available_stock.to_f
    else
      @product.stock_batches.central.active.sum(:quantity_remaining).to_f
    end
  end

  def add_batch(delta)
    src = @variant || @product
    cost = (@cost_price.presence || src.try(:buying_price) || src.try(:purchase_price)).to_f
    sell = (@selling_price.presence || (@variant ? @variant.selling_price : @product.price)).to_f
    sell = cost if sell <= 0
    raise Error, 'Set a cost/buying price (cost_price) before adding stock' if cost <= 0

    @product.stock_batches.create!(
      vendor: default_vendor, store_id: nil, product_variant_id: @variant&.id,
      quantity_purchased: delta, quantity_remaining: delta,
      purchase_price: cost, selling_price: sell, batch_date: Date.current, status: 'active'
    )
    delta
  end

  def reduce_batches(amount)
    scope = @product.stock_batches.central.active.by_fifo
    scope = scope.where(product_variant_id: @variant.id) if @variant
    remaining = amount
    scope.each do |batch|
      break if remaining <= 0

      take = [batch.quantity_remaining, remaining].min
      batch.reduce_stock!(take)
      remaining -= take
    end
    # Variants can hold more on available_stock than their batches show (older
    # data); the column is still lowered by the full amount in that case.
    @variant ? amount : amount - remaining
  end

  def log_movement(delta, new_total)
    label = @variant ? "#{@product.name} #{@variant.label}" : @product.name
    @product.stock_movements.create!(
      reference_type: 'adjustment', reference_id: nil,
      movement_type: delta.positive? ? 'added' : 'adjusted',
      quantity: delta, stock_before: new_total - delta, stock_after: new_total,
      notes: ["Mobile app stock #{@mode}: #{label} → #{fmt(new_total)}", @note.presence].compact.join(' — ')
    )
  rescue => e
    Rails.logger.error "StockAdjustment movement log failed for Product ##{@product.id}: #{e.message}"
  end

  def default_vendor
    Vendor.find_or_create_by(name: 'System Default') do |v|
      v.email = 'system@default.com'
      v.phone = '0000000000'
      v.address = 'System Generated'
      v.payment_type = 'Paid'
      v.status = true
    end
  end

  def fmt(n) = n.to_f == n.to_i ? n.to_i.to_s : n.to_f.round(2).to_s
end

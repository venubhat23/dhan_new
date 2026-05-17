class BookingItem < ApplicationRecord
  belongs_to :booking
  belongs_to :product
  belongs_to :product_variant, optional: true

  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validate :check_stock_availability

  before_save :calculate_total
  after_create :reduce_product_stock
  after_update :handle_quantity_change, if: :saved_change_to_quantity?
  after_destroy :restore_product_stock

  def calculate_total
    self.total = quantity * price
  end

  private

  def check_stock_availability
    return unless quantity.present? && product.present?

    available_stock = stock_batches_scope.sum(:quantity_remaining)

    if persisted? && quantity_changed?
      available_stock += quantity_was
    end

    if quantity > available_stock
      store_label = booking_store_id.present? ? 'in this store' : 'in stock'
      errors.add(:quantity, "only #{available_stock.to_i} units available #{store_label}")
    end
  end

  def reduce_product_stock
    return unless quantity.present? && product.present?

    current_stock = stock_batches_scope.sum(:quantity_remaining)
    remaining_to_allocate = quantity.to_f

    stock_batches_scope.each do |batch|
      break if remaining_to_allocate <= 0

      if batch.quantity_remaining > 0
        allocation = [remaining_to_allocate, batch.quantity_remaining].min
        batch.quantity_remaining -= allocation
        remaining_to_allocate -= allocation
        batch.status = 'exhausted' if batch.quantity_remaining <= 0
        batch.save!

        Rails.logger.info "Allocated #{allocation} units from Batch ##{batch.id} (store: #{batch.store_id.inspect})"
      end
    end

    new_stock = stock_batches_scope.reload.sum(:quantity_remaining)
    product.update_column(:stock, product.total_batch_stock)

    store_note = booking_store_id.present? ? " at #{booking.store.name}" : ''
    product.stock_movements.create!(
      reference_type: 'booking',
      reference_id: booking.id,
      movement_type: 'consumed',
      quantity: -quantity.to_f,
      stock_before: current_stock,
      stock_after: new_stock,
      notes: "Stock consumed for booking#{store_note}: #{product.name} (Qty: #{quantity})"
    )

    Rails.logger.info "Reduced stock for Product ##{product.id} by #{quantity}. New store stock: #{new_stock}"
  end

  def handle_quantity_change
    return unless quantity_previously_changed? && product.present?

    old_quantity = quantity_previously_was || 0
    new_quantity = quantity
    quantity_difference = new_quantity - old_quantity
    current_stock = stock_batches_scope.sum(:quantity_remaining)

    if quantity_difference > 0
      remaining_to_allocate = quantity_difference.to_f

      stock_batches_scope.each do |batch|
        break if remaining_to_allocate <= 0

        if batch.quantity_remaining > 0
          allocation = [remaining_to_allocate, batch.quantity_remaining].min
          batch.quantity_remaining -= allocation
          remaining_to_allocate -= allocation
          batch.status = 'exhausted' if batch.quantity_remaining <= 0
          batch.save!
        end
      end
    elsif quantity_difference < 0
      quantity_to_restore = quantity_difference.abs.to_f

      restore_scope = booking_store_id.present? \
        ? product.stock_batches.where(store_id: booking_store_id).order(:batch_date, :created_at) \
        : product.stock_batches.order(:batch_date, :created_at)

      restore_scope.reverse_each do |batch|
        break if quantity_to_restore <= 0

        if batch.status == 'exhausted'
          batch.quantity_remaining += quantity_to_restore
          batch.status = 'active'
          batch.save!
          break
        elsif batch.status == 'active'
          batch.quantity_remaining += quantity_to_restore
          batch.save!
          break
        end
      end
    end

    new_stock = stock_batches_scope.reload.sum(:quantity_remaining)
    product.update_column(:stock, product.total_batch_stock)

    # Create stock movement record for the change
    if quantity_difference != 0
      movement_type = quantity_difference > 0 ? 'consumed' : 'adjusted'
      movement_quantity = quantity_difference > 0 ? -quantity_difference.abs : quantity_difference.abs

      product.stock_movements.create!(
        reference_type: 'booking',
        reference_id: booking.id,
        movement_type: movement_type,
        quantity: movement_quantity,
        stock_before: current_stock,
        stock_after: new_stock,
        notes: "Booking item quantity changed from #{old_quantity} to #{new_quantity}"
      )
    end
  end

  def restore_product_stock
    return unless quantity.present? && product.present?

    current_stock = stock_batches_scope.sum(:quantity_remaining)
    quantity_to_restore = quantity.to_f

    restore_scope = booking_store_id.present? \
      ? product.stock_batches.where(store_id: booking_store_id).order(:batch_date, :created_at) \
      : product.stock_batches.order(:batch_date, :created_at)

    restore_scope.reverse_each do |batch|
      break if quantity_to_restore <= 0

      if batch.status == 'exhausted'
        batch.quantity_remaining += quantity_to_restore
        batch.status = 'active'
        batch.save!
        break
      elsif batch.status == 'active'
        batch.quantity_remaining += quantity_to_restore
        batch.save!
        break
      end
    end

    new_stock = stock_batches_scope.reload.sum(:quantity_remaining)
    product.update_column(:stock, product.total_batch_stock)

    product.stock_movements.create!(
      reference_type: 'booking',
      reference_id: booking.id,
      movement_type: 'adjusted',
      quantity: quantity.to_f,
      stock_before: current_stock,
      stock_after: new_stock,
      notes: "Stock restored from cancelled booking item: #{product.name} (Qty: #{quantity})"
    )

    Rails.logger.info "Restored stock for Product ##{product.id} by #{quantity}. New stock: #{new_stock}"
  end

  def booking_store_id
    booking&.store_id
  end

  def stock_batches_scope
    if booking_store_id.present?
      product.stock_batches.active.where(store_id: booking_store_id).order(:batch_date, :created_at)
    else
      product.stock_batches.active.order(:batch_date, :created_at)
    end
  end
end

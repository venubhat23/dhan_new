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

    available_stock = product.total_batch_stock

    # If this is an update, add back the previous quantity to available stock
    if persisted? && quantity_changed?
      available_stock += quantity_was
    end

    if quantity > available_stock
      errors.add(:quantity, "only #{available_stock} units available in stock")
    end
  end

  def reduce_product_stock
    return unless quantity.present? && product.present?

    current_stock = product.total_batch_stock

    # Use FIFO allocation from stock batches
    remaining_to_allocate = quantity.to_f

    product.stock_batches.active.order(:batch_date, :created_at).each do |batch|
      break if remaining_to_allocate <= 0

      if batch.quantity_remaining > 0
        allocation = [remaining_to_allocate, batch.quantity_remaining].min
        batch.quantity_remaining -= allocation
        remaining_to_allocate -= allocation

        # Mark batch as exhausted if empty
        batch.status = 'exhausted' if batch.quantity_remaining <= 0
        batch.save!

        Rails.logger.info "Allocated #{allocation} units from Batch ##{batch.id}. Remaining in batch: #{batch.quantity_remaining}"
      end
    end

    # Update the product.stock field for backward compatibility
    new_stock = product.total_batch_stock
    product.update_column(:stock, new_stock)

    # Create stock movement record
    product.stock_movements.create!(
      reference_type: 'booking',
      reference_id: booking.id,
      movement_type: 'consumed',
      quantity: -quantity.to_f, # Negative for consumption
      stock_before: current_stock,
      stock_after: new_stock,
      notes: "Stock consumed for booking item: #{product.name} (Qty: #{quantity})"
    )

    Rails.logger.info "Reduced stock for Product ##{product.id} by #{quantity}. New stock: #{new_stock}"
  end

  def handle_quantity_change
    return unless quantity_previously_changed? && product.present?

    old_quantity = quantity_previously_was || 0
    new_quantity = quantity
    quantity_difference = new_quantity - old_quantity
    current_stock = product.total_batch_stock

    if quantity_difference > 0
      # Quantity increased, allocate more stock using FIFO
      remaining_to_allocate = quantity_difference.to_f

      product.stock_batches.active.order(:batch_date, :created_at).each do |batch|
        break if remaining_to_allocate <= 0

        if batch.quantity_remaining > 0
          allocation = [remaining_to_allocate, batch.quantity_remaining].min
          batch.quantity_remaining -= allocation
          remaining_to_allocate -= allocation

          batch.status = 'exhausted' if batch.quantity_remaining <= 0
          batch.save!
        end
      end

      Rails.logger.info "Allocated additional #{quantity_difference} units for Product ##{product.id}"
    elsif quantity_difference < 0
      # Quantity decreased, restore stock to the most recent batches (reverse FIFO)
      quantity_to_restore = quantity_difference.abs.to_f

      product.stock_batches.order(:batch_date, :created_at).reverse_each do |batch|
        break if quantity_to_restore <= 0

        # Restore to exhausted batches first, then active batches
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

      Rails.logger.info "Restored #{quantity_difference.abs} units for Product ##{product.id}"
    end

    # Update the product.stock field for backward compatibility
    new_stock = product.total_batch_stock
    product.update_column(:stock, new_stock)

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

    current_stock = product.total_batch_stock

    # Restore stock to the most recent batches (reverse FIFO)
    quantity_to_restore = quantity.to_f

    product.stock_batches.order(:batch_date, :created_at).reverse_each do |batch|
      break if quantity_to_restore <= 0

      # Restore to exhausted batches first, then active batches
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

    # Update the product.stock field for backward compatibility
    new_stock = product.total_batch_stock
    product.update_column(:stock, new_stock)

    # Create stock movement record for restoration
    product.stock_movements.create!(
      reference_type: 'booking',
      reference_id: booking.id,
      movement_type: 'adjusted',
      quantity: quantity.to_f, # Positive for restoration
      stock_before: current_stock,
      stock_after: new_stock,
      notes: "Stock restored from cancelled booking item: #{product.name} (Qty: #{quantity})"
    )

    Rails.logger.info "Restored stock for Product ##{product.id} by #{quantity}. New stock: #{new_stock}"
  end
end

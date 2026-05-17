class StockTransfer < ApplicationRecord
  belongs_to :from_store, class_name: 'Store', foreign_key: :from_store_id, optional: true
  belongs_to :to_store, class_name: 'Store', foreign_key: :to_store_id
  belongs_to :product
  belongs_to :product_variant, optional: true
  belongs_to :requested_by, class_name: 'User', foreign_key: :requested_by_id
  belongs_to :approved_by, class_name: 'User', foreign_key: :approved_by_id, optional: true

  validates :quantity, numericality: { greater_than: 0 }
  validates :status, inclusion: { in: %w[pending approved rejected completed] }

  scope :pending, -> { where(status: 'pending') }
  scope :approved, -> { where(status: 'approved') }
  scope :completed, -> { where(status: 'completed') }
  scope :rejected, -> { where(status: 'rejected') }
  scope :for_store, ->(store_id) { where('from_store_id = ? OR to_store_id = ?', store_id, store_id) }

  def from_store_name
    from_store&.name || 'Central Inventory'
  end

  def product_display_name
    product_variant ? "#{product.name} — #{product_variant.label}" : product.name
  end

  def approve!(approver)
    ActiveRecord::Base.transaction do
      available = source_available_stock
      if available < quantity
        raise "Insufficient stock in #{from_store_name}. Available: #{available}, Requested: #{quantity}"
      end

      # Deduct from source (FIFO)
      allocations = StockBatch.fifo_allocation(product_id, quantity, store_id: from_store_id)
      raise "Could not allocate stock from #{from_store_name}" unless allocations[:fulfilled]

      allocations[:allocation].each do |alloc|
        alloc[:batch].reduce_stock!(alloc[:quantity])
      end

      # Create batch at destination store
      ref_batch = StockBatch.where(product_id: product_id).active.first
      StockBatch.create!(
        product: product,
        vendor: ref_batch&.vendor || product.stock_batches.first&.vendor,
        store_id: to_store_id,
        quantity_purchased: quantity,
        quantity_remaining: quantity,
        purchase_price: ref_batch&.purchase_price || product.buying_price || 0,
        selling_price: ref_batch&.selling_price || product.price || 0,
        batch_date: Date.current,
        status: 'active'
      )

      update!(status: 'completed', approved_by: approver, approved_at: Time.current, completed_at: Time.current)
    end
  end

  def reject!(approver, reason = nil)
    update!(status: 'rejected', approved_by: approver, rejection_reason: reason)
  end

  private

  def source_available_stock
    StockBatch.available_for_product(product_id, store_id: from_store_id).sum(:quantity_remaining)
  end
end

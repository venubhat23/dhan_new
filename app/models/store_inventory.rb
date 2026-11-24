class StoreInventory < ApplicationRecord
  belongs_to :store
  belongs_to :product
  belongs_to :product_variant, optional: true

  validates :quantity, numericality: { greater_than_or_equal_to: 0 }
  validates :low_stock_threshold, numericality: { greater_than_or_equal_to: 0 }
  validates :product_id, uniqueness: { scope: [:store_id, :product_variant_id] }

  # Threshold 0 = no alert; inactive products never count as low stock.
  scope :low_stock, -> {
    joins(:product)
      .where(products: { status: 'active' })
      .where("store_inventories.low_stock_threshold > 0 AND store_inventories.quantity <= store_inventories.low_stock_threshold")
  }

  def low_stock?
    low_stock_threshold.to_f > 0 && quantity.to_f <= low_stock_threshold.to_f
  end

  def label
    product_variant ? "#{product.name} — #{product_variant.label}" : product.name
  end
end

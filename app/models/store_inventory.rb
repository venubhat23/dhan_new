class StoreInventory < ApplicationRecord
  belongs_to :store
  belongs_to :product
  belongs_to :product_variant, optional: true

  validates :quantity, numericality: { greater_than_or_equal_to: 0 }
  validates :low_stock_threshold, numericality: { greater_than_or_equal_to: 0 }
  validates :product_id, uniqueness: { scope: [:store_id, :product_variant_id] }

  scope :low_stock, -> { where("quantity <= low_stock_threshold") }

  def low_stock?
    quantity.to_f <= low_stock_threshold.to_f
  end

  def label
    product_variant ? "#{product.name} — #{product_variant.label}" : product.name
  end
end

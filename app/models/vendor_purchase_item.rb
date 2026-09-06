class VendorPurchaseItem < ApplicationRecord
  belongs_to :vendor_purchase
  belongs_to :product
  belongs_to :product_variant, optional: true

  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :purchase_price, presence: true, numericality: { greater_than: 0 }
  validates :selling_price, presence: true, numericality: { greater_than: 0 }

  before_save :calculate_line_total
  validate :selling_price_should_be_greater_than_purchase_price

  # Name shown on the purchase / stock-movement records. Includes the variant
  # pack size when the line targets a specific variant.
  def display_name
    product_variant ? "#{product.name} #{product_variant.label}" : product.name
  end

  # Composite value the purchase form's product <select> carries for this line:
  # "<product_id>" for a plain product, "<product_id>-v<variant_id>" for a variant.
  def selected_option_value
    return '' if product_id.blank?
    product_variant_id.present? ? "#{product_id}-v#{product_variant_id}" : product_id.to_s
  end

  def profit_margin
    return 0 if purchase_price.zero?
    ((selling_price - purchase_price) / purchase_price * 100).round(2)
  end

  def total_profit_potential
    (selling_price - purchase_price) * quantity
  end

  private

  def calculate_line_total
    self.line_total = quantity * purchase_price
  end

  def selling_price_should_be_greater_than_purchase_price
    return unless selling_price && purchase_price

    if selling_price <= purchase_price
      errors.add(:selling_price, 'must be greater than purchase price')
    end
  end
end
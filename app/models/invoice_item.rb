class InvoiceItem < ApplicationRecord
  belongs_to :invoice
  belongs_to :milk_delivery_task, optional: true
  belongs_to :product, optional: true
  belongs_to :product_variant, optional: true

  DISCOUNT_TYPES = %w[percentage fixed].freeze

  validates :description, presence: true
  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :unit_price, presence: true, numericality: { greater_than: 0 }
  validates :total_amount, presence: true, numericality: { greater_than: 0 }
  validates :discount_type, inclusion: { in: DISCOUNT_TYPES }, allow_nil: true, allow_blank: true
  validates :discount_value, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  before_validation :normalize_discount
  before_validation :calculate_total_amount

  # Pre-discount base unit price for display ("was ₹X"); falls back to the net price.
  def list_unit_price
    original_unit_price.present? && original_unit_price.to_f > 0 ? original_unit_price : unit_price
  end

  # True when this line was sold below its recorded list price.
  def line_discount?
    original_unit_price.to_f > 0 && original_unit_price.to_f.round(2) > unit_price.to_f.round(2)
  end

  # Human label for the discount, e.g. "10% off" or "₹15 off".
  def discount_label
    return nil unless line_discount?

    if discount_type == 'percentage' && discount_value.to_f > 0
      "#{discount_value.to_f.round(2).to_s.sub(/\.0+$/, '')}% off"
    else
      "₹#{discount_amount.to_f.round(2).to_s.sub(/\.0+$/, '')} off"
    end
  end

  private

  # unit_price is always the NET (actually-charged) base price and drives every
  # downstream total. original_unit_price + discount_type/value are display
  # metadata; discount_amount is derived from the gap so the invoice can show it.
  def normalize_discount
    self.discount_type = nil if discount_type.blank?
    self.discount_value = nil if discount_type.nil?

    self.discount_amount = if original_unit_price.to_f > 0 && unit_price.to_f > 0
                             [(original_unit_price.to_f - unit_price.to_f) * quantity.to_f, 0].max.round(2)
                           else
                             0
                           end
  end

  def calculate_total_amount
    self.total_amount = (quantity || 0) * (unit_price || 0)
  end
end

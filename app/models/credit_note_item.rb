class CreditNoteItem < ApplicationRecord
  belongs_to :credit_note
  belongs_to :booking_item
  belongs_to :product
  belongs_to :product_variant, optional: true

  validates :quantity, numericality: { greater_than: 0 }
  validates :amount, numericality: { greater_than_or_equal_to: 0 }

  def display_name
    product_variant ? "#{product&.name} (#{product_variant.label})" : product&.name
  end
end

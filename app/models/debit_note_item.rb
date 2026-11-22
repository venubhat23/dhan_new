class DebitNoteItem < ApplicationRecord
  belongs_to :debit_note
  belongs_to :vendor_purchase_item
  belongs_to :stock_batch, optional: true
  belongs_to :product
  belongs_to :product_variant, optional: true

  validates :quantity, numericality: { greater_than: 0 }
  validates :amount, numericality: { greater_than_or_equal_to: 0 }

  def display_name
    product_variant ? "#{product&.name} (#{product_variant.label})" : product&.name
  end
end

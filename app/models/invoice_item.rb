class InvoiceItem < ApplicationRecord
  belongs_to :invoice
  belongs_to :milk_delivery_task, optional: true
  belongs_to :product, optional: true
  belongs_to :product_variant, optional: true

  validates :description, presence: true
  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :unit_price, presence: true, numericality: { greater_than: 0 }
  validates :total_amount, presence: true, numericality: { greater_than: 0 }

  before_validation :calculate_total_amount

  private

  def calculate_total_amount
    self.total_amount = (quantity || 0) * (unit_price || 0)
  end
end

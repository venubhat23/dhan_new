class DeliveryCharge < ApplicationRecord
  validates :pincode, presence: true, uniqueness: true
  validates :charge_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :bangalore_pincodes, -> { where('pincode LIKE ?', '56%') }

  def self.for_pincode(pincode)
    find_by(pincode: pincode, is_active: true)
  end

  def self.charge_for_pincode(pincode)
    charge = for_pincode(pincode)
    charge&.charge_amount || 0.0
  end

  def formatted_charge
    "₹#{charge_amount}"
  end

  def status_text
    is_active? ? 'Active' : 'Inactive'
  end
end
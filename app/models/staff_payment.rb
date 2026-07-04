class StaffPayment < ApplicationRecord
  belongs_to :staff_member

  validates :amount, numericality: { greater_than: 0 }
  validates :payment_date, presence: true
  validates :month, inclusion: { in: 1..12 }
  validates :year, numericality: { greater_than: 2000 }
end

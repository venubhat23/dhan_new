class VendorPayment < ApplicationRecord
  include DashboardCacheBust
  belongs_to :vendor
  belongs_to :vendor_purchase

  validates :amount_paid, presence: true, numericality: { greater_than: 0 }
  validates :payment_date, presence: true
  validates :payment_mode, inclusion: { in: %w[Cash Cheque UPI NEFT RTGS Card] }

  after_create :update_vendor_purchase_paid_amount
  after_destroy :update_vendor_purchase_paid_amount

  def payment_number
    "PAY#{id.to_s.padded(6, '0')}"
  end

  def payment_mode_badge_class
    case payment_mode
    when 'Cash'
      'badge-success'
    when 'Cheque'
      'badge-warning'
    when 'UPI', 'NEFT', 'RTGS'
      'badge-info'
    when 'Card'
      'badge-primary'
    else
      'badge-secondary'
    end
  end

  private

  def update_vendor_purchase_paid_amount
    total_paid = vendor_purchase.vendor_payments.sum(:amount_paid)
    vendor_purchase.update_column(:paid_amount, total_paid)
  end
end
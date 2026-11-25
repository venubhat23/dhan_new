# Purchase Receipt: record of a purchase made from a vendor. Created automatically
# when a vendor purchase is saved (VendorPurchase#sync_purchase_receipt) and kept in
# step with that purchase, or added manually from /admin/purchase_receipts. Bank
# fields are filled in afterwards from the "Update Bank Info" modal.
class PurchaseReceipt < ApplicationRecord
  PAYMENT_MODES = VendorPurchase::PAYMENT_MODES
  BANK_FIELDS = %i[bank_date bank_narration bank_opening_balance bank_closing_balance].freeze

  belongs_to :vendor_purchase, optional: true
  belongs_to :vendor, optional: true
  belongs_to :created_by, class_name: 'User', optional: true

  validates :receipt_number, presence: true, uniqueness: true
  validates :receipt_date, presence: true
  validates :vendor_name, presence: true
  validates :amount, numericality: { greater_than: 0 }
  validates :payment_mode, inclusion: { in: PAYMENT_MODES.keys }, allow_blank: true
  validates :vendor_purchase_id, uniqueness: true, allow_nil: true

  before_validation :assign_receipt_number, on: :create

  scope :recent, -> { order(receipt_date: :desc, id: :desc) }
  scope :bank_complete, -> { where.not(bank_date: nil).where.not(bank_opening_balance: nil).where.not(bank_closing_balance: nil).where("COALESCE(bank_narration, '') <> ''") }
  scope :bank_pending, -> { where("bank_date IS NULL OR bank_opening_balance IS NULL OR bank_closing_balance IS NULL OR COALESCE(bank_narration, '') = ''") }

  # Creates the receipt for a purchase, or refreshes its snapshot if it already
  # exists (receipt number, date, bank info and notes are left as they are).
  def self.sync_from_vendor_purchase!(purchase, user: nil)
    receipt = find_by(vendor_purchase_id: purchase.id)
    attrs = attributes_from_vendor_purchase(purchase)
    if receipt
      receipt.update!(attrs.except(:receipt_date))
      receipt
    else
      create!(attrs.merge(created_by: user, source: 'auto'))
    end
  end

  def self.attributes_from_vendor_purchase(purchase)
    vendor = purchase.vendor
    items = purchase.vendor_purchase_items.includes(:product, :product_variant).map do |i|
      name = i.product_variant ? "#{i.product&.name} (#{i.product_variant.try(:label)})" : i.product&.name
      qty = i.quantity.to_f
      price = i.purchase_price.to_f
      { name: name, product_id: i.product_id, product_variant_id: i.product_variant_id,
        quantity: qty, price: price, total: (qty * price).round(2) }
    end
    {
      vendor_purchase: purchase, vendor_id: purchase.vendor_id,
      receipt_date: purchase.purchase_date || Date.current,
      purchase_number: purchase.purchase_number, purchase_date: purchase.purchase_date,
      vendor_name: vendor&.name.presence || 'Vendor', vendor_phone: vendor&.phone, vendor_email: vendor&.email,
      vendor_address: vendor&.address, vendor_gst_no: vendor&.gst_no,
      items: items, amount: purchase.total_amount.to_f, payment_mode: purchase.payment_mode
    }
  end

  def payment_mode_label
    PAYMENT_MODES[payment_mode.to_s] || '—'
  end

  def bank_fields_filled_count
    BANK_FIELDS.count { |f| self[f].present? }
  end

  def bank_info_complete?
    bank_fields_filled_count == BANK_FIELDS.size
  end

  private

  def assign_receipt_number
    return if receipt_number.present?

    last = PurchaseReceipt.where("receipt_number ~ '^PR-[0-9]+$'").maximum(Arel.sql("CAST(SUBSTRING(receipt_number FROM 4) AS INTEGER)")).to_i
    self.receipt_number = format('PR-%05d', last + 1)
  end
end

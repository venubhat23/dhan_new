# Sales Receipt: proof of money received for a sale. Created automatically when a
# booking becomes Paid (Booking#create_sales_receipt_if_paid), or manually from
# /admin/sales_receipts. Booking details are snapshotted so the receipt stays as
# issued even if the booking changes later. Bank fields are filled in afterwards
# from the "Update Bank Info" modal.
class SalesReceipt < ApplicationRecord
  PAYMENT_MODES = Booking::PAID_VIA_OPTIONS
  BANK_FIELDS = %i[bank_date bank_narration bank_opening_balance bank_closing_balance].freeze

  belongs_to :booking, optional: true
  belongs_to :customer, optional: true
  belongs_to :store, optional: true
  belongs_to :created_by, class_name: 'User', optional: true

  validates :receipt_number, presence: true, uniqueness: true
  validates :receipt_date, presence: true
  validates :customer_name, presence: true
  validates :amount, numericality: { greater_than: 0 }
  validates :payment_mode, inclusion: { in: PAYMENT_MODES.keys }, allow_blank: true
  validates :booking_id, uniqueness: true, allow_nil: true

  before_validation :assign_receipt_number, on: :create

  scope :recent, -> { order(receipt_date: :desc, id: :desc) }

  def self.create_from_booking!(booking, user: nil, source: 'auto')
    existing = find_by(booking_id: booking.id)
    return existing if existing

    create!(attributes_from_booking(booking).merge(created_by: user, source: source))
  end

  # Everything worth keeping from the booking, as SalesReceipt attributes.
  def self.attributes_from_booking(booking)
    items = booking.booking_items.includes(:product, :product_variant).map do |i|
      name = i.product_variant ? "#{i.product&.name} (#{i.product_variant.try(:label)})" : i.product&.name
      { name: name, product_id: i.product_id, product_variant_id: i.product_variant_id,
        quantity: i.quantity.to_f, price: i.price.to_f, discount_amount: i.discount_amount.to_f, total: i.total.to_f }
    end
    {
      booking: booking, customer_id: booking.customer_id, store_id: booking.store_id,
      receipt_date: (booking.payment_completed_at || Time.current).to_date,
      booking_number: booking.booking_number, invoice_number: booking.invoice_number,
      customer_name: booking.customer&.try(:display_name).presence || booking.customer_name.presence || 'Walk-in Customer',
      customer_phone: booking.customer_phone, customer_email: booking.customer_email,
      customer_address: booking.delivery_address, gstin: booking.gstin,
      booking_date: booking.booking_date || booking.created_at, items: items,
      subtotal: booking.subtotal, tax_amount: booking.tax_amount, discount_amount: booking.discount_amount,
      shipping_charges: booking.shipping_charges, amount: booking.total_amount, payment_mode: booking.paid_via
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

    last = SalesReceipt.where("receipt_number ~ '^SR-[0-9]+$'").maximum(Arel.sql("CAST(SUBSTRING(receipt_number FROM 4) AS INTEGER)")).to_i
    self.receipt_number = format('SR-%05d', last + 1)
  end
end

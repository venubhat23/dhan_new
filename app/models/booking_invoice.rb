class BookingInvoice < ApplicationRecord
  belongs_to :booking
  belongs_to :customer, optional: true

  # Enums
  enum :payment_status, {
    unpaid: 0,
    paid: 1,
    partially_paid: 2,
    refunded: 3
  }, prefix: true

  enum :status, {
    draft: 0,
    sent: 1,
    viewed: 2,
    overdue: 3,
    cancelled: 4
  }

  # Validations
  validates :invoice_number, presence: true, uniqueness: true
  validates :invoice_date, presence: true
  validates :total_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Callbacks
  before_validation :generate_invoice_number, on: :create
  before_validation :set_defaults, on: :create
  before_validation :generate_share_token, on: :create

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :pending_payment, -> { where(payment_status: [:unpaid, :partially_paid]) }
  scope :overdue_invoices, -> { where('due_date < ? AND payment_status IN (?)', Date.current, [:unpaid, :partially_paid]) }

  def generate_invoice_number
    return if invoice_number.present?

    self.invoice_number = "INV#{Date.current.strftime('%Y%m%d')}#{SecureRandom.hex(3).upcase}"
  end

  def set_defaults
    self.invoice_date ||= Time.current
    self.due_date ||= 30.days.from_now
    self.status ||= :draft

    if booking.present?
      self.customer_id ||= booking.customer_id
      self.subtotal ||= booking.subtotal
      self.tax_amount ||= booking.tax_amount
      self.discount_amount ||= booking.discount_amount
      self.total_amount ||= booking.total_amount
      self.payment_status ||= booking.payment_status

      # Store invoice items as JSON
      self.invoice_items ||= build_invoice_items_json
    end
  end

  def build_invoice_items_json
    return nil unless booking&.booking_items&.any?

    items = booking.booking_items.includes(:product).map do |item|
      {
        product_id: item.product_id,
        product_name: item.product&.name || 'Unknown Product',
        quantity: item.quantity,
        price: item.price,
        discount_type: item.discount_type,
        discount_value: item.discount_value,
        discount_amount: item.line_discount_amount,
        discounted_unit_price: item.discounted_unit_price.round(2),
        total: (item.quantity * item.price - item.line_discount_amount).round(2)
      }
    end

    JSON.generate(items)
  end

  def parsed_invoice_items
    return [] if invoice_items.blank?

    JSON.parse(invoice_items)
  rescue JSON::ParserError
    []
  end

  def mark_as_paid!
    update!(
      payment_status: :paid,
      paid_at: Time.current,
      status: :sent
    )
  end

  def mark_as_partially_paid!(amount_paid)
    remaining = total_amount - amount_paid

    update!(
      payment_status: remaining > 0 ? :partially_paid : :paid,
      paid_at: remaining <= 0 ? Time.current : nil
    )
  end

  def overdue?
    due_date < Date.current && payment_status_unpaid?
  end

  def days_overdue
    return 0 unless overdue?
    (Date.current - due_date.to_date).to_i
  end

  def formatted_total
    "₹#{total_amount.to_f.round(2)}"
  end

  def customer_name
    customer&.display_name || booking&.customer_name || 'Unknown Customer'
  end

  def customer_email
    customer&.email || booking&.customer_email
  end

  def customer_phone
    customer&.mobile || booking&.customer_phone
  end

  def payment_status_display
    case payment_status
    when 'unpaid' then 'Unpaid'
    when 'paid' then 'Paid'
    when 'partially_paid' then 'Partially Paid'
    when 'refunded' then 'Refunded'
    else 'Unpaid'
    end
  end

  def generate_share_token
    return if share_token.present?

    loop do
      token = SecureRandom.urlsafe_base64(32)
      break self.share_token = token unless BookingInvoice.exists?(share_token: token)
    end
  end

  def formatted_number
    invoice_number
  end
end

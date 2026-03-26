class VendorInvoice < ApplicationRecord
  belongs_to :vendor_purchase
  has_one :vendor, through: :vendor_purchase

  enum :status, { draft: 0, sent: 1, paid: 2, cancelled: 3 }

  validates :invoice_number, presence: true, uniqueness: true
  validates :total_amount, presence: true, numericality: { greater_than: 0 }
  validates :invoice_date, presence: true
  validates :share_token, uniqueness: { allow_blank: true }

  before_validation :generate_invoice_number, on: :create
  before_validation :generate_share_token, on: :create
  before_validation :set_invoice_date, on: :create
  before_validation :set_total_amount, on: :create

  scope :recent, -> { order(created_at: :desc) }

  def vendor
    vendor_purchase.vendor
  end

  def purchase_number
    vendor_purchase.purchase_number
  end

  def vendor_name
    vendor.name
  end

  def vendor_phone
    vendor.phone
  end

  def vendor_email
    vendor.email
  end

  def purchase_items
    vendor_purchase.vendor_purchase_items
  end

  def status_badge_class
    case status
    when 'paid'
      'bg-success text-white'
    when 'sent'
      'bg-info text-white'
    when 'draft'
      'bg-secondary text-white'
    when 'cancelled'
      'bg-danger text-white'
    else
      'bg-secondary text-white'
    end
  end

  def public_url
    # Use localhost for development, production domain for production
    host = Rails.env.development? ? 'localhost:3000' : (Rails.application.config.action_mailer.default_url_options[:host] || 'localhost:3000')
    protocol = Rails.env.development? ? 'http' : 'https'
    Rails.application.routes.url_helpers.vendor_invoice_public_url(share_token, host: host, protocol: protocol)
  end

  private

  def generate_invoice_number
    return if invoice_number.present?

    date_part = Date.current.strftime('%Y%m%d')
    last_invoice = VendorInvoice.where("invoice_number LIKE ?", "VI#{date_part}%")
                               .order(:invoice_number)
                               .last

    if last_invoice
      last_number = last_invoice.invoice_number.split('-').last.to_i
      next_number = last_number + 1
    else
      next_number = 1
    end

    self.invoice_number = "VI#{date_part}-#{next_number.to_s.rjust(4, '0')}"
  end

  def generate_share_token
    return if share_token.present?

    loop do
      token = SecureRandom.urlsafe_base64(32)
      break self.share_token = token unless VendorInvoice.exists?(share_token: token)
    end
  end

  def set_invoice_date
    self.invoice_date ||= Date.current
  end

  def set_total_amount
    self.total_amount = vendor_purchase.total_amount
  end
end

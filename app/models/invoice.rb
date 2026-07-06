class Invoice < ApplicationRecord
  belongs_to :customer, optional: true
  belongs_to :created_by_user, class_name: 'User', foreign_key: 'created_by', optional: true
  has_many :invoice_items, dependent: :destroy

  accepts_nested_attributes_for :invoice_items, allow_destroy: true, reject_if: :all_blank

  enum :status, { draft: 'draft', sent: 'sent', paid: 'paid', overdue: 'overdue', cancelled: 'cancelled' }
  enum :payment_status, { unpaid: 0, partially_paid: 1, fully_paid: 2 }

  validates :invoice_number, presence: true, uniqueness: true
  validates :total_amount, presence: true, numericality: { greater_than: 0 }
  validates :invoice_date, presence: true

  before_validation :generate_invoice_number, on: :create
  before_validation :calculate_total_from_items
  before_create :generate_share_token
  after_update :sync_booking_payment_status, if: :saved_change_to_payment_status?
  after_update :sync_booking_delivery_charge, if: :saved_change_to_delivery_charge?

  scope :for_month, ->(month, year) { where(invoice_date: Date.new(year, month).beginning_of_month..Date.new(year, month).end_of_month) }

  # Keeps the originating Booking's payment_status/label in sync when an invoice is
  # marked paid (or unpaid) from the invoices screen, mirroring Booking#sync_invoice_payment_status.
  def sync_booking_payment_status
    return if invoice_number.blank?

    booking = Booking.find_by(invoice_number: invoice_number)
    return unless booking

    target_status = case payment_status
                     when 'fully_paid' then 'paid'
                     when 'partially_paid' then 'partially_paid'
                     else 'unpaid'
                     end

    booking.update(payment_status: target_status) unless booking.payment_status == target_status
  end

  # Keeps the originating Booking's shipping_charges in sync when the delivery charge is
  # edited from the invoice screen, mirroring Booking#sync_invoice_delivery_charge.
  def sync_booking_delivery_charge
    return if invoice_number.blank?

    booking = Booking.find_by(invoice_number: invoice_number)
    return unless booking
    return if booking.shipping_charges.to_f == delivery_charge.to_f

    booking.update(shipping_charges: delivery_charge)
  end

  # Get customer display name (customer or walk-in from booking)
  def customer_display_name
    return customer.display_name if customer.present?

    # For walk-in customers, get name from related booking
    related_booking = Booking.find_by(invoice_number: invoice_number)
    return related_booking.customer_name if related_booking&.customer_name.present?

    'Walk-in Customer'
  end

  # Get customer address (customer or walk-in from booking)
  def customer_address
    return customer.address if customer&.address.present?

    # For walk-in customers, get address from related booking
    related_booking = Booking.find_by(invoice_number: invoice_number)
    return related_booking.delivery_address if related_booking&.delivery_address.present?

    'Walk-in Address'
  end

  # Get customer mobile (customer or walk-in from booking)
  def customer_mobile
    return customer.mobile if customer&.mobile.present?

    # For walk-in customers, get mobile from related booking
    related_booking = Booking.find_by(invoice_number: invoice_number)
    return related_booking.customer_phone if related_booking&.customer_phone.present?

    nil
  end

  def generate_share_token!
    self.share_token = SecureRandom.urlsafe_base64(32)
    save!
  end

  def formatted_number
    invoice_number
  end

  def customer_name
    "#{customer&.first_name} #{customer&.last_name}".strip
  end

  def customer_phone
    customer&.mobile
  end

  def customer_email
    customer&.email
  end

  def overdue?
    due_date && due_date < Date.current && payment_status != 'fully_paid'
  end

  def remaining_amount
    total_amount - (paid_amount || 0)
  end

  def paid_percentage
    return 0 if total_amount.zero?
    ((paid_amount || 0) / total_amount * 100).round(2)
  end

  def fully_paid?
    payment_status == 'fully_paid' || remaining_amount <= 0
  end

  def partially_paid?
    payment_status == 'partially_paid' || (paid_amount && paid_amount > 0 && paid_amount < total_amount)
  end

  private

  def generate_invoice_number
    return if invoice_number.present?

    # Get the month from invoice_date or current date
    invoice_month = (invoice_date || Date.current).month
    month_prefix = invoice_month.to_s.rjust(2, '0')

    # Get the next invoice number for this month
    last_invoice = Invoice.where("invoice_number LIKE ?", "INV-#{month_prefix}-%")
                         .order(created_at: :desc)
                         .first

    if last_invoice
      # Extract the number part and increment
      last_number = last_invoice.invoice_number.split('-').last.to_i
      next_number = (last_number + 1).to_s.rjust(5, '0')
    else
      # Start from 00001 for this month
      next_number = '00001'
    end

    self.invoice_number = "INV-#{month_prefix}-#{next_number}"
  end

  # Helper method to generate month-based invoice number for specific month
  def self.generate_invoice_number_for_month(month)
    month_prefix = month.to_s.rjust(2, '0')

    last_invoice = where("invoice_number LIKE ?", "INV-#{month_prefix}-%")
                   .order(created_at: :desc)
                   .first

    if last_invoice
      last_number = last_invoice.invoice_number.split('-').last.to_i
      next_number = (last_number + 1).to_s.rjust(5, '0')
    else
      next_number = '00001'
    end

    "INV-#{month_prefix}-#{next_number}"
  end

  def generate_share_token
    return if share_token.present?
    self.share_token = SecureRandom.urlsafe_base64(32)
  end

  private

  def calculate_total_from_items
    # Only recalculate if invoice_items are present and changed
    if invoice_items.any? || (respond_to?(:invoice_items_attributes) && invoice_items_attributes.present?)
      new_total = 0

      # Calculate from existing items
      invoice_items.each do |item|
        next if item.marked_for_destruction?
        new_total += line_amount_with_tax(item.product, item.quantity, item.unit_price)
      end

      # Add new items from nested attributes if present
      if respond_to?(:invoice_items_attributes) && invoice_items_attributes.present?
        invoice_items_attributes.each do |_, attrs|
          next if attrs['_destroy'] == '1' || attrs[:_destroy] == '1'
          next if attrs['id'].present? || attrs[:id].present? # Skip existing items already counted

          quantity = (attrs['quantity'] || attrs[:quantity] || 0).to_f
          unit_price = (attrs['unit_price'] || attrs[:unit_price] || 0).to_f
          product = Product.find_by(id: attrs['product_id'] || attrs[:product_id])
          new_total += line_amount_with_tax(product, quantity, unit_price)
        end
      end

      self.total_amount = new_total + delivery_charge.to_f if new_total > 0
    end
  end

  # Line total including GST, matching the tax calculation shown on the invoice view page.
  def line_amount_with_tax(product, quantity, unit_price)
    base = quantity.to_f * unit_price.to_f
    return base unless product&.gst_enabled

    gst_rate = if product.cgst_percentage.present? || product.sgst_percentage.present?
                 (product.cgst_percentage || 0) + (product.sgst_percentage || 0) + (product.igst_percentage || 0)
               else
                 product.gst_percentage || 0
               end

    base * (1 + gst_rate.to_f / 100)
  end
end

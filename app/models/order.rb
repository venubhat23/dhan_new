class Order < ApplicationRecord
  # belongs_to :booking, optional: true  # Temporarily disabled until booking_id column is added
  belongs_to :customer, optional: true
  belongs_to :user, optional: true
  has_many :order_items, dependent: :destroy
  has_many :sale_items, dependent: :destroy

  # Enums - Complete workflow matching Booking
  enum :status, {
    draft: 0,           # Initial order creation
    ordered_and_delivery_pending: 1, # Order placed, waiting for processing
    confirmed: 2,       # Order confirmed
    processing: 3,      # Order being prepared
    packed: 4,          # Items packed and ready
    shipped: 5,         # Shipped out
    out_for_delivery: 6, # Out for delivery
    delivered: 7,       # Successfully delivered
    completed: 8,       # Transaction completed
    cancelled: 9,       # Cancelled
    returned: 10        # Returned
  }

  enum :payment_status, {
    unpaid: 0,
    paid: 1,
    partially_paid: 2,
    refunded: 3
  }, prefix: true

  enum :payment_method, {
    cash: 0,
    card: 1,
    upi: 2,
    bank_transfer: 3,
    online: 4,
    cod: 5
  }, prefix: true

  # Validations
  validates :order_number, presence: true, uniqueness: true
  validates :total_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :recent, -> { order(created_at: :desc) }
  scope :today, -> { where(created_at: Date.current.all_day) }
  scope :active, -> { where.not(status: [statuses[:cancelled], statuses[:returned]]) }

  after_commit :bust_mobile_customer_cache

  def bust_mobile_customer_cache
    cid = customer_id || customer&.id
    return unless cid
    Rails.cache.delete("mobile_api/customer_orders/#{cid}")
  end

  # Status management methods
  def can_cancel?
    %w[draft ordered_and_delivery_pending confirmed processing].include?(status)
  end

  def can_return?
    %w[delivered completed].include?(status)
  end

  def mark_as_confirmed!
    update!(status: :confirmed) if draft? || ordered_and_delivery_pending?
  end

  def mark_as_processing!
    update!(status: :processing) if confirmed?
  end

  def mark_as_packed!
    update!(status: :packed) if processing?
  end

  def mark_as_shipped!(tracking_number = nil)
    if packed?
      updates = { status: :shipped }
      updates[:tracking_number] = tracking_number if tracking_number.present?
      update!(updates)
    end
  end

  def mark_as_out_for_delivery!
    update!(status: :out_for_delivery) if shipped?
  end

  def mark_as_delivered!
    if out_for_delivery?
      update!(status: :delivered, delivered_at: Time.current)
    end
  end

  def mark_as_completed!
    update!(status: :completed) if delivered?
  end

  def cancel_order!(reason = nil)
    if can_cancel?
      cancel_notes = reason.present? ? "Cancelled: #{reason}" : "Cancelled"
      update!(
        status: :cancelled,
        notes: "#{notes}\n#{cancel_notes} at #{Time.current.strftime('%d/%m/%Y %I:%M %p')}"
      )
    end
  end

  def return_order!(reason = nil)
    if can_return?
      return_notes = reason.present? ? "Returned: #{reason}" : "Returned"
      update!(
        status: :returned,
        notes: "#{notes}\n#{return_notes} at #{Time.current.strftime('%d/%m/%Y %I:%M %p')}"
      )
    end
  end

  # Display helpers
  def status_color
    case status
    when 'draft', 'ordered_and_delivery_pending' then 'secondary'
    when 'confirmed' then 'info'
    when 'processing', 'packed' then 'warning'
    when 'shipped', 'out_for_delivery' then 'primary'
    when 'delivered', 'completed' then 'success'
    when 'cancelled', 'returned' then 'danger'
    else 'secondary'
    end
  end

  def status_icon
    case status
    when 'draft' then 'bi-pencil'
    when 'ordered_and_delivery_pending' then 'bi-clock'
    when 'confirmed' then 'bi-check-circle'
    when 'processing' then 'bi-gear'
    when 'packed' then 'bi-box'
    when 'shipped' then 'bi-truck'
    when 'out_for_delivery' then 'bi-geo-alt'
    when 'delivered' then 'bi-house-check'
    when 'completed' then 'bi-check-all'
    when 'cancelled' then 'bi-x-circle'
    when 'returned' then 'bi-arrow-return-left'
    else 'bi-question-circle'
    end
  end

  def next_possible_statuses
    case status
    when 'draft' then ['ordered_and_delivery_pending', 'confirmed', 'cancelled']
    when 'ordered_and_delivery_pending' then ['confirmed', 'cancelled']
    when 'confirmed' then ['processing', 'cancelled']
    when 'processing' then ['packed', 'cancelled']
    when 'packed' then ['shipped']
    when 'shipped' then ['out_for_delivery']
    when 'out_for_delivery' then ['delivered']
    when 'delivered' then ['completed', 'returned']
    else []
    end
  end
end

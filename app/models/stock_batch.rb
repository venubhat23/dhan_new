class StockBatch < ApplicationRecord
  belongs_to :product
  belongs_to :vendor
  belongs_to :vendor_purchase, optional: true
  belongs_to :store, optional: true
  has_many :sale_items, dependent: :restrict_with_error

  validates :quantity_purchased, presence: true, numericality: { greater_than: 0 }
  validates :quantity_remaining, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :purchase_price, presence: true, numericality: { greater_than: 0 }
  validates :selling_price, presence: true, numericality: { greater_than: 0 }
  validates :status, inclusion: { in: %w[active exhausted expired] }

  scope :active, -> { where(status: 'active').where('quantity_remaining > 0') }
  scope :exhausted, -> { where(status: 'exhausted') }
  scope :expired, -> { where(status: 'expired') }
  scope :by_fifo, -> { order(:batch_date, :created_at) }
  scope :for_store, ->(store_id) { where(store_id: store_id) }
  scope :central, -> { where(store_id: nil) }
  scope :for_store_or_central, ->(store_id) { where(store_id: [store_id, nil]) }

  before_save :update_status
  after_update :mark_as_exhausted_if_needed
  after_update :send_low_stock_alert_if_needed

  def batch_number
    "BATCH#{id.to_s.rjust(8, '0')}"
  end

  def quantity_sold
    quantity_purchased - quantity_remaining
  end

  def remaining_percentage
    return 0 if quantity_purchased.zero?
    (quantity_remaining / quantity_purchased * 100).round(2)
  end

  def profit_margin
    return 0 if purchase_price.zero?
    ((selling_price - purchase_price) / purchase_price * 100).round(2)
  end

  def total_value
    quantity_remaining * purchase_price
  end

  def potential_profit
    quantity_remaining * (selling_price - purchase_price)
  end

  def can_fulfill?(requested_quantity)
    active? && quantity_remaining >= requested_quantity
  end

  def reduce_stock!(sold_quantity)
    return false unless can_fulfill?(sold_quantity)

    self.quantity_remaining -= sold_quantity
    self.status = 'exhausted' if quantity_remaining <= 0
    save!
  end

  def active?
    status == 'active' && quantity_remaining > 0
  end

  def exhausted?
    status == 'exhausted' || quantity_remaining <= 0
  end

  def status_badge_class
    case status
    when 'active'
      if quantity_remaining > (quantity_purchased * 0.2)
        'badge-success'
      else
        'badge-warning'
      end
    when 'exhausted'
      'badge-danger'
    when 'expired'
      'badge-secondary'
    else
      'badge-light'
    end
  end

  def self.available_for_product(product_id, store_id: nil)
    scope = where(product_id: product_id).active.by_fifo
    store_id.present? ? scope.where(store_id: store_id) : scope.where(store_id: nil)
  end

  def self.total_available(product_id, store_id: nil)
    available_for_product(product_id, store_id: store_id).sum(:quantity_remaining)
  end

  def self.fifo_allocation(product_id, requested_quantity, store_id: nil)
    batches = available_for_product(product_id, store_id: store_id)
    allocation = []
    remaining_needed = requested_quantity

    batches.each do |batch|
      break if remaining_needed <= 0

      available_in_batch = batch.quantity_remaining
      allocated_from_batch = [remaining_needed, available_in_batch].min

      allocation << {
        batch: batch,
        quantity: allocated_from_batch,
        purchase_price: batch.purchase_price,
        selling_price: batch.selling_price
      }

      remaining_needed -= allocated_from_batch
    end

    {
      allocation: allocation,
      fulfilled: remaining_needed <= 0,
      shortage: remaining_needed > 0 ? remaining_needed : 0
    }
  end

  private

  def update_status
    if quantity_remaining <= 0
      self.status = 'exhausted'
    elsif status == 'exhausted' && quantity_remaining > 0
      self.status = 'active'
    end
  end

  def mark_as_exhausted_if_needed
    if quantity_remaining <= 0 && status != 'exhausted'
      update_column(:status, 'exhausted')
    end
  end

  def send_low_stock_alert_if_needed
    return unless saved_change_to_quantity_remaining?
    return unless SystemSetting.low_stock_alert_enabled?

    threshold = SystemSetting.low_stock_alert_threshold
    prev_qty  = quantity_remaining_before_last_save.to_f
    curr_qty  = quantity_remaining.to_f

    return unless prev_qty > threshold && curr_qty <= threshold
    return if curr_qty <= 0

    email = SystemSetting.low_stock_alert_email
    return if email.blank?

    LowStockMailer.alert(
      product:            product,
      store:              store,
      quantity_remaining: curr_qty,
      threshold:          threshold,
      recipient_email:    email
    ).deliver_later
  rescue StandardError => e
    Rails.logger.error "LowStockMailer failed: #{e.message}"
  end
end
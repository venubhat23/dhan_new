class VendorPurchase < ApplicationRecord
  include DashboardCacheBust
  belongs_to :vendor
  has_many :vendor_purchase_items, dependent: :destroy
  has_many :products, through: :vendor_purchase_items
  has_many :stock_batches, dependent: :destroy
  has_many :vendor_payments, dependent: :destroy
  has_one :vendor_invoice, dependent: :destroy

  validates :purchase_date, presence: true
  validates :paid_amount, numericality: { greater_than_or_equal_to: 0 }
  validate :must_have_items
  validate :validate_total_amount
  validates :status, inclusion: { in: %w[pending completed cancelled] }

  accepts_nested_attributes_for :vendor_purchase_items, reject_if: lambda { |attrs| attrs['product_id'].blank? && attrs['quantity'].blank? }, allow_destroy: true

  scope :pending, -> { where(status: 'pending') }
  scope :completed, -> { where(status: 'completed') }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :recent, -> { order(created_at: :desc) }

  before_save :calculate_totals
  after_save :create_stock_batches, if: :saved_change_to_id?
  # Runs after the nested items have been saved (the autosave callbacks are
  # declared first), so dirty tracking on the items is already cleared here —
  # reconcile against the batches instead. Only for saves that submitted items
  # (the edit form), not status/payment updates.
  after_update :sync_stock_batches, if: -> { @items_submitted }
  after_save -> { @items_submitted = false }

  def vendor_purchase_items_attributes=(attributes)
    @items_submitted = true
    super
  end

  # Flat option list for the purchase form's product picker. Multi-quantity
  # products expand to one entry per variant (so a purchase line can target a
  # specific pack size); everything else stays a single product entry. `value`
  # is the composite the <select> carries: "<product_id>" for a plain product
  # or "<product_id>-v<variant_id>" for a variant.
  def self.product_option_list(products)
    products.flat_map do |product|
      if product.has_multiple_quantities? && product.product_variants.any?
        product.sorted_variants.map do |variant|
          {
            value: "#{product.id}-v#{variant.id}",
            product_id: product.id,
            variant_id: variant.id,
            name: "#{product.name} — #{variant.label}",
            unit_type: 'units',
            default_selling_price: variant.effective_price.to_f,
            default_purchase_price: variant_purchase_cost(variant)
          }
        end
      else
        [{
          value: product.id.to_s,
          product_id: product.id,
          variant_id: nil,
          name: product.name,
          unit_type: product.unit_type || 'units',
          default_selling_price: (product.default_selling_price.to_f.positive? ? product.default_selling_price : product.price).to_f,
          default_purchase_price: product.try(:buying_price).to_f
        }]
      end
    end
  end

  # Last known cost for a variant, used only to prefill the purchase-price field.
  def self.variant_purchase_cost(variant)
    cost = variant.buying_price.to_f
    cost = variant.try(:purchase_price).to_f if cost <= 0
    cost
  end

  def purchase_number
    "VP#{id.to_s.rjust(6, '0')}"
  end

  def outstanding_amount
    total_amount - paid_amount
  end

  def payment_status
    if paid_amount >= total_amount
      'paid'
    elsif paid_amount > 0
      'partial'
    else
      'unpaid'
    end
  end

  def payment_status_badge_class
    case payment_status
    when 'paid'
      'bg-success text-white border-0'
    when 'partial'
      'bg-warning text-dark border-0'
    when 'unpaid'
      'bg-danger text-white border-0'
    else
      'bg-secondary text-white border-0'
    end
  end

  def status_badge_class
    case status
    when 'completed'
      'bg-success text-white border-0'
    when 'pending'
      'bg-warning text-dark border-0'
    when 'cancelled'
      'bg-danger text-white border-0'
    else
      'bg-secondary text-white border-0'
    end
  end

  def can_be_cancelled?
    status == 'pending'
  end

  def can_be_edited?
    status == 'pending'
  end

  def has_invoice?
    vendor_invoice.present?
  end

  def invoice_url
    vendor_invoice&.public_url
  end

  private

  def must_have_items
    if vendor_purchase_items.reject(&:marked_for_destruction?).empty?
      errors.add(:base, "Purchase must have at least one item")
    end
  end

  def validate_total_amount
    # Calculate total manually for validation
    calculate_totals

    if total_amount.blank?
      errors.add(:total_amount, "can't be blank")
    elsif total_amount <= 0
      errors.add(:total_amount, "must be greater than 0. Please add at least one item.")
    end
  end

  def calculate_totals
    # Calculate total from items (both saved and unsaved)
    total = 0

    # Include both persisted and new items
    all_items = vendor_purchase_items.reject(&:marked_for_destruction?)

    all_items.each do |item|
      if item.quantity.present? && item.purchase_price.present?
        quantity = item.quantity.to_f
        price = item.purchase_price.to_f
        line_total = quantity * price
        total += line_total if line_total > 0
      end
    end

    self.total_amount = total
    self.paid_amount ||= 0
  end

  def create_stock_batches
    vendor_purchase_items.each { |item| add_item_stock(item) }
  end

  # Brings the purchase's stock batches in line with its current items after an
  # edit: new lines get a batch, changed quantities adjust the batch by the
  # difference (keeping whatever has already been sold from it), and removed
  # lines take their unsold quantity back out of stock.
  def sync_stock_batches
    items = vendor_purchase_items.reload.to_a
    batches = stock_batches.reload.to_a

    items.each do |item|
      batch = batches.find { |b| b.product_id == item.product_id && b.product_variant_id == item.product_variant_id }
      if batch
        batches.delete(batch)
        adjust_item_stock(item, batch)
      else
        add_item_stock(item)
      end
    end

    batches.each { |batch| remove_batch_stock(batch) }
  end

  def add_item_stock(item)
    product = item.product
    variant = item.product_variant
    current_stock = on_hand_stock(product, variant)

    StockBatch.create!(
      product: product,
      product_variant: variant,
      vendor: vendor,
      vendor_purchase: self,
      quantity_purchased: item.quantity,
      quantity_remaining: item.quantity,
      purchase_price: item.purchase_price,
      selling_price: item.selling_price,
      batch_date: purchase_date,
      status: 'active'
    )

    new_stock = apply_on_hand_change(product, variant, item.quantity.to_f)
    product.stock_movements.create!(
      reference_type: 'vendor_purchase',
      reference_id: id,
      movement_type: 'added',
      quantity: item.quantity.to_f, # Positive for addition
      stock_before: current_stock,
      stock_after: new_stock,
      notes: "Stock added from vendor purchase: #{purchase_number} - #{item.display_name} (Qty: #{item.quantity})"
    )
  end

  def adjust_item_stock(item, batch)
    product = item.product
    variant = item.product_variant
    current_stock = on_hand_stock(product, variant)
    quantity_difference = item.quantity.to_f - batch.quantity_purchased.to_f
    # Can't take back more than is still unsold in this batch.
    remaining_change = [quantity_difference, -batch.quantity_remaining.to_f].max

    batch.update!(
      quantity_purchased: item.quantity,
      quantity_remaining: batch.quantity_remaining.to_f + remaining_change,
      purchase_price: item.purchase_price,
      selling_price: item.selling_price
    )
    return if remaining_change.zero?

    new_stock = apply_on_hand_change(product, variant, remaining_change)
    product.stock_movements.create!(
      reference_type: 'vendor_purchase',
      reference_id: id,
      movement_type: remaining_change > 0 ? 'added' : 'adjusted',
      quantity: remaining_change,
      stock_before: current_stock,
      stock_after: new_stock,
      notes: "Vendor purchase updated: #{purchase_number} - #{item.display_name} quantity changed by #{quantity_difference}"
    )
  end

  def remove_batch_stock(batch)
    product = batch.product
    variant = batch.product_variant
    current_stock = on_hand_stock(product, variant)
    unsold = batch.quantity_remaining.to_f

    batch.update!(quantity_remaining: 0, status: 'exhausted')
    return if unsold.zero?

    new_stock = apply_on_hand_change(product, variant, -unsold)
    product.stock_movements.create!(
      reference_type: 'vendor_purchase',
      reference_id: id,
      movement_type: 'adjusted',
      quantity: -unsold,
      stock_before: current_stock,
      stock_after: new_stock,
      notes: "Vendor purchase updated: #{purchase_number} - #{variant ? "#{product.name} #{variant.label}" : product.name} line removed"
    )
  end

  def on_hand_stock(product, variant)
    variant ? variant.available_stock.to_f : product.total_batch_stock
  end

  # Update the on-hand stock field: variant available_stock for a variant
  # line, product stock (kept in sync with batch totals) otherwise. Uses
  # update_column to skip validations since only stock is changing.
  def apply_on_hand_change(product, variant, quantity)
    if variant
      new_stock = [(variant.available_stock.to_f + quantity).round, 0].max
      variant.update_column(:available_stock, new_stock)
    else
      new_stock = product.total_batch_stock
      product.update_column(:stock, new_stock)
    end
    new_stock
  end
end
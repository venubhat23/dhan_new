class Booking < ApplicationRecord
  include DashboardCacheBust
  belongs_to :customer, optional: true
  belongs_to :user, optional: true # Admin who created the booking
  belongs_to :booking_schedule, optional: true # For subscription bookings
  belongs_to :store, optional: true
  belongs_to :delivery_person, optional: true
  belongs_to :franchise, optional: true
  has_many :booking_items, dependent: :destroy
  # has_one :order, dependent: :nullify  # Temporarily disabled until booking_id column is added to orders table
  has_many :booking_invoices, dependent: :destroy
  has_many :sale_items, dependent: :destroy

  accepts_nested_attributes_for :booking_items, allow_destroy: true

  # A booking tagged to a store draws its stock down from that store's inventory
  # only (see BookingItem#stock_batches_scope) and is labelled a "Store Booking"
  # in the admin lists, regardless of who keyed it in.
  scope :store_bookings, -> { where.not(store_id: nil) }

  def store_booking?
    store_id.present?
  end


  # Delivery stages — the only booking statuses (DB, admin, store admin, mobile
  # UI, API). Order = display order; Delivered is the default.
  enum :status, {
    ordered_and_delivery_pending: 'ordered_and_delivery_pending',
    packed: 'packed',
    shipped: 'shipped',
    delivered: 'delivered',
    cancelled: 'cancelled',
    returned: 'returned',
    refund: 'refund',
    reconfirm_order: 'reconfirm_order'
  }

  # One official name per stage; every dropdown, badge and message uses these.
  STATUS_LABELS = {
    'ordered_and_delivery_pending' => 'Delivery Pending',
    'packed'          => 'Packed',
    'shipped'         => 'Shipped',
    'delivered'       => 'Delivered',
    'cancelled'       => 'Cancelled',
    'returned'        => 'Returned',
    'refund'          => 'Refund',
    'reconfirm_order' => 'Reconfirm order'
  }.freeze

  # Retired statuses (migrated away in the DB). Anything still sending them —
  # older mobile app builds, checkout/payment code, stage_history entries — is
  # mapped onto the current stage instead of failing.
  LEGACY_STATUS_MAP = {
    'draft'            => 'ordered_and_delivery_pending',
    'confirmed'        => 'ordered_and_delivery_pending',
    'processing'       => 'ordered_and_delivery_pending',
    'out_for_delivery' => 'shipped',
    'completed'        => 'delivered'
  }.freeze

  DEFAULT_STATUS = 'delivered'.freeze

  # Forward path shown as the progress bar on booking lists.
  PROGRESS_STAGES = %w[ordered_and_delivery_pending packed shipped delivered].freeze

  def self.normalize_status(value)
    LEGACY_STATUS_MAP.fetch(value.to_s, value)
  end

  def status=(value)
    super(self.class.normalize_status(value))
  end

  # Value for a status filter param (old links may still say e.g. 'completed').
  def self.status_filter_values(status)
    normalize_status(status).to_s
  end

  # 0-based position on PROGRESS_STAGES (nil for cancelled/returned/refund).
  def progress_stage_index
    return nil if %w[cancelled returned refund].include?(status)

    PROGRESS_STAGES.index(status) || 0
  end

  # Next step along the normal flow, or nil when delivered/closed.
  def next_stage
    idx = progress_stage_index
    idx && PROGRESS_STAGES[idx + 1]
  end

  def self.status_label(status)
    STATUS_LABELS[normalize_status(status).to_s] || status.to_s.humanize.presence || 'Unknown'
  end

  # [[label, value], ...] for a status <select>.
  def self.status_options
    STATUS_LABELS.map { |value, label| [label, value] }
  end

  def status_label
    self.class.status_label(status)
  end

  def status_for_select
    status.to_s
  end

  def status_select_options
    self.class.status_options
  end

  enum :payment_status, {
    unpaid: 'unpaid',
    paid: 'paid',
    partially_paid: 'partially_paid',
    refunded: 'refunded'
  }, prefix: true

  enum :payment_method, {
    cash: 0,
    card: 1,
    upi: 2,
    bank_transfer: 3,
    online: 4,
    cod: 5,
    cashfree: 6,
    cloudflare: 7
  }, prefix: true

  enum :payment_gateway, {
    cash: 'cash',
    cashfree: 'cashfree',
    cloudflare: 'cloudflare',
    upi_direct: 'upi_direct'
  }, prefix: true

  # Validations
  validates :booking_number, presence: true, uniqueness: true
  validates :total_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  before_validation :generate_booking_number, on: :create
  before_validation :link_or_create_customer, on: :create
  before_create     :generate_share_token
  before_validation :calculate_totals
  before_validation :calculate_final_amount_after_discount
  after_validation :ensure_total_amount_present
  after_update :allocate_inventory, if: :saved_change_to_status?
  after_update :sync_invoice_payment_status, if: :saved_change_to_payment_status?
  after_update :sync_invoice_delivery_charge, if: :saved_change_to_shipping_charges?
  after_save :sync_invoice_items_from_booking
  after_commit :bust_mobile_customer_cache

  def bust_mobile_customer_cache
    cid = customer_id || customer&.id
    MobileApiCache.bust_booking!(cid)
  end

  # Keeps the already-generated Invoice's payment_status in step with the booking's,
  # so a booking marked paid after invoice creation doesn't leave a stale "unpaid" invoice.
  # Some bookings (e.g. created unpaid via the mobile UI) never got an invoice generated
  # at creation time — if one of those is later marked paid, generate the invoice now
  # instead of silently no-op'ing.
  def sync_invoice_payment_status
    unless invoice_generated? && invoice_number.present?
      generate_quick_invoice! if payment_status_paid?
      return
    end

    invoice = Invoice.find_by(invoice_number: invoice_number)
    return unless invoice

    case payment_status
    when 'paid'
      return if invoice.payment_status == 'fully_paid'
      invoice.update(payment_status: :fully_paid, paid_at: invoice.paid_at || Time.current, paid_amount: invoice.total_amount)
    when 'partially_paid'
      return if invoice.payment_status == 'partially_paid'
      invoice.update(payment_status: :partially_paid)
    else
      return if invoice.payment_status == 'unpaid'
      invoice.update(payment_status: :unpaid, paid_at: nil, paid_amount: 0)
    end
  end

  # Keeps the already-generated Invoice's delivery_charge in step with the booking's
  # shipping_charges, so editing it on either screen updates both totals.
  def sync_invoice_delivery_charge
    return unless invoice_generated? && invoice_number.present?

    invoice = Invoice.find_by(invoice_number: invoice_number)
    return unless invoice
    return if invoice.delivery_charge.to_f == shipping_charges.to_f

    invoice.update(delivery_charge: shipping_charges)
  end

  # Keeps the already-generated Invoice's invoice_items in step with this booking's
  # booking_items (products/quantities/prices), so editing line items on either
  # screen propagates to the other. Mirrors Invoice#sync_booking_items_from_invoice.
  def sync_invoice_items_from_booking
    return unless invoice_generated? && invoice_number.present?

    invoice = Invoice.find_by(invoice_number: invoice_number)
    return unless invoice

    invoice.rebuild_items_from_booking!(self)
  rescue => e
    Rails.logger.error "Failed to sync invoice items from booking ##{id}: #{e.message}"
  end

  # Rebuilds this booking's booking_items from an invoice's current invoice_items.
  # Booking items have stock side effects (allocation/restoration on create/update/
  # destroy), so matched products are updated in place rather than destroyed and
  # recreated, to avoid spurious stock churn. Called by Invoice#sync_booking_items_from_invoice.
  def rebuild_items_from_invoice!(invoice)
    return if items_match_invoice?(invoice)

    transaction do
      target_rows = invoice.invoice_items.includes(:product).filter_map do |ii|
        next unless ii.product
        {
          product: ii.product,
          quantity: ii.quantity,
          price: final_price_for(ii.product, invoice_item_list_price(ii)),
          discount_type: ii.discount_type.presence,
          discount_value: ii.discount_type.present? ? ii.discount_value : nil
        }
      end

      existing_by_product = booking_items.index_by(&:product_id)
      seen_product_ids = []

      target_rows.each do |row|
        seen_product_ids << row[:product].id
        existing = existing_by_product[row[:product].id]
        attrs = { quantity: row[:quantity], price: row[:price],
                  discount_type: row[:discount_type], discount_value: row[:discount_value] }

        if existing
          unless existing.quantity.to_f.round(3) == row[:quantity].to_f.round(3) &&
                 existing.price.to_f.round(2) == row[:price].round(2) &&
                 existing.discount_type.presence == row[:discount_type] &&
                 existing.discount_value.to_f == row[:discount_value].to_f
            existing.update!(attrs)
          end
        else
          booking_items.create!(attrs.merge(product: row[:product]))
        end
      end

      if seen_product_ids.any?
        booking_items.where.not(product_id: seen_product_ids).destroy_all
      else
        booking_items.destroy_all
      end

      # The where.not(...).destroy_all above runs on a separate query, so the
      # association loaded by index_by still holds the removed rows; reload it so
      # calculate_totals (before_validation) recomputes total_amount from what's left.
      booking_items.reset
      update!(shipping_charges: invoice.delivery_charge.to_f)
    end
  rescue => e
    Rails.logger.error "Failed to rebuild booking ##{id} items from invoice ##{invoice.id}: #{e.message}"
  end

  def items_match_invoice?(invoice)
    current = booking_items.map do |bi|
      [bi.product_id, bi.quantity.to_f.round(3), bi.price.to_f.round(2),
       bi.discount_type.presence, bi.discount_value.to_f]
    end.sort_by { |row| row.map(&:to_s) }
    target = invoice.invoice_items.filter_map do |ii|
      next unless ii.product_id
      [ii.product_id, ii.quantity.to_f.round(3), final_price_for(ii.product, invoice_item_list_price(ii)).round(2),
       ii.discount_type.presence, (ii.discount_type.present? ? ii.discount_value.to_f : 0.0)]
    end.sort_by { |row| row.map(&:to_s) }

    current == target && shipping_charges.to_f.round(2) == invoice.delivery_charge.to_f.round(2)
  end

  # The pre-discount base unit price recorded on an invoice line (falls back to
  # the net unit_price for legacy rows written before per-line discounts existed).
  def invoice_item_list_price(invoice_item)
    invoice_item.original_unit_price.presence || invoice_item.unit_price
  end

  # Tax-inclusive price derived from an invoice's base unit_price, matching the
  # tax-inclusive-price convention used by booking_item.price.
  def final_price_for(product, base_unit_price)
    return base_unit_price.to_f unless product&.gst_enabled? && product.gst_percentage.present?

    base_unit_price.to_f * (1 + product.gst_percentage.to_f / 100)
  end

  # Base (pre-GST) price extracted from an actually-charged, tax-inclusive price.
  def base_unit_price_for(product, charged_price)
    return charged_price.to_f unless product&.gst_enabled? && product.gst_percentage.present?

    charged_price.to_f / (1 + product.gst_percentage.to_f / 100)
  end

  # Base (pre-GST), discount-adjusted unit price for a booking_item, used when
  # generating/syncing this booking's invoice line items. Shared by
  # generate_quick_invoice! and Invoice#rebuild_items_from_booking! so the two
  # paths never disagree on how a line's price is derived. GST is extracted from
  # the price actually charged on the item (not the product's current master
  # price), so later product price changes don't retroactively alter old invoices.
  def invoice_unit_price_for(booking_item)
    # Start from the per-product-discounted, tax-inclusive unit price, then strip GST.
    unit_price = base_unit_price_for(booking_item.product, booking_item.discounted_unit_price)

    if discount_amount.to_f > 0 && total_amount.to_f > 0
      unit_price = unit_price * (1 - discount_amount.to_f / total_amount.to_f)
    end

    unit_price.to_f
  end

  scope :recent, -> { order(created_at: :desc) }
  scope :today, -> { where(created_at: Date.current.all_day) }
  scope :active, -> { where.not(status: [:cancelled, :returned, :refund]) }
  scope :completed_orders, -> { where(status: :delivered) }
  scope :pending_orders, -> { where(status: [:ordered_and_delivery_pending, :reconfirm_order]) }
  scope :in_progress, -> { where(status: [:packed, :shipped]) }

  def generate_booking_number
    self.booking_number ||= "BK#{Date.current.strftime('%Y%m%d')}#{SecureRandom.hex(3).upcase}"
  end

  # 16 random bytes (128 bits of entropy) makes a collision practically
  # impossible, so this skips the extra Booking.exists? round-trip per call —
  # ensure_share_token! runs per booking row on every index page view for any
  # booking still missing a token. The DB's unique index on share_token is the
  # real backstop; #ensure_share_token! retries in the astronomically rare
  # case it fires.
  def generate_share_token
    return if share_token.present?
    self.share_token = SecureRandom.urlsafe_base64(16)
  end

  def ensure_share_token!
    return share_token if share_token.present?
    generate_share_token
    begin
      update_column(:share_token, share_token)
    rescue ActiveRecord::RecordNotUnique
      self.share_token = nil
      retry
    end
    share_token
  end


  def create_booking_invoice_record
    return if booking_invoices.any? # Avoid duplicates

    # Ensure totals are calculated before creating invoice
    calculate_totals

    booking_invoices.create!(
      customer: self.customer,
      invoice_number: self.invoice_number,
      invoice_date: Time.current,
      due_date: 30.days.from_now,
      subtotal: self.subtotal || 0,
      tax_amount: self.tax_amount || 0,
      discount_amount: self.discount_amount || 0,
      total_amount: self.total_amount || 0,
      payment_status: self.payment_status || :unpaid,
      status: :sent,
      notes: "Invoice generated for booking ##{self.booking_number}"
    )
  rescue => e
    Rails.logger.error "Failed to create BookingInvoice for Booking ##{id}: #{e.message}"
    # Don't fail the booking creation if invoice creation fails
  end

  def calculate_totals
    # Calculate totals for items (including unsaved ones)
    items_total = 0
    total_gst = 0

    booking_items.each do |item|
      if item.quantity.present? && item.price.present?
        quantity = item.quantity
        # Per-product (line-item) discount is applied to the tax-inclusive price
        # first; GST is then re-extracted from the reduced amount below.
        price = item.discounted_unit_price

        # Check if product has GST enabled
        if item.product && item.product.gst_enabled && item.product.gst_percentage.to_f > 0
          # Price is inclusive of GST: tax is extracted (rate/(100+rate)), base = price - tax.
          # Matches the invoice, whose base unit_price is price / (1 + rate).
          gst_rate = item.product.gst_percentage.to_f
          total_price = price * quantity
          item_gst = (total_price * gst_rate / (100 + gst_rate)).round(2)
          item_base = total_price - item_gst

          items_total += item_base
          total_gst += item_gst
        else
          # No GST, use price as is
          items_total += price * quantity
        end
      end
    end

    # Ensure discount doesn't exceed subtotal + tax
    current_discount = discount_amount.to_f
    max_discount = items_total + total_gst
    if current_discount > max_discount
      current_discount = max_discount
      self.discount_amount = current_discount
    end

    self.subtotal = items_total.round(2)
    self.tax_amount = total_gst.round(2)
    self.total_amount = (items_total + total_gst - current_discount + shipping_charges.to_f).round(2)
  end

  def calculate_totals!
    calculate_totals
    save!
  end

  # Dynamic calculation methods for invoice display
  def calculated_subtotal
    return subtotal if subtotal.present?

    total = booking_items.sum { |item| (item.quantity || 0) * item.discounted_unit_price }
    total.round(2)
  end

  def calculated_tax_amount
    return tax_amount if tax_amount.present?

    # Calculate GST based on individual products
    total_gst = 0
    booking_items.each do |item|
      if item.product && item.product.gst_enabled && item.product.gst_percentage.to_f > 0
        gst_rate = item.product.gst_percentage.to_f
        item_incl = item.discounted_unit_price * (item.quantity || 0)
        item_gst = (item_incl * gst_rate / (100 + gst_rate)).round(2)
        total_gst += item_gst
      end
    end
    total_gst.round(2)
  end

  def calculated_gst_percentage
    return 0 if calculated_subtotal == 0
    ((calculated_tax_amount / calculated_subtotal) * 100).round(2)
  end

  def calculated_total_amount
    return total_amount if total_amount.present?

    (calculated_subtotal + calculated_tax_amount - (discount_amount || 0) + shipping_charges.to_f).round(2)
  end

  def amount_in_words
    amount = calculated_total_amount.to_i
    convert_to_words(amount) + " Rupees Only"
  end

  # Status management methods
  def can_cancel?
    %w[ordered_and_delivery_pending reconfirm_order packed].include?(status)
  end

  def can_return?
    delivered?
  end

  # "Confirmed" is no longer a separate stage: confirming a re-confirm order puts
  # it back to Delivery Pending and sends the confirmation email.
  def mark_as_confirmed!
    if ordered_and_delivery_pending? || reconfirm_order?
      update!(status: :ordered_and_delivery_pending)
      send_booking_confirmation_email
    end
  end

  # Kept for older callers; "processing" is part of Delivery Pending → Packed.
  def mark_as_processing!
    mark_as_packed!
  end

  def mark_as_packed!
    update!(status: :packed) if ordered_and_delivery_pending? || reconfirm_order?
  end

  def mark_as_shipped!(tracking_number = nil)
    if packed?
      updates = { status: :shipped }
      updates[:notes] = "#{notes}\nTracking: #{tracking_number}" if tracking_number.present?
      update!(updates)
    end
  end

  # Kept for older callers; "out for delivery" is part of Shipped.
  def mark_as_out_for_delivery!
    mark_as_shipped!
  end

  def mark_as_delivered!
    return if delivered? || %w[cancelled returned refund].include?(status)

    update!(
      status: :delivered,
      notes: "#{notes}\nDelivered at: #{Time.current.strftime('%d/%m/%Y %I:%M %p')}"
    )
    # Generate and send invoice when booking is delivered
    generate_and_send_completion_notification
  end

  # "Completed" is the same stage as Delivered now.
  def mark_as_completed!
    mark_as_delivered!
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
    when 'ordered_and_delivery_pending' then 'secondary'
    when 'packed' then 'warning'
    when 'shipped' then 'primary'
    when 'delivered' then 'success'
    when 'cancelled', 'returned', 'refund' then 'danger'
    when 'reconfirm_order' then 'info'
    else 'secondary'
    end
  end

  def status_icon
    case status
    when 'ordered_and_delivery_pending' then 'bi-clock'
    when 'packed' then 'bi-box'
    when 'shipped' then 'bi-truck'
    when 'delivered' then 'bi-house-check'
    when 'cancelled' then 'bi-x-circle'
    when 'returned' then 'bi-arrow-return-left'
    when 'refund' then 'bi-cash-coin'
    when 'reconfirm_order' then 'bi-telephone'
    else 'bi-question-circle'
    end
  end

  # Any of the standard statuses other than the current one (staff move orders
  # freely between them, same as the edit-page dropdown).
  def next_possible_statuses
    STATUS_LABELS.keys - [status_for_select]
  end

  def payment_method_display
    case payment_method.to_s
    when 'cash'          then 'Cash'
    when 'card'          then 'Card'
    when 'upi'           then 'UPI'
    when 'bank_transfer' then 'Bank Transfer'
    when 'online'        then 'Online'
    when 'cod'           then 'Cash on Delivery'
    when 'cashfree', 'cloudflare' then 'Online Payment'
    else 'Cash on Delivery'
    end
  end

  def payment_method_label
    %w[card upi bank_transfer online cashfree cloudflare].include?(payment_method.to_s) ? 'Online Payment' : 'Cash on Delivery'
  end

  def payment_status_display
    case payment_status.to_s
    when 'unpaid'         then 'Unpaid'
    when 'paid'           then 'Paid'
    when 'partially_paid' then 'Partially Paid'
    when 'refunded'       then 'Refunded'
    else 'Unpaid'
    end
  end

  # Temporary method to handle missing booking_id column in orders table
  def order
    # TODO: Remove this method once booking_id column is added to orders table
    # Return nil for now to avoid association errors
    return nil
  end

  # Also define as a method to prevent Rails from trying to load association
  def order=(value)
    # Do nothing for now
  end

  # Find the associated invoice created by the consolidated invoice generation system
  def associated_invoice
    return @associated_invoice if defined?(@associated_invoice)

    # Look for invoice items that reference this booking by booking number in the description
    invoice_item = InvoiceItem.joins(:invoice)
                             .where('description LIKE ?', "%#{booking_number}%")
                             .first

    @associated_invoice = invoice_item&.invoice
  end

  # Check if this booking has an associated invoice (either BookingInvoice or regular Invoice)
  def has_invoice?
    booking_invoices.any? || associated_invoice.present?
  end

  # Get the invoice link for this booking (prioritize regular Invoice over BookingInvoice)
  def invoice_link_path
    if associated_invoice
      "/admin/invoices/#{associated_invoice.id}"
    elsif booking_invoices.any?
      "/admin/booking_invoices/#{booking_invoices.first.id}"
    else
      nil
    end
  end

  # Get the invoice number for display (prioritize regular Invoice over BookingInvoice)
  def display_invoice_number
    if associated_invoice
      associated_invoice.invoice_number
    elsif booking_invoices.any?
      booking_invoices.first.invoice_number
    else
      invoice_number # fallback to booking's own invoice_number field
    end
  end

  # Calculate final amount after discount
  def calculate_final_amount_after_discount
    # Calculate from subtotal + tax - discount (not from total_amount which may already include discount)
    base_amount = (subtotal || calculated_subtotal).to_f + (tax_amount || calculated_tax_amount).to_f
    discount_amt = discount_amount.to_f

    if discount_amt > 0
      self.final_amount_after_discount = base_amount - discount_amt
    else
      self.final_amount_after_discount = base_amount
    end
  end

  # Email notification methods
  def send_booking_confirmation_email
    return unless customer&.email.present?

    begin
      CustomerMailer.booking_confirmation(self).deliver_now
      Rails.logger.info "Booking confirmation email sent for booking ##{booking_number} to #{customer.email}"
    rescue => e
      Rails.logger.error "Failed to send booking confirmation email for booking ##{booking_number}: #{e.message}"
      # Don't fail the booking process if email fails
    end
  end

  def send_booking_confirmation_email_async
    return unless customer&.email.present?

    begin
      CustomerMailer.booking_confirmation(self).deliver_later
      Rails.logger.info "Booking confirmation email queued for booking ##{booking_number} to #{customer.email}"
    rescue => e
      Rails.logger.error "Failed to queue booking confirmation email for booking ##{booking_number}: #{e.message}"
    end
  end

  def generate_and_send_completion_notification
    return unless customer&.email.present?

    begin
      # Generate invoice if not already generated
      generate_invoice_number unless invoice_number.present?

      # Ensure any associated invoice has a share token for public access
      if associated_invoice && !associated_invoice.share_token.present?
        associated_invoice.generate_share_token!
      end

      # Send completion email with invoice
      send_booking_confirmation_email
      Rails.logger.info "Booking completion notification sent for booking ##{booking_number} to #{customer.email}"
    rescue => e
      Rails.logger.error "Failed to send booking completion notification for booking ##{booking_number}: #{e.message}"
    end
  end

  def generate_invoice_number
    return if invoice_number.present?

    self.invoice_number = "INV#{Date.current.strftime('%Y%m%d')}#{SecureRandom.hex(3).upcase}"
    self.invoice_generated = true

    # Save the booking first
    if save
      # BookingInvoice creation disabled - invoices will be generated via consolidated system
      # create_booking_invoice_record
    end
  end

  # A booking typed in with just a name/phone (no customer picked) still gets
  # a Customer record, so new customers appear in the customers list.
  def link_or_create_customer
    return if customer_id.present? || customer.present? || customer_phone.blank?

    self.customer = Customer.find_or_create_from_booking_contact(
      name: customer_name, phone: customer_phone, email: customer_email
    )
  end

  private

  def ensure_total_amount_present
    if total_amount.blank? || total_amount <= 0
      errors.add(:base, "Please add at least one item to the booking")
    end
  end

  def convert_to_words(number)
    return "Zero" if number == 0

    ones = %w[Zero One Two Three Four Five Six Seven Eight Nine Ten Eleven Twelve Thirteen Fourteen Fifteen Sixteen Seventeen Eighteen Nineteen]
    tens = %w[Zero Ten Twenty Thirty Forty Fifty Sixty Seventy Eighty Ninety]

    result = []

    # Handle thousands
    if number >= 1000
      thousands = number / 1000
      if thousands >= 100
        result << ones[thousands / 100]
        result << "Hundred"
        thousands %= 100
      end

      if thousands >= 20
        result << tens[thousands / 10]
        thousands %= 10
      end

      if thousands > 0
        result << ones[thousands]
      end

      result << "Thousand"
      number %= 1000
    end

    # Handle hundreds
    if number >= 100
      result << ones[number / 100]
      result << "Hundred"
      number %= 100
    end

    # Handle tens and ones
    if number >= 20
      result << tens[number / 10]
      number %= 10
    end

    if number > 0
      result << ones[number]
    end

    result.join(" ")
  end

  def allocate_inventory
    # Only allocate when order is confirmed
    if status == 'confirmed' && status_previously_was != 'confirmed'
      begin
        inventory_service = InventoryService.new

        # Prepare items for allocation
        items = booking_items.map do |item|
          {
            product_id: item.product_id,
            quantity: item.quantity
          }
        end

        # Check availability first
        insufficient_items = []
        allocation_data = []

        items.each do |item|
          availability = inventory_service.check_availability(item[:product_id], item[:quantity])
          if availability[:available]
            allocations = inventory_service.allocate_stock(item[:product_id], item[:quantity])
            allocation_data << allocations
          else
            insufficient_items << {
              product: Product.find(item[:product_id]).name,
              available: availability[:available_stock],
              requested: item[:quantity],
              shortage: availability[:shortage]
            }
          end
        end

        if insufficient_items.any?
          # Revert status if inventory is insufficient
          update_column(:status, status_previously_was)
          errors.add(:status, "Insufficient inventory: #{insufficient_items.map { |item|
            "#{item[:product]} (need #{item[:requested]}, have #{item[:available]})"
          }.join(', ')}")
          return false
        else
          # Reduce stock and create sale items
          allocation_data.flatten.each_with_index do |allocation, index|
            inventory_service.reduce_stock([allocation])

            # Create sale item for tracking
            SaleItem.create!(
              booking: self,
              product: allocation[:batch].product,
              stock_batch: allocation[:batch],
              quantity: allocation[:quantity],
              selling_price: allocation[:selling_price],
              purchase_price: allocation[:purchase_price]
            )
          end

          Rails.logger.info "Inventory allocated successfully for booking ##{booking_number}"
        end
      rescue InventoryService::InsufficientStockError => e
        # Revert status if inventory allocation fails
        update_column(:status, status_previously_was)
        errors.add(:status, "Inventory allocation failed: #{e.message}")
        return false
      rescue => e
        Rails.logger.error "Error allocating inventory for booking ##{booking_number}: #{e.message}"
        # Don't revert status for other errors, just log them
      end
    end

    # Free up inventory when order is cancelled or returned
    if %w[cancelled returned].include?(status) && !%w[cancelled returned].include?(status_previously_was)
      begin
        release_allocated_inventory
      rescue => e
        Rails.logger.error "Error releasing inventory for booking ##{booking_number}: #{e.message}"
      end
    end
  end

  def release_allocated_inventory
    # Find all sale items for this booking and restore the stock
    SaleItem.where(booking: self).find_each do |sale_item|
      stock_batch = sale_item.stock_batch
      product = sale_item.product

      if stock_batch
        # Restore the quantity to the batch
        stock_batch.quantity_remaining += sale_item.quantity
        stock_batch.status = 'active' if stock_batch.exhausted? && stock_batch.quantity_remaining > 0
        stock_batch.save!

        Rails.logger.info "Restored #{sale_item.quantity} units to batch #{stock_batch.batch_number}"

        # Update product stock for backward compatibility
        if product
          product.update_column(:stock, product.total_batch_stock)
        end
      end

      # Mark the sale item as refunded/returned
      sale_item.destroy
    end
  end

  public

  # Cashfree Payment Methods
  def self.generate_cashfree_order_id
    "MKS_#{Time.current.strftime('%Y%m%d%H%M%S')}_#{SecureRandom.hex(4).upcase}"
  end

  def mark_payment_initiated!(gateway = 'cashfree')
    update!(
      payment_gateway: gateway,
      payment_initiated_at: Time.current,
      payment_status: 'unpaid'
    )
  end

  def mark_payment_completed!(payment_details = {})
    update!(
      payment_status: 'paid',
      payment_completed_at: Time.current,
      cashfree_payment_id: payment_details[:cf_payment_id],
      payment_method: payment_details[:payment_method] || 'cashfree',
      gateway_response: payment_details.to_json,
      status: 'confirmed'
    )
    # Send booking confirmation email when payment is completed
    send_booking_confirmation_email

    # Generate invoice automatically after payment completion
    generate_invoice_after_payment
  end

  def mark_payment_failed!(failure_reason = nil)
    response_data = { failure_reason: failure_reason, failed_at: Time.current }
    update!(
      payment_status: 'unpaid',
      gateway_response: response_data.to_json
    )
  end

  def can_initiate_payment?
    ordered_and_delivery_pending? && total_amount.present? && total_amount > 0 && customer.present?
  end

  def payment_pending?
    payment_initiated_at.present? && payment_completed_at.blank? && payment_status_unpaid?
  end

  def payment_successful?
    payment_status_paid? && cashfree_payment_id.present?
  end

  def gateway_response_hash
    return {} if gateway_response.blank?
    JSON.parse(gateway_response)
  rescue JSON::ParserError
    {}
  end

  def generate_invoice_after_payment
    # Check if invoice already exists
    return if booking_invoices.exists?

    begin
      # Create invoice for the booking using existing method
      create_booking_invoice_record

      Rails.logger.info "📄 Auto-generated invoice for booking ##{booking_number}"

      booking_invoices.first
    rescue => e
      Rails.logger.error "❌ Failed to auto-generate invoice for booking ##{booking_number}: #{e.message}"
      nil
    end
  end

  # Generate a proper Invoice record (with InvoiceItems) for this booking.
  # The invoice's payment_status mirrors the booking's payment_status (paid -> fully_paid,
  # otherwise unpaid). Sets invoice_generated=true and invoice_number on the booking so
  # the admin UI recognises the booking as invoiced. Returns the Invoice on success, nil on failure.
  def generate_quick_invoice!
    return nil if invoice_generated?
    return nil if booking_items.empty?

    invoice = Invoice.new(
      customer: customer,
      invoice_date: Date.current,
      due_date: Date.current + 30.days,
      status: :sent,
      payment_status: payment_status_paid? ? :fully_paid : :unpaid,
      paid_at: payment_status_paid? ? Time.current : nil,
      delivery_charge: shipping_charges.to_f,
      quick_invoice: true
    )

    invoice_total = 0

    # In the create flow booking_items is already loaded (with products memoised
    # from calculate_totals) — reuse it instead of forcing a fresh 3-query reload.
    items = booking_items.loaded? ? booking_items.to_a : booking_items.includes(:product, :product_variant).to_a
    items.each do |item|
      product = item.product
      next unless product

      unit_price = invoice_unit_price_for(item)
      item_total = item.quantity * unit_price
      invoice_total += item_total

      invoice.invoice_items.build(
        description: "#{product.name} - Booking ##{booking_number} (#{booking_date.strftime('%d %b %Y')})",
        quantity: item.quantity,
        unit_price: unit_price,
        total_amount: item_total,
        product: product,
        product_variant: item.product_variant,
        original_unit_price: base_unit_price_for(product, item.price),
        discount_type: item.discount_type.presence,
        discount_value: item.discount_type.present? ? item.discount_value : nil,
        discount_amount: item.discount_amount
      )
    end

    invoice.total_amount = invoice_total + shipping_charges.to_f

    if invoice.save
      # total_amount may have been recalculated by Invoice's before_validation
      # callback (tax-inclusive line totals), so paid_amount must be set from
      # the final persisted total, not the pre-save estimate above.
      invoice.update_column(:paid_amount, invoice.total_amount) if payment_status_paid?

      update_columns(
        invoice_generated: true,
        invoice_number: invoice.invoice_number,
        quick_invoice: true
      )
      Rails.logger.info "Invoice ##{invoice.invoice_number} generated for booking ##{booking_number}"
      invoice
    else
      Rails.logger.error "Failed to generate invoice for booking ##{booking_number}: #{invoice.errors.full_messages.join(', ')}"
      nil
    end
  rescue => e
    Rails.logger.error "Error generating invoice for booking ##{booking_number}: #{e.message}"
    nil
  end

  private

end

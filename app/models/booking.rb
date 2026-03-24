class Booking < ApplicationRecord
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


  # Enums - Comprehensive status for complete workflow
  enum :status, {
    draft: 'draft',                                 # Initial booking creation
    ordered_and_delivery_pending: 'ordered_and_delivery_pending', # Order placed, waiting for processing
    confirmed: 'confirmed',                         # Booking confirmed, payment received
    processing: 'processing',                       # Order being prepared
    packed: 'packed',                               # Items packed and ready
    shipped: 'shipped',                             # Shipped out
    out_for_delivery: 'out_for_delivery',          # Out for delivery
    delivered: 'delivered',                         # Successfully delivered
    completed: 'completed',                         # Transaction completed
    cancelled: 'cancelled',                         # Cancelled
    returned: 'returned'                           # Returned
  }

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
    cashfree: 6
  }, prefix: true

  enum :payment_gateway, {
    cash: 'cash',
    cashfree: 'cashfree',
    upi_direct: 'upi_direct'
  }, prefix: true

  # Validations
  validates :booking_number, presence: true, uniqueness: true
  validates :total_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  before_validation :generate_booking_number, on: :create
  before_validation :calculate_totals
  before_validation :calculate_final_amount_after_discount
  after_validation :ensure_total_amount_present
  after_update :allocate_inventory, if: :saved_change_to_status?

  scope :recent, -> { order(created_at: :desc) }
  scope :today, -> { where(created_at: Date.current.all_day) }
  scope :active, -> { where.not(status: [:cancelled, :returned]) }
  scope :completed_orders, -> { where(status: [:delivered, :completed]) }
  scope :pending_orders, -> { where(status: [:draft, :ordered_and_delivery_pending, :confirmed]) }
  scope :in_progress, -> { where(status: [:processing, :packed, :shipped, :out_for_delivery]) }

  def generate_booking_number
    self.booking_number ||= "BK#{Date.current.strftime('%Y%m%d')}#{SecureRandom.hex(3).upcase}"
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
        price = item.price

        # Check if product has GST enabled
        if item.product && item.product.gst_enabled && item.product.gst_percentage.to_f > 0
          # Price is exclusive of GST, so calculate GST on the price
          gst_rate = item.product.gst_percentage.to_f
          item_base = price * quantity
          item_gst = (item_base * gst_rate / 100).round(2)

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
    self.total_amount = (items_total + total_gst - current_discount).round(2)
  end

  def calculate_totals!
    calculate_totals
    save!
  end

  # Dynamic calculation methods for invoice display
  def calculated_subtotal
    return subtotal if subtotal.present?

    total = booking_items.sum { |item| (item.quantity || 0) * (item.price || 0) }
    total.round(2)
  end

  def calculated_tax_amount
    return tax_amount if tax_amount.present?

    # Calculate GST based on individual products
    total_gst = 0
    booking_items.each do |item|
      if item.product && item.product.gst_enabled && item.product.gst_percentage.to_f > 0
        gst_rate = item.product.gst_percentage.to_f
        item_base = (item.price || 0) * (item.quantity || 0)
        item_gst = (item_base * gst_rate / 100).round(2)
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

    (calculated_subtotal + calculated_tax_amount - (discount_amount || 0)).round(2)
  end

  def amount_in_words
    amount = calculated_total_amount.to_i
    convert_to_words(amount) + " Rupees Only"
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
      updates[:notes] = "#{notes}\nTracking: #{tracking_number}" if tracking_number.present?
      update!(updates)
    end
  end

  def mark_as_out_for_delivery!
    update!(status: :out_for_delivery) if shipped?
  end

  def mark_as_delivered!
    if out_for_delivery?
      update!(
        status: :delivered,
        notes: "#{notes}\nDelivered at: #{Time.current.strftime('%d/%m/%Y %I:%M %p')}"
      )
      # Auto-transition to completed when delivered (as per user requirement)
      mark_as_completed!
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
    when 'delivered' then ['returned']  # Auto-transitions to completed, so only return is possible
    else []
    end
  end

  def payment_method_display
    # Get the raw value from database
    raw_value = read_attribute('payment_method')
    return 'Unknown' if raw_value.blank?

    # Handle both string keys and numeric values since there's a mismatch
    case raw_value.to_s
    when 'cash', '0' then 'Cash'
    when 'card', '1' then 'Card'
    when 'upi', '2' then 'UPI'
    when 'bank_transfer', '3' then 'Bank Transfer'
    when 'online', '4' then 'Online'
    when 'cod', '5' then 'COD'
    when 'cashfree', '6' then 'Online Payment'
    else raw_value.to_s.humanize
    end
  end

  def payment_status_display
    # Get the raw value directly from database using SQL to bypass any Rails caching issues
    raw_value = self.class.connection.select_value("SELECT payment_status FROM bookings WHERE id = #{id}")
    return 'Unpaid' if raw_value.blank?

    case raw_value.to_s
    when 'unpaid', '0' then 'Unpaid'
    when 'paid', '1' then 'Paid'
    when 'partially_paid', '2' then 'Partially Paid'
    when 'refunded', '3' then 'Refunded'
    else 'Unpaid'
    end
  end

  # Method to provide booking_items_count functionality
  def booking_items_count
    booking_items.size
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
  end

  def mark_payment_failed!(failure_reason = nil)
    response_data = { failure_reason: failure_reason, failed_at: Time.current }
    update!(
      payment_status: 'unpaid',
      gateway_response: response_data.to_json
    )
  end

  def can_initiate_payment?
    draft? && total_amount.present? && total_amount > 0 && customer.present?
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

end

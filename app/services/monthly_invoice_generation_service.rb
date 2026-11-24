class MonthlyInvoiceGenerationService
  attr_reader :month, :year, :customer_id

  def initialize(month: Date.current.month, year: Date.current.year, customer_id: nil)
    @month = month
    @year = year
    @customer_id = customer_id
  end

  # Generate invoices for all customers or specific customer
  def generate_monthly_invoices
    customers = customer_id ? [Customer.find(customer_id)] : Customer.all
    results = []

    customers.each do |customer|
      result = generate_invoice_for_customer(customer)
      results << result if result
    end

    results
  end

  # Generate invoice for a specific customer
  def generate_invoice_for_customer(customer)
    # Collect all pending items for the customer
    pending_items = collect_monthly_pending_items(customer)

    return nil if pending_items.empty?

    # Group by product and create invoice
    grouped_items = group_items_by_product(pending_items)

    invoice = create_invoice_with_items(customer, grouped_items)

    # Mark items as invoiced
    mark_items_as_invoiced(pending_items)

    {
      customer: customer,
      invoice: invoice,
      items_count: pending_items.count,
      products_count: grouped_items.count,
      total_amount: invoice.total_amount
    }
  end

  private

  # Collect pending items from all three sources
  def collect_monthly_pending_items(customer)
    items = []

    # 1. Pending daily milk delivery tasks for the month
    milk_tasks = MilkDeliveryTask.joins(:customer)
                                 .where(customer: customer)
                                 .where(delivery_date: month_range)
                                 .where(status: ['delivered', 'completed'])
                                 .uninvoiced

    milk_tasks.each do |task|
      # Calculate proper unit price (base price excluding GST for GST products)
      unit_price = if task.product.gst_enabled? && task.product.gst_percentage.present?
        task.product.calculate_base_price
      else
        task.product.price
      end

      items << {
        source: 'milk_delivery',
        source_id: task.id,
        product: task.product,
        quantity: task.quantity,
        unit_price: unit_price,
        description: "Milk delivery - #{task.product.name} (#{task.delivery_date.strftime('%d %b')})",
        date: task.delivery_date,
        model: task
      }
    end

    # 2. Pending bookings for the month
    pending_bookings = Booking.joins(:customer, :booking_items)
                             .where(customer: customer)
                             .where(booking_date: month_range)
                             .where(status: ['delivered', 'completed'])
                             .where('NOT EXISTS (SELECT 1 FROM invoices WHERE invoices.booking_id = bookings.id)')

    pending_bookings.includes(:booking_items).each do |booking|
      booking.booking_items.each do |item|
        # Calculate proper unit price (base price excluding GST for GST products)
        unit_price = if item.bulk_gst_exempt?
          item.charged_unit_price # > 25 kg: billed without GST
        elsif item.product.gst_enabled? && item.product.gst_percentage.present?
          item.product.calculate_base_price
        else
          item.price
        end

        items << {
          source: 'booking',
          source_id: booking.id,
          product: item.product,
          quantity: item.quantity,
          unit_price: unit_price,
          description: "Order item - #{item.product.name} (#{booking.booking_date.strftime('%d %b')})",
          date: booking.booking_date,
          model: booking,
          booking_item: item
        }
      end
    end

    # 3. Pending amounts from last month to today that are still pending
    pending_amounts = PendingAmount.where(customer: customer)
                                  .current_pending
                                  .from_last_month_to_today

    pending_amounts.each do |pending_amount|
      items << {
        source: 'pending_amount',
        source_id: pending_amount.id,
        product: nil, # Pending amounts may not have specific products
        quantity: 1,
        unit_price: pending_amount.amount,
        description: pending_amount.description,
        date: pending_amount.pending_date,
        model: pending_amount
      }
    end

    items
  end

  # Group items by product for consolidated line items
  def group_items_by_product(items)
    grouped = {}

    items.each do |item|
      # Use product_id as key, or 'misc' for items without products
      key = item[:product] ? "product_#{item[:product].id}" : "misc_#{item[:source]}_#{item[:source_id]}"

      if grouped[key]
        # Add to existing group
        grouped[key][:quantity] += item[:quantity]
        grouped[key][:total_amount] += (item[:quantity] * item[:unit_price])
        grouped[key][:descriptions] << item[:description]
        grouped[key][:source_items] << item
      else
        # Create new group
        grouped[key] = {
          product: item[:product],
          quantity: item[:quantity],
          unit_price: item[:unit_price],
          total_amount: item[:quantity] * item[:unit_price],
          descriptions: [item[:description]],
          source_items: [item],
          combined_description: item[:product] ?
            "#{item[:product].name} - Monthly delivery" :
            item[:description]
        }
      end
    end

    # Update unit price for grouped items (average price)
    grouped.each do |key, group|
      if group[:source_items].count > 1 && group[:product]
        total_value = group[:source_items].sum { |item| item[:quantity] * item[:unit_price] }
        total_quantity = group[:source_items].sum { |item| item[:quantity] }
        group[:unit_price] = total_value / total_quantity if total_quantity > 0
      end
    end

    grouped.values
  end

  # Create invoice with line items
  def create_invoice_with_items(customer, grouped_items)
    invoice = Invoice.new(
      customer: customer,
      invoice_date: Date.new(year, month).end_of_month,
      due_date: SystemSetting.invoice_due_date_for(Date.new(year, month).end_of_month),
      status: 'sent'
    )

    # Create invoice items
    grouped_items.each do |group|
      invoice.invoice_items.build(
        product: group[:product],
        description: group[:combined_description],
        quantity: group[:quantity],
        unit_price: group[:unit_price],
        total_amount: group[:total_amount]
      )
    end

    # Calculate totals
    subtotal = grouped_items.sum { |group| group[:total_amount] }
    tax_amount = calculate_tax_amount(grouped_items)

    invoice.assign_attributes(
      subtotal: subtotal,
      tax_amount: tax_amount,
      total_amount: subtotal + tax_amount
    )

    invoice.save!
    invoice
  end

  # Calculate tax amount based on products
  def calculate_tax_amount(grouped_items)
    total_tax = 0

    grouped_items.each do |group|
      next unless group[:product]&.gst_enabled

      gst_rate = group[:product].gst_percentage.to_f
      if gst_rate > 0
        # Calculate tax on the total amount
        tax_amount = (group[:total_amount] * gst_rate) / 100
        total_tax += tax_amount
      end
    end

    total_tax.round(2)
  end

  # Mark source items as invoiced
  def mark_items_as_invoiced(items)
    items.each do |item|
      case item[:source]
      when 'milk_delivery'
        item[:model].update(invoiced: true) if item[:model].respond_to?(:invoiced)
      when 'booking'
        # Mark booking as invoiced by creating invoice record if not exists
        unless Invoice.exists?(booking_id: item[:model].id)
          # We can add a booking_id field to Invoice model if needed
          # For now, we'll add a note in the invoice
        end
      when 'pending_amount'
        item[:model].update(status: :resolved)
      end
    end
  end

  def month_range
    Date.new(year, month).beginning_of_month..Date.new(year, month).end_of_month
  end

  # Class method for easy access
  def self.generate_for_month(month, year, customer_id = nil)
    service = new(month: month, year: year, customer_id: customer_id)
    service.generate_monthly_invoices
  end

  # Generate summary report
  def generate_summary_report
    customers = customer_id ? [Customer.find(customer_id)] : Customer.all
    report = {
      month: month,
      year: year,
      total_customers: 0,
      customers_with_pending: 0,
      total_invoices_generated: 0,
      total_amount: 0,
      breakdown: {
        milk_deliveries: { count: 0, amount: 0 },
        bookings: { count: 0, amount: 0 },
        pending_amounts: { count: 0, amount: 0 }
      }
    }

    customers.each do |customer|
      pending_items = collect_monthly_pending_items(customer)

      if pending_items.any?
        report[:customers_with_pending] += 1

        pending_items.each do |item|
          amount = item[:quantity] * item[:unit_price]
          report[:breakdown][item[:source].pluralize.to_sym][:count] += 1
          report[:breakdown][item[:source].pluralize.to_sym][:amount] += amount
          report[:total_amount] += amount
        end
      end

      report[:total_customers] += 1
    end

    report
  end
end
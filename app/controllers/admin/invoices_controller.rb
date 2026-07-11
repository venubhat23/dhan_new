require 'set'

class Admin::InvoicesController < Admin::ApplicationController
  before_action :set_invoice, only: [:show, :edit, :update, :destroy, :mark_as_paid, :download_pdf]

  def index
    # Show only regular invoices by default (exclude booking invoices)
    invoice_type = params[:type] || 'regular'  # Default to 'regular' only

    # Build invoices collection - only regular invoices
    @all_invoices = []

    # Get only regular invoices
    regular_invoices = build_regular_invoices_query.to_a
    booking_lookup = booking_numbers_lookup(regular_invoices)
    @all_invoices.concat(regular_invoices.map { |inv| prepare_invoice_data(inv, 'regular', booking_lookup) })

    # Sort invoices: when searching, rank customer-name matches by relevance
    # (name/word starting with the search term ranks above a mid-name match),
    # then fall back to newest first within the same relevance tier.
    if params[:search].present?
      @all_invoices.sort_by! { |inv| [name_match_rank(inv[:customer_name], params[:search]), -(inv[:created_at]&.to_i || 0)] }
    else
      @all_invoices.sort_by! { |inv| inv[:created_at] }.reverse!
    end

    # Apply pagination
    limit = params[:limit]&.to_i || 50
    offset = params[:offset]&.to_i || 0
    @invoices = @all_invoices[offset, limit] || []

    # Calculate summary statistics for regular invoices only
    @stats = calculate_regular_invoice_stats_only

    # Get delivery persons for filter dropdown
    @delivery_persons = DeliveryPerson.active.order(:first_name, :last_name)

    # Set invoice type for the view
    @invoice_type = invoice_type
  end

  def customers
    @customers = Customer.order(:first_name, :last_name)
                        .select(:id, :first_name, :middle_name, :last_name)
                        .map { |c| { id: c.id, display_name: c.display_name } }
    render json: @customers
  end

  def delivery_persons
    @delivery_persons = DeliveryPerson.active.order(:first_name, :last_name)
                                     .select(:id, :first_name, :last_name)
                                     .map { |dp| { id: dp.id, display_name: dp.display_name } }
    render json: @delivery_persons
  end

  def customers_by_delivery_person
    delivery_person_id = params[:delivery_person_id]
    if delivery_person_id.present?
      # Find customers who have bookings with this delivery person
      booking_customer_ids = Booking.where(delivery_person_id: delivery_person_id)
                                   .distinct
                                   .pluck(:customer_id)
                                   .compact

      # Find customers who have subscriptions with this delivery person
      subscription_customer_ids = []
      if defined?(MilkSubscription)
        subscription_customer_ids += MilkSubscription.where(delivery_person_id: delivery_person_id)
                                                    .distinct
                                                    .pluck(:customer_id)
                                                    .compact
      end

      if defined?(SubscriptionTemplate)
        subscription_customer_ids += SubscriptionTemplate.where(delivery_person_id: delivery_person_id)
                                                         .distinct
                                                         .pluck(:customer_id)
                                                         .compact
      end

      # Combine all customer IDs from bookings and subscriptions
      all_customer_ids = (booking_customer_ids + subscription_customer_ids).uniq

      @customers = Customer.where(id: all_customer_ids)
                          .order(:first_name, :last_name)
                          .select(:id, :first_name, :middle_name, :last_name, :email, :mobile)
                          .map { |c| {
                            id: c.id,
                            display_name: c.display_name,
                            email: c.email,
                            mobile: c.mobile
                          } }
    else
      @customers = []
    end
    render json: @customers
  end

  def generate
    month = params[:month].to_i
    year = params[:year].to_i
    customer_selection = params[:customer_selection]
    customer_ids = params[:customer_ids]
    delivery_person_id = params[:delivery_person_id]

    # Get pending items summary before generation
    pending_summary = get_pending_items_summary(customer_selection, customer_ids, delivery_person_id)

    if customer_selection == 'all'
      customers = Customer.all
    elsif customer_selection == 'delivery_person' && delivery_person_id.present?
      # Get customers who have bookings with the selected delivery person
      customer_ids_from_bookings = Booking.where(delivery_person_id: delivery_person_id)
                                         .distinct
                                         .pluck(:customer_id)
                                         .compact

      # Get customers who have subscriptions with the selected delivery person
      customer_ids_from_subscriptions = []
      if defined?(MilkSubscription)
        customer_ids_from_subscriptions += MilkSubscription.where(delivery_person_id: delivery_person_id)
                                                          .distinct
                                                          .pluck(:customer_id)
                                                          .compact
      end

      if defined?(SubscriptionTemplate)
        customer_ids_from_subscriptions += SubscriptionTemplate.where(delivery_person_id: delivery_person_id)
                                                               .distinct
                                                               .pluck(:customer_id)
                                                               .compact
      end

      # Combine all customer IDs from bookings and subscriptions
      all_customer_ids_from_delivery_person = (customer_ids_from_bookings + customer_ids_from_subscriptions).uniq

      # If specific customers were also selected, use the intersection
      if customer_ids.present?
        final_customer_ids = all_customer_ids_from_delivery_person & customer_ids.map(&:to_i)
        customers = Customer.where(id: final_customer_ids)
      else
        customers = Customer.where(id: all_customer_ids_from_delivery_person)
      end
    else
      customers = Customer.where(id: customer_ids)
    end

    generated_invoices = []
    errors = []

    customers.find_each do |customer|
      begin
        invoice = generate_customer_invoice(customer, month, year)
        generated_invoices << invoice if invoice
      rescue => e
        errors << "#{customer.display_name}: #{e.message}"
      end
    end

    if generated_invoices.any?
      render json: {
        success: true,
        invoices_created: generated_invoices.count,
        message: "Generated #{generated_invoices.count} invoices successfully",
        errors: errors,
        pending_items_summary: pending_summary,
        invoices: generated_invoices.map { |inv| { id: inv.id, number: inv.invoice_number, customer: inv.customer.display_name, amount: inv.total_amount } }
      }
    else
      render json: {
        success: false,
        invoices_created: 0,
        error: "No invoices could be generated. " + (errors.any? ? errors.join(', ') : 'No completed deliveries found for the selected period.'),
        errors: errors,
        pending_items_summary: pending_summary
      }
    end
  end

  def show
    @invoice_items = @invoice&.invoice_items&.includes(:product, :milk_delivery_task) || []
  end

  def download_pdf
    @invoice_items = @invoice&.invoice_items&.includes(:product, :milk_delivery_task) || []

    respond_to do |format|
      format.pdf do
        pdf = WickedPdf.new.pdf_from_string(
          render_to_string(template: 'admin/invoices/show', formats: [:html], layout: false),
          page_size: 'A4',
          margin: {
            top: '0.5in',
            bottom: '0.5in',
            left: '0.5in',
            right: '0.5in'
          },
          dpi: 300,
          encoding: 'UTF-8',
          disable_smart_shrinking: true,
          print_media_type: true,
          orientation: 'Portrait'
        )

        send_data pdf,
                  filename: "invoice-#{@invoice.invoice_number}.pdf",
                  type: 'application/pdf',
                  disposition: 'attachment'
      end
    end
  end

  def edit
    @invoice_items = @invoice.invoice_items.includes(:milk_delivery_task, product: :product_variants)
  end

  def update
    # Store original quantities for stock rollback if needed
    original_quantities = {}
    @invoice.invoice_items.each do |item|
      original_quantities[item.id] = item.quantity if item.product
    end

    @invoice.assign_attributes(invoice_params)

    # Calculate new total based on invoice items and check stock availability
    new_total = 0
    stock_errors = []

    # Check nested attributes from params
    invoice_items_attributes = invoice_params[:invoice_items_attributes]

    if invoice_items_attributes
      invoice_items_attributes.each do |_, item_attrs|
        next if item_attrs['_destroy'] == '1'

        quantity = item_attrs['quantity'].to_f
        unit_price = item_attrs['unit_price'].to_f
        new_total += quantity * unit_price

        # Check stock availability for products
        if item_attrs['product_id'].present?
          product = Product.find(item_attrs['product_id'])
          item_id = item_attrs['id']

          # Calculate quantity difference
          # For new items (no ID), original_qty is 0
          original_qty = item_id.present? ? (original_quantities[item_id.to_i] || 0) : 0
          qty_difference = quantity - original_qty

          # Only check stock if quantity is increasing and product tracks stock
          if qty_difference > 0 && product.respond_to?(:track_stock?) && product.track_stock?
            if product.respond_to?(:available_stock)
              available_stock = product.available_stock
              if available_stock < qty_difference
                stock_errors << "Insufficient stock for #{product.name}. Available: #{available_stock}, Required additional: #{qty_difference}"
              end
            end
          end
        end
      end
    end

    # If there are stock errors, don't save and show errors
    unless stock_errors.empty?
      @invoice.errors.add(:base, stock_errors.join(', '))
      render_invoice_edit_with_errors
      return
    end

    @invoice.total_amount = new_total + @invoice.delivery_charge.to_f

    if @invoice.save
      # Update stock for products after successful save
      @invoice.invoice_items.each do |item|
        if item.product && item.product.respond_to?(:track_stock?) && item.product.track_stock?
          # For new items, original_quantities won't have this item.id, so original_qty = 0
          original_qty = original_quantities[item.id] || 0
          qty_difference = item.quantity - original_qty

          # Only update stock if there's a quantity change and product supports stock updates
          if qty_difference != 0 && item.product.respond_to?(:update_stock_for_invoice)
            item.product.update_stock_for_invoice(qty_difference)
          end
        end
      end

      # Update related booking stock if invoice is connected to a booking
      update_related_booking_stock(original_quantities)

      if params[:mobile_ui].present?
        redirect_to admin_mobile_ui_show_invoice_path(@invoice), notice: 'Invoice was successfully updated.'
      else
        redirect_to admin_invoice_path(@invoice), notice: 'Invoice was successfully updated.'
      end
    else
      render_invoice_edit_with_errors
    end
  end

  def destroy
    @invoice.destroy
    redirect_to admin_invoices_path, notice: 'Invoice was successfully deleted.'
  rescue => e
    redirect_to admin_invoices_path, alert: "Error deleting invoice: #{e.message}"
  end

  def mark_as_paid
    @invoice.update!(
      payment_status: :fully_paid,
      status: :paid,
      paid_at: Time.current,
      paid_amount: @invoice.total_amount
    )

    redirect_to admin_invoices_path, notice: 'Invoice marked as paid successfully.'
  rescue => e
    redirect_to admin_invoices_path, alert: "Error marking invoice as paid: #{e.message}"
  end

  def bulk_delete
    invoice_ids = params[:invoice_ids]

    if invoice_ids.blank? || !invoice_ids.is_a?(Array)
      render json: { success: false, error: 'No invoice IDs provided' }, status: :bad_request
      return
    end

    invoices = Invoice.where(id: invoice_ids)
    deleted_count = invoices.count

    Invoice.transaction do
      InvoiceItem.where(invoice_id: invoice_ids).delete_all
      invoices.delete_all
    end

    render json: {
      success: true,
      deleted_count: deleted_count,
      message: "Successfully deleted #{deleted_count} invoice(s)"
    }
  rescue => e
    render json: { success: false, error: e.message }, status: :internal_server_error
  end

  def bulk_mark_as_paid
    invoice_ids = params[:invoice_ids]

    if invoice_ids.blank? || !invoice_ids.is_a?(Array)
      render json: { success: false, error: 'No invoice IDs provided' }, status: :bad_request
      return
    end

    # Find invoices that are not already paid
    invoices_to_update = Invoice.where(id: invoice_ids)
                               .where.not(payment_status: 'fully_paid')

    if invoices_to_update.empty?
      render json: { success: false, error: 'No unpaid invoices found to update' }, status: :bad_request
      return
    end

    updated_count = 0

    Invoice.transaction do
      invoices_to_update.find_each do |invoice|
        invoice.update!(
          payment_status: :fully_paid,
          status: :paid,
          paid_at: Time.current
        )
        updated_count += 1
      end
    end

    render json: {
      success: true,
      updated_count: updated_count,
      message: "Successfully marked #{updated_count} invoice(s) as paid"
    }
  rescue => e
    Rails.logger.error "Bulk mark as paid error: #{e.message}"
    render json: {
      success: false,
      error: "Error marking invoices as paid: #{e.message}"
    }, status: :internal_server_error
  end

  def partial_payment
    begin
      invoice_id = params[:invoice_id]
      amount = params[:amount].to_f
      notes = params[:notes]

      if invoice_id.blank? || amount <= 0
        render json: { success: false, error: 'Invalid invoice ID or amount' }, status: :bad_request
        return
      end

      invoice = Invoice.find(invoice_id)

      # Get current paid amount (initialize if needed)
      current_paid_amount = invoice.paid_amount || 0
      new_paid_amount = current_paid_amount + amount

      # Calculate remaining amount
      remaining_amount = invoice.total_amount - new_paid_amount

      # Validate payment amount
      if new_paid_amount > invoice.total_amount
        render json: {
          success: false,
          error: 'Payment amount exceeds remaining invoice amount'
        }, status: :bad_request
        return
      end

      # Update invoice with payment information
      Invoice.transaction do
        # Update paid amount and payment status
        if remaining_amount <= 0
          invoice.update!(
            paid_amount: invoice.total_amount,
            payment_status: :fully_paid,
            status: :paid,
            paid_at: Time.current
          )
        else
          invoice.update!(
            paid_amount: new_paid_amount,
            payment_status: :partially_paid
          )
        end

        # Create a payment record/note if notes are provided
        if notes.present?
          # You can create a separate payment record here if needed
          # For now, we'll just update the invoice notes
          existing_notes = invoice.notes.present? ? invoice.notes : ""
          payment_note = "Payment of ₹#{amount} on #{Time.current.strftime('%Y-%m-%d %H:%M')} - #{notes}"

          if existing_notes.present?
            invoice.update!(notes: "#{existing_notes}\n#{payment_note}")
          else
            invoice.update!(notes: payment_note)
          end
        end
      end

      render json: {
        success: true,
        message: remaining_amount <= 0 ? 'Invoice marked as fully paid' : 'Partial payment processed successfully',
        invoice: {
          id: invoice.id,
          paid_amount: invoice.paid_amount,
          remaining_amount: invoice.total_amount - invoice.paid_amount,
          payment_status: invoice.payment_status
        }
      }

    rescue ActiveRecord::RecordNotFound
      render json: { success: false, error: 'Invoice not found' }, status: :not_found
    rescue => e
      Rails.logger.error "Partial payment error: #{e.message}"
      render json: {
        success: false,
        error: "Error processing partial payment: #{e.message}"
      }, status: :internal_server_error
    end
  end

  private

  # Re-renders the edit form after a failed update, preserving whichever
  # layout (desktop admin vs. mobile UI) the request came from.
  def render_invoice_edit_with_errors
    @invoice_items = @invoice.invoice_items.includes(:product, :milk_delivery_task)
    if params[:mobile_ui].present?
      render template: 'admin/invoices/edit', layout: false, locals: { mobile_ui: true }, status: :unprocessable_entity
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def build_regular_invoices_query
    # invoice_items aren't rendered on the index list, so don't eager-load them
    base_query = Invoice.includes(:customer)
    apply_search_filters(base_query, 'invoices')
  end

  # Batches the per-row Booking.find_by(invoice_number:) lookup that
  # prepare_invoice_data used to do into a single query.
  def booking_numbers_lookup(invoices)
    invoice_numbers = invoices.select(&:quick_invoice?).map(&:invoice_number)
    return {} if invoice_numbers.empty?

    Booking.where(invoice_number: invoice_numbers).pluck(:invoice_number, :booking_number).to_h
  end

  def build_booking_invoices_query
    base_query = BookingInvoice.includes(:customer, :booking)
    apply_search_filters(base_query, 'booking_invoices')
  end

  def build_regular_invoices_query_for_stats
    base_query = Invoice.includes(:customer)
    apply_search_filters_for_stats(base_query, 'invoices')
  end

  def build_booking_invoices_query_for_stats
    base_query = BookingInvoice.includes(:customer)
    apply_search_filters_for_stats(base_query, 'booking_invoices')
  end

  def apply_search_filters(base_query, table_name)
    # Apply search filters
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      base_query = base_query.joins(:customer)
                            .where("#{table_name}.invoice_number ILIKE ? OR
                                    customers.first_name ILIKE ? OR
                                    customers.middle_name ILIKE ? OR
                                    customers.last_name ILIKE ? OR
                                    CONCAT_WS(' ', customers.first_name, customers.middle_name, customers.last_name) ILIKE ? OR
                                    customers.email ILIKE ? OR
                                    customers.mobile ILIKE ?",
                                   search_term, search_term, search_term, search_term, search_term, search_term, search_term)
    end

    # Apply delivery person filter based on milk subscriptions
    if params[:delivery_person_id].present? && params[:delivery_person_id] != 'all'
      delivery_person_id = params[:delivery_person_id].to_i

      # Get customers associated with this delivery person through milk subscriptions
      customer_ids_from_subscriptions = MilkSubscription.where(delivery_person_id: delivery_person_id)
                                                       .distinct
                                                       .pluck(:customer_id)
                                                       .compact

      # Also get customers from subscription templates
      customer_ids_from_templates = []
      if defined?(SubscriptionTemplate)
        customer_ids_from_templates = SubscriptionTemplate.where(delivery_person_id: delivery_person_id)
                                                         .distinct
                                                         .pluck(:customer_id)
                                                         .compact
      end

      # Combine all customer IDs from subscriptions
      all_customer_ids = (customer_ids_from_subscriptions + customer_ids_from_templates).uniq

      if all_customer_ids.any?
        base_query = base_query.where(customer_id: all_customer_ids)
      else
        # If no customers found for this delivery person, return empty result
        base_query = base_query.none
      end
    end

    # Apply status filter
    if params[:status].present? && params[:status] != 'all'
      base_query = base_query.where(payment_status: params[:status])
    end

    # Apply date range filter
    if params[:date_from].present?
      date_column = table_name == 'invoices' ? 'invoice_date' : 'invoice_date'
      base_query = base_query.where("#{table_name}.#{date_column} >= ?", Date.parse(params[:date_from]))
    end

    if params[:date_to].present?
      date_column = table_name == 'invoices' ? 'invoice_date' : 'invoice_date'
      base_query = base_query.where("#{table_name}.#{date_column} <= ?", Date.parse(params[:date_to]))
    end

    base_query.order(created_at: :desc).limit(200) # Limit to prevent memory issues
  end

  def apply_search_filters_for_stats(base_query, table_name)
    # Apply same search filters as above but without the limit for accurate stats
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      base_query = base_query.joins(:customer)
                            .where("#{table_name}.invoice_number ILIKE ? OR
                                    customers.first_name ILIKE ? OR
                                    customers.middle_name ILIKE ? OR
                                    customers.last_name ILIKE ? OR
                                    CONCAT_WS(' ', customers.first_name, customers.middle_name, customers.last_name) ILIKE ? OR
                                    customers.email ILIKE ? OR
                                    customers.mobile ILIKE ?",
                                   search_term, search_term, search_term, search_term, search_term, search_term, search_term)
    end

    # Apply delivery person filter based on milk subscriptions
    if params[:delivery_person_id].present? && params[:delivery_person_id] != 'all'
      delivery_person_id = params[:delivery_person_id].to_i

      # Get customers associated with this delivery person through milk subscriptions
      customer_ids_from_subscriptions = MilkSubscription.where(delivery_person_id: delivery_person_id)
                                                       .distinct
                                                       .pluck(:customer_id)
                                                       .compact

      # Also get customers from subscription templates
      customer_ids_from_templates = []
      if defined?(SubscriptionTemplate)
        customer_ids_from_templates = SubscriptionTemplate.where(delivery_person_id: delivery_person_id)
                                                         .distinct
                                                         .pluck(:customer_id)
                                                         .compact
      end

      # Combine all customer IDs from subscriptions
      all_customer_ids = (customer_ids_from_subscriptions + customer_ids_from_templates).uniq

      if all_customer_ids.any?
        base_query = base_query.where(customer_id: all_customer_ids)
      else
        # If no customers found for this delivery person, return empty result
        base_query = base_query.none
      end
    end

    # Apply status filter
    if params[:status].present? && params[:status] != 'all'
      base_query = base_query.where(payment_status: params[:status])
    end

    # Apply date range filter
    if params[:date_from].present?
      date_column = table_name == 'invoices' ? 'invoice_date' : 'invoice_date'
      base_query = base_query.where("#{table_name}.#{date_column} >= ?", Date.parse(params[:date_from]))
    end

    if params[:date_to].present?
      date_column = table_name == 'invoices' ? 'invoice_date' : 'invoice_date'
      base_query = base_query.where("#{table_name}.#{date_column} <= ?", Date.parse(params[:date_to]))
    end

    # No limit here - we need all records for accurate stats
    base_query
  end

  # Lower rank = higher up the results. Full-name match beats a word starting
  # with the term, which beats the term merely appearing somewhere in the name.
  def name_match_rank(customer_name, search)
    name = customer_name.to_s.downcase
    term = search.to_s.strip.downcase
    return 3 if term.blank?

    return 0 if name.start_with?(term)
    return 1 if name.split(/\s+/).any? { |word| word.start_with?(term) }
    return 2 if name.include?(term)

    3
  end

  def prepare_invoice_data(invoice, type, booking_lookup = {})
    actual_type = (type == 'regular' && invoice.quick_invoice?) ? 'booking' : type

    booking_number = booking_lookup[invoice.invoice_number] if actual_type == 'booking'

    {
      id: invoice.id,
      invoice_number: invoice.invoice_number,
      customer_name: invoice.customer&.display_name || invoice.customer_display_name || 'N/A',
      customer_mobile: invoice.customer&.mobile || invoice.customer_mobile,
      total_amount: invoice.total_amount,
      paid_amount: invoice.paid_amount || 0,
      payment_status: invoice.payment_status,
      status: invoice.status,
      invoice_date: invoice.invoice_date || invoice.created_at&.to_date,
      created_at: invoice.created_at,
      type: actual_type,
      model_object: invoice,
      booking_number: booking_number
    }
  end

  def calculate_regular_invoice_stats_only
    # Calculate stats from regular invoices only (exclude booking invoices).
    # A single GROUP BY payment_status query (x2, for counts and sums) replaces
    # what used to be 6 separate round trips against the same filtered query.
    regular_query = build_regular_invoices_query_for_stats
    counts_by_status = regular_query.group(:payment_status).count
    amounts_by_status = regular_query.group(:payment_status).sum(:total_amount)

    {
      total_invoices: counts_by_status.values.sum,
      total_amount: amounts_by_status.values.sum,
      paid_amount: amounts_by_status['fully_paid'] || 0,
      pending_amount: amounts_by_status.values_at('unpaid', 'partially_paid').compact.sum,
      paid_count: counts_by_status['fully_paid'] || 0,
      pending_count: counts_by_status.values_at('unpaid', 'partially_paid').compact.sum
    }
  end

  def calculate_combined_invoice_stats
    # Calculate stats from full database, not just paginated results
    invoice_type = params[:type] || 'regular'

    # Get full queries without limits for accurate stats
    regular_stats = { total_amount: 0, paid_amount: 0, pending_amount: 0, total_count: 0, paid_count: 0, pending_count: 0 }
    booking_stats = { total_amount: 0, paid_amount: 0, pending_amount: 0, total_count: 0, paid_count: 0, pending_count: 0 }

    if ['all', 'regular'].include?(invoice_type)
      regular_query = build_regular_invoices_query_for_stats
      regular_stats = {
        total_count: regular_query.count,
        total_amount: regular_query.sum(:total_amount) || 0,
        paid_amount: regular_query.where(payment_status: ['paid', 'fully_paid']).sum(:total_amount) || 0,
        pending_amount: regular_query.where(payment_status: ['unpaid', 'partially_paid']).sum(:total_amount) || 0,
        paid_count: regular_query.where(payment_status: ['paid', 'fully_paid']).count,
        pending_count: regular_query.where(payment_status: ['unpaid', 'partially_paid']).count
      }
    end

    if ['all', 'booking'].include?(invoice_type)
      booking_query = build_booking_invoices_query_for_stats
      booking_stats = {
        total_count: booking_query.count,
        total_amount: booking_query.sum(:total_amount) || 0,
        paid_amount: booking_query.where(payment_status: ['paid', 'fully_paid']).sum(:total_amount) || 0,
        pending_amount: booking_query.where(payment_status: ['unpaid', 'partially_paid']).sum(:total_amount) || 0,
        paid_count: booking_query.where(payment_status: ['paid', 'fully_paid']).count,
        pending_count: booking_query.where(payment_status: ['unpaid', 'partially_paid']).count
      }
    end

    {
      total_invoices: regular_stats[:total_count] + booking_stats[:total_count],
      total_amount: regular_stats[:total_amount] + booking_stats[:total_amount],
      paid_amount: regular_stats[:paid_amount] + booking_stats[:paid_amount],
      pending_amount: regular_stats[:pending_amount] + booking_stats[:pending_amount],
      paid_count: regular_stats[:paid_count] + booking_stats[:paid_count],
      pending_count: regular_stats[:pending_count] + booking_stats[:pending_count]
    }
  end

  def set_invoice
    @invoice = Invoice.find(params[:id])
  end

  def get_pending_items_summary(customer_selection, customer_ids, delivery_person_id)
    # Determine which customers to check based on selection criteria
    customers = []
    if customer_selection == 'all'
      customers = Customer.all
    elsif customer_selection == 'delivery_person' && delivery_person_id.present?
      # Get customers who have bookings or subscriptions with the selected delivery person
      customer_ids_from_bookings = Booking.where(delivery_person_id: delivery_person_id)
                                         .distinct
                                         .pluck(:customer_id)
                                         .compact

      customer_ids_from_subscriptions = []
      if defined?(MilkSubscription)
        customer_ids_from_subscriptions += MilkSubscription.where(delivery_person_id: delivery_person_id)
                                                          .distinct
                                                          .pluck(:customer_id)
                                                          .compact
      end

      if defined?(SubscriptionTemplate)
        customer_ids_from_subscriptions += SubscriptionTemplate.where(delivery_person_id: delivery_person_id)
                                                               .distinct
                                                               .pluck(:customer_id)
                                                               .compact
      end

      all_customer_ids_from_delivery_person = (customer_ids_from_bookings + customer_ids_from_subscriptions).uniq

      if customer_ids.present?
        final_customer_ids = all_customer_ids_from_delivery_person & customer_ids.map(&:to_i)
        customers = Customer.where(id: final_customer_ids)
      else
        customers = Customer.where(id: all_customer_ids_from_delivery_person)
      end
    else
      customers = Customer.where(id: customer_ids)
    end

    # Get pending amounts for the selected customers - only include unresolved pending amounts
    pending_amounts = PendingAmount.joins(:customer)
                                   .where(customer: customers)
                                   .current_pending

    # Build summary
    summary = {
      total_count: pending_amounts.count,
      total_amount: pending_amounts.sum(:amount),
      customers_count: pending_amounts.distinct.count(:customer_id),
      from_date: 'All time',
      to_date: Date.current.strftime('%Y-%m-%d'),
      breakdown: []
    }

    # Group by customer for breakdown
    customer_breakdown = pending_amounts.joins(:customer)
                                       .group('customers.id', 'customers.first_name', 'customers.last_name')
                                       .select('customers.id, customers.first_name, customers.last_name, COUNT(*) as count, SUM(amount) as total')

    customer_breakdown.each do |item|
      summary[:breakdown] << {
        customer_id: item.id,
        customer_name: "#{item.first_name} #{item.last_name}".strip,
        pending_count: item.count,
        pending_amount: item.total
      }
    end

    summary
  end

  def invoice_params
    params.require(:invoice).permit(:invoice_date, :due_date, :status, :payment_status, :total_amount, :delivery_charge,
                                   invoice_items_attributes: [:id, :product_id, :description, :quantity, :unit_price, :total_amount, :_destroy])
  end

  def update_related_booking_stock(original_quantities)
    # Find booking related to this invoice
    related_booking = Booking.find_by(invoice_number: @invoice.invoice_number)
    return unless related_booking

    # Track which invoice items have been processed to avoid conflicts
    processed_products = Set.new

    @invoice.invoice_items.each do |invoice_item|
      next unless invoice_item.product
      next if processed_products.include?(invoice_item.product_id)

      # Find corresponding booking item
      booking_item = related_booking.booking_items.find_by(product_id: invoice_item.product_id)
      next unless booking_item

      # Calculate quantity difference for this invoice item
      original_qty = original_quantities[invoice_item.id] || 0
      invoice_qty_difference = invoice_item.quantity - original_qty

      if invoice_qty_difference != 0
        # Update the booking item quantity to match invoice item
        new_booking_qty = booking_item.quantity + invoice_qty_difference

        if new_booking_qty > 0
          # Update booking item quantity (this will trigger its stock update callbacks)
          booking_item.update!(quantity: new_booking_qty)
        else
          # If quantity becomes 0 or negative, remove the booking item
          booking_item.destroy!
        end

        processed_products.add(invoice_item.product_id)
      end
    end

    # Handle removed invoice items (items that were deleted from invoice)
    invoice_items_attributes = invoice_params[:invoice_items_attributes]
    if invoice_items_attributes
      invoice_items_attributes.each do |_, item_attrs|
        if item_attrs['_destroy'] == '1' && item_attrs['id'].present? && item_attrs['product_id'].present?
          # This invoice item was deleted, find corresponding booking item
          booking_item = related_booking.booking_items.find_by(product_id: item_attrs['product_id'])
          if booking_item
            # Remove the booking item as well to keep them in sync
            booking_item.destroy!
          end
        end
      end
    end

    # Recalculate booking totals
    related_booking.reload
    new_booking_total = related_booking.booking_items.sum { |item| item.quantity * item.price }
    related_booking.update!(total_amount: new_booking_total)
  end

  def generate_customer_invoice(customer, month, year)
    start_date = Date.new(year, month).beginning_of_month
    end_date = Date.new(year, month).end_of_month

    # Check if invoice already exists for this month
    existing_invoice = Invoice.where(customer: customer)
                             .where(invoice_date: start_date..end_date)
                             .first

    return existing_invoice if existing_invoice

    invoice_items_data = []

    # 1. Find unpaid, not invoiced, completed bookings for the customer in the specified month
    # Check only amount after discount as requested
    unpaid_bookings = customer.bookings
                             .where(booking_date: start_date..end_date)
                             .where(status: ['completed', 'delivered'])
                             .where(payment_status: [nil, '', 'unpaid'])
                             .where(invoice_generated: [false, nil])
                             .where.not(id: BookingInvoice.select(:booking_id).where.not(booking_id: nil))

    # Process unpaid bookings - add individual line items for each booking item
    unpaid_bookings.each do |booking|
      booking.booking_items.includes(:product).each do |item|
        product = item.product
        next unless product

        # Calculate proper unit price (base price excluding GST for GST products)
        unit_price = if product.gst_enabled? && product.gst_percentage.present?
          product.calculate_base_price || item.price
        else
          item.price || product.selling_price
        end

        # Apply any booking-level discount proportionally
        if booking.discount_amount.to_f > 0 && booking.total_amount.to_f > 0
          discount_ratio = booking.discount_amount.to_f / booking.total_amount.to_f
          unit_price = unit_price * (1 - discount_ratio)
        end

        invoice_items_data << {
          product: product,
          quantity: item.quantity,
          unit_price: unit_price,
          description: "#{product.name} - Booking ##{booking.booking_number} (#{booking.booking_date.strftime('%d %b %Y')})",
          booking_item: item,
          booking: booking
        }
      end
    end

    # 2. Check pending amounts for this customer for date range and check the line items pending
    pending_amounts = PendingAmount.where(customer: customer)
                                  .where(pending_date: start_date..end_date)
                                  .current_pending

    # Add pending amounts as line items
    pending_amounts.each do |pending_amount|
      invoice_items_data << {
        product: nil,
        quantity: 1,
        unit_price: pending_amount.amount,
        description: "Pending Amount: #{pending_amount.description} (#{pending_amount.pending_date&.strftime('%d %b %Y') || pending_amount.created_at.strftime('%d %b %Y')})",
        pending_amount: pending_amount
      }
    end

    # 3. Check MilkDeliveryTask if we have any pending for month check
    if defined?(MilkDeliveryTask)
      pending_delivery_tasks = MilkDeliveryTask.joins(:product)
                                              .where(customer: customer,
                                                     delivery_date: start_date..end_date)
                                              .where(status: ['pending', 'scheduled', 'completed'])
                                              .where(invoiced: [false, nil])

      # Group pending delivery tasks by product and sum quantities
      grouped_pending_tasks = pending_delivery_tasks.group_by(&:product)

      grouped_pending_tasks.each do |product, tasks|
        total_quantity = tasks.sum(&:quantity)

        # Calculate proper unit price (base price excluding GST for GST products)
        unit_price = if product.gst_enabled? && product.gst_percentage.present?
          product.calculate_base_price
        else
          product.selling_price
        end

        # Get date range for description
        dates = tasks.map(&:delivery_date).sort
        date_range = if dates.size > 1
          "#{dates.first.strftime('%Y-%m-%d')} to #{dates.last.strftime('%Y-%m-%d')}"
        else
          dates.first.strftime('%Y-%m-%d')
        end

        invoice_items_data << {
          product: product,
          quantity: total_quantity,
          unit_price: unit_price,
          description: "#{product.name} - Milk Deliveries (#{dates.size} tasks: #{date_range})",
          delivery_tasks: tasks
        }
      end
    end

    return nil if invoice_items_data.empty?

    # Create new invoice
    invoice = Invoice.new(
      customer: customer,
      invoice_date: end_date,
      due_date: end_date + 30.days,
      status: :draft,
      payment_status: :unpaid
    )

    total_amount = 0

    # Create invoice items
    invoice_items_data.each do |item_data|
      item_total = item_data[:quantity] * item_data[:unit_price]

      # For grouped delivery tasks, we'll link to the first task
      # (we could also create a separate junction table, but this is simpler for now)
      delivery_task = if item_data[:delivery_tasks]
                       item_data[:delivery_tasks].first
                     else
                       item_data[:delivery_task]
                     end

      invoice_item = invoice.invoice_items.build(
        description: item_data[:description],
        quantity: item_data[:quantity],
        unit_price: item_data[:unit_price],
        total_amount: item_total,
        product: item_data[:product],
        milk_delivery_task: delivery_task
      )

      # Store reference to pending amount for later processing
      invoice_item.instance_variable_set(:@pending_amount, item_data[:pending_amount]) if item_data[:pending_amount]

      total_amount += item_total
    end

    invoice.total_amount = total_amount

    if invoice.save
      # Mark delivery tasks as invoiced if applicable
      if defined?(MilkDeliveryTask)
        invoice_items_data.each do |item_data|
          # Handle both single tasks and grouped tasks
          tasks_to_mark = if item_data[:delivery_tasks]
                           item_data[:delivery_tasks]
                         elsif item_data[:delivery_task]
                           [item_data[:delivery_task]]
                         else
                           []
                         end

          tasks_to_mark.each do |task|
            task.update(invoiced: true, invoiced_at: Time.current) if task
          end
        end
      end

      # Mark bookings as invoiced (avoid duplicates)
      invoiced_bookings = Set.new
      invoice_items_data.each do |item_data|
        if item_data[:booking] && !invoiced_bookings.include?(item_data[:booking].id)
          item_data[:booking].update!(
            invoice_generated: true,
            invoice_number: invoice.invoice_number
          )
          invoiced_bookings.add(item_data[:booking].id)
        end
      end

      # Mark pending amounts as resolved since they're now included in the invoice
      invoice_items_data.each do |item_data|
        if item_data[:pending_amount]
          # Build update attributes based on available columns
          update_attributes = {
            status: :resolved
          }

          # Add resolution information to notes field (append, don't replace)
          resolution_info = "Resolved via Invoice ##{invoice.invoice_number} on #{Time.current.strftime('%Y-%m-%d')}"
          existing_notes = item_data[:pending_amount].notes.present? ? item_data[:pending_amount].notes : ""

          if existing_notes.present?
            update_attributes[:notes] = "#{existing_notes} | #{resolution_info}"
          else
            update_attributes[:notes] = resolution_info
          end

          # Add resolved_at if the column exists
          if item_data[:pending_amount].respond_to?(:resolved_at)
            update_attributes[:resolved_at] = Time.current
          end

          item_data[:pending_amount].update!(update_attributes)
        end
      end

      return invoice
    else
      raise invoice.errors.full_messages.join(', ')
    end
  end

  def calculate_invoice_stats(query)
    stats = query.group(:payment_status).sum(:total_amount)

    {
      total_invoices: query.count,
      total_amount: query.sum(:total_amount) || 0,
      paid_amount: stats['fully_paid'] || 0,
      pending_amount: (stats['unpaid'] || 0) + (stats['partially_paid'] || 0),
      partially_paid_amount: stats['partially_paid'] || 0,
      paid_count: query.where(payment_status: 'fully_paid').count,
      pending_count: query.where(payment_status: ['unpaid', 'partially_paid']).count,
      this_month_count: query.where(invoice_date: Date.current.beginning_of_month..Date.current.end_of_month).count,
      this_month_amount: query.where(invoice_date: Date.current.beginning_of_month..Date.current.end_of_month).sum(:total_amount) || 0
    }
  end
end
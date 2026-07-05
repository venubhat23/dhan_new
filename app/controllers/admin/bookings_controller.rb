class Admin::BookingsController < Admin::ApplicationController
  before_action :authenticate_user!
  before_action :set_booking, only: [:show, :edit, :update, :destroy, :generate_invoice, :invoice, :convert_to_order, :update_status, :cancel_order, :mark_delivered, :mark_completed, :mark_paid, :manage_stage, :update_stage, :update_delivery_charge]

  LIST_STATE_PARAMS = %i[page search status date_from date_to customer_id b2b booked_by payment_status delivery_pending].freeze

  def index
    # Base scope for filters — no includes here (stats use SQL aggregates, not loaded records)
    base_scope = current_user.franchise? ? Booking.where(user_id: current_user.id) : Booking.all

    # Build filtered scope
    @bookings = base_scope.recent

    if params[:search].present?
      @bookings = @bookings.where(
        "booking_number LIKE ? OR customer_name LIKE ? OR customer_email LIKE ? OR customer_phone LIKE ?",
        "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%"
      )
    end
    @bookings = @bookings.where(status: params[:status])           if params[:status].present? && params[:status].strip != ''
    @bookings = @bookings.where(created_at: params[:date_from]..params[:date_to]) if params[:date_from].present? && params[:date_to].present?
    @bookings = @bookings.where(customer_id: params[:customer_id]) if params[:customer_id].present? && params[:customer_id].strip != ''
    @bookings = @bookings.where(is_b2b: true)                      if params[:b2b] == '1'
    @bookings = @bookings.where(booked_by: params[:booked_by])     if params[:booked_by].present? && params[:booked_by].strip != ''
    @bookings = @bookings.where(payment_status: params[:payment_status]) if params[:payment_status].present? && params[:payment_status].strip != ''
    @bookings = @bookings.where.not(status: %w[delivered completed cancelled returned]) if params[:delivery_pending] == '1'

    # Pre-compute stats with a single GROUP BY — avoids 6 COUNT queries in the view
    stats_counts = @bookings.reorder('').group(:status).count
    @booking_stats = {
      draft:      stats_counts['draft'].to_i,
      pending:    stats_counts['ordered_and_delivery_pending'].to_i,
      processing: stats_counts.slice('confirmed', 'processing', 'packed').values.sum,
      shipped:    stats_counts.slice('shipped', 'out_for_delivery').values.sum,
      completed:  stats_counts['completed'].to_i,
      issues:     (stats_counts['cancelled'].to_i + stats_counts['returned'].to_i)
    }
    # Keep @bookings_for_stats as the filtered scope (without includes) so view COUNT calls still work
    @bookings_for_stats = @bookings

    # Paginate with eager-loading only on the page being displayed
    @per_page = SystemSetting.default_pagination_per_page
    @bookings = @bookings.includes(:customer, { user: :franchise }, :booking_items, :store, :booking_invoices)
                         .page(params[:page]).per(@per_page)

    # Batch-preload associated_invoice for bookings with no BookingInvoice,
    # replacing up to N individual LIKE queries with a single batched query.
    bookings_without_bi = @bookings.select { |b| b.booking_invoices.empty? }
    if bookings_without_bi.any?
      numbers = bookings_without_bi.map(&:booking_number)
      like_clauses = numbers.map { "invoice_items.description LIKE ?" }.join(" OR ")
      matched = InvoiceItem.joins(:invoice)
                           .eager_load(:invoice)
                           .where(like_clauses, *numbers.map { |n| "%#{n}%" })
      inv_by_number = {}
      matched.each do |item|
        numbers.each { |bn| inv_by_number[bn] ||= item.invoice if item.description.include?(bn) }
      end
      bookings_without_bi.each do |b|
        b.instance_variable_set(:@associated_invoice, inv_by_number[b.booking_number])
      end
    end

    # Only load customers needed for the filter dropdown
    @customers = Customer.select(:id, :first_name, :middle_name, :last_name, :email, :mobile)
                         .order(:first_name, :last_name)
                         .limit(500)
  end

  def new
    @booking = Booking.new
    @booking.booking_items.build

    # Pre-select customer if redirected from quick customer creation
    @preselected_customer = Customer.find_by(id: params[:customer_id]) if params[:customer_id].present?
    if @preselected_customer
      @booking.customer_id = @preselected_customer.id
      @booking.customer_name = @preselected_customer.display_name
      @booking.customer_phone = @preselected_customer.mobile
      @booking.customer_email = @preselected_customer.email
    end

    # Only count central/main inventory (store_id IS NULL) so transferred stock is not double-counted
    @products = Product.active
                       .includes(:category, :product_variants, image_attachment: :blob)
                       .joins("LEFT JOIN stock_batches ON stock_batches.product_id = products.id AND stock_batches.status = 'active' AND stock_batches.quantity_remaining > 0 AND stock_batches.store_id IS NULL")
                       .select("products.*, COALESCE(SUM(stock_batches.quantity_remaining), 0) as cached_stock")
                       .group("products.id")
                       .order(Arel.sql("CASE WHEN COALESCE(SUM(stock_batches.quantity_remaining), 0) > 0 THEN 0 ELSE 1 END ASC, products.name ASC"))

    @categories = Category.where(status: true).order(:name)
    @customers = Customer.select(:id, :first_name, :middle_name, :last_name, :email, :mobile)
                         .order(:first_name, :last_name)
                         .limit(500)
  end

  def create
    @booking = Booking.new(booking_params)
    @booking.user = current_user

    # Auto-set franchise_id for franchise users
    if current_user.franchise?
      @booking.franchise_id = current_user.franchise&.id
      @booking.booked_by = 'franchise'
    else
      @booking.booked_by = 'admin'
    end

    # Only set booking_date to current time if not provided in params
    @booking.booking_date = @booking.booking_date.present? ? @booking.booking_date : Time.current

    # Clean and validate discount amount
    discount_value = params[:booking][:discount_amount] if params[:booking]
    Rails.logger.info "Processing discount value: #{discount_value.inspect}"

    if discount_value.present?
      # Clean the discount value - remove all whitespace, newlines, etc.
      cleaned_discount = discount_value.to_s.gsub(/\s+/, '').strip
      discount_amount = cleaned_discount.to_f
      @booking.discount_amount = discount_amount > 0 ? discount_amount : 0
      Rails.logger.info "Applied discount: #{@booking.discount_amount}"
    else
      @booking.discount_amount = 0
    end

    # Clean and validate delivery/shipping charge
    shipping_value = params[:booking][:shipping_charges] if params[:booking]

    if shipping_value.present?
      cleaned_shipping = shipping_value.to_s.gsub(/\s+/, '').strip
      shipping_charges = cleaned_shipping.to_f
      @booking.shipping_charges = shipping_charges > 0 ? shipping_charges : 0
      Rails.logger.info "Applied delivery charge: #{@booking.shipping_charges}"
    else
      @booking.shipping_charges = 0
    end

    # Store payment status value for after save (to avoid enum conflicts during validation)
    @payment_status_from_form = params[:booking][:payment_status]
    Rails.logger.info "Payment status from form: #{@payment_status_from_form}"

    # Validate stock availability before saving
    unless validate_stock_availability(@booking)
      @products = Product.active.includes(:category, :product_variants, image_attachment: :blob, additional_images_attachments: :blob)
      @customers = Customer.all.order(:first_name, :last_name)
      @stores = Store.where(status: true)
      render :new, status: :unprocessable_entity
      return
    end

    if @booking.save
      # Calculate totals after saving
      @booking.calculate_totals

      # Set payment status after initial save (to avoid enum conflicts)
      if @payment_status_from_form == 'paid'
        @booking.payment_status = :paid
      elsif @payment_status_from_form == 'partially_paid'
        @booking.payment_status = :partially_paid
      else
        @booking.payment_status = :unpaid
      end

      # Save again to persist the calculated totals and payment status
      @booking.save!

      # Log the calculated totals for debugging
      Rails.logger.info "Booking totals - Subtotal: #{@booking.subtotal}, Tax: #{@booking.tax_amount}, Discount: #{@booking.discount_amount}, Total: #{@booking.total_amount}"
      Rails.logger.info "Final payment status after save: #{@booking.payment_status}"

      # Generate the invoice immediately, regardless of payment status —
      # the invoice's own payment_status mirrors the booking's (paid vs unpaid).
      invoice_notice = ""
      begin
        invoice = generate_immediate_invoice_for_booking(@booking)
        if invoice
          invoice_notice = " Invoice ##{invoice.invoice_number} generated (#{@booking.payment_status_paid? ? 'paid' : 'unpaid'})."
        end
      rescue => e
        Rails.logger.error "Failed to generate immediate invoice for booking ##{@booking.id}: #{e.message}"
        invoice_notice = " Note: Invoice generation failed."
      end

      # Convert to order if payment is received
      if @booking.payment_status_paid? && params[:create_order] == '1'
        @booking.convert_to_order!
      end

      redirect_to admin_booking_path(@booking), notice: "Booking created successfully!#{invoice_notice}"
    else
      Rails.logger.error "Booking creation failed: #{@booking.errors.full_messages.join(', ')}"
      Rails.logger.error "Booking items errors: #{@booking.booking_items.map(&:errors).map(&:full_messages).flatten.join(', ')}"

      @products = Product.active.includes(:category, :product_variants, image_attachment: :blob, additional_images_attachments: :blob)
      @customers = Customer.all.order(:first_name, :last_name)
      @stores = Store.where(status: true)
      flash.now[:alert] = @booking.errors.full_messages.join(', ')
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @list_state = list_state_params
    @booking_items = @booking.booking_items.includes(product: [:category, image_attachment: :blob, additional_images_attachments: :blob])
  end

  def edit
    @list_state = list_state_params
    @products = Product.active.includes(:category, :product_variants, image_attachment: :blob, additional_images_attachments: :blob)
    @customers = Customer.all.order(:first_name, :last_name)
  end

  def update
    @list_state = list_state_params

    # Validate stock availability for updates
    unless validate_stock_availability(@booking, is_update: true)
      @products = Product.active.includes(:category, :product_variants, image_attachment: :blob, additional_images_attachments: :blob)
      @customers = Customer.all.order(:first_name, :last_name)
      render :edit, status: :unprocessable_entity
      return
    end

    if @booking.update(booking_params)
      redirect_to admin_bookings_path(@list_state), notice: 'Booking updated successfully!'
    else
      @products = Product.active.includes(:category, :product_variants, image_attachment: :blob, additional_images_attachments: :blob)
      @customers = Customer.all.order(:first_name, :last_name)
      render :edit
    end
  end

  def destroy
    begin
      # Check for associated orders (if enabled)
      if @booking.respond_to?(:order) && @booking.order.present?
        redirect_to admin_bookings_path(list_state_params), alert: 'Cannot delete booking with associated order.'
        return
      end

      # Store booking info for confirmation message
      booking_number = @booking.booking_number
      customer_name = @booking.customer&.display_name || 'Unknown'

      # Log the deletion for audit purposes
      Rails.logger.info "Deleting booking #{booking_number} (ID: #{@booking.id}) for customer #{customer_name} by user #{current_user&.email || 'Unknown'}"

      # Also clean up any regular Invoice records that might reference this booking
      if defined?(Invoice)
        related_invoices = Invoice.where("invoice_items.description LIKE ?", "%#{booking_number}%")
                                  .joins(:invoice_items)
        if related_invoices.any?
          Rails.logger.info "Found #{related_invoices.count} invoice(s) with items referencing booking #{booking_number}"
          related_invoices.each do |invoice|
            # Only delete invoice items that reference this booking
            invoice.invoice_items.where("description LIKE ?", "%#{booking_number}%").destroy_all
            # Delete the entire invoice if it has no items left
            if invoice.invoice_items.count == 0
              Rails.logger.info "Deleting empty invoice #{invoice.invoice_number} after removing booking items"
              invoice.destroy
            end
          end
        end
      end

      # Delete the booking (will cascade delete all associated records due to dependent: :destroy)
      @booking.destroy!

      # Log successful deletion
      Rails.logger.info "Successfully deleted booking #{booking_number} and all associated records"

      redirect_to admin_bookings_path(list_state_params), notice: "Booking #{booking_number} for #{customer_name} has been permanently deleted along with all associated records."
    rescue => e
      # Log the error
      Rails.logger.error "Failed to delete booking #{@booking.booking_number} (ID: #{@booking.id}): #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      # Provide user-friendly error message
      redirect_to admin_bookings_path(list_state_params), alert: "Failed to delete booking: #{e.message}. Please try again or contact support if the issue persists."
    end
  end

  def generate_invoice
    if @booking.invoice_generated?
      redirect_to admin_booking_path(@booking, list_state_params), notice: 'Invoice already generated.'
      return
    end

    invoice = generate_immediate_invoice_for_booking(@booking)
    if invoice
      redirect_to admin_booking_path(@booking, list_state_params), notice: "Invoice ##{invoice.invoice_number} generated successfully."
    else
      @booking.generate_invoice_number
      redirect_to admin_booking_path(@booking, list_state_params), notice: 'Invoice generated successfully.'
    end
  end

  def invoice
    respond_to do |format|
      format.html { render template: 'admin/bookings/invoice', layout: 'invoice' }
      format.pdf do
        pdf = WickedPdf.new.pdf_from_string(
          render_to_string('admin/bookings/invoice', formats: [:html], layout: 'invoice_pdf'),
          page_size: 'A4',
          margin: {
            top: '0.75in',
            bottom: '0.75in',
            left: '0.75in',
            right: '0.75in'
          },
          dpi: 300,
          encoding: 'UTF-8',
          disable_smart_shrinking: true,
          print_media_type: true,
          orientation: 'Portrait',
          header: {
            html: {
              template: 'shared/pdf_header'
            }
          },
          footer: {
            html: {
              template: 'shared/pdf_footer'
            }
          }
        )

        invoice_filename = "invoice-#{@booking.invoice_number || @booking.booking_number}-#{Date.current.strftime('%Y%m%d')}.pdf"

        send_data pdf,
                  filename: invoice_filename,
                  type: 'application/pdf',
                  disposition: 'attachment'
      end
    end
  end

  def convert_to_order
    if @booking.order.present?
      redirect_to admin_order_path(@booking.order), notice: 'Order already exists for this booking.'
    else
      order = @booking.convert_to_order!
      redirect_to admin_order_path(order), notice: 'Order created successfully!'
    end
  end

  # Status management actions
  def update_status
    new_status = params[:status]

    if @booking.next_possible_statuses.include?(new_status)
      case new_status
      when 'ordered_and_delivery_pending'
        @booking.update!(status: :ordered_and_delivery_pending)
        message = 'Booking moved to Ordered & Delivery Pending!'
      when 'confirmed'
        @booking.mark_as_confirmed!
        message = 'Booking confirmed successfully!'
      when 'processing'
        @booking.mark_as_processing!
        message = 'Order marked as processing!'
      when 'packed'
        @booking.mark_as_packed!
        message = 'Order packed successfully!'
      when 'shipped'
        @booking.mark_as_shipped!(params[:tracking_number])
        message = 'Order shipped successfully!'
      when 'out_for_delivery'
        @booking.mark_as_out_for_delivery!
        message = 'Order is out for delivery!'
      when 'delivered'
        @booking.mark_as_delivered!
        message = 'Order delivered and completed successfully!'
      when 'completed'
        @booking.mark_as_completed!
        message = 'Order completed!'
      else
        @booking.update!(status: new_status)
        message = "Status updated to #{new_status.humanize}!"
      end

      respond_to do |format|
        format.html {
          if params[:return_to] == 'index'
            redirect_to admin_bookings_path(list_state_params), notice: message
          else
            redirect_to admin_booking_path(@booking, list_state_params), notice: message
          end
        }
        format.json { render json: { success: true, message: message, new_status: @booking.status } }
      end
    else
      respond_to do |format|
        format.html {
          if params[:return_to] == 'index'
            redirect_to admin_bookings_path(list_state_params), alert: 'Invalid status transition!'
          else
            redirect_to admin_booking_path(@booking, list_state_params), alert: 'Invalid status transition!'
          end
        }
        format.json { render json: { success: false, error: 'Invalid status transition!' } }
      end
    end
  end

  def cancel_order
    reason = params[:reason]
    @booking.cancel_order!(reason)
    redirect_to admin_booking_path(@booking, list_state_params), notice: 'Booking cancelled successfully!'
  end

  def mark_delivered
    @booking.mark_as_delivered!
    redirect_to admin_booking_path(@booking, list_state_params), notice: 'Order marked as delivered!'
  end

  def mark_completed
    @booking.mark_as_completed!
    redirect_to admin_booking_path(@booking, list_state_params), notice: 'Order marked as completed!'
  end

  def mark_paid
    if @booking.payment_status_paid?
      redirect_to admin_booking_path(@booking, list_state_params), notice: 'Booking is already marked as paid.'
      return
    end

    @booking.payment_status = :paid
    @booking.save! # syncs the existing invoice to fully_paid via the payment_status callback, if one exists

    invoice = @booking.invoice_generated? ? Invoice.find_by(invoice_number: @booking.invoice_number) : generate_immediate_invoice_for_booking(@booking)
    if invoice
      redirect_to admin_booking_path(@booking, list_state_params), notice: "Booking marked as paid. Invoice ##{invoice.invoice_number} updated."
    else
      redirect_to admin_booking_path(@booking, list_state_params), notice: 'Booking marked as paid.'
    end
  rescue => e
    redirect_to admin_booking_path(@booking, list_state_params), alert: "Failed to mark as paid: #{e.message}"
  end

  def update_delivery_charge
    new_charge = params[:shipping_charges].to_s.gsub(/\s+/, '').to_f
    new_charge = 0 if new_charge < 0

    @booking.shipping_charges = new_charge
    @booking.calculate_totals!
    sync_booking_invoice_totals(@booking)

    respond_to do |format|
      format.html { redirect_to admin_booking_path(@booking), notice: 'Delivery charge updated successfully!' }
      format.json { render json: { success: true, shipping_charges: @booking.shipping_charges, total_amount: @booking.total_amount } }
    end
  rescue => e
    respond_to do |format|
      format.html { redirect_to admin_booking_path(@booking), alert: "Failed to update delivery charge: #{e.message}" }
      format.json { render json: { success: false, error: e.message } }
    end
  end

  def stage_transition
    @target_stage = params[:target_stage]

    unless @target_stage.present?
      redirect_to admin_booking_path(@booking), alert: 'Target stage not specified'
      return
    end

    unless @booking.next_possible_statuses.include?(@target_stage) ||
           (@booking.can_return? && @target_stage == 'returned')
      redirect_to admin_booking_path(@booking), alert: 'Invalid stage transition'
      return
    end

    # Load delivery people for shipped stage
    @delivery_people = DeliveryPerson.where(status: true).order(:first_name, :last_name) if @target_stage == 'shipped'
  end

  def process_stage_transition
    @target_stage = params[:target_stage]

    unless @target_stage.present?
      redirect_to admin_booking_path(@booking), alert: 'Target stage not specified'
      return
    end

    # Build stage transition data
    transition_data = build_transition_data

    # Update booking with stage-specific fields and transition history
    update_booking_with_transition(transition_data)

    case @target_stage
    when 'confirmed'
      process_confirmed_transition
    when 'processing'
      process_processing_transition
    when 'packed'
      process_packed_transition
    when 'shipped'
      process_shipped_transition
    when 'out_for_delivery'
      process_out_for_delivery_transition
    when 'delivered'
      process_delivered_transition
    when 'cancelled'
      process_cancelled_transition
    when 'returned'
      process_returned_transition
    else
      process_general_transition
    end
  end

  # Real-time data endpoint
  def realtime_data
    # Get fresh data for statistics
    all_bookings = Booking.includes(:customer, :user, :booking_items)

    stats = {
      draft: all_bookings.draft.count,
      pending: all_bookings.ordered_and_delivery_pending.count,
      processing: all_bookings.where(status: [:confirmed, :processing, :packed]).count,
      shipped: all_bookings.where(status: [:shipped, :out_for_delivery]).count,
      delivered: all_bookings.where(status: [:delivered, :completed]).count,
      issues: all_bookings.where(status: [:cancelled, :returned]).count,
      total: all_bookings.count,
      today_bookings: all_bookings.where(created_at: Date.current.all_day).count,
      total_revenue: all_bookings.where(status: [:completed, :delivered]).sum(:total_amount),
      last_updated: Time.current.strftime('%I:%M:%S %p')
    }

    # Get recent bookings (last 5)
    recent_bookings = all_bookings.recent.limit(5).includes(:customer, :booking_items).map do |booking|
      {
        id: booking.id,
        booking_number: booking.booking_number,
        customer_name: booking.customer&.display_name || booking.customer_name,
        status: booking.status,
        status_color: booking.status_color,
        status_icon: booking.status_icon,
        total_amount: booking.total_amount,
        created_at: booking.created_at.strftime('%d %b %Y %I:%M %p'),
        items_count: booking.booking_items.count
      }
    end

    render json: {
      success: true,
      stats: stats,
      recent_bookings: recent_bookings
    }
  rescue => e
    render json: {
      success: false,
      error: e.message
    }
  end

  # AJAX endpoints
  def search_products
    @products = Product.active
                       .where("name ILIKE ? OR sku ILIKE ?", "%#{params[:q]}%", "%#{params[:q]}%")
                       .limit(10)

    render json: @products.map { |p|
      {
        id: p.id,
        text: "#{p.name} - #{p.formatted_selling_price}",
        name: p.name,
        price: p.selling_price,
        stock: p.total_batch_stock, # Use batch stock for accuracy
        stock_status: p.stock_status_enhanced,
        stock_status_text: p.stock_status_text_enhanced,
        out_of_stock: p.out_of_stock?,
        low_stock: p.low_stock?,
        minimum_threshold: p.minimum_stock_threshold,
        image_url: p.main_image ? url_for(p.main_image) : nil
      }
    }
  end

  def search_customers
    @customers = Customer.where(
      "first_name ILIKE ? OR last_name ILIKE ? OR email ILIKE ? OR mobile ILIKE ?",
      "%#{params[:q]}%", "%#{params[:q]}%", "%#{params[:q]}%", "%#{params[:q]}%"
    ).limit(10)

    render json: @customers.map { |c|
      {
        id: c.id,
        text: "#{c.display_name} - #{c.mobile}",
        name: c.display_name,
        email: c.email,
        phone: c.mobile,
        address: c.address
      }
    }
  end

  def manage_stage
    # This will render the manage_stage.html.erb view
    @list_state = list_state_params
    @available_statuses = Booking.statuses.keys.map { |status| [status.humanize, status] }
    @next_stages = @booking.next_possible_statuses
  end

  def update_stage
    @list_state = list_state_params
    @target_stage = params[:target_stage] || params[:booking][:status]

    unless @target_stage.present?
      redirect_to manage_stage_admin_booking_path(@booking, list_state: @list_state), alert: "Please select a target stage."
      return
    end

    begin
      # Build transition data
      transition_data = build_stage_transition_data

      # Update booking with new status and transition data
      if update_booking_with_stage_transition(transition_data)
        redirect_to admin_bookings_path(@list_state), notice: "Booking stage updated to #{@target_stage.humanize} successfully."
      else
        redirect_to manage_stage_admin_booking_path(@booking, list_state: @list_state), alert: "Failed to update stage: #{@booking.errors.full_messages.join(', ')}"
      end
    rescue => e
      Rails.logger.error "Error in update_stage: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      redirect_to manage_stage_admin_booking_path(@booking, list_state: @list_state), alert: "Failed to update stage: #{e.message}"
    end
  end

  private

  def set_booking
    @booking = Booking.find(params[:id])
  end

  # Read forward-carried list page/filter state from the nested `list_state`
  # param, never the top-level params (some actions, e.g. update_status,
  # use a top-level `status` param for their own purpose which would
  # otherwise collide with the list's `status` filter).
  def list_state_params
    params[:list_state]&.permit(*LIST_STATE_PARAMS)&.to_h || {}
  end

  # Keep any persisted BookingInvoice snapshot for this booking in sync with the
  # booking's freshly recalculated totals (delivery charge changes only affect total_amount).
  def sync_booking_invoice_totals(booking)
    booking.booking_invoices.each do |booking_invoice|
      booking_invoice.update!(
        subtotal: booking.subtotal,
        tax_amount: booking.tax_amount,
        discount_amount: booking.discount_amount,
        total_amount: booking.total_amount
      )
    end
  end

  # Build transition data from form parameters
  def build_transition_data
    transition_data = {
      from_stage: @booking.status,
      to_stage: @target_stage,
      timestamp: Time.current,
      user_id: current_user.id,
      user_name: current_user.full_name || current_user.email
    }

    # Add stage-specific data based on target stage
    case @target_stage
    when 'shipped'
      transition_data[:courier_service] = params[:courier_service]
      transition_data[:tracking_number] = params[:tracking_number]
      transition_data[:shipping_charges] = params[:shipping_charges]
      transition_data[:expected_delivery_date] = params[:expected_delivery_date]
    when 'processing'
      transition_data[:processing_team] = params[:processing_team]
      transition_data[:expected_completion_time] = params[:expected_completion_time]
      transition_data[:estimated_processing_time] = params[:estimated_processing_time]
    when 'packed'
      transition_data[:package_weight] = params[:package_weight]
      transition_data[:package_dimensions] = params[:package_dimensions]
      transition_data[:quality_status] = params[:quality_status]
    when 'delivered'
      transition_data[:delivery_person] = params[:delivery_person]
      transition_data[:delivery_contact] = params[:delivery_contact]
      transition_data[:delivered_to] = params[:delivered_to]
      transition_data[:delivery_time] = params[:delivery_time]
      transition_data[:customer_satisfaction] = params[:customer_satisfaction]
    when 'cancelled'
      transition_data[:cancellation_reason] = params[:cancellation_reason]
    when 'returned'
      transition_data[:return_reason] = params[:return_reason]
      transition_data[:return_condition] = params[:return_condition]
      transition_data[:refund_amount] = params[:refund_amount]
      transition_data[:refund_method] = params[:refund_method]
    end

    # Add transition notes
    transition_data[:transition_notes] = params[:transition_notes] if params[:transition_notes].present?

    transition_data
  end

  # Update booking with stage transition data
  def update_booking_with_transition(transition_data)
    # Get current stage history or initialize empty array
    current_history = @booking.stage_history.present? ? JSON.parse(@booking.stage_history) : []

    # Add new transition to history
    current_history << transition_data

    # Prepare update attributes
    update_attrs = {
      status: @target_stage,
      stage_history: current_history.to_json,
      stage_updated_at: Time.current,
      stage_updated_by: current_user.id,
      transition_notes: transition_data[:transition_notes]
    }

    # Add stage-specific fields to booking
    case @target_stage
    when 'shipped'
      update_attrs[:courier_service] = params[:courier_service] if params[:courier_service].present?
      update_attrs[:tracking_number] = params[:tracking_number] if params[:tracking_number].present?
      update_attrs[:shipping_charges] = params[:shipping_charges] if params[:shipping_charges].present?
      update_attrs[:expected_delivery_date] = params[:expected_delivery_date] if params[:expected_delivery_date].present?
    when 'processing'
      update_attrs[:processing_team] = params[:processing_team] if params[:processing_team].present?
      update_attrs[:expected_completion_time] = params[:expected_completion_time] if params[:expected_completion_time].present?
      update_attrs[:estimated_processing_time] = params[:estimated_processing_time] if params[:estimated_processing_time].present?
    when 'packed'
      update_attrs[:package_weight] = params[:package_weight] if params[:package_weight].present?
      update_attrs[:package_dimensions] = params[:package_dimensions] if params[:package_dimensions].present?
      update_attrs[:quality_status] = params[:quality_status] if params[:quality_status].present?
    when 'delivered'
      update_attrs[:delivery_person] = params[:delivery_person] if params[:delivery_person].present?
      update_attrs[:delivery_contact] = params[:delivery_contact] if params[:delivery_contact].present?
      update_attrs[:delivered_to] = params[:delivered_to] if params[:delivered_to].present?
      update_attrs[:delivery_time] = params[:delivery_time] if params[:delivery_time].present?
      update_attrs[:customer_satisfaction] = params[:customer_satisfaction] if params[:customer_satisfaction].present?
    when 'cancelled'
      update_attrs[:cancellation_reason] = params[:cancellation_reason] if params[:cancellation_reason].present?
    when 'returned'
      update_attrs[:return_reason] = params[:return_reason] if params[:return_reason].present?
      update_attrs[:return_condition] = params[:return_condition] if params[:return_condition].present?
      update_attrs[:refund_amount] = params[:refund_amount] if params[:refund_amount].present?
      update_attrs[:refund_method] = params[:refund_method] if params[:refund_method].present?
    end

    @booking.update!(update_attrs)
  rescue => e
    Rails.logger.error "Error updating booking with transition data: #{e.message}"
    raise e
  end

  def build_stage_transition_data
    transition_data = {
      from_stage: @booking.status,
      to_stage: @target_stage,
      timestamp: Time.current,
      user_id: current_user.id,
      user_name: current_user.try(:full_name) || current_user.email
    }

    # Add stage-specific data
    case @target_stage
    when 'shipped'
      transition_data[:courier_service] = params[:courier_service]
      transition_data[:tracking_number] = params[:tracking_number]
      transition_data[:shipping_charges] = params[:shipping_charges]
      transition_data[:expected_delivery_date] = params[:expected_delivery_date]
    when 'out_for_delivery'
      transition_data[:delivery_person_id] = params[:delivery_person_id]
      transition_data[:delivery_person] = params[:delivery_person]
      transition_data[:delivery_contact] = params[:delivery_contact]
    when 'delivered'
      transition_data[:delivery_person] = params[:delivery_person]
      transition_data[:delivery_time] = params[:delivery_time]
      transition_data[:customer_satisfaction] = params[:customer_satisfaction]
    when 'cancelled'
      transition_data[:cancellation_reason] = params[:cancellation_reason]
      transition_data[:refund_amount] = params[:refund_amount]
    when 'returned'
      transition_data[:return_reason] = params[:return_reason]
      transition_data[:refund_amount] = params[:refund_amount]
    end

    transition_data[:notes] = params[:transition_notes] if params[:transition_notes].present?
    transition_data
  end

  def update_booking_with_stage_transition(transition_data)
    @booking.status = @target_stage

    # Store transition-specific fields
    case @target_stage
    when 'shipped'
      @booking.tracking_number = transition_data[:tracking_number] if transition_data[:tracking_number].present?
      @booking.shipping_charges = transition_data[:shipping_charges] if transition_data[:shipping_charges].present?
      @booking.expected_delivery_date = transition_data[:expected_delivery_date] if transition_data[:expected_delivery_date].present?
      @booking.courier_service = transition_data[:courier_service] if transition_data[:courier_service].present?
    when 'delivered'
      @booking.delivery_time = transition_data[:delivery_time] if transition_data[:delivery_time].present?
      @booking.customer_satisfaction = transition_data[:customer_satisfaction] if transition_data[:customer_satisfaction].present?
      @booking.delivery_person = transition_data[:delivery_person] if transition_data[:delivery_person].present?
      @booking.delivered_to = transition_data[:delivered_to] if transition_data[:delivered_to].present?
    when 'cancelled'
      @booking.cancellation_reason = transition_data[:cancellation_reason] if transition_data[:cancellation_reason].present?
      @booking.refund_amount = transition_data[:refund_amount] if transition_data[:refund_amount].present?
    when 'returned'
      @booking.return_reason = transition_data[:return_reason] if transition_data[:return_reason].present?
      @booking.refund_amount = transition_data[:refund_amount] if transition_data[:refund_amount].present?
      @booking.return_condition = transition_data[:return_condition] if transition_data[:return_condition].present?
    when 'processing'
      @booking.processing_team = transition_data[:processing_team] if transition_data[:processing_team].present?
      @booking.estimated_processing_time = transition_data[:estimated_processing_time] if transition_data[:estimated_processing_time].present?
    when 'packed'
      @booking.package_weight = transition_data[:package_weight] if transition_data[:package_weight].present?
      @booking.package_dimensions = transition_data[:package_dimensions] if transition_data[:package_dimensions].present?
      @booking.quality_status = transition_data[:quality_status] if transition_data[:quality_status].present?
    when 'out_for_delivery'
      @booking.delivery_person = transition_data[:delivery_person] if transition_data[:delivery_person].present?
      @booking.delivery_contact = transition_data[:delivery_contact] if transition_data[:delivery_contact].present?
      @booking.delivery_person_id = transition_data[:delivery_person_id] if transition_data[:delivery_person_id].present?
    end

    # Update stage history - parse existing JSON and add new entry
    begin
      history = @booking.stage_history.present? ? JSON.parse(@booking.stage_history) : []
    rescue JSON::ParserError
      history = []
    end

    history << transition_data.stringify_keys
    @booking.stage_history = history.to_json
    @booking.stage_updated_at = Time.current
    @booking.stage_updated_by = current_user.id

    # Add notes if provided
    if transition_data[:notes].present?
      @booking.transition_notes = [@booking.transition_notes, transition_data[:notes]].compact.join("\n---\n")
    end

    @booking.save!
  rescue => e
    Rails.logger.error "Failed to update booking stage: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
  end

  def booking_params
    params.require(:booking).permit(
      :customer_id, :customer_name, :customer_email, :customer_phone,
      :payment_method, :payment_status, :discount_amount, :shipping_charges, :notes,
      :delivery_address, :cash_received, :change_amount, :status, :store_id,
      :booking_date, :is_b2b, booking_items_attributes: [:id, :product_id, :product_variant_id, :quantity, :price, :_destroy]
    )
  end

  def validate_stock_availability(booking, is_update: false)
    stock_errors = []
    active_items = booking.booking_items.reject(&:marked_for_destruction?).select { |i| i.product_id.present? && i.quantity.to_i > 0 }
    return true if active_items.empty?

    # Preload products and variants to avoid N+1
    product_ids = active_items.map(&:product_id).uniq
    variant_ids = active_items.map(&:product_variant_id).compact.uniq
    products_by_id = Product.where(id: product_ids).index_by(&:id)
    variants_by_id = ProductVariant.where(id: variant_ids).index_by(&:id)

    active_items.each do |item|
      product = products_by_id[item.product_id]
      next unless product

      # Admin bookings sell from central inventory only (store_id IS NULL)
      if product.has_multiple_quantities? && item.product_variant_id.present?
        variant = variants_by_id[item.product_variant_id]
        available_stock = variant ? variant.available_stock.to_f : 0.0
      else
        available_stock = StockBatch.available_for_product(product.id, store_id: nil).sum(:quantity_remaining).to_f
      end

      # For updates, add back the current item's quantity if it exists
      if is_update && item.persisted? && item.quantity_changed?
        available_stock += (item.quantity_was || 0)
      end

      if item.quantity > available_stock
        stock_errors << {
          product: product,
          requested: item.quantity,
          available: available_stock,
          item: item
        }
      end
    end

    if stock_errors.any?
      stock_errors.each do |error|
        booking.errors.add(:base,
          "#{error[:product].name}: Only #{error[:available]} units available, but #{error[:requested]} requested")

        # Also add error to the specific booking item
        error[:item].errors.add(:quantity,
          "only #{error[:available]} units available")
      end

      flash.now[:alert] = "Stock validation failed: #{stock_errors.map { |e|
        "#{e[:product].name} (Available: #{e[:available]}, Requested: #{e[:requested]})"
      }.join(', ')}"

      return false
    end

    true
  end

  # Stage transition processing methods
  def process_confirmed_transition
    # The booking status and data have already been updated in update_booking_with_transition
    # Just need to provide the redirect response

    respond_to do |format|
      format.html { redirect_to admin_bookings_path, notice: 'Booking confirmed successfully!' }
      format.json { render json: { success: true, message: 'Booking confirmed successfully!', status: @booking.status } }
    end
  rescue => e
    respond_to do |format|
      format.html { redirect_to admin_bookings_path, alert: "Error confirming booking: #{e.message}" }
      format.json { render json: { success: false, error: e.message } }
    end
  end

  def process_processing_transition
    respond_to do |format|
      format.html { redirect_to admin_bookings_path, notice: 'Booking moved to processing!' }
      format.json { render json: { success: true, message: 'Booking moved to processing!', status: @booking.status } }
    end
  rescue => e
    respond_to do |format|
      format.html { redirect_to admin_bookings_path, alert: "Error processing booking: #{e.message}" }
      format.json { render json: { success: false, error: e.message } }
    end
  end

  def process_packed_transition
    respond_to do |format|
      format.html { redirect_to admin_bookings_path, notice: 'Booking marked as packed!' }
      format.json { render json: { success: true, message: 'Booking marked as packed!', status: @booking.status } }
    end
  rescue => e
    respond_to do |format|
      format.html { redirect_to admin_bookings_path, alert: "Error packing booking: #{e.message}" }
      format.json { render json: { success: false, error: e.message } }
    end
  end

  def process_shipped_transition
    # Validation for required fields
    unless params[:courier_service].present? && params[:tracking_number].present?
      respond_to do |format|
        format.html { redirect_to admin_bookings_path, alert: 'Courier service and tracking number are required for shipping' }
        format.json { render json: { success: false, error: 'Courier service and tracking number are required for shipping' } }
      end
      return
    end

    respond_to do |format|
      format.html { redirect_to admin_bookings_path, notice: 'Booking marked as shipped with tracking details!' }
      format.json { render json: { success: true, message: 'Booking marked as shipped with tracking details!', status: @booking.status } }
    end
  rescue => e
    respond_to do |format|
      format.html { redirect_to admin_bookings_path, alert: "Error shipping booking: #{e.message}" }
      format.json { render json: { success: false, error: e.message } }
    end
  end

  def process_out_for_delivery_transition
    # Validation for required fields
    unless params[:delivery_person_id].present?
      respond_to do |format|
        format.html { redirect_to manage_stage_admin_booking_path(@booking), alert: 'Please select a delivery person for out for delivery' }
        format.json { render json: { success: false, error: 'Please select a delivery person for out for delivery' } }
      end
      return
    end

    respond_to do |format|
      format.html { redirect_to admin_bookings_path, notice: 'Booking marked as out for delivery with delivery person assigned!' }
      format.json { render json: { success: true, message: 'Booking marked as out for delivery with delivery person assigned!', status: @booking.status } }
    end
  rescue => e
    respond_to do |format|
      format.html { redirect_to admin_bookings_path, alert: "Error updating delivery status: #{e.message}" }
      format.json { render json: { success: false, error: e.message } }
    end
  end

  def process_delivered_transition
    # Auto-transition to completed as per original logic
    @booking.update!(status: :completed)

    respond_to do |format|
      format.html { redirect_to admin_bookings_path, notice: 'Booking marked as delivered and completed!' }
      format.json { render json: { success: true, message: 'Booking marked as delivered and completed!', status: @booking.status } }
    end
  rescue => e
    respond_to do |format|
      format.html { redirect_to admin_bookings_path, alert: "Error marking as delivered: #{e.message}" }
      format.json { render json: { success: false, error: e.message } }
    end
  end

  def process_cancelled_transition
    unless params[:cancellation_reason].present?
      respond_to do |format|
        format.html { redirect_to admin_bookings_path, alert: 'Cancellation reason is required' }
        format.json { render json: { success: false, error: 'Cancellation reason is required' } }
      end
      return
    end

    respond_to do |format|
      format.html { redirect_to admin_bookings_path, notice: 'Booking cancelled successfully!' }
      format.json { render json: { success: true, message: 'Booking cancelled successfully!', status: @booking.status } }
    end
  rescue => e
    respond_to do |format|
      format.html { redirect_to admin_bookings_path, alert: "Error cancelling booking: #{e.message}" }
      format.json { render json: { success: false, error: e.message } }
    end
  end

  def process_returned_transition
    unless params[:return_reason].present?
      respond_to do |format|
        format.html { redirect_to admin_bookings_path, alert: 'Return reason is required' }
        format.json { render json: { success: false, error: 'Return reason is required' } }
      end
      return
    end

    respond_to do |format|
      format.html { redirect_to admin_bookings_path, notice: 'Return processed successfully!' }
      format.json { render json: { success: true, message: 'Return processed successfully!', status: @booking.status } }
    end
  rescue => e
    respond_to do |format|
      format.html { redirect_to admin_bookings_path, alert: "Error processing return: #{e.message}" }
      format.json { render json: { success: false, error: e.message } }
    end
  end

  def process_general_transition
    respond_to do |format|
      format.html { redirect_to admin_bookings_path, notice: "Booking updated to #{@target_stage.humanize}!" }
      format.json { render json: { success: true, message: "Booking updated to #{@target_stage.humanize}!", status: @booking.status } }
    end
  rescue => e
    respond_to do |format|
      format.html { redirect_to admin_bookings_path, alert: "Error updating booking: #{e.message}" }
      format.json { render json: { success: false, error: e.message } }
    end
  end

  # Generate immediate invoice for paid booking
  def generate_immediate_invoice_for_booking(booking)
    booking.generate_quick_invoice!
  end
end
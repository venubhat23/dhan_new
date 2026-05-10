class Franchise::BookingsController < Franchise::BaseController
  before_action :set_booking, only: [:show, :edit, :update, :destroy, :generate_invoice, :invoice, :convert_to_order, :update_status, :cancel_order, :mark_delivered, :mark_completed, :manage_stage, :update_stage]

  def index
    # Franchise-created bookings
    franchise_bookings = Booking.where(franchise_id: current_franchise.id)
    # Online orders placed by customers through the shop
    online_orders = Booking.where(booked_by: 'customer')

    # Combined base query for statistics
    @all_bookings = Booking.where(
      franchise_id: current_franchise.id
    ).or(
      Booking.where(booked_by: 'customer')
    ).includes(:customer, :user, :booking_items, :store)

    # Source filter: 'franchise' = only franchise-created, 'online' = only customer orders, default = all
    @source_filter = params[:source].presence || 'all'
    base_scope = case @source_filter
                 when 'franchise'
                   franchise_bookings
                 when 'online'
                   online_orders
                 else
                   @all_bookings
                 end

    @bookings = base_scope.recent

    if params[:search].present?
      @bookings = @bookings.where(
        "booking_number LIKE ? OR customer_name LIKE ? OR customer_email LIKE ? OR customer_phone LIKE ?",
        "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%"
      )
    end

    if params[:status].present? && params[:status].strip != ''
      @bookings = @bookings.where(status: params[:status])
    end

    if params[:date_from].present? && params[:date_to].present?
      @bookings = @bookings.where(created_at: params[:date_from]..params[:date_to])
    end

    if params[:customer_id].present? && params[:customer_id].strip != ''
      @bookings = @bookings.where(customer_id: params[:customer_id])
    end

    @per_page = SystemSetting.default_pagination_per_page
    @bookings = @bookings.page(params[:page]).per(@per_page)

    @bookings_for_stats = @all_bookings

    # Counts for source tabs
    @franchise_bookings_count = franchise_bookings.count
    @online_orders_count = online_orders.count

    @customers = Customer.select(:id, :first_name, :middle_name, :last_name, :email, :mobile)
                        .order(:first_name, :last_name)
  end

  def new
    @booking = Booking.new
    @booking.booking_items.build

    # Eager load all necessary associations and precompute stock data
    @products = Product.active
                       .includes(
                         :category,
                         :stock_batches,
                         image_attachment: :blob,
                         additional_images_attachments: :blob
                       )
                       .joins("LEFT JOIN stock_batches ON stock_batches.product_id = products.id AND stock_batches.status = 'active' AND stock_batches.quantity_remaining > 0")
                       .select(
                         "products.*,
                          COALESCE(SUM(stock_batches.quantity_remaining), 0) as cached_stock,
                          MIN(stock_batches.batch_date) as first_batch_date,
                          (SELECT quantity_purchased FROM stock_batches sb2 WHERE sb2.product_id = products.id ORDER BY sb2.batch_date ASC, sb2.created_at ASC LIMIT 1) as initial_stock_value"
                       )
                       .group("products.id")
                       .order(Arel.sql("CASE WHEN COALESCE(SUM(stock_batches.quantity_remaining), 0) > 0 THEN 0 ELSE 1 END ASC, products.name ASC"))

    @customers = Customer.select(:id, :first_name, :middle_name, :last_name, :email, :mobile)
                        .order(:first_name, :last_name)
  end

  def create
    @booking = Booking.new(booking_params)
    @booking.user = current_user
    @booking.franchise_id = current_franchise.id
    @booking.booked_by = 'franchise'

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

    # Store payment status value for after save (to avoid enum conflicts during validation)
    @payment_status_from_form = params[:booking][:payment_status]
    Rails.logger.info "Payment status from form: #{@payment_status_from_form}"

    # Validate stock availability before saving
    unless validate_stock_availability(@booking)
      @products = Product.active.includes(:category, image_attachment: :blob, additional_images_attachments: :blob)
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
      else
        @booking.payment_status = :unpaid
      end

      # Save again to persist the calculated totals and payment status
      @booking.save!

      # Log the calculated totals for debugging
      Rails.logger.info "Booking totals - Subtotal: #{@booking.subtotal}, Tax: #{@booking.tax_amount}, Discount: #{@booking.discount_amount}, Total: #{@booking.total_amount}"
      Rails.logger.info "Final payment status after save: #{@booking.payment_status}"

      # Generate invoice immediately if payment is received
      invoice_notice = ""
      if @booking.payment_status_paid?
        begin
          invoice = generate_immediate_invoice_for_booking(@booking)
          if invoice
            invoice_notice = " Invoice ##{invoice.invoice_number} generated with paid status."
          end
        rescue => e
          Rails.logger.error "Failed to generate immediate invoice for booking ##{@booking.id}: #{e.message}"
          invoice_notice = " Note: Invoice generation failed, will be handled via consolidated system."
        end
      else
        Rails.logger.info "Booking ##{@booking.id} created successfully. Invoice will be generated via consolidated system when payment is received."
      end

      # Convert to order if payment is received
      if @booking.payment_status_paid? && params[:create_order] == '1'
        @booking.convert_to_order!
      end

      redirect_to franchise_booking_path(@booking), notice: "Booking created successfully!#{invoice_notice}"
    else
      Rails.logger.error "Booking creation failed: #{@booking.errors.full_messages.join(', ')}"
      Rails.logger.error "Booking items errors: #{@booking.booking_items.map(&:errors).map(&:full_messages).flatten.join(', ')}"

      @products = Product.active.includes(:category, image_attachment: :blob, additional_images_attachments: :blob)
      @customers = Customer.all.order(:first_name, :last_name)
      @stores = Store.where(status: true)
      flash.now[:alert] = @booking.errors.full_messages.join(', ')
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @booking_items = @booking.booking_items.includes(product: [:category, image_attachment: :blob, additional_images_attachments: :blob])
  end

  def edit
    @products = Product.active.includes(:category, image_attachment: :blob, additional_images_attachments: :blob)
    @customers = Customer.all.order(:first_name, :last_name)
  end

  def update
    # Validate stock availability for updates
    unless validate_stock_availability(@booking, is_update: true)
      @products = Product.active.includes(:category, image_attachment: :blob, additional_images_attachments: :blob)
      @customers = Customer.all.order(:first_name, :last_name)
      render :edit, status: :unprocessable_entity
      return
    end

    if @booking.update(booking_params)
      redirect_to franchise_booking_path(@booking), notice: 'Booking updated successfully!'
    else
      @products = Product.active.includes(:category, image_attachment: :blob, additional_images_attachments: :blob)
      @customers = Customer.all.order(:first_name, :last_name)
      render :edit
    end
  end

  def destroy
    begin
      # Check for associated orders (if enabled)
      if @booking.respond_to?(:order) && @booking.order.present?
        redirect_to franchise_bookings_path, alert: 'Cannot delete booking with associated order.'
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

      redirect_to franchise_bookings_path, notice: "Booking #{booking_number} for #{customer_name} has been permanently deleted along with all associated records."
    rescue => e
      # Log the error
      Rails.logger.error "Failed to delete booking #{@booking.booking_number} (ID: #{@booking.id}): #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      # Provide user-friendly error message
      redirect_to franchise_bookings_path, alert: "Failed to delete booking: #{e.message}. Please try again or contact support if the issue persists."
    end
  end

  def generate_invoice
    @booking.generate_invoice_number
    redirect_to invoice_franchise_booking_path(@booking)
  end

  def invoice
    respond_to do |format|
      format.html { render template: 'franchise/bookings/invoice', layout: 'invoice' }
      format.pdf do
        pdf = WickedPdf.new.pdf_from_string(
          render_to_string('franchise/bookings/invoice', layout: 'invoice_pdf'),
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
      redirect_to franchise_order_path(@booking.order), notice: 'Order already exists for this booking.'
    else
      order = @booking.convert_to_order!
      redirect_to franchise_order_path(order), notice: 'Order created successfully!'
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
        format.html { redirect_to franchise_booking_path(@booking), notice: message }
        format.json { render json: { success: true, message: message, new_status: @booking.status } }
      end
    else
      respond_to do |format|
        format.html { redirect_to franchise_booking_path(@booking), alert: 'Invalid status transition.' }
        format.json { render json: { success: false, message: 'Invalid status transition.' } }
      end
    end
  end

  private

  def set_booking
    @booking = Booking.where(franchise_id: current_franchise.id)
                     .or(Booking.where(booked_by: 'customer'))
                     .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to franchise_bookings_path, alert: 'Booking not found'
  end

  def booking_params
    params.require(:booking).permit(
      :customer_id, :booking_date, :status, :notes, :customer_name, :customer_email,
      :customer_phone, :customer_address, :delivery_address, :delivery_date, :delivery_time,
      :payment_method, :payment_status, :cash_received, :change_amount, :discount_amount, :store_id, :booked_by,
      booking_items_attributes: [
        :id, :product_id, :quantity, :price, :unit_price, :subtotal, :_destroy
      ]
    )
  end

  def validate_stock_availability(booking, is_update: false)
    booking.booking_items.each do |item|
      next if item.marked_for_destruction?

      product = Product.find(item.product_id)
      available_stock = product.available_stock

      # For updates, add back the current item's quantity to available stock
      if is_update && item.persisted?
        original_item = booking.booking_items.find(item.id)
        available_stock += original_item.quantity if original_item
      end

      if item.quantity > available_stock
        @booking.errors.add(:base, "Insufficient stock for #{product.name}. Available: #{available_stock}, Requested: #{item.quantity}")
        return false
      end
    end
    true
  end

  def generate_immediate_invoice_for_booking(booking)
    # Add invoice generation logic here if needed
    # This would be similar to admin functionality
    nil
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
        stock: p.total_batch_stock,
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
    @available_statuses = Booking.statuses.keys.map { |status| [status.humanize, status] }
    @next_stages = @booking.next_possible_statuses
  end

  def update_stage
    @target_stage = params[:target_stage] || params[:booking][:status]

    unless @target_stage.present?
      redirect_to manage_stage_franchise_booking_path(@booking), alert: "Please select a target stage."
      return
    end

    begin
      # Build transition data
      transition_data = build_stage_transition_data

      # Update booking with new status and transition data
      if update_booking_with_stage_transition(transition_data)
        redirect_to franchise_bookings_path, notice: "Booking stage updated to #{@target_stage.humanize} successfully."
      else
        redirect_to manage_stage_franchise_booking_path(@booking), alert: "Failed to update stage: #{@booking.errors.full_messages.join(', ')}"
      end
    rescue => e
      Rails.logger.error "Error in update_stage: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      redirect_to manage_stage_franchise_booking_path(@booking), alert: "Failed to update stage: #{e.message}"
    end
  end

  def realtime_data
    # Calculate statistics
    total_count = @all_bookings.count
    pending_count = @all_bookings.where(status: 'pending').count
    processing_count = @all_bookings.where(status: 'processing').count
    delivered_count = @all_bookings.where(status: 'delivered').count

    stats = {
      total: total_count,
      pending: pending_count,
      processing: processing_count,
      delivered: delivered_count
    }

    # Get recent bookings
    recent_bookings = @all_bookings.recent.limit(5).map do |booking|
      {
        id: booking.id,
        booking_number: booking.booking_number,
        customer_name: booking.customer_name,
        status: booking.status,
        total_amount: booking.total_amount,
        created_at: booking.created_at.strftime('%b %d, %Y')
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

  def build_stage_transition_data
    {
      from_stage: @booking.status,
      to_stage: @target_stage,
      timestamp: Time.current,
      user_id: current_user.id,
      user_name: current_user.email,
      notes: params[:transition_notes]
    }
  end

  def update_booking_with_stage_transition(transition_data)
    @booking.status = @target_stage
    @booking.stage_updated_at = transition_data[:timestamp]
    @booking.stage_updated_by = transition_data[:user_name]
    @booking.transition_notes = transition_data[:notes] if transition_data[:notes].present?
    @booking.save
  end
end
class StoreAdmin::BookingsController < StoreAdmin::ApplicationController
  before_action -> { require_permission!(:can_create_bookings?, message: 'You do not have permission to manage bookings.') },
                only: [:new, :create, :edit, :update, :destroy]
  before_action :set_booking, only: [:show, :edit, :update, :destroy, :generate_invoice, :invoice,
                                     :convert_to_order, :update_status, :cancel, :cancel_order,
                                     :mark_delivered, :mark_completed, :mark_paid, :manage_stage,
                                     :update_stage, :update_delivery_charge, :stage_transition,
                                     :process_stage_transition]

  LIST_STATE_PARAMS = %i[page search status date_from date_to customer_id b2b booked_by payment_status delivery_pending].freeze

  def index
    @bookings = store_bookings.recent

    if params[:search].present?
      term = "%#{params[:search]}%"
      @bookings = @bookings.where('booking_number LIKE ? OR customer_name LIKE ? OR customer_email LIKE ? OR customer_phone LIKE ?', term, term, term, term)
    end
    @bookings = @bookings.where(status: params[:status])                if params[:status].present? && params[:status].strip != ''
    @bookings = @bookings.where(created_at: params[:date_from]..params[:date_to]) if params[:date_from].present? && params[:date_to].present?
    @bookings = @bookings.where(customer_id: params[:customer_id])      if params[:customer_id].present? && params[:customer_id].strip != ''
    @bookings = @bookings.where(is_b2b: true)                           if params[:b2b] == '1'
    @bookings = @bookings.where(payment_status: params[:payment_status]) if params[:payment_status].present? && params[:payment_status].strip != ''
    @bookings = @bookings.where.not(status: %w[delivered completed cancelled returned]) if params[:delivery_pending] == '1'

    stats_counts = @bookings.reorder('').group(:status).count
    @booking_stats = {
      draft:      stats_counts['draft'].to_i,
      pending:    stats_counts['ordered_and_delivery_pending'].to_i,
      processing: stats_counts.slice('confirmed', 'processing', 'packed').values.sum,
      shipped:    stats_counts.slice('shipped', 'out_for_delivery').values.sum,
      completed:  stats_counts['completed'].to_i,
      issues:     (stats_counts['cancelled'].to_i + stats_counts['returned'].to_i)
    }
    @bookings_for_stats = @bookings

    @per_page = (SystemSetting.respond_to?(:default_pagination_per_page) ? SystemSetting.default_pagination_per_page : 20)
    @bookings = @bookings.includes(:customer, :store, :booking_invoices).page(params[:page]).per(@per_page)

    @summary = calculate_bookings_summary
    @customers = Customer.select(:id, :full_name, :email, :mobile).order(:full_name).limit(500)
  end

  STATUS_FILTER_ACTIONS = {
    pending: 'ordered_and_delivery_pending', confirmed: 'confirmed', processing: 'processing',
    packed: 'packed', shipped: 'shipped', out_for_delivery: 'out_for_delivery',
    delivered: 'delivered', completed: 'completed', cancelled: 'cancelled', returned: 'returned'
  }.freeze

  STATUS_FILTER_ACTIONS.each do |action_name, status_value|
    define_method(action_name) do
      params[:status] = status_value
      index
      render :index unless performed?
    end
  end

  def show
    @list_state = list_state_params
    @booking_items = @booking.booking_items.includes(product: [:category, image_attachment: :blob])
    @can_update_status = @booking.store_id == @current_store.id
    @available_statuses = (Booking.statuses.keys - [@booking.status] rescue [])
  end

  def new
    @booking = @current_store.bookings.build
    @booking.booking_items.build
    @preselected_customer = Customer.find_by(id: params[:customer_id]) if params[:customer_id].present?
    if @preselected_customer
      @booking.customer_id = @preselected_customer.id
      @booking.customer_name = @preselected_customer.display_name
      @booking.customer_phone = @preselected_customer.mobile
      @booking.customer_email = @preselected_customer.email
    end
    @selected_store = @current_store
    @products = products_for_picker
    @categories = Category.where(status: true).order(:name)
    @customers = Customer.select(:id, :full_name, :email, :mobile).order(:full_name).limit(500)
    @store_products = @current_store.store_products_with_inventory.includes(:product_variants).by_stock_availability rescue @products
  end

  def create
    @booking = @current_store.bookings.build(booking_params)
    @booking.store_id = @current_store.id
    @booking.user = current_user if @booking.respond_to?(:user=)
    @booking.booked_by = 'store_admin' if @booking.respond_to?(:booked_by=)
    @booking.booking_date = @booking.booking_date.presence || Time.current

    @booking.discount_amount = params.dig(:booking, :discount_amount).to_s.gsub(/\s+/, '').to_f.clamp(0, Float::INFINITY)
    @booking.shipping_charges = params.dig(:booking, :shipping_charges).to_s.gsub(/\s+/, '').to_f.clamp(0, Float::INFINITY) if @booking.respond_to?(:shipping_charges=)
    @payment_status_from_form = params.dig(:booking, :payment_status)

    unless validate_stock_availability(@booking)
      return render_new_with_errors
    end

    if @booking.save
      @booking.calculate_totals if @booking.respond_to?(:calculate_totals)
      @booking.payment_status = case @payment_status_from_form
                                when 'paid' then :paid
                                when 'partially_paid' then :partially_paid
                                else :unpaid
                                end
      @booking.save!

      invoice_notice = ''
      begin
        invoice = generate_immediate_invoice_for_booking(@booking)
        invoice_notice = " Invoice ##{invoice.invoice_number} generated." if invoice
      rescue => e
        Rails.logger.error "Immediate invoice failed for booking ##{@booking.id}: #{e.message}"
        invoice_notice = ' Note: invoice generation failed.'
      end

      @booking.convert_to_order! if @booking.payment_status_paid? && params[:create_order] == '1' && @booking.respond_to?(:convert_to_order!)
      redirect_to store_admin_booking_path(@booking), notice: "Booking created successfully!#{invoice_notice}"
    else
      flash.now[:alert] = @booking.errors.full_messages.join(', ')
      render_new_with_errors
    end
  end

  def edit
    @list_state = list_state_params
    @products = products_for_picker
    @customers = Customer.order(:full_name)
    @categories = Category.where(status: true).order(:name)
  end

  def update
    @list_state = list_state_params
    unless validate_stock_availability(@booking, is_update: true)
      @products = products_for_picker
      @customers = Customer.order(:full_name)
      return render(:edit, status: :unprocessable_entity)
    end

    if @booking.update(booking_params)
      redirect_to store_admin_bookings_path(@list_state), notice: 'Booking updated successfully!'
    else
      @products = products_for_picker
      @customers = Customer.order(:full_name)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @booking.respond_to?(:order) && @booking.order.present?
      return redirect_to(store_admin_bookings_path(list_state_params), alert: 'Cannot delete booking with associated order.')
    end
    number = @booking.booking_number
    customer_name = @booking.customer&.display_name || 'Unknown'

    if defined?(Invoice)
      Invoice.joins(:invoice_items).where('invoice_items.description LIKE ?', "%#{number}%").distinct.each do |invoice|
        invoice.invoice_items.where('description LIKE ?', "%#{number}%").destroy_all
        invoice.destroy if invoice.invoice_items.reload.empty?
      end
    end
    @booking.destroy!
    redirect_to store_admin_bookings_path(list_state_params),
                notice: "Booking #{number} for #{customer_name} has been permanently deleted along with all associated records."
  rescue => e
    redirect_to store_admin_bookings_path(list_state_params), alert: "Failed to delete booking: #{e.message}."
  end

  def generate_invoice
    if @booking.invoice_generated?
      return redirect_to(store_admin_booking_path(@booking, list_state_params), notice: 'Invoice already generated.')
    end
    invoice = generate_immediate_invoice_for_booking(@booking)
    if invoice
      redirect_to store_admin_booking_path(@booking, list_state_params), notice: "Invoice ##{invoice.invoice_number} generated successfully."
    else
      @booking.generate_invoice_number
      redirect_to store_admin_booking_path(@booking, list_state_params), notice: 'Invoice generated successfully.'
    end
  end

  def invoice
    respond_to do |format|
      format.html { render template: 'admin/bookings/invoice', layout: 'invoice' }
      format.pdf do
        pdf = WickedPdf.new.pdf_from_string(
          render_to_string('admin/bookings/invoice', formats: [:html], layout: 'invoice_pdf'),
          page_size: 'A4', margin: { top: '0.75in', bottom: '0.75in', left: '0.75in', right: '0.75in' },
          dpi: 300, encoding: 'UTF-8', disable_smart_shrinking: true, print_media_type: true, orientation: 'Portrait'
        )
        send_data pdf, filename: "invoice-#{@booking.invoice_number || @booking.booking_number}-#{Date.current.strftime('%Y%m%d')}.pdf",
                  type: 'application/pdf', disposition: 'attachment'
      end
    end
  end

  def convert_to_order
    if @booking.respond_to?(:order) && @booking.order.present?
      redirect_to store_admin_booking_path(@booking), notice: 'Order already exists for this booking.'
    else
      @booking.convert_to_order!
      redirect_to store_admin_booking_path(@booking), notice: 'Order created successfully!'
    end
  rescue => e
    redirect_to store_admin_booking_path(@booking), alert: "Failed to create order: #{e.message}"
  end

  def update_status
    new_status = params[:new_status] || params[:status]
    if @booking.respond_to?(:next_possible_statuses) && @booking.next_possible_statuses.include?(new_status)
      apply_named_status_transition(new_status)
      message = "Status updated to #{new_status.humanize}."
    elsif @booking.update(status: new_status)
      message = "Status updated to #{new_status.to_s.humanize}."
    else
      return respond_to do |format|
        format.html { redirect_to store_admin_booking_path(@booking, list_state_params), alert: 'Invalid status transition!' }
        format.json { render json: { success: false, error: 'Invalid status transition!' } }
      end
    end
    respond_to do |format|
      format.html do
        target = params[:return_to] == 'index' ? store_admin_bookings_path(list_state_params) : store_admin_booking_path(@booking, list_state_params)
        redirect_to target, notice: message
      end
      format.json { render json: { success: true, message: message, new_status: @booking.status } }
    end
  end

  def cancel
    if @booking.update(status: 'cancelled', cancellation_reason: params[:cancellation_reason] || params[:reason])
      redirect_to store_admin_bookings_path, notice: 'Booking cancelled successfully.'
    else
      redirect_to store_admin_booking_path(@booking), alert: 'Failed to cancel booking.'
    end
  end

  def cancel_order
    @booking.cancel_order!(params[:reason])
    redirect_to store_admin_booking_path(@booking, list_state_params), notice: 'Booking cancelled successfully!'
  rescue => e
    redirect_to store_admin_booking_path(@booking, list_state_params), alert: "Failed to cancel: #{e.message}"
  end

  def mark_delivered
    @booking.mark_as_delivered!
    redirect_to store_admin_booking_path(@booking, list_state_params), notice: 'Order marked as delivered!'
  end

  def mark_completed
    @booking.mark_as_completed!
    redirect_to store_admin_booking_path(@booking, list_state_params), notice: 'Order marked as completed!'
  end

  def mark_paid
    if @booking.payment_status_paid?
      return redirect_to(store_admin_booking_path(@booking, list_state_params), notice: 'Booking is already marked as paid.')
    end
    @booking.payment_status = :paid
    @booking.save!
    invoice = @booking.invoice_generated? ? Invoice.find_by(invoice_number: @booking.invoice_number) : generate_immediate_invoice_for_booking(@booking)
    notice = invoice ? "Booking marked as paid. Invoice ##{invoice.invoice_number} updated." : 'Booking marked as paid.'
    redirect_to store_admin_booking_path(@booking, list_state_params), notice: notice
  rescue => e
    redirect_to store_admin_booking_path(@booking, list_state_params), alert: "Failed to mark as paid: #{e.message}"
  end

  def update_delivery_charge
    new_charge = params[:shipping_charges].to_s.gsub(/\s+/, '').to_f
    new_charge = 0 if new_charge < 0
    @booking.shipping_charges = new_charge
    @booking.calculate_totals! if @booking.respond_to?(:calculate_totals!)
    sync_booking_invoice_totals(@booking)
    respond_to do |format|
      format.html { redirect_to store_admin_booking_path(@booking), notice: 'Delivery charge updated successfully!' }
      format.json { render json: { success: true, shipping_charges: @booking.shipping_charges, total_amount: @booking.total_amount } }
    end
  rescue => e
    respond_to do |format|
      format.html { redirect_to store_admin_booking_path(@booking), alert: "Failed to update delivery charge: #{e.message}" }
      format.json { render json: { success: false, error: e.message } }
    end
  end

  def stage_transition
    @target_stage = params[:target_stage]
    return redirect_to(store_admin_booking_path(@booking), alert: 'Target stage not specified') if @target_stage.blank?
    unless @booking.next_possible_statuses.include?(@target_stage) || (@booking.respond_to?(:can_return?) && @booking.can_return? && @target_stage == 'returned')
      return redirect_to(store_admin_booking_path(@booking), alert: 'Invalid stage transition')
    end
    @delivery_people = DeliveryPerson.where(status: true).order(:first_name, :last_name) if @target_stage == 'shipped' && defined?(DeliveryPerson)
  end

  def process_stage_transition
    @target_stage = params[:target_stage]
    return redirect_to(store_admin_booking_path(@booking), alert: 'Target stage not specified') if @target_stage.blank?

    update_booking_with_transition(build_transition_data)

    case @target_stage
    when 'confirmed'        then process_confirmed_transition
    when 'processing'       then process_processing_transition
    when 'packed'           then process_packed_transition
    when 'shipped'          then process_shipped_transition
    when 'out_for_delivery' then process_out_for_delivery_transition
    when 'delivered'        then process_delivered_transition
    when 'cancelled'        then process_cancelled_transition
    when 'returned'         then process_returned_transition
    else                        process_general_transition
    end
  end

  def manage_stage
    @list_state = list_state_params
    @available_statuses = Booking.statuses.keys.map { |s| [s.humanize, s] }
    @next_stages = @booking.next_possible_statuses
  end

  def update_stage
    @list_state = list_state_params
    @target_stage = params[:target_stage] || params.dig(:booking, :status)
    if @target_stage.blank?
      return redirect_to(manage_stage_store_admin_booking_path(@booking, list_state: @list_state), alert: 'Please select a target stage.')
    end
    if update_booking_with_stage_transition(build_stage_transition_data)
      redirect_to store_admin_bookings_path(@list_state), notice: "Booking stage updated to #{@target_stage.humanize} successfully."
    else
      redirect_to manage_stage_store_admin_booking_path(@booking, list_state: @list_state),
                  alert: "Failed to update stage: #{@booking.errors.full_messages.join(', ')}"
    end
  rescue => e
    redirect_to manage_stage_store_admin_booking_path(@booking, list_state: @list_state), alert: "Failed to update stage: #{e.message}"
  end

  def realtime_data
    base = store_bookings
    status_counts = base.group(:status).count
    stats = {
      draft: status_counts['draft'].to_i,
      pending: status_counts['ordered_and_delivery_pending'].to_i,
      processing: status_counts.values_at('confirmed', 'processing', 'packed').compact.sum,
      shipped: status_counts.values_at('shipped', 'out_for_delivery').compact.sum,
      delivered: status_counts.values_at('delivered', 'completed').compact.sum,
      issues: status_counts.values_at('cancelled', 'returned').compact.sum,
      total: status_counts.values.sum,
      today_bookings: base.where(created_at: Date.current.all_day).count,
      total_revenue: base.where(status: [:completed, :delivered]).sum(:total_amount),
      last_updated: Time.current.strftime('%I:%M:%S %p')
    }
    recent = base.recent.limit(5).includes(:customer).map do |b|
      { id: b.id, booking_number: b.booking_number,
        customer_name: b.customer&.display_name || b.customer_name,
        status: b.status, status_color: b.try(:status_color), status_icon: b.try(:status_icon),
        total_amount: b.total_amount, created_at: b.created_at.strftime('%d %b %Y %I:%M %p'),
        items_count: b.try(:booking_items_count) || b.booking_items.size }
    end
    render json: { success: true, stats: stats, recent_bookings: recent }
  rescue => e
    render json: { success: false, error: e.message }
  end

  def search_products
    q = params[:q].to_s.strip
    products = Product.active.where('name ILIKE ? OR sku ILIKE ?', "%#{q}%", "%#{q}%").limit(15)
    render json: products.map { |p|
      store_stock = @current_store.available_stock_for(p.id)
      { id: p.id, text: "#{p.name} - #{p.try(:formatted_selling_price) || p.price}", name: p.name, sku: p.sku,
        price: p.price.to_f, store_stock: store_stock.to_f, stock: store_stock.to_f, unit_type: p.unit_type,
        has_variants: p.has_multiple_quantities?,
        variants: p.has_multiple_quantities? ? p.product_variants.order(:display_order, :weight).map { |v|
          { id: v.id, label: "#{v.weight} #{v.unit}", price: v.selling_price.to_f, stock: v.available_stock.to_f }
        } : [] }
    }
  end

  def search_customers
    q = params[:q].to_s
    customers = Customer.where('full_name ILIKE ? OR email ILIKE ? OR mobile ILIKE ?', "%#{q}%", "%#{q}%", "%#{q}%").limit(10)
    render json: customers.map { |c|
      { id: c.id, text: "#{c.display_name} - #{c.mobile}", name: c.display_name, email: c.email, phone: c.mobile, address: c.address }
    }
  end

  private

  def set_booking
    @booking = store_bookings.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to store_admin_bookings_path, alert: 'Booking not found for this store.'
  end

  def render_new_with_errors
    @selected_store = @current_store
    @products = products_for_picker
    @customers = Customer.all.order(:full_name)
    @categories = Category.where(status: true).order(:name)
    render :new, status: :unprocessable_entity
  end

  def apply_named_status_transition(new_status)
    case new_status
    when 'confirmed'        then @booking.mark_as_confirmed!
    when 'processing'       then @booking.mark_as_processing!
    when 'packed'           then @booking.mark_as_packed!
    when 'shipped'          then @booking.mark_as_shipped!(params[:tracking_number])
    when 'out_for_delivery' then @booking.mark_as_out_for_delivery!
    when 'delivered'        then @booking.mark_as_delivered!
    when 'completed'        then @booking.mark_as_completed!
    else                        @booking.update!(status: new_status)
    end
  end

  def list_state_params
    params[:list_state]&.permit(*LIST_STATE_PARAMS)&.to_h || {}
  end

  def calculate_bookings_summary
    base = store_bookings
    {
      total_bookings: base.count,
      pending_bookings: base.where(status: ['draft', 'ordered_and_delivery_pending', 'confirmed']).count,
      processing_bookings: base.where(status: ['processing', 'packed', 'shipped', 'out_for_delivery']).count,
      completed_bookings: base.where(status: ['delivered', 'completed']).count,
      cancelled_bookings: base.where(status: ['cancelled', 'returned']).count,
      today_revenue: base.where(created_at: Date.current.all_day).where.not(status: ['cancelled', 'returned']).sum(:total_amount),
      month_revenue: base.where(created_at: Date.current.all_month).where.not(status: ['cancelled', 'returned']).sum(:total_amount)
    }
  end

  def products_for_picker
    sid = @current_store.id.to_i

    # `cached_stock` must match Store#available_stock_for — the same figure the
    # store-inventory screen and Product Summary show: a store_inventories row
    # (when the store has one for the product) is the source of truth for that
    # store's on-hand; only when there is no row do we fall back to the store's
    # active batch total. The old raw batch sum over-counted whenever
    # store_inventories had been reconciled to a different number.
    batch_sum = "(SELECT COALESCE(SUM(sb.quantity_remaining), 0) FROM stock_batches sb " \
                "WHERE sb.product_id = products.id AND sb.status = 'active' " \
                "AND sb.quantity_remaining > 0 AND sb.store_id = #{sid})"
    inv_sum   = "(SELECT SUM(si.quantity) FROM store_inventories si " \
                "WHERE si.product_id = products.id AND si.store_id = #{sid})"
    effective = "COALESCE(#{inv_sum}, #{batch_sum})"

    Product.active
           .includes(:category, :product_variants, image_attachment: :blob)
           .select("products.*, #{effective} AS cached_stock")
           .order(Arel.sql("CASE WHEN #{effective} > 0 THEN 0 ELSE 1 END ASC, products.name ASC"))
  end

  def sync_booking_invoice_totals(booking)
    booking.booking_invoices.each do |bi|
      bi.update!(subtotal: booking.subtotal, tax_amount: booking.tax_amount,
                 discount_amount: booking.discount_amount, total_amount: booking.total_amount)
    end
  end

  def generate_immediate_invoice_for_booking(booking)
    booking.generate_quick_invoice! if booking.respond_to?(:generate_quick_invoice!)
  end

  def validate_stock_availability(booking, is_update: false)
    active_items = booking.booking_items.reject(&:marked_for_destruction?).select { |i| i.product_id.present? && i.quantity.to_i > 0 }
    return true if active_items.empty?

    products_by_id = Product.where(id: active_items.map(&:product_id).uniq).index_by(&:id)
    variants_by_id = ProductVariant.where(id: active_items.map(&:product_variant_id).compact.uniq).index_by(&:id)
    scope_store_id = booking.store_id || @current_store.id
    stock_errors = []

    active_items.each do |item|
      product = products_by_id[item.product_id]
      next unless product
      if product.has_multiple_quantities? && item.product_variant_id.present?
        available = variants_by_id[item.product_variant_id]&.available_stock.to_f
      else
        # Same overlay as products_for_picker / Store#available_stock_for:
        # store_inventories row wins, batch sum is only the fallback.
        store = Store.find_by(id: scope_store_id)
        available = if store
                      store.available_stock_for(product.id).to_f
                    else
                      StockBatch.available_for_product(product.id, store_id: scope_store_id).sum(:quantity_remaining).to_f
                    end
      end
      available += (item.quantity_was || 0) if is_update && item.persisted? && item.quantity_changed?
      stock_errors << { product: product, requested: item.quantity, available: available, item: item } if item.quantity > available
    end

    return true if stock_errors.empty?

    stock_errors.each do |e|
      booking.errors.add(:base, "#{e[:product].name}: Only #{e[:available]} units available, but #{e[:requested]} requested")
      e[:item].errors.add(:quantity, "only #{e[:available]} units available")
    end
    flash.now[:alert] = "Stock validation failed: #{stock_errors.map { |e| "#{e[:product].name} (Available: #{e[:available]}, Requested: #{e[:requested]})" }.join(', ')}"
    false
  end

  # ---- stage transition data builders (ported verbatim) ------------------

  def build_transition_data
    data = { from_stage: @booking.status, to_stage: @target_stage, timestamp: Time.current,
             user_id: current_user.id, user_name: current_user.try(:full_name) || current_user.email }
    case @target_stage
    when 'shipped'
      data.merge!(courier_service: params[:courier_service], tracking_number: params[:tracking_number],
                  shipping_charges: params[:shipping_charges], expected_delivery_date: params[:expected_delivery_date])
    when 'processing'
      data.merge!(processing_team: params[:processing_team], expected_completion_time: params[:expected_completion_time],
                  estimated_processing_time: params[:estimated_processing_time])
    when 'packed'
      data.merge!(package_weight: params[:package_weight], package_dimensions: params[:package_dimensions], quality_status: params[:quality_status])
    when 'delivered'
      data.merge!(delivery_person: params[:delivery_person], delivery_contact: params[:delivery_contact],
                  delivered_to: params[:delivered_to], delivery_time: params[:delivery_time],
                  customer_satisfaction: params[:customer_satisfaction])
    when 'cancelled'
      data[:cancellation_reason] = params[:cancellation_reason]
    when 'returned'
      data.merge!(return_reason: params[:return_reason], return_condition: params[:return_condition],
                  refund_amount: params[:refund_amount], refund_method: params[:refund_method])
    end
    data[:transition_notes] = params[:transition_notes] if params[:transition_notes].present?
    data
  end

  def update_booking_with_transition(transition_data)
    history = (@booking.stage_history.present? ? JSON.parse(@booking.stage_history) : []) rescue []
    history << transition_data
    attrs = { status: @target_stage, stage_history: history.to_json, stage_updated_at: Time.current,
              stage_updated_by: current_user.id, transition_notes: transition_data[:transition_notes] }
    %i[courier_service tracking_number shipping_charges expected_delivery_date processing_team
       expected_completion_time estimated_processing_time package_weight package_dimensions quality_status
       delivery_person delivery_contact delivered_to delivery_time customer_satisfaction
       cancellation_reason return_reason return_condition refund_amount refund_method].each do |field|
      attrs[field] = params[field] if params[field].present? && @booking.respond_to?("#{field}=")
    end
    @booking.update!(attrs.select { |k, _| @booking.respond_to?("#{k}=") })
  end

  def build_stage_transition_data
    data = { from_stage: @booking.status, to_stage: @target_stage, timestamp: Time.current,
             user_id: current_user.id, user_name: current_user.try(:full_name) || current_user.email }
    case @target_stage
    when 'shipped'
      data.merge!(courier_service: params[:courier_service], tracking_number: params[:tracking_number],
                  shipping_charges: params[:shipping_charges], expected_delivery_date: params[:expected_delivery_date])
    when 'out_for_delivery'
      data.merge!(delivery_person_id: params[:delivery_person_id], delivery_person: params[:delivery_person], delivery_contact: params[:delivery_contact])
    when 'delivered'
      data.merge!(delivery_person: params[:delivery_person], delivery_time: params[:delivery_time], customer_satisfaction: params[:customer_satisfaction])
    when 'cancelled'
      data.merge!(cancellation_reason: params[:cancellation_reason], refund_amount: params[:refund_amount])
    when 'returned'
      data.merge!(return_reason: params[:return_reason], refund_amount: params[:refund_amount])
    end
    data[:notes] = params[:transition_notes] if params[:transition_notes].present?
    data
  end

  def update_booking_with_stage_transition(transition_data)
    @booking.status = @target_stage
    %i[courier_service tracking_number shipping_charges expected_delivery_date delivery_time
       customer_satisfaction delivery_person delivered_to cancellation_reason refund_amount
       return_reason return_condition processing_team estimated_processing_time package_weight
       package_dimensions quality_status delivery_contact delivery_person_id].each do |field|
      val = transition_data[field]
      @booking.public_send("#{field}=", val) if val.present? && @booking.respond_to?("#{field}=")
    end
    history = (@booking.stage_history.present? ? JSON.parse(@booking.stage_history) : []) rescue []
    history << transition_data.stringify_keys
    @booking.stage_history = history.to_json
    @booking.stage_updated_at = Time.current
    @booking.stage_updated_by = current_user.id
    if transition_data[:notes].present? && @booking.respond_to?(:transition_notes)
      @booking.transition_notes = [@booking.transition_notes, transition_data[:notes]].compact.join("\n---\n")
    end
    @booking.save!
  end

  def process_confirmed_transition  = stage_redirect('Booking confirmed successfully!')
  def process_processing_transition = stage_redirect('Booking moved to processing!')
  def process_packed_transition     = stage_redirect('Booking marked as packed!')

  def process_shipped_transition
    if params[:courier_service].blank? || params[:tracking_number].blank?
      return stage_redirect('Courier service and tracking number are required for shipping', alert: true)
    end
    stage_redirect('Booking marked as shipped with tracking details!')
  end

  def process_out_for_delivery_transition
    if params[:delivery_person_id].blank?
      return stage_redirect('Please select a delivery person for out for delivery', alert: true, to: manage_stage_store_admin_booking_path(@booking))
    end
    stage_redirect('Booking marked as out for delivery with delivery person assigned!')
  end

  def process_delivered_transition
    @booking.update!(status: :completed)
    stage_redirect('Booking marked as delivered and completed!')
  end

  def process_cancelled_transition
    return stage_redirect('Cancellation reason is required', alert: true) if params[:cancellation_reason].blank?
    stage_redirect('Booking cancelled successfully!')
  end

  def process_returned_transition
    return stage_redirect('Return reason is required', alert: true) if params[:return_reason].blank?
    stage_redirect('Return processed successfully!')
  end

  def process_general_transition = stage_redirect("Booking updated to #{@target_stage.humanize}!")

  def stage_redirect(message, alert: false, to: nil)
    target = to || store_admin_bookings_path
    respond_to do |format|
      format.html { redirect_to target, (alert ? { alert: message } : { notice: message }) }
      format.json { render json: { success: !alert, message: message, status: @booking.status } }
    end
  end

  def booking_params
    params.require(:booking).permit(
      :customer_id, :customer_name, :customer_email, :customer_phone,
      :payment_method, :payment_status, :discount_amount, :shipping_charges, :notes,
      :delivery_address, :cash_received, :change_amount, :status, :store_id,
      :booking_date, :is_b2b,
      booking_items_attributes: [:id, :product_id, :product_variant_id, :quantity, :price, :discount_type, :discount_value, :_destroy]
    )
  end
end

require 'set'

class StoreAdmin::InvoicesController < StoreAdmin::ApplicationController
  before_action :set_invoice, only: [:show, :edit, :update, :destroy, :mark_as_paid,
                                     :download_pdf, :show_premium, :download_premium_pdf]

  # Invoices generated from bookings placed at the current store.
  def index
    regular_invoices = build_regular_invoices_query.to_a
    booking_lookup = booking_numbers_lookup(regular_invoices)
    @all_invoices = regular_invoices.map { |inv| prepare_invoice_data(inv, 'regular', booking_lookup) }

    if params[:search].present?
      @all_invoices.sort_by! { |inv| [name_match_rank(inv[:customer_name], params[:search]), -(inv[:created_at]&.to_i || 0)] }
    else
      @all_invoices.sort_by! { |inv| inv[:created_at] || Time.at(0) }.reverse!
    end

    limit = params[:limit]&.to_i || 50
    offset = params[:offset]&.to_i || 0
    @invoices = @all_invoices[offset, limit] || []

    @stats = calculate_regular_invoice_stats_only
    @delivery_persons = (DeliveryPerson.active.order(:first_name, :last_name) if defined?(DeliveryPerson)) || []
    @invoice_type = 'regular'
    @booking_numbers = booking_lookup
  end

  def customers
    render json: store_customers.order(:full_name).map { |c| { id: c.id, display_name: c.display_name } }
  end

  def delivery_persons
    list = defined?(DeliveryPerson) ? DeliveryPerson.active.order(:first_name, :last_name) : []
    render json: list.map { |dp| { id: dp.id, display_name: dp.display_name } }
  end

  def customers_by_delivery_person
    dp_id = params[:delivery_person_id]
    ids = dp_id.present? ? @current_store.bookings.where(delivery_person_id: dp_id).distinct.pluck(:customer_id).compact : []
    render json: store_customers.where(id: ids).order(:full_name).map { |c|
      { id: c.id, display_name: c.display_name, email: c.email, mobile: c.mobile }
    }
  end

  def generate
    month = params[:month].to_i
    year  = params[:year].to_i
    customer_ids = Array(params[:customer_ids]) & store_customers.pluck(:id).map(&:to_s)
    customers = params[:customer_selection] == 'all' ? store_customers : store_customers.where(id: customer_ids)

    generated = []
    errors = []
    customers.find_each do |customer|
      begin
        invoice = generate_customer_invoice(customer, month, year)
        generated << invoice if invoice
      rescue => e
        errors << "#{customer.display_name}: #{e.message}"
      end
    end

    if generated.any?
      render json: { success: true, invoices_created: generated.count,
                     message: "Generated #{generated.count} invoices successfully", errors: errors,
                     invoices: generated.map { |inv| { id: inv.id, number: inv.invoice_number, customer: inv.customer&.display_name, amount: inv.total_amount } } }
    else
      render json: { success: false, invoices_created: 0,
                     error: "No invoices could be generated. #{errors.any? ? errors.join(', ') : 'No completed deliveries found for the selected period.'}",
                     errors: errors }
    end
  end
  alias_method :generate_invoice, :generate

  def generate_bulk_invoices
    generate
  end

  def show
    @invoice_items = @invoice.invoice_items.includes(product: :product_variants)
    @booking = related_booking
  end

  def edit
    @invoice_items = @invoice.invoice_items.includes(product: :product_variants)
  end

  def update
    original_quantities = {}
    @invoice.invoice_items.each { |item| original_quantities[item.id] = item.quantity if item.product }

    @invoice.assign_attributes(invoice_params)
    new_total = 0
    (invoice_params[:invoice_items_attributes] || {}).each do |_, attrs|
      next if attrs['_destroy'] == '1'
      new_total += attrs['quantity'].to_f * attrs['unit_price'].to_f
    end
    @invoice.total_amount = new_total + @invoice.delivery_charge.to_f

    if @invoice.save
      update_related_booking_stock(original_quantities)
      redirect_to store_admin_invoice_path(@invoice), notice: 'Invoice was successfully updated.'
    else
      @invoice_items = @invoice.invoice_items.includes(product: :product_variants)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @invoice.destroy
    redirect_to store_admin_invoices_path, notice: 'Invoice was successfully deleted.'
  rescue => e
    redirect_to store_admin_invoice_path(@invoice), alert: "Error deleting invoice: #{e.message}"
  end

  def mark_as_paid
    @invoice.update!(payment_status: :fully_paid, status: :paid, paid_at: Time.current, paid_amount: @invoice.total_amount)
    redirect_to store_admin_invoices_path, notice: 'Invoice marked as paid successfully.'
  rescue => e
    redirect_to store_admin_invoices_path, alert: "Error marking invoice as paid: #{e.message}"
  end

  def download_pdf
    @invoice_items = @invoice&.invoice_items&.includes(:product) || []
    respond_to do |format|
      format.pdf do
        pdf = WickedPdf.new.pdf_from_string(
          render_to_string(template: 'admin/invoices/show', formats: [:html], layout: false),
          page_size: 'A4', margin: { top: '0.5in', bottom: '0.5in', left: '0.5in', right: '0.5in' },
          dpi: 300, encoding: 'UTF-8', disable_smart_shrinking: true, print_media_type: true, orientation: 'Portrait'
        )
        send_data pdf, filename: "invoice-#{@invoice.invoice_number}.pdf", type: 'application/pdf', disposition: 'attachment'
      end
      format.html { redirect_to store_admin_invoice_path(@invoice) }
    end
  end

  def show_premium
    @invoice_items = @invoice.invoice_items.includes(product: :product_variants)
    @booking = related_booking
    render template: 'store_admin/invoices/show_premium', layout: 'application'
  rescue ActionView::MissingTemplate
    redirect_to store_admin_invoice_path(@invoice)
  end

  def download_premium_pdf
    @invoice_items = @invoice&.invoice_items&.includes(:product) || []
    respond_to do |format|
      format.pdf do
        pdf = WickedPdf.new.pdf_from_string(
          render_to_string(template: 'store_admin/invoices/show_premium', formats: [:html], layout: false),
          page_size: 'A4', dpi: 300, encoding: 'UTF-8', print_media_type: true, orientation: 'Portrait'
        )
        send_data pdf, filename: "invoice-#{@invoice.invoice_number}-premium.pdf", type: 'application/pdf', disposition: 'attachment'
      end
      format.html { redirect_to store_admin_invoice_path(@invoice) }
    end
  rescue ActionView::MissingTemplate
    redirect_to store_admin_invoice_path(@invoice), alert: 'Premium invoice template not available.'
  end

  # ---- bulk actions (JSON) -------------------------------------------------

  def bulk_delete_preview
    ids = store_scoped_bulk_ids
    return render(json: { success: false, error: 'No invoices selected' }, status: :bad_request) if ids.empty?
    render json: { success: true, invoice_count: Invoice.where(id: ids).count, item_count: InvoiceItem.where(invoice_id: ids).count }
  end

  def bulk_delete
    ids = store_scoped_bulk_ids
    return render(json: { success: false, error: 'No invoices selected' }, status: :bad_request) if ids.empty?

    deleted_count = Invoice.where(id: ids).count
    deleted_items = InvoiceItem.where(invoice_id: ids).count
    Invoice.transaction do
      InvoiceItem.where(invoice_id: ids).delete_all
      Invoice.where(id: ids).delete_all
    end
    render json: { success: true, deleted_count: deleted_count, deleted_items: deleted_items,
                   message: "Deleted #{deleted_count} invoice(s) and #{deleted_items} line item(s)" }
  rescue => e
    render json: { success: false, error: e.message }, status: :internal_server_error
  end

  def bulk_mark_as_paid
    ids = store_scoped_bulk_ids
    scope = Invoice.where(id: ids).where.not(payment_status: 'fully_paid')
    return render(json: { success: false, error: 'No unpaid invoices found to update' }, status: :bad_request) if scope.empty?

    updated = 0
    Invoice.transaction do
      scope.find_each do |invoice|
        invoice.update!(payment_status: :fully_paid, status: :paid, paid_at: Time.current)
        updated += 1
      end
    end
    render json: { success: true, updated_count: updated, message: "Successfully marked #{updated} invoice(s) as paid" }
  rescue => e
    render json: { success: false, error: "Error marking invoices as paid: #{e.message}" }, status: :internal_server_error
  end

  def partial_payment
    invoice = store_invoices.find_by(id: params[:invoice_id])
    amount = params[:amount].to_f
    return render(json: { success: false, error: 'Invalid invoice ID or amount' }, status: :bad_request) if invoice.nil? || amount <= 0

    new_paid = (invoice.paid_amount || 0) + amount
    return render(json: { success: false, error: 'Payment amount exceeds remaining invoice amount' }, status: :bad_request) if new_paid > invoice.total_amount

    Invoice.transaction do
      if invoice.total_amount - new_paid <= 0
        invoice.update!(paid_amount: invoice.total_amount, payment_status: :fully_paid, status: :paid, paid_at: Time.current)
      else
        invoice.update!(paid_amount: new_paid, payment_status: :partially_paid)
      end
      if params[:notes].present?
        note = "Payment of ₹#{amount} on #{Time.current.strftime('%Y-%m-%d %H:%M')} - #{params[:notes]}"
        invoice.update!(notes: [invoice.notes.presence, note].compact.join("\n"))
      end
    end
    render json: { success: true,
                   message: invoice.payment_status_fully_paid? ? 'Invoice marked as fully paid' : 'Partial payment processed successfully',
                   invoice: { id: invoice.id, paid_amount: invoice.paid_amount,
                              remaining_amount: invoice.total_amount - invoice.paid_amount, payment_status: invoice.payment_status } }
  rescue => e
    render json: { success: false, error: "Error processing partial payment: #{e.message}" }, status: :internal_server_error
  end

  private

  def set_invoice
    @invoice = store_invoices.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to store_admin_invoices_path, alert: 'Invoice not found for this store.'
  end

  def store_scoped_bulk_ids
    ids = params[:invoice_ids]
    ids = ids.values if ids.respond_to?(:values) && !ids.is_a?(Array)
    wanted = Array(ids).map { |id| id.to_s.strip }.reject(&:blank?).map(&:to_i).uniq
    wanted & store_invoices.pluck(:id)
  end

  def related_booking
    return nil if @invoice.invoice_number.blank?
    @current_store.bookings.find_by(invoice_number: @invoice.invoice_number)
  end

  def build_regular_invoices_query
    apply_search_filters(store_invoices.includes(:customer))
  end

  def booking_numbers_lookup(invoices)
    numbers = invoices.select { |i| i.respond_to?(:quick_invoice?) ? i.quick_invoice? : true }.map(&:invoice_number).compact
    return {} if numbers.empty?
    Booking.where(invoice_number: numbers).pluck(:invoice_number, :booking_number).to_h
  end

  def apply_search_filters(base_query)
    if params[:search].present?
      term = "%#{params[:search]}%"
      base_query = base_query.left_joins(:customer)
                             .where('invoices.invoice_number ILIKE ? OR customers.full_name ILIKE ? OR customers.email ILIKE ? OR customers.mobile ILIKE ?',
                                    term, term, term, term)
    end
    base_query = base_query.where(payment_status: params[:status]) if params[:status].present? && params[:status] != 'all'
    base_query = base_query.where('invoices.invoice_date >= ?', Date.parse(params[:date_from])) if params[:date_from].present?
    base_query = base_query.where('invoices.invoice_date <= ?', Date.parse(params[:date_to])) if params[:date_to].present?
    base_query.order(created_at: :desc).limit(200)
  end

  def name_match_rank(customer_name, search)
    name = customer_name.to_s.downcase
    term = search.to_s.strip.downcase
    return 3 if term.blank?
    return 0 if name.start_with?(term)
    return 1 if name.split(/\s+/).any? { |w| w.start_with?(term) }
    return 2 if name.include?(term)
    3
  end

  def prepare_invoice_data(invoice, type, booking_lookup = {})
    actual_type = (type == 'regular' && invoice.try(:quick_invoice?)) ? 'booking' : type
    {
      id: invoice.id, invoice_number: invoice.invoice_number,
      customer_name: invoice.customer&.display_name || invoice.try(:customer_display_name) || 'N/A',
      customer_mobile: invoice.customer&.mobile || invoice.try(:customer_mobile),
      total_amount: invoice.total_amount, paid_amount: invoice.paid_amount || 0,
      payment_status: invoice.payment_status, status: invoice.status,
      invoice_date: invoice.invoice_date || invoice.created_at&.to_date,
      created_at: invoice.created_at, type: actual_type, model_object: invoice,
      booking_number: (booking_lookup[invoice.invoice_number] if actual_type == 'booking')
    }
  end

  def calculate_regular_invoice_stats_only
    query = apply_search_filters_for_stats(store_invoices.includes(:customer))
    counts = query.group(:payment_status).count
    amounts = query.group(:payment_status).sum(:total_amount)
    {
      total_invoices: counts.values.sum,
      total_amount: amounts.values.sum,
      paid_amount: amounts['fully_paid'] || 0,
      pending_amount: amounts.values_at('unpaid', 'partially_paid').compact.sum,
      paid_count: counts['fully_paid'] || 0,
      pending_count: counts.values_at('unpaid', 'partially_paid').compact.sum
    }
  end

  def apply_search_filters_for_stats(base_query)
    if params[:search].present?
      term = "%#{params[:search]}%"
      base_query = base_query.left_joins(:customer)
                             .where('invoices.invoice_number ILIKE ? OR customers.full_name ILIKE ? OR customers.email ILIKE ? OR customers.mobile ILIKE ?',
                                    term, term, term, term)
    end
    base_query = base_query.where(payment_status: params[:status]) if params[:status].present? && params[:status] != 'all'
    base_query = base_query.where('invoices.invoice_date >= ?', Date.parse(params[:date_from])) if params[:date_from].present?
    base_query = base_query.where('invoices.invoice_date <= ?', Date.parse(params[:date_to])) if params[:date_to].present?
    base_query
  end

  def update_related_booking_stock(original_quantities)
    booking = @current_store.bookings.find_by(invoice_number: @invoice.invoice_number)
    return unless booking

    processed = Set.new
    @invoice.invoice_items.each do |invoice_item|
      next unless invoice_item.product
      next if processed.include?(invoice_item.product_id)
      booking_item = booking.booking_items.find_by(product_id: invoice_item.product_id)
      next unless booking_item
      diff = invoice_item.quantity - (original_quantities[invoice_item.id] || 0)
      next if diff.zero?
      new_qty = booking_item.quantity + diff
      new_qty > 0 ? booking_item.update!(quantity: new_qty) : booking_item.destroy!
      processed.add(invoice_item.product_id)
    end

    (invoice_params[:invoice_items_attributes] || {}).each do |_, attrs|
      next unless attrs['_destroy'] == '1' && attrs['id'].present? && attrs['product_id'].present?
      booking.booking_items.find_by(product_id: attrs['product_id'])&.destroy!
    end

    booking.reload
    booking.update!(total_amount: booking.booking_items.sum { |i| i.quantity * i.price })
  end

  # Store-scoped port of Admin::InvoicesController#generate_customer_invoice —
  # bills this customer's completed, uninvoiced bookings for the month.
  def generate_customer_invoice(customer, month, year)
    start_date = Date.new(year, month).beginning_of_month
    end_date   = Date.new(year, month).end_of_month

    existing = Invoice.where(customer: customer).where(invoice_date: start_date..end_date).first
    return existing if existing

    items = []
    unpaid_bookings = @current_store.bookings.where(customer_id: customer.id)
                                   .where(booking_date: start_date..end_date)
                                   .where(status: ['completed', 'delivered'])
                                   .where(payment_status: [nil, '', 'unpaid'])
                                   .where(invoice_generated: [false, nil])

    unpaid_bookings.each do |booking|
      booking.booking_items.includes(:product).each do |item|
        product = item.product
        next unless product
        unit_price = if product.gst_enabled? && product.gst_percentage.present?
                       product.try(:calculate_base_price) || item.price
                     else
                       item.price || product.selling_price
                     end
        if booking.discount_amount.to_f > 0 && booking.total_amount.to_f > 0
          unit_price *= (1 - booking.discount_amount.to_f / booking.total_amount.to_f)
        end
        items << { product: product, quantity: item.quantity, unit_price: unit_price,
                   description: "#{product.name} - Booking ##{booking.booking_number} (#{booking.booking_date&.strftime('%d %b %Y')})",
                   booking: booking }
      end
    end

    return nil if items.empty?

    invoice = Invoice.new(customer: customer, invoice_date: end_date, due_date: end_date + 30.days,
                          status: :draft, payment_status: :unpaid)
    total = 0
    items.each do |d|
      line_total = d[:quantity] * d[:unit_price]
      invoice.invoice_items.build(description: d[:description], quantity: d[:quantity],
                                  unit_price: d[:unit_price], total_amount: line_total, product: d[:product])
      total += line_total
    end
    invoice.total_amount = total

    if invoice.save
      invoiced = Set.new
      items.each do |d|
        next unless d[:booking] && !invoiced.include?(d[:booking].id)
        d[:booking].update!(invoice_generated: true, invoice_number: invoice.invoice_number)
        invoiced.add(d[:booking].id)
      end
      invoice
    else
      raise invoice.errors.full_messages.join(', ')
    end
  end

  def invoice_params
    params.require(:invoice).permit(
      :invoice_date, :due_date, :status, :payment_status, :total_amount, :delivery_charge,
      invoice_items_attributes: [:id, :product_id, :description, :quantity, :unit_price, :total_amount,
                                 :discount_type, :discount_value, :original_unit_price, :_destroy]
    )
  end
end

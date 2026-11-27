# Admin app — bookings. Same model logic as /admin/bookings.
class Api::V1::App::BookingsController < Api::V1::App::BaseController
  before_action :require_admin!
  before_action :set_booking, except: [:index, :create, :payment_reminders]

  # GET /bookings?q=&status=&payment_status=&customer_id=&delivery_person_id=&date_from=&date_to=&page=&per_page=
  def index
    scope = Booking.where.not(status: 'draft').includes(:customer, :delivery_person, :store)
    if params[:q].present?
      q = "%#{Booking.sanitize_sql_like(params[:q].strip)}%"
      scope = scope.where('bookings.booking_number ILIKE :q OR bookings.customer_name ILIKE :q OR bookings.customer_phone ILIKE :q ' \
                          'OR bookings.customer_id IN (SELECT id FROM customers WHERE full_name ILIKE :q OR mobile ILIKE :q)', q: q)
    end
    scope = scope.where(status: Booking.status_filter_values(params[:status])) if params[:status].present?
    scope = scope.where(payment_status: params[:payment_status]) if params[:payment_status].present?
    scope = scope.where(customer_id: params[:customer_id]) if params[:customer_id].present?
    scope = scope.where(delivery_person_id: params[:delivery_person_id]) if params[:delivery_person_id].present?
    scope = scope.where('COALESCE(bookings.booking_date, bookings.created_at) >= ?', Date.parse(params[:date_from]).beginning_of_day) if params[:date_from].present?
    scope = scope.where('COALESCE(bookings.booking_date, bookings.created_at) <= ?', Date.parse(params[:date_to]).end_of_day) if params[:date_to].present?
    scope = scope.where(expected_delivery_date: Date.parse(params[:delivery_date])) if params[:delivery_date].present?

    rows, meta = paginate(scope.order(Arel.sql('COALESCE(bookings.booking_date, bookings.created_at) DESC, bookings.id DESC')))
    preload_invoices(rows)
    render_success(rows.map { |b| booking_json(b) }, meta: meta)
  rescue Date::Error
    render_error('Invalid date, use YYYY-MM-DD')
  end

  # GET /bookings/:id
  def show
    render_success(booking_json(@booking, full: true))
  end

  # POST /bookings
  # { "booking": { "customer_id": 1, "delivery_address": "...", "payment_status": "unpaid",
  #   "items": [{ "product_id": 5, "product_variant_id": null, "quantity": 2, "price": 120 }] } }
  def create
    bp = params.require(:booking)
    items = Array(bp[:items])
    return render_error('Add at least one item') if items.empty?

    customer = Customer.find(bp[:customer_id]) if bp[:customer_id].present?
    booking = Booking.new(
      customer: customer,
      customer_name: bp[:customer_name].presence || customer&.display_name,
      customer_phone: bp[:customer_phone].presence || customer&.mobile,
      customer_email: bp[:customer_email].presence || (customer&.email unless customer&.email.to_s.end_with?('.invalid')),
      delivery_address: bp[:delivery_address].presence || customer&.try(:shipping_address).presence || customer&.address,
      store_id: bp[:store_id].presence,
      notes: bp[:notes],
      discount_amount: [bp[:discount_amount].to_f, 0].max,
      shipping_charges: [bp[:shipping_charges].to_f, 0].max,
      expected_delivery_date: bp[:expected_delivery_date].presence,
      expected_delivery_time: bp[:expected_delivery_time].presence,
      delivery_person_id: bp[:delivery_person_id].presence,
      is_b2b: ActiveModel::Type::Boolean.new.cast(bp[:is_b2b]) || customer&.try(:is_b2b) || false,
      gstin: bp[:gstin].presence || (customer&.gst_no if customer&.try(:is_b2b)),
      payment_method: bp[:payment_method].presence || 'cash',
      booking_date: bp[:booking_date].presence || Time.current,
      status: Booking::DEFAULT_STATUS,
      user_id: current_admin.id,
      booked_by: bp[:store_id].present? ? 'store' : 'mobile_api'
    )

    items.each do |it|
      product = Product.find(it[:product_id])
      variant = product.product_variants.find(it[:product_variant_id]) if it[:product_variant_id].present?
      booking.booking_items.build(
        product: product, product_variant: variant, quantity: it[:quantity],
        price: it[:price].presence || default_price(product, variant, booking.is_b2b),
        discount_type: it[:discount_type].presence, discount_value: it[:discount_value].presence
      )
    end

    ActiveRecord::Base.transaction do
      booking.save!
      booking.calculate_totals
      booking.payment_status = bp[:payment_status].to_s == 'paid' ? :paid : :unpaid
      booking.paid_via = bp[:paid_via] if booking.payment_status_paid? && Booking::PAID_VIA_OPTIONS.key?(bp[:paid_via].to_s)
      booking.save!
    end

    invoice_note = nil
    begin
      inv = booking.generate_quick_invoice!
      invoice_note = "Invoice ##{inv.invoice_number} generated" if inv
    rescue => e
      Rails.logger.error "App API: invoice generation failed for booking ##{booking.id}: #{e.message}"
      invoice_note = 'Invoice generation failed'
    end

    render_success(booking_json(booking.reload, full: true),
                   message: ["Booking ##{booking.booking_number} created", invoice_note].compact.join('. '), status: :created)
  rescue ActiveRecord::RecordInvalid => e
    render_error(booking_errors(e.record).to_sentence, :unprocessable_entity, booking_errors(e.record))
  end

  # PATCH /bookings/:id  — notes, address, discount, delivery charge, items
  # (items: [{id, quantity, price, _destroy}] edits lines; lines without id are added)
  def update
    bp = params.require(:booking)
    attrs = bp.permit(:notes, :delivery_address, :customer_name, :customer_phone, :gstin, :is_b2b).to_h
    attrs[:discount_amount] = [bp[:discount_amount].to_f, 0].max if bp.key?(:discount_amount)
    attrs[:shipping_charges] = [bp[:shipping_charges].to_f, 0].max if bp.key?(:shipping_charges)
    @booking.assign_attributes(attrs)

    Array(bp[:items]).each do |it|
      if it[:id].present?
        # Edit the loaded association record so @booking.save! saves it.
        line = @booking.booking_items.detect { |i| i.id == it[:id].to_i } ||
               raise(ActiveRecord::RecordNotFound.new("Booking item #{it[:id]} not found", 'BookingItem'))
        if ActiveModel::Type::Boolean.new.cast(it[:_destroy])
          line.mark_for_destruction
        else
          line.quantity = it[:quantity] if it[:quantity].present?
          line.price = it[:price] if it[:price].present?
          line.discount_type = it[:discount_type] if it.key?(:discount_type)
          line.discount_value = it[:discount_value] if it.key?(:discount_value)
        end
      else
        product = Product.find(it[:product_id])
        variant = product.product_variants.find(it[:product_variant_id]) if it[:product_variant_id].present?
        @booking.booking_items.build(product: product, product_variant: variant, quantity: it[:quantity],
                                     price: it[:price].presence || default_price(product, variant, @booking.is_b2b))
      end
    end

    @booking.save!
    @booking.calculate_totals!
    sync_invoice_totals(@booking)
    render_success(booking_json(@booking.reload, full: true), message: 'Booking updated')
  rescue ActiveRecord::RecordInvalid => e
    render_error(booking_errors(e.record).to_sentence, :unprocessable_entity, booking_errors(e.record))
  end

  # PATCH /bookings/:id/status { status: "delivered", tracking_number: "" , reason: "" }
  def update_status
    new_status = params[:status].to_s
    unless Booking::STATUS_LABELS.key?(new_status)
      return render_error("Invalid status. Allowed: #{Booking::STATUS_LABELS.keys.join(', ')}", :unprocessable_entity)
    end

    case new_status
    when 'delivered' then @booking.mark_as_delivered!
    when 'shipped' then @booking.mark_as_shipped!(params[:tracking_number])
    when 'packed' then @booking.mark_as_packed!
    when 'cancelled' then @booking.cancel_order!(params[:reason]) || @booking.update!(status: :cancelled)
    else @booking.update!(status: new_status)
    end
    render_success(booking_json(@booking.reload), message: "Status updated to #{Booking.status_label(@booking.status)}")
  end

  # POST /bookings/:id/mark_paid { paid_via: "cash" | "upi" | "bank" }
  def mark_paid
    return render_error('Booking is already paid') if @booking.payment_status_paid?

    paid_via = params[:paid_via].to_s
    return render_error('paid_via must be one of cash, upi, bank') if paid_via.present? && !Booking::PAID_VIA_OPTIONS.key?(paid_via)

    @booking.paid_via = paid_via.presence
    @booking.payment_status = :paid
    @booking.save!
    inv = booking_invoice(@booking) || @booking.generate_quick_invoice!
    @booking_invoice_cache = nil
    render_success(booking_json(@booking.reload, full: true),
                   message: "Booking marked as paid#{inv ? ". Invoice ##{inv.invoice_number} updated" : ''}")
  end

  # POST /bookings/:id/partial_payment { amount: 500, notes: "" }
  def partial_payment
    amount = params[:amount].to_f
    return render_error('Please enter a valid payment amount') if amount <= 0

    invoice = booking_invoice(@booking) || @booking.generate_quick_invoice!
    return render_error('Could not find or generate an invoice for this booking', :unprocessable_entity) unless invoice

    remaining = invoice.record_payment!(amount, notes: params[:notes])
    @booking_invoice_cache = nil
    render_success(booking_json(@booking.reload, full: true).merge(remaining_amount: money(remaining)),
                   message: remaining <= 0 ? 'Booking marked as fully paid' : 'Partial payment recorded')
  rescue ArgumentError => e
    render_error(e.message)
  end

  # PATCH /bookings/:id/delivery { expected_delivery_date: "2026-11-30", expected_delivery_time: "14:30", delivery_person_id: 3 }
  def update_delivery
    attrs = {}
    if params.key?(:expected_delivery_date)
      date = params[:expected_delivery_date].presence && Date.iso8601(params[:expected_delivery_date])
      attrs[:expected_delivery_date] = date
      attrs[:expected_delivery_time] = nil unless date
    end
    if params[:expected_delivery_time].present?
      return render_error('Time must be HH:MM (24h)') unless params[:expected_delivery_time].match?(/\A([01]\d|2[0-3]):[0-5]\d\z/)

      attrs[:expected_delivery_time] = params[:expected_delivery_time]
    end
    if params.key?(:delivery_person_id)
      dp = params[:delivery_person_id].presence && DeliveryPerson.find(params[:delivery_person_id])
      attrs[:delivery_person_id] = dp&.id
    end
    @booking.update_columns(attrs.merge(updated_at: Time.current)) if attrs.any?
    render_success(booking_json(@booking.reload), message: 'Delivery details updated')
  rescue Date::Error
    render_error('Invalid date, use YYYY-MM-DD')
  end

  # GET /bookings/:id/whatsapp — ready-to-open wa.me links + message texts
  def whatsapp
    @booking.ensure_share_token!
    public_url = "#{base_url}/booking/#{@booking.share_token}"
    inv = booking_invoice(@booking)
    render_success({
      phone: @booking.customer&.mobile.presence || @booking.customer_phone,
      links: booking_whatsapp_links(@booking, public_url),
      messages: {
        send_invoice: booking_send_invoice_message(@booking, public_url),
        payment_thank_you: booking_payment_thanks_message(@booking, invoice: inv),
        payment_reminder: (@booking.payment_status_paid? ? nil : payment_reminder_message(@booking))
      }
    })
  end

  # GET /payment_reminders?min_days=0&q=&page=
  # Unpaid / partially-paid bookings (delayed payments), oldest first, with the
  # amount due, days since booking / past due date and a WhatsApp reminder link.
  def payment_reminders
    min_days = params[:min_days].to_i
    due_days = SystemSetting.invoice_due_days.to_i
    scope = Booking.where.not(status: %w[draft cancelled returned refund])
                   .where(payment_status: %w[unpaid partially_paid])
                   .where('COALESCE(bookings.booking_date, bookings.created_at) <= ?', min_days.days.ago.end_of_day)
                   .includes(:customer)
    if params[:q].present?
      q = "%#{Booking.sanitize_sql_like(params[:q].strip)}%"
      scope = scope.where('bookings.booking_number ILIKE :q OR bookings.customer_name ILIKE :q OR bookings.customer_phone ILIKE :q', q: q)
    end
    rows, meta = paginate(scope.order(Arel.sql('COALESCE(bookings.booking_date, bookings.created_at) ASC')))
    preload_invoices(rows)
    today = Date.current
    data = rows.map do |b|
      date = (b.booking_date || b.created_at).to_date
      due_on = date + due_days
      b.ensure_share_token!
      booking_json(b).merge(days_since_booking: (today - date).to_i, due_date: due_on.iso8601,
                            days_overdue: [(today - due_on).to_i, 0].max,
                            reminder_message: payment_reminder_message(b),
                            whatsapp_reminder_url: wa_link(b.customer&.mobile.presence || b.customer_phone, payment_reminder_message(b)))
    end
    total_due = scope.sum(:total_amount).to_f -
                Invoice.where(invoice_number: scope.where.not(invoice_number: nil).select(:invoice_number)).sum(:paid_amount).to_f
    render_success(data, meta: meta.merge(total_due: money(total_due), invoice_due_days: due_days))
  end

  private

  def set_booking
    @booking = Booking.includes(:customer, :delivery_person, :store, booking_items: [:product, :product_variant]).find(params[:id])
  end

  def default_price(product, variant, b2b)
    if variant
      (b2b && variant.b2b_price.to_f.positive? ? variant.b2b_price : variant.selling_price).to_f
    else
      (b2b && product.b2b_price.to_f.positive? ? product.b2b_price : product.price).to_f
    end
  end

  def booking_errors(record)
    msgs = record.errors.full_messages
    if record.respond_to?(:booking_items)
      record.booking_items.each do |i|
        i.errors.full_messages.each { |m| msgs << "#{i.product&.name}: #{m}" }
      end
    end
    msgs.reject { |m| m.start_with?('Booking items') }.uniq
  end

  def preload_invoices(rows)
    numbers = rows.map(&:invoice_number).compact
    by_number = numbers.any? ? Invoice.where(invoice_number: numbers).index_by(&:invoice_number) : {}
    @booking_invoice_cache = rows.to_h { |b| [b.id, by_number[b.invoice_number]] }
  end

  # Same as Admin::BookingsController#sync_booking_invoice_totals.
  # (The Invoice's own line items/total follow via Booking#sync_invoice_items_from_booking.)
  def sync_invoice_totals(booking)
    booking.booking_invoices.each do |bi|
      bi.update!(subtotal: booking.subtotal, tax_amount: booking.tax_amount,
                 discount_amount: booking.discount_amount, total_amount: booking.total_amount)
    end
  rescue => e
    Rails.logger.error "App API: invoice total sync failed for booking ##{booking.id}: #{e.message}"
  end
end

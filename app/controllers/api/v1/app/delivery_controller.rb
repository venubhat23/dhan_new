# Delivery app — a logged-in delivery person sees and updates ONLY the
# bookings assigned to them (bookings.delivery_person_id), plus a route map.
class Api::V1::App::DeliveryController < Api::V1::App::BaseController
  before_action :require_delivery_person!
  before_action :set_booking, only: [:show, :update_status, :collect_payment]

  OPEN = %w[ordered_and_delivery_pending packed shipped rescheduled reconfirm_order shop_pickup].freeze
  # Statuses a delivery person may set.
  ALLOWED = %w[shipped delivered rescheduled].freeze

  # GET /delivery/bookings?scope=today|pending|delivered|all&date=YYYY-MM-DD
  def index
    scope = my_bookings.includes(:customer, :store)
    case params[:scope].presence || 'pending'
    when 'today' then scope = scope.where(status: OPEN).where(expected_delivery_date: [Date.current, nil])
    when 'pending' then scope = scope.where(status: OPEN)
    when 'delivered' then scope = scope.where(status: 'delivered')
    end
    scope = scope.where(expected_delivery_date: Date.iso8601(params[:date])) if params[:date].present?
    rows, meta = paginate(scope.order(Arel.sql('expected_delivery_date NULLS LAST, expected_delivery_time NULLS LAST, bookings.id')))
    render_success(rows.map { |b| booking_json(b).merge(location: location_json(b)) }, meta: meta)
  rescue Date::Error
    render_error('Invalid date, use YYYY-MM-DD')
  end

  # GET /delivery/bookings/:id
  def show
    render_success(booking_json(@booking, full: true))
  end

  # PATCH /delivery/bookings/:id/status { "status": "delivered" | "shipped" | "rescheduled", "note": "" }
  def update_status
    status = params[:status].to_s
    return render_error("Status must be one of #{ALLOWED.join(', ')}", :unprocessable_entity) unless ALLOWED.include?(status)

    note = "#{Booking.status_label(status)} by #{current_delivery_person.display_name}" \
           "#{params[:note].present? ? " — #{params[:note]}" : ''} at #{Time.current.strftime('%d/%m/%Y %I:%M %p')}"
    case status
    when 'delivered' then @booking.mark_as_delivered!
    when 'shipped' then @booking.mark_as_shipped!
    else @booking.update!(status: status)
    end
    @booking.update_columns(notes: [@booking.reload.notes.presence, note].compact.join("\n"), delivered_to: params[:delivered_to].presence || @booking.delivered_to)
    render_success(booking_json(@booking.reload), message: "Marked #{Booking.status_label(@booking.status)}")
  end

  # POST /delivery/bookings/:id/collect_payment { "amount": 500, "paid_via": "cash" }
  # Full amount (or no amount) → marks paid; less → partial payment on the invoice.
  def collect_payment
    return render_error('Booking is already paid') if @booking.payment_status_paid?

    invoice = booking_invoice(@booking) || @booking.generate_quick_invoice!
    due = invoice ? invoice.total_amount.to_f - invoice.paid_amount.to_f : @booking.total_amount.to_f
    amount = params[:amount].present? ? params[:amount].to_f : due
    return render_error('Please enter a valid amount') if amount <= 0
    return render_error("Amount is more than the balance due (#{money(due)})") if amount > due + 0.01

    if amount >= due - 0.01
      @booking.paid_via = params[:paid_via] if Booking::PAID_VIA_OPTIONS.key?(params[:paid_via].to_s)
      @booking.payment_status = :paid
      @booking.save!
    else
      invoice.record_payment!(amount, notes: "Collected by #{current_delivery_person.display_name} (#{params[:paid_via].presence || 'cash'})")
    end
    @booking_invoice_cache = nil
    render_success(booking_json(@booking.reload), message: 'Payment recorded')
  end

  # GET /delivery/route?date=YYYY-MM-DD&origin_lat=&origin_lng=
  # Today's (or the given day's) open stops in delivery-time order, each with a
  # map link, plus one Google Maps directions URL covering every stop.
  def route
    date = params[:date].present? ? Date.iso8601(params[:date]) : Date.current
    bookings = my_bookings.includes(:customer).where(status: OPEN)
                          .where('expected_delivery_date = ? OR expected_delivery_date IS NULL', date)
                          .order(Arel.sql('expected_delivery_time NULLS LAST, bookings.id')).to_a
    stops = bookings.each_with_index.map do |b, i|
      { stop: i + 1, booking_id: b.id, booking_number: b.booking_number,
        customer_name: b.customer_name.presence || b.customer&.display_name,
        customer_phone: b.customer_phone.presence || b.customer&.mobile,
        expected_delivery_time: b.expected_delivery_time, due_amount: money(b.total_amount.to_f - booking_paid_amount(b)),
        status: b.status, status_label: Booking.status_label(b.status) }.merge(location_json(b))
    end
    points = stops.map { |s| s[:latitude] && s[:longitude] ? "#{s[:latitude]},#{s[:longitude]}" : s[:address] }.compact_blank
    directions = nil
    if points.any?
      dest = points.last
      waypoints = points[0...-1].first(9) # Google Maps URLs accept up to 9 waypoints
      directions = 'https://www.google.com/maps/dir/?api=1&travelmode=driving' \
                   "&destination=#{ERB::Util.url_encode(dest)}"
      directions += "&origin=#{params[:origin_lat]},#{params[:origin_lng]}" if params[:origin_lat].present? && params[:origin_lng].present?
      directions += "&waypoints=#{ERB::Util.url_encode(waypoints.join('|'))}" if waypoints.any?
    end
    render_success({ date: date.iso8601, total_stops: stops.size, directions_url: directions, stops: stops })
  rescue Date::Error
    render_error('Invalid date, use YYYY-MM-DD')
  end

  private

  def my_bookings
    Booking.where(delivery_person_id: current_delivery_person.id).where.not(status: 'draft')
  end

  def set_booking
    @booking = my_bookings.includes(:customer, booking_items: [:product, :product_variant]).find(params[:id])
  end
end

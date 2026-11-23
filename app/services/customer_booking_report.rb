# Customer booking / delivery report: every booking in a period with its
# items, quantities, customer and delivery address, filterable by status,
# customer, delivery person, store, product, payment status and address.
#
# The period can be applied on the booking date or on the expected delivery
# date (delivery-run view). Amounts are booking_items.total (GST-inclusive,
# after per-line discount); booking totals are bookings.total_amount.
class CustomerBookingReport
  BOOKING_DATE = 'COALESCE(bookings.booking_date, bookings.created_at)'.freeze
  DATE_BASES = { 'booking' => 'Booking Date', 'delivery' => 'Expected Delivery Date' }.freeze
  VIEWS = { 'bookings' => 'Bookings', 'items' => 'Booking Items', 'customers' => 'Customer Summary', 'products' => 'Product Quantity' }.freeze

  attr_reader :filters

  # filters: from_date, to_date, date_basis, statuses[], customer, customer_id,
  #          delivery_person_id, store_id, product_id, payment_status, address
  def initialize(**filters)
    @filters = filters
  end

  # ---- scopes --------------------------------------------------------------

  def bookings_scope
    @bookings_scope ||= begin
      s = Booking.where.not(status: 'draft')
      s = apply_dates(s)
      s = s.where(status: statuses) if statuses.any?
      s = s.where(customer_id: filters[:customer_id]) if filters[:customer_id].present?
      if filters[:customer].present?
        q = "%#{Booking.sanitize_sql_like(filters[:customer].to_s.strip)}%"
        s = s.left_joins(:customer).where(
          'bookings.customer_name ILIKE :q OR bookings.customer_phone ILIKE :q OR customers.full_name ILIKE :q OR customers.mobile ILIKE :q', q: q
        )
      end
      s = s.where(delivery_person_id: filters[:delivery_person_id]) if filters[:delivery_person_id].present?
      s = s.where(store_id: filters[:store_id]) if filters[:store_id].present?
      s = s.where(payment_status: filters[:payment_status]) if filters[:payment_status].present?
      if filters[:address].present?
        q = "%#{Booking.sanitize_sql_like(filters[:address].to_s.strip)}%"
        s = s.where('bookings.delivery_address ILIKE ?', q)
      end
      if filters[:product_id].present?
        s = s.where(id: BookingItem.where(product_id: filters[:product_id]).select(:booking_id))
      end
      s
    end
  end

  def items_scope
    s = BookingItem.joins(:booking).where(booking_id: bookings_scope.reorder(nil).select(:id))
    s = s.where(product_id: filters[:product_id]) if filters[:product_id].present?
    s
  end

  # Bookings for display, newest first, with everything the rows need.
  def bookings
    bookings_scope.includes(:customer, :store, :delivery_person, booking_items: [:product, :product_variant])
                  .order(Arel.sql(order_sql))
  end

  def items
    items_scope.includes(:product, :product_variant, booking: [:customer, :store, :delivery_person])
               .order(Arel.sql("#{order_sql}, booking_items.id"))
  end

  # ---- aggregates ----------------------------------------------------------

  def totals
    @totals ||= begin
      ids = bookings_scope.reorder(nil).select(:id)
      base = Booking.where(id: ids)
      qty, lines = BookingItem.where(booking_id: ids).pick(Arel.sql('COALESCE(SUM(quantity),0)'), Arel.sql('COUNT(*)'))
      {
        bookings: base.count,
        amount: base.sum(:total_amount).to_f.round(2),
        qty: qty.to_f,
        lines: lines.to_i,
        customers: base.distinct.count(Arel.sql("COALESCE(customer_id::text, customer_phone, customer_name)")),
        delivered: base.where(status: 'delivered').count,
        pending: base.where(status: %w[ordered_and_delivery_pending packed shipped rescheduled reconfirm_order]).count
      }
    end
  end

  # { 'delivered' => 12, ... } for the status chips — counts ignore the
  # status filter itself so every chip shows what clicking it would give.
  def status_counts
    @status_counts ||= self.class.new(**filters.merge(statuses: [])).bookings_scope
                           .reorder(nil).group(:status).count
  end

  # Per-customer roll-up.
  def customer_rows
    ids = bookings_scope.reorder(nil).select(:id)
    qty_by_booking = BookingItem.where(booking_id: ids).group(:booking_id).sum(:quantity)
    rows = {}
    Booking.where(id: ids).includes(:customer).order(Arel.sql(BOOKING_DATE)).each do |b|
      k = b.customer_id ? "c#{b.customer_id}" : "#{b.customer_phone}|#{b.customer_name}"
      r = rows[k] ||= { customer_id: b.customer_id, name: customer_name(b), phone: customer_phone(b), address: address_for(b),
                        bookings: 0, qty: 0.0, amount: 0.0, delivered: 0, pending: 0, last_date: nil, statuses: Hash.new(0) }
      r[:bookings] += 1
      r[:qty] += qty_by_booking[b.id].to_f
      r[:amount] += b.total_amount.to_f
      r[:delivered] += 1 if b.status == 'delivered'
      r[:statuses][b.status] += 1
      r[:address] = address_for(b).presence || r[:address]
      r[:last_date] = booking_date(b)
    end
    rows.values.sort_by { |r| [-r[:amount], r[:name].to_s] }
  end

  # Product-wise quantity to deliver (useful for packing a delivery run).
  def product_qty_rows
    items_scope.joins(:product).left_joins(:product_variant)
               .group('products.id', 'products.name', 'product_variants.id', 'product_variants.weight', 'product_variants.unit', 'products.unit_type')
               .order(Arel.sql('SUM(booking_items.quantity) DESC'))
               .pluck(Arel.sql('products.name'), Arel.sql('product_variants.weight'), Arel.sql('product_variants.unit'),
                      Arel.sql('products.unit_type'), Arel.sql('SUM(booking_items.quantity)'), Arel.sql('SUM(booking_items.total)'),
                      Arel.sql('COUNT(DISTINCT booking_items.booking_id)'))
               .map do |name, w, u, ut, q, t, n|
                 pack = w ? "#{w.to_f.to_s.sub(/\.0$/, '')} #{u}" : nil
                 { name: name, pack: pack, unit: ut, qty: q.to_f, amount: t.to_f.round(2), bookings: n.to_i }
               end
  end

  # ---- row helpers ---------------------------------------------------------

  def self.item_label(item)
    name = item.product&.name || 'Product'
    item.product_variant ? "#{name} (#{item.product_variant.label})" : name
  end

  def customer_name(b) = b.customer_name.presence || b.customer&.display_name || 'Walk-in'
  def customer_phone(b) = b.customer_phone.presence || b.customer&.mobile
  def booking_date(b) = b.booking_date || b.created_at

  def address_for(b)
    b.delivery_address.presence || b.customer&.shipping_address.presence || b.customer&.address.presence
  end

  def delivery_person_name(b) = b.delivery_person&.display_name || b.read_attribute(:delivery_person).presence

  private

  def statuses = Array(filters[:statuses]).reject(&:blank?).map { |s| Booking.normalize_status(s) }.uniq

  def delivery_basis? = filters[:date_basis] == 'delivery'

  def order_sql
    delivery_basis? ? 'bookings.expected_delivery_date DESC NULLS LAST, bookings.id DESC' : "#{BOOKING_DATE} DESC, bookings.id DESC"
  end

  def apply_dates(scope)
    from, to = filters[:from_date], filters[:to_date]
    return scope unless from && to

    if delivery_basis?
      scope.where(expected_delivery_date: from..to)
    else
      scope.where("#{BOOKING_DATE} BETWEEN ? AND ?", from.beginning_of_day, to.end_of_day)
    end
  end
end

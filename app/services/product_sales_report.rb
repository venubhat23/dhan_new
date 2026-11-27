# Product-wise sales from booking lines: a ranked list of every product sold
# in a period, and a drill-down for one product (pack sizes, trend, top
# customers, every order line).
#
# Amounts are booking_items.total — what the customer was charged for the line
# (GST-inclusive, after the per-line discount). Cancelled / returned / refund
# bookings and drafts are left out, same as the Profit & Loss report. Returns
# booked through Credit Notes in the period are shown alongside.
class ProductSalesReport
  EXCLUDED_STATUSES = %w[cancelled returned refund draft].freeze
  SORTS = {
    'qty' => 'Quantity Sold', 'revenue' => 'Revenue', 'orders' => 'Orders', 'customers' => 'Customers'
  }.freeze
  SALE_DATE = 'COALESCE(bookings.booking_date, bookings.created_at)'.freeze

  attr_reader :from_date, :to_date, :store_id, :status

  def initialize(from_date:, to_date:, store_id: nil, status: nil)
    @from_date = from_date
    @to_date = to_date
    @store_id = store_id.presence
    @status = status.presence && Booking.normalize_status(status).to_s
    @status = nil unless self.class.status_options.any? { |_, v| v == @status }
  end

  # Delivery statuses that can appear in this report (excluded ones never do).
  def self.status_options
    Booking.status_options.reject { |_, v| EXCLUDED_STATUSES.include?(v) }
  end

  # ---- ranking -------------------------------------------------------------

  # [{ product_id:, name:, category:, unit:, qty:, revenue:, orders:, customers:,
  #    last_sold:, avg_price:, share:, returned_qty:, returned_amount:, rank: }]
  def rows(sort: 'qty', search: nil)
    rows = ranking_rows.dup
    if search.present?
      q = search.downcase
      rows = rows.select { |r| r[:name].to_s.downcase.include?(q) || r[:sku].to_s.downcase.include?(q) }
    end
    key = SORTS.key?(sort) ? sort.to_sym : :qty
    rows.sort_by { |r| [-r[key].to_f, -r[:revenue].to_f, r[:name].to_s] }
  end

  def totals
    @totals ||= {
      products: ranking_rows.size,
      qty: ranking_rows.sum { |r| r[:qty] }.round(2),
      revenue: ranking_rows.sum { |r| r[:revenue] }.round(2),
      orders: line_scope.distinct.count('bookings.id'),
      returned_amount: ranking_rows.sum { |r| r[:returned_amount] }.round(2)
    }
  end

  # ---- one product ---------------------------------------------------------

  def product_summary(product_id)
    scope = line_scope.where(product_id: product_id)
    row = scope.pick(Arel.sql('COALESCE(SUM(booking_items.quantity),0)'), Arel.sql('COALESCE(SUM(booking_items.total),0)'),
                     Arel.sql('COUNT(DISTINCT bookings.id)'), Arel.sql("COUNT(DISTINCT COALESCE(bookings.customer_id::text, bookings.customer_phone, bookings.customer_name))"),
                     Arel.sql("MIN(#{SALE_DATE})"), Arel.sql("MAX(#{SALE_DATE})"))
    qty, revenue, orders, customers, first, last = row
    ret = returns_by_product[product_id.to_i] || {}
    rank = rows(sort: 'qty').index { |r| r[:product_id] == product_id.to_i }
    {
      qty: qty.to_f, revenue: revenue.to_f.round(2), orders: orders.to_i, customers: customers.to_i,
      avg_price: qty.to_f.positive? ? (revenue.to_f / qty.to_f).round(2) : 0.0,
      first_sold: first, last_sold: last,
      returned_qty: ret[:qty].to_f, returned_amount: ret[:amount].to_f,
      net_revenue: (revenue.to_f - ret[:amount].to_f).round(2),
      share: totals[:revenue].positive? ? (revenue.to_f * 100 / totals[:revenue]).round(1) : 0.0,
      rank: rank ? rank + 1 : nil, ranked_of: ranking_rows.size
    }
  end

  # Sales per pack size (variant); nil variant = the plain product.
  def variant_rows(product_id)
    data = line_scope.where(product_id: product_id).group(:product_variant_id)
                     .pluck(:product_variant_id, Arel.sql('SUM(booking_items.quantity)'), Arel.sql('SUM(booking_items.total)'),
                            Arel.sql('COUNT(DISTINCT bookings.id)'))
    variants = ProductVariant.where(id: data.map(&:first).compact).index_by(&:id)
    total = data.sum { |d| d[2].to_f }
    data.map do |vid, qty, rev, orders|
      { label: vid ? (variants[vid]&.label || "Variant ##{vid}") : 'Standard', qty: qty.to_f, revenue: rev.to_f.round(2),
        orders: orders.to_i, share: total.positive? ? (rev.to_f * 100 / total).round(1) : 0.0 }
    end.sort_by { |r| -r[:revenue] }
  end

  # Daily points for ranges up to ~3 months, monthly beyond that.
  def trend(product_id)
    monthly = (to_date - from_date).to_i > 92
    unit = monthly ? 'month' : 'day'
    data = line_scope.where(product_id: product_id)
                     .group(Arel.sql("DATE_TRUNC('#{unit}', #{SALE_DATE})::date"))
                     .pluck(Arel.sql("DATE_TRUNC('#{unit}', #{SALE_DATE})::date"),
                            Arel.sql('SUM(booking_items.quantity)'), Arel.sql('SUM(booking_items.total)'))
                     .to_h { |d, q, r| [d, [q.to_f, r.to_f.round(2)]] }
    points = []
    cursor = monthly ? from_date.beginning_of_month : from_date
    while cursor <= to_date
      q, r = data[cursor] || [0.0, 0.0]
      points << { label: cursor.strftime(monthly ? '%b %Y' : '%d %b'), qty: q, revenue: r }
      cursor = monthly ? cursor.next_month : cursor + 1
    end
    points
  end

  def top_customers(product_id, limit: 10)
    line_scope.where(product_id: product_id)
              .group(Arel.sql("COALESCE(bookings.customer_name, 'Walk-in')"), 'bookings.customer_phone')
              .order(Arel.sql('SUM(booking_items.total) DESC'))
              .limit(limit)
              .pluck(Arel.sql("COALESCE(bookings.customer_name, 'Walk-in')"), 'bookings.customer_phone',
                     Arel.sql('SUM(booking_items.quantity)'), Arel.sql('SUM(booking_items.total)'), Arel.sql('COUNT(DISTINCT bookings.id)'))
              .map { |n, ph, q, r, o| { name: n, phone: ph, qty: q.to_f, revenue: r.to_f.round(2), orders: o.to_i } }
  end

  def order_lines(product_id, limit: nil)
    scope = line_scope.where(product_id: product_id).includes(:product_variant, booking: :store)
                      .order(Arel.sql("#{SALE_DATE} DESC"), 'bookings.id DESC')
    scope = scope.limit(limit) if limit
    scope.map do |bi|
      b = bi.booking
      { booking: b, date: b.booking_date || b.created_at, number: b.booking_number, customer: b.customer_name.presence || 'Walk-in',
        phone: b.customer_phone, store: b.store&.name, variant: bi.product_variant&.label, qty: bi.quantity.to_f,
        unit_price: bi.price.to_f, discount: bi.discount_amount.to_f, total: bi.total.to_f, status: b.status_label }
    end
  end

  # Products that sold in the period, for the picker (name, id), best sellers first.
  def product_options
    rows(sort: 'qty').map { |r| ["#{r[:name]} — #{fmt_qty(r[:qty])} sold", r[:product_id]] }
  end

  private

  def line_scope
    scope = BookingItem.joins(:booking)
                       .where.not(bookings: { status: EXCLUDED_STATUSES })
                       .where("#{SALE_DATE} BETWEEN ? AND ?", from_date.beginning_of_day, to_date.end_of_day)
    scope = scope.where(bookings: { store_id: store_id }) if store_id
    scope = scope.where(bookings: { status: status }) if status
    scope
  end

  def ranking_rows
    @ranking_rows ||= begin
      data = line_scope.group(:product_id).pluck(
        :product_id, Arel.sql('SUM(booking_items.quantity)'), Arel.sql('SUM(booking_items.total)'),
        Arel.sql('COUNT(DISTINCT bookings.id)'),
        Arel.sql("COUNT(DISTINCT COALESCE(bookings.customer_id::text, bookings.customer_phone, bookings.customer_name))"),
        Arel.sql("MAX(#{SALE_DATE})")
      )
      products = Product.where(id: data.map(&:first)).includes(:category).index_by(&:id)
      grand = data.sum { |d| d[2].to_f }
      data.filter_map do |pid, qty, rev, orders, customers, last|
        p = products[pid]
        next unless p

        ret = returns_by_product[pid] || {}
        { product_id: pid, name: p.name, sku: p.try(:sku), category: p.category&.name, unit: p.unit_type,
          statuses: status_qty_by_product[pid] || [],
          qty: qty.to_f, revenue: rev.to_f.round(2), orders: orders.to_i, customers: customers.to_i, last_sold: last,
          avg_price: qty.to_f.positive? ? (rev.to_f / qty.to_f).round(2) : 0.0,
          share: grand.positive? ? (rev.to_f * 100 / grand).round(1) : 0.0,
          returned_qty: ret[:qty].to_f, returned_amount: ret[:amount].to_f.round(2) }
      end
    end
  end

  # { product_id => [[status_label, qty], ...] } in the standard status order.
  def status_qty_by_product
    @status_qty_by_product ||= begin
      order = Booking::STATUS_LABELS.keys
      line_scope.group(:product_id, 'bookings.status')
                .pluck(:product_id, 'bookings.status', Arel.sql('SUM(booking_items.quantity)'))
                .group_by(&:first)
                .transform_values do |list|
                  list.sort_by { |_, st, _| order.index(st) || order.size }
                      .map { |_, st, q| [Booking.status_label(st), q.to_f] }
                end
    end
  end

  # Credit-note returns in the period, by product.
  def returns_by_product
    @returns_by_product ||= begin
      return {} unless ActiveRecord::Base.connection.data_source_exists?('credit_notes')

      scope = CreditNoteItem.joins(:credit_note).where(credit_notes: { credit_date: from_date..to_date })
      scope = scope.where(credit_notes: { store_id: store_id }) if store_id
      scope.group(:product_id).pluck(:product_id, Arel.sql('SUM(credit_note_items.quantity)'), Arel.sql('SUM(credit_note_items.amount)'))
           .to_h { |pid, q, a| [pid, { qty: q.to_f, amount: a.to_f }] }
    end
  end

  def fmt_qty(q) = q.to_f == q.to_i ? q.to_i : q.round(2)
end

class Admin::StoreAnalyticsController < Admin::ApplicationController
  before_action :authenticate_user!

  def comparison
    @stores = Store.all.order(:name)
    @month = params[:month].present? ? Date.parse(params[:month]) : Date.current.beginning_of_month

    @store_data = @stores.map do |store|
      period = @month.beginning_of_month..@month.end_of_month
      bookings = store.bookings.where(created_at: period)
      expenses = store.expenses.by_date_range(@month.beginning_of_month, @month.end_of_month)
      stock_value = store.stock_batches.where(status: 'active').where('quantity_remaining > 0')
                         .sum('quantity_remaining * purchase_price')

      revenue      = bookings.sum(:total_amount).to_f
      expense_sum  = expenses.sum(:amount).to_f

      {
        store: store,
        revenue: revenue,
        bookings_count: bookings.count,
        expenses_total: expense_sum,
        stock_value: stock_value.to_f,
        net: revenue - expense_sum
      }
    end

    @totals = {
      revenue:        @store_data.sum { |d| d[:revenue] },
      bookings_count: @store_data.sum { |d| d[:bookings_count] },
      expenses_total: @store_data.sum { |d| d[:expenses_total] },
      stock_value:    @store_data.sum { |d| d[:stock_value] },
      net:            @store_data.sum { |d| d[:net] }
    }
  end

  def top_products
    @stores = Store.all.order(:name)
    @selected_store_id = params[:store_id].presence
    @month = params[:month].present? ? Date.parse(params[:month]) : Date.current.beginning_of_month
    period = @month.beginning_of_month..@month.end_of_month

    booking_scope = Booking.where(created_at: period)
    booking_scope = booking_scope.where(store_id: @selected_store_id) if @selected_store_id.present?

    booking_ids = booking_scope.pluck(:id)

    @top_products = SaleItem
      .where(booking_id: booking_ids)
      .joins(:product)
      .group('products.id', 'products.name')
      .select(
        'products.id   AS product_id',
        'products.name AS product_name',
        'SUM(sale_items.quantity)   AS total_qty',
        'SUM(sale_items.line_total) AS total_revenue',
        'SUM(sale_items.profit_amount) AS total_profit'
      )
      .order('total_qty DESC')
      .limit(20)
  end

  def peak_hours
    @stores = Store.all.order(:name)
    @selected_store_id = params[:store_id].presence

    scope = Booking.where(created_at: 3.months.ago..Time.current)
    scope = scope.where(store_id: @selected_store_id) if @selected_store_id.present?

    raw = scope
      .select(
        "EXTRACT(DOW FROM created_at AT TIME ZONE 'Asia/Kolkata')::INTEGER AS day_num",
        "EXTRACT(HOUR FROM created_at AT TIME ZONE 'Asia/Kolkata')::INTEGER AS hour_num",
        'COUNT(*) AS cnt'
      )
      .group('day_num', 'hour_num')
      .map { |r| { day: r.day_num.to_i, hour: r.hour_num.to_i, count: r.cnt.to_i } }

    @heatmap = Array.new(7) { Array.new(24, 0) }
    @max_count = 1
    raw.each do |r|
      @heatmap[r[:day]][r[:hour]] = r[:count]
      @max_count = [@max_count, r[:count]].max
    end

    @day_labels  = %w[Sun Mon Tue Wed Thu Fri Sat]
    @hour_labels = (0..23).map { |h| format('%02d:00', h) }
  end
end

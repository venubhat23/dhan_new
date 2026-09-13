class StoreAdmin::DashboardController < StoreAdmin::ApplicationController
  def index
    # One GROUP BY replaces the two separate all-time status .count calls the
    # view used to run (Pending / Completed metric cards).
    status_counts = store_bookings.group(:status).count

    @inventory_summary = {
      total_products: 0,
      total_stock_value: 0,
      low_stock_count: 0,
      pending_incoming_transfers: 0,
      pending_outgoing_transfers: 0,
      recent_bookings_count: store_bookings.where(created_at: 1.week.ago..Time.current).count,
      pending_bookings_count: status_counts.values_at('draft', 'ordered_and_delivery_pending', 'confirmed').compact.sum,
      completed_bookings_count: status_counts.values_at('delivered', 'completed').compact.sum
    }
    @recent_bookings = store_bookings.order(created_at: :desc).limit(5).includes(:customer, booking_items: :product)
    @daily_sales = calculate_daily_sales_trend
  end

  private

  # One GROUP BY for sums and one for counts instead of 2 queries per day
  # (16 round trips for the 8-day window this used to run).
  def calculate_daily_sales_trend
    start_date = 7.days.ago.to_date
    end_date = Date.current

    scope = store_bookings
              .where(created_at: start_date.beginning_of_day..end_date.end_of_day)
              .where.not(status: ['cancelled', 'returned'])

    normalize_keys = ->(hash) { hash.transform_keys { |k| k.is_a?(String) ? Date.parse(k) : k } }
    sales_by_date = normalize_keys.call(scope.group("DATE(created_at)").sum(:total_amount))
    counts_by_date = normalize_keys.call(scope.group("DATE(created_at)").count)

    (start_date..end_date).map do |date|
      {
        date: date.strftime('%m/%d'),
        sales: sales_by_date[date] || 0,
        bookings_count: counts_by_date[date] || 0
      }
    end
  end
end

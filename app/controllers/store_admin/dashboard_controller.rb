class StoreAdmin::DashboardController < StoreAdmin::ApplicationController
  def index
    @inventory_summary = {
      total_products: 0,
      total_stock_value: 0,
      low_stock_count: 0,
      pending_incoming_transfers: 0,
      pending_outgoing_transfers: 0,
      recent_bookings_count: @current_store.bookings.where(created_at: 1.week.ago..Time.current).count
    }
    @recent_bookings = @current_store.bookings.order(created_at: :desc).limit(5).includes(:customer, booking_items: :product)
    @daily_sales = calculate_daily_sales_trend
  end

  private

  def calculate_daily_sales_trend
    start_date = 7.days.ago.to_date
    end_date = Date.current
    (start_date..end_date).map do |date|
      {
        date: date.strftime('%m/%d'),
        sales: @current_store.bookings
                             .where(created_at: date.beginning_of_day..date.end_of_day)
                             .where.not(status: ['cancelled', 'returned'])
                             .sum(:total_amount),
        bookings_count: @current_store.bookings
                                      .where(created_at: date.beginning_of_day..date.end_of_day)
                                      .where.not(status: ['cancelled', 'returned'])
                                      .count
      }
    end
  end
end

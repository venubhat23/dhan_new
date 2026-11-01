class Franchise::DashboardController < Franchise::BaseController
  def index
    # Get bookings for the current franchise
    # Since bookings are associated with franchises, not users directly
    @bookings = current_franchise.bookings.includes(:customer, :booking_items)

    # Analytics data
    @total_bookings = @bookings.count
    @draft_bookings = @bookings.draft.count
    @pending_bookings = @bookings.ordered_and_delivery_pending.count
    @confirmed_bookings = @bookings.confirmed.count
    @processing_bookings = @bookings.where(status: [:processing, :packed]).count
    @shipped_bookings = @bookings.where(status: [:shipped, :shop_pickup, :out_for_delivery]).count
    @delivered_bookings = @bookings.where(status: [:delivered, :completed]).count
    @cancelled_bookings = @bookings.where(status: [:cancelled, :returned]).count

    # Revenue analytics
    @total_revenue = @bookings.where(status: [:delivered, :completed]).sum(:total_amount) || 0
    @pending_revenue = @bookings.where.not(status: [:cancelled, :returned]).sum(:total_amount) || 0
    @this_month_revenue = @bookings.where(
      status: [:delivered, :completed],
      created_at: Date.current.beginning_of_month..Date.current.end_of_month
    ).sum(:total_amount) || 0

    # Today's statistics
    @today_bookings = @bookings.where(created_at: Date.current.all_day).count
    @today_revenue = @bookings.where(
      status: [:delivered, :completed],
      created_at: Date.current.all_day
    ).sum(:total_amount) || 0

    # Recent bookings
    @recent_bookings = @bookings.recent.limit(5)

    # Average order value
    completed_bookings = @bookings.where(status: [:delivered, :completed])
    @average_order_value = completed_bookings.any? ?
      (completed_bookings.sum(:total_amount) / completed_bookings.count) : 0
  end
end
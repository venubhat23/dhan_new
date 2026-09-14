class Customer::DashboardController < Customer::BaseController
  def index
    # Categories for the category cards section
    @categories = Category.where(status: true).order(:display_order, :name).limit(8)

    # Featured products for showcase - prioritize products with images and good stock
    @featured_products = Product.includes(:category)
                                .where(status: 'active')
                                .where('stock > 0')
                                .order(created_at: :desc)
                                .limit(4)

    # Popular products - could be based on sales or manually marked as popular
    @popular_products = Product.includes(:category)
                               .where(status: 'active')
                               .where('stock > 0')
                               .order(:stock)
                               .limit(4)

    # Customer's cart count for the action cards (using pending booking items as cart)
    pending_booking = current_customer&.bookings&.where(status: 'pending')&.first
    @cart_items_count = pending_booking&.booking_items&.sum(:quantity) || 0

    # Customer's recent orders count
    @recent_orders_count = current_customer&.bookings&.where('created_at > ?', 30.days.ago)&.count || 0

    # Customer's active subscriptions count
    @active_subscriptions_count = current_customer&.milk_subscriptions&.where(is_active: true)&.count || 0

    # Customer's recent bookings for reference
    @recent_bookings = current_customer&.bookings&.order(created_at: :desc)&.limit(3) || []

    # Active subscriptions for reference
    @active_subscriptions = current_customer&.milk_subscriptions&.where(is_active: true)&.limit(3) || []

    # Chart data for Order Activity (Last 7 days)
    @order_activity_data = build_order_activity_data

    # Chart data for Monthly Spending (This year)
    @monthly_spending_data = build_monthly_spending_data

    # Dashboard Banners - Show only once per login session
    # For debugging - clear session if needed
    if params[:clear_banner_session] == 'true'
      session[:dashboard_banners_shown] = nil
      Rails.logger.debug "🎯 Banner Debug: Session cleared"
    end

    @dashboard_banners = fetch_dashboard_banners_for_session

    # Additional debug - force show banner for testing
    if params[:force_banner] == 'true'
      @dashboard_banners = Banner.where(status: true, display_location: 'dashboard')
      Rails.logger.debug "🎯 FORCE Banner Debug: Found #{@dashboard_banners.count} banners (ignoring session and dates)"
    end
  end

  private

  def fetch_dashboard_banners_for_session
    Rails.logger.debug "🎯 Banner Debug: Session shown status: #{session[:dashboard_banners_shown]}"

    # For debugging - temporarily disable session check
    # return [] if session[:dashboard_banners_shown]

    # Fetch active, current, dashboard banners
    banners = Banner.where(status: true, display_location: 'dashboard')
                    .where('display_start_date <= ? AND display_end_date >= ?', Date.current, Date.current)
                    .order(:display_order)

    Rails.logger.debug "🎯 Banner Debug: Found #{banners.count} banners"
    banners.each do |banner|
      Rails.logger.debug "🎯 Banner: ID=#{banner.id}, Title='#{banner.title}', Status=#{banner.status}, Location=#{banner.display_location}"
      Rails.logger.debug "🎯 Banner Dates: Start=#{banner.display_start_date}, End=#{banner.display_end_date}, Current=#{Date.current}"
      Rails.logger.debug "🎯 Banner Image: R2=#{banner.r2_image_url.present?}, Cloudinary=#{banner.image_url.present?}, Local=#{banner.banner_image.attached?}"
    end

    # If banners exist, mark them as shown for this session (disabled for debugging)
    if banners.any?
      # session[:dashboard_banners_shown] = true
      Rails.logger.debug "🎯 Banner Debug: Returning #{banners.count} banners to view"
      banners
    else
      Rails.logger.debug "🎯 Banner Debug: No banners found"
      []
    end
  end

  def build_order_activity_data
    # Get order counts for last 7 days — one grouped query instead of 8
    # separate per-day COUNTs.
    dates = 7.downto(0).map { |days_ago| Date.current - days_ago.days }
    labels = dates.map { |date| date.strftime('%a') }

    counts_by_date = {}
    if current_customer
      counts_by_date = current_customer.bookings
                                       .where(booking_date: dates.first.beginning_of_day..dates.last.end_of_day)
                                       .group("DATE(booking_date)").count
                                       .transform_keys { |k| k.is_a?(String) ? Date.parse(k) : k }
    end
    order_data = dates.map { |date| counts_by_date[date].to_i }

    # If no data exists, provide sample data with message
    if order_data.sum == 0
      {
        labels: labels,
        data: [0, 0, 0, 0, 0, 0, 0],
        has_data: false,
        message: 'No orders in the last 7 days'
      }
    else
      {
        labels: labels,
        data: order_data,
        has_data: true,
        message: nil
      }
    end
  end

  def build_monthly_spending_data
    # Get spending data for current year by month — one grouped query
    # instead of 12 separate per-month SUMs.
    current_year = Date.current.year
    labels = (1..12).map { |month| Date::MONTHNAMES[month][0, 3] }

    sums_by_month = {}
    if current_customer
      sums_by_month = current_customer.bookings
                                      .where(booking_date: Date.new(current_year, 1, 1).beginning_of_day..Date.new(current_year, 12, 31).end_of_day)
                                      .where.not(total_amount: nil)
                                      .group("EXTRACT(MONTH FROM booking_date)").sum(:total_amount)
                                      .transform_keys(&:to_i)
    end
    spending_data = (1..12).map { |month| sums_by_month[month].to_f }

    # If no data exists, provide sample data with message
    if spending_data.sum == 0
      {
        labels: labels,
        data: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        has_data: false,
        message: 'No spending data for this year'
      }
    else
      {
        labels: labels,
        data: spending_data,
        has_data: true,
        message: nil
      }
    end
  end
end
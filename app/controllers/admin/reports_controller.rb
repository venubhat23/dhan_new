class Admin::ReportsController < Admin::ApplicationController

  # Explicitly skip CanCan for this controller
  skip_authorization_check if respond_to?(:skip_authorization_check)
  skip_load_and_authorize_resource if respond_to?(:skip_load_and_authorize_resource)

  # GET /admin/reports/commission
  def commission
    @date_range = params[:date_range] || '30_days'

    case @date_range
    when '7_days'
      start_date = 7.days.ago
    when '30_days'
      start_date = 30.days.ago
    when '3_months'
      start_date = 3.months.ago
    when '6_months'
      start_date = 6.months.ago
    when '1_year'
      start_date = 1.year.ago
    else
      start_date = 30.days.ago
    end

    # Commission calculations would go here
    # This is a placeholder implementation
    @total_commission = Policy.where(created_at: start_date..Time.current).sum(:total_premium) * 0.1 rescue 0
    @commission_by_agent = User.where(user_type: ['agent', 'sub_agent'])
                               .joins(:policies)
                               .where(policies: { created_at: start_date..Time.current })
                               .group('users.first_name', 'users.last_name')
                               .sum('policies.total_premium * 0.1') rescue {}
  end

  # GET /admin/reports/expired_insurance
  def expired_insurance
    @expired_health_insurances = HealthInsurance.expired.includes(:customer).order(:policy_end_date)
    @expired_life_insurances = LifeInsurance.expired.includes(:customer).order(:policy_end_date)
    @expired_motor_insurances = MotorInsurance.expired.includes(policy: :customer).order(:policy_end_date)
    @expired_other_insurances = OtherInsurance.expired.includes(policy: :customer).order(:policy_end_date)

    @stats = {
      total_expired: @expired_health_insurances.count + @expired_life_insurances.count +
                    @expired_motor_insurances.count + @expired_other_insurances.count,
      health_expired: @expired_health_insurances.count,
      life_expired: @expired_life_insurances.count,
      motor_expired: @expired_motor_insurances.count,
      other_expired: @expired_other_insurances.count
    }
  rescue => e
    Rails.logger.error "Error in expired_insurance: #{e.message}"
    @expired_health_insurances = HealthInsurance.none
    @expired_life_insurances = LifeInsurance.none
    @expired_motor_insurances = MotorInsurance.none
    @expired_other_insurances = OtherInsurance.none
    @stats = {
      total_expired: 0,
      health_expired: 0,
      life_expired: 0,
      motor_expired: 0,
      other_expired: 0
    }
  end

  # GET /admin/reports/payment_due
  def payment_due
    # Logic for payment due reports
    @payment_due_policies = Policy.active
                                  .where('end_date > ? AND end_date <= ?', Date.current, 30.days.from_now)
                                  .includes(:customer)
                                  .order(:end_date) rescue []
  end

  # GET /admin/reports/upcoming_renewal
  def upcoming_renewal
    # Define renewal period (next 60 days)
    start_date = Date.current
    end_date = 60.days.from_now

    @renewal_health_insurances = HealthInsurance.where(policy_end_date: start_date..end_date)
                                               .includes(:customer)
                                               .order(:policy_end_date)

    @renewal_life_insurances = LifeInsurance.where(policy_end_date: start_date..end_date)
                                           .includes(:customer)
                                           .order(:policy_end_date)

    @renewal_motor_insurances = MotorInsurance.where(policy_end_date: start_date..end_date)
                                             .includes(policy: :customer)
                                             .order(:policy_end_date)

    @renewal_other_insurances = OtherInsurance.where(policy_end_date: start_date..end_date)
                                             .includes(policy: :customer)
                                             .order(:policy_end_date)

    @stats = {
      total_renewals: @renewal_health_insurances.count + @renewal_life_insurances.count +
                     @renewal_motor_insurances.count + @renewal_other_insurances.count,
      health_renewals: @renewal_health_insurances.count,
      life_renewals: @renewal_life_insurances.count,
      motor_renewals: @renewal_motor_insurances.count,
      other_renewals: @renewal_other_insurances.count
    }
  rescue => e
    Rails.logger.error "Error in upcoming_renewal: #{e.message}"
    @renewal_health_insurances = HealthInsurance.none
    @renewal_life_insurances = LifeInsurance.none
    @renewal_motor_insurances = MotorInsurance.none
    @renewal_other_insurances = OtherInsurance.none
    @stats = {
      total_renewals: 0,
      health_renewals: 0,
      life_renewals: 0,
      motor_renewals: 0,
      other_renewals: 0
    }
  end

  # GET /admin/reports/upcoming_payment
  def upcoming_payment
    @upcoming_payments = Policy.active
                               .where('end_date BETWEEN ? AND ?', Date.current, 30.days.from_now)
                               .includes(:customer)
                               .order(:end_date) rescue []
  end

  # GET /admin/reports/leads
  def leads
    @date_range = params[:date_range] || '30_days'

    case @date_range
    when '7_days'
      start_date = 7.days.ago
    when '30_days'
      start_date = 30.days.ago
    when '3_months'
      start_date = 3.months.ago
    when '6_months'
      start_date = 6.months.ago
    when '1_year'
      start_date = 1.year.ago
    else
      start_date = 30.days.ago
    end

    @leads_data = {
      total_leads: Lead.where(created_date: start_date..Time.current).count,
      conversion_rate: 0
    }

    if Lead.column_names.include?('current_stage')
      @leads_by_stage = Lead.where(created_date: start_date..Time.current)
                           .group(:current_stage)
                           .count
    else
      @leads_by_stage = {}
    end
  rescue
    @leads_data = { total_leads: 0, conversion_rate: 0 }
    @leads_by_stage = {}
  end

  # GET /admin/reports/sessions
  def sessions
    @date_range = params[:date_range] || 'today'

    # Calculate date range
    case @date_range
    when 'today'
      start_date = Date.current.beginning_of_day
      end_date = Date.current.end_of_day
    when '7_days'
      start_date = 7.days.ago.beginning_of_day
      end_date = Date.current.end_of_day
    when '30_days'
      start_date = 30.days.ago.beginning_of_day
      end_date = Date.current.end_of_day
    when '3_months'
      start_date = 3.months.ago.beginning_of_day
      end_date = Date.current.end_of_day
    else
      start_date = Date.current.beginning_of_day
      end_date = Date.current.end_of_day
    end

    # Session analytics
    @active_users = User.where(status: true).count
    @total_sessions = User.where(created_at: start_date..end_date).count
    @avg_session_time = "24m" # Placeholder for actual session tracking
    @failed_logins = 0 # Placeholder for failed login tracking

    # Sample recent sessions data
    @recent_sessions = User.where(status: true)
                          .limit(20)
                          .order(created_at: :desc)
                          .map.with_index do |user, index|
      {
        id: user.id,
        user_id: user.id,
        user_name: "#{user.first_name} #{user.last_name}".strip,
        email: user.email,
        user_type: user.user_type || 'user',
        login_time: user.created_at + rand(0..72).hours,
        last_activity: case rand(5)
                      when 0 then "Just now"
                      when 1 then "#{rand(1..10)} minutes ago"
                      when 2 then "#{rand(1..2)} hours ago"
                      else "#{rand(1..5)} hours ago"
                      end,
        duration: "#{rand(5..120)}m",
        ip_address: "192.168.1.#{rand(100..200)}",
        status: rand(10) < 7 ? 'active' : 'inactive'
      }
    end
  end

  # GET /admin/reports/products
  def products
    @date_range = params[:date_range] || '30_days'

    case @date_range
    when '7_days'
      start_date = 7.days.ago
    when '30_days'
      start_date = 30.days.ago
    when '3_months'
      start_date = 3.months.ago
    when '6_months'
      start_date = 6.months.ago
    when '1_year'
      start_date = 1.year.ago
    else
      start_date = 30.days.ago
    end

    if defined?(Product)
      @total_products = Product.count
      @active_products = Product.where(status: 'active').count rescue Product.count
      @out_of_stock = Product.where('stock <= ?', 0).count rescue 0
      @low_stock = Product.where('stock > 0 AND stock <= ?', 10).count rescue 0

      @top_products = Product.joins(:order_items)
                             .where(order_items: { created_at: start_date..Time.current })
                             .group('products.id', 'products.name')
                             .order('COUNT(order_items.id) DESC')
                             .limit(10)
                             .pluck('products.name', 'COUNT(order_items.id)') rescue []
    else
      @total_products = 0
      @active_products = 0
      @out_of_stock = 0
      @low_stock = 0
      @top_products = []
    end
  end

  # GET /admin/reports/customers
  def customers
    @date_range = params[:date_range] || '30_days'

    case @date_range
    when '7_days'
      start_date = 7.days.ago
    when '30_days'
      start_date = 30.days.ago
    when '3_months'
      start_date = 3.months.ago
    when '6_months'
      start_date = 6.months.ago
    when '1_year'
      start_date = 1.year.ago
    else
      start_date = 30.days.ago
    end

    @total_customers = Customer.count
    @new_customers = Customer.where(created_at: start_date..Time.current).count
    @active_customers = Customer.joins(:health_insurances)
                               .where(health_insurances: { created_at: start_date..Time.current })
                               .distinct.count rescue 0

    # One grouped query instead of 7 separate per-day COUNTs.
    counts_by_date = Customer.where(created_at: 6.days.ago.beginning_of_day..Time.current)
                             .group("DATE(created_at)").count
                             .transform_keys { |k| k.is_a?(String) ? Date.parse(k) : k }
    @customer_growth = (0..6).map do |i|
      date = (6-i).days.ago.to_date
      { date: date.strftime('%b %d'), count: counts_by_date[date].to_i }
    end
  end

  # GET /admin/reports/revenue
  def revenue
    @date_range = params[:date_range] || '30_days'

    case @date_range
    when '7_days'
      start_date = 7.days.ago
    when '30_days'
      start_date = 30.days.ago
    when '3_months'
      start_date = 3.months.ago
    when '6_months'
      start_date = 6.months.ago
    when '1_year'
      start_date = 1.year.ago
    else
      start_date = 30.days.ago
    end

    if defined?(Order)
      @total_revenue = Order.where(created_at: start_date..Time.current).sum(:total_amount)
      @total_orders = Order.where(created_at: start_date..Time.current).count
      @average_order_value = @total_orders > 0 ? (@total_revenue / @total_orders).round(2) : 0

      revenue_by_date = Order.where(created_at: 6.days.ago.beginning_of_day..Time.current)
                             .group("DATE(created_at)").sum(:total_amount)
                             .transform_keys { |k| k.is_a?(String) ? Date.parse(k) : k }
      @revenue_by_day = (0..6).map do |i|
        date = (6-i).days.ago.to_date
        { date: date.strftime('%b %d'), revenue: revenue_by_date[date] || 0 }
      end
    elsif defined?(Booking)
      @total_revenue = Booking.where(created_at: start_date..Time.current).sum(:total_amount)
      @total_orders = Booking.where(created_at: start_date..Time.current).count
      @average_order_value = @total_orders > 0 ? (@total_revenue / @total_orders).round(2) : 0

      revenue_by_date = Booking.where(created_at: 6.days.ago.beginning_of_day..Time.current)
                               .group("DATE(created_at)").sum(:total_amount)
                               .transform_keys { |k| k.is_a?(String) ? Date.parse(k) : k }
      @revenue_by_day = (0..6).map do |i|
        date = (6-i).days.ago.to_date
        { date: date.strftime('%b %d'), revenue: revenue_by_date[date] || 0 }
      end
    else
      @total_revenue = 0
      @total_orders = 0
      @average_order_value = 0
      @revenue_by_day = []
    end
  end

  # GET /admin/reports/inventory
  def inventory
    if defined?(Product)
      @total_products = Product.count
      @total_stock_value = Product.sum('stock * price') rescue 0
      @out_of_stock = Product.where('stock <= ?', 0).count rescue 0
      @low_stock = Product.where('stock > 0 AND stock <= ?', 10).count rescue 0

      @low_stock_products = Product.where('stock > 0 AND stock <= ?', 10)
                                   .order(:stock)
                                   .limit(20) rescue []

      @out_of_stock_products = Product.where('stock <= ?', 0)
                                      .order(:updated_at)
                                      .limit(20) rescue []

      @categories_stock = Category.joins(:products)
                                  .group('categories.name')
                                  .sum('products.stock') rescue {}
    else
      @total_products = 0
      @total_stock_value = 0
      @out_of_stock = 0
      @low_stock = 0
      @low_stock_products = []
      @out_of_stock_products = []
      @categories_stock = {}
    end
  end

  # GET /admin/reports/orders
  def orders
    @date_range = params[:date_range] || '30_days'

    case @date_range
    when '7_days'
      start_date = 7.days.ago
    when '30_days'
      start_date = 30.days.ago
    when '3_months'
      start_date = 3.months.ago
    when '6_months'
      start_date = 6.months.ago
    when '1_year'
      start_date = 1.year.ago
    else
      start_date = 30.days.ago
    end

    if defined?(Order)
      @total_orders = Order.where(created_at: start_date..Time.current).count
      @pending_orders = Order.where(created_at: start_date..Time.current, status: 'pending').count rescue 0
      @processing_orders = Order.where(created_at: start_date..Time.current, status: 'processing').count rescue 0
      @completed_orders = Order.where(created_at: start_date..Time.current, status: ['completed', 'delivered']).count rescue 0
      @cancelled_orders = Order.where(created_at: start_date..Time.current, status: 'cancelled').count rescue 0

      @recent_orders = Order.where(created_at: start_date..Time.current)
                           .includes(:customer)
                           .order(created_at: :desc)
                           .limit(20) rescue []

      @orders_by_status = Order.where(created_at: start_date..Time.current)
                               .group(:status)
                               .count rescue {}
    elsif defined?(Booking)
      @total_orders = Booking.where(created_at: start_date..Time.current).count
      @pending_orders = Booking.where(created_at: start_date..Time.current, status: 'pending').count rescue 0
      @processing_orders = Booking.where(created_at: start_date..Time.current, status: 'processing').count rescue 0
      @completed_orders = Booking.where(created_at: start_date..Time.current, status: ['completed', 'confirmed']).count rescue 0
      @cancelled_orders = Booking.where(created_at: start_date..Time.current, status: 'cancelled').count rescue 0

      @recent_orders = Booking.where(created_at: start_date..Time.current)
                             .includes(:customer)
                             .order(created_at: :desc)
                             .limit(20) rescue []

      @orders_by_status = Booking.where(created_at: start_date..Time.current)
                                .group(:status)
                                .count rescue {}
    else
      @total_orders = 0
      @pending_orders = 0
      @processing_orders = 0
      @completed_orders = 0
      @cancelled_orders = 0
      @recent_orders = []
      @orders_by_status = {}
    end
  end

  # GET /admin/reports/financial
  def financial
    @date_range = params[:date_range] || '30_days'

    case @date_range
    when '7_days'
      start_date = 7.days.ago
    when '30_days'
      start_date = 30.days.ago
    when '3_months'
      start_date = 3.months.ago
    when '6_months'
      start_date = 6.months.ago
    when '1_year'
      start_date = 1.year.ago
    else
      start_date = 30.days.ago
    end

    # Revenue calculations
    if defined?(Order)
      @total_revenue = Order.where(created_at: start_date..Time.current).sum(:total_amount)
      @total_tax = Order.where(created_at: start_date..Time.current).sum(:tax_amount)
      @total_discount = Order.where(created_at: start_date..Time.current).sum(:discount_amount)
      @net_revenue = @total_revenue - @total_tax - @total_discount
    elsif defined?(Booking)
      @total_revenue = Booking.where(created_at: start_date..Time.current).sum(:total_amount)
      @total_tax = Booking.where(created_at: start_date..Time.current).sum(:tax_amount)
      @total_discount = Booking.where(created_at: start_date..Time.current).sum(:discount_amount)
      @net_revenue = @total_revenue - @total_tax - @total_discount
    else
      @total_revenue = 0
      @total_tax = 0
      @total_discount = 0
      @net_revenue = 0
    end

    # Commission calculations
    @total_commissions = CommissionPayout.where(created_at: start_date..Time.current).sum(:payout_amount) rescue 0
    @pending_commissions = CommissionPayout.where(created_at: start_date..Time.current, status: 'pending').sum(:payout_amount) rescue 0
    @paid_commissions = CommissionPayout.where(created_at: start_date..Time.current, status: 'paid').sum(:payout_amount) rescue 0

    # Insurance premium calculations
    @health_premiums = HealthInsurance.where(created_at: start_date..Time.current).sum(:total_premium) rescue 0
    @life_premiums = LifeInsurance.where(created_at: start_date..Time.current).sum(:total_premium) rescue 0
    @motor_premiums = MotorInsurance.where(created_at: start_date..Time.current).sum(:total_premium) rescue 0
    @total_premiums = @health_premiums + @life_premiums + @motor_premiums

    # Profit calculations
    @gross_profit = @net_revenue * 0.3 rescue 0  # Assuming 30% margin
    @net_profit = @gross_profit - @total_commissions rescue 0
  end

  # GET /admin/reports/performance
  def performance
    @date_range = params[:date_range] || '30_days'

    case @date_range
    when '7_days'
      start_date = 7.days.ago
    when '30_days'
      start_date = 30.days.ago
    when '3_months'
      start_date = 3.months.ago
    when '6_months'
      start_date = 6.months.ago
    when '1_year'
      start_date = 1.year.ago
    else
      start_date = 30.days.ago
    end

    # Sales performance
    if defined?(Order)
      @total_sales = Order.where(created_at: start_date..Time.current).count
      @avg_order_value = Order.where(created_at: start_date..Time.current).average(:total_amount) || 0
      @conversion_rate = 0  # Would need visitor tracking to calculate
    elsif defined?(Booking)
      @total_sales = Booking.where(created_at: start_date..Time.current).count
      @avg_order_value = Booking.where(created_at: start_date..Time.current).average(:total_amount) || 0
      @conversion_rate = 0
    else
      @total_sales = 0
      @avg_order_value = 0
      @conversion_rate = 0
    end

    # Agent performance
    @top_agents = User.where(user_type: 'agent')
                     .joins(:life_insurances)
                     .where(life_insurances: { created_at: start_date..Time.current })
                     .group('users.id', 'users.first_name', 'users.last_name')
                     .order('COUNT(life_insurances.id) DESC')
                     .limit(10)
                     .pluck('users.first_name', 'users.last_name', 'COUNT(life_insurances.id)') rescue []

    # Product performance
    if defined?(Product)
      @top_performing_products = Product.joins(:order_items)
                                       .where(order_items: { created_at: start_date..Time.current })
                                       .group('products.id', 'products.name')
                                       .order('SUM(order_items.quantity * order_items.price) DESC')
                                       .limit(10)
                                       .pluck('products.name', 'SUM(order_items.quantity * order_items.price)') rescue []
    else
      @top_performing_products = []
    end

    # Customer metrics
    @new_customers = Customer.where(created_at: start_date..Time.current).count
    @repeat_customers = Customer.joins(:health_insurances)
                               .where(health_insurances: { created_at: start_date..Time.current })
                               .group('customers.id')
                               .having('COUNT(health_insurances.id) > 1')
                               .count.keys.count rescue 0

    @customer_retention_rate = @repeat_customers > 0 && @new_customers > 0 ?
                              ((@repeat_customers.to_f / @new_customers) * 100).round(2) : 0
  end

  # GET /admin/reports/enhanced_sales
  def enhanced_sales
    # Date range parameters
    @from_date = params[:from_date].present? ? Date.parse(params[:from_date]) : Date.current.beginning_of_month
    @to_date = params[:to_date].present? ? Date.parse(params[:to_date]) : Date.current.end_of_month

    # Handle Excel export separately
    if params[:format] == 'xlsx'
      @report_data = build_enhanced_sales_data
      send_data generate_excel(@report_data),
                filename: "enhanced_sales_report_#{@from_date.strftime('%Y%m%d')}_#{@to_date.strftime('%Y%m%d')}.xlsx",
                type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      return
    end

    # Export format check
    respond_to do |format|
      format.html do
        @report_data = build_enhanced_sales_data
      end
      format.csv do
        @report_data = build_enhanced_sales_data
        send_data generate_csv(@report_data),
                  filename: "enhanced_sales_report_#{@from_date.strftime('%Y%m%d')}_#{@to_date.strftime('%Y%m%d')}.csv",
                  type: 'text/csv'
      end
    end
  rescue => e
    Rails.logger.error "Error in enhanced_sales: #{e.message}"
    flash[:error] = "Error generating report: #{e.message}"
    redirect_to admin_reports_enhanced_sales_path
  end

  # GET /admin/reports/profit_loss
  # Zoho-style Profit & Loss statement (see ProfitLossReport). view=products
  # shows the older product-wise margin table for the same period.
  def profit_loss
    load_profit_loss_filters
    @report = ProfitLossReport.new(from_date: @from_date, to_date: @to_date, basis: @basis, store_id: @store_id)

    @compare_columns = []
    if @compare != 'none'
      from, to = @from_date, @to_date
      @compare_count.times do
        from, to = if @compare == 'previous_year'
                     [from - 1.year, to - 1.year]
                   else
                     ProfitLossReport.previous_period(from, to)
                   end
        r = ProfitLossReport.new(from_date: from, to_date: to, basis: @basis, store_id: @store_id)
        @compare_columns << { label: "#{from.strftime('%d/%m/%Y')} - #{to.strftime('%d/%m/%Y')}", amounts: r.amounts }
      end
    end

    if @view == 'products'
      build_product_profit_rows
      if params[:download] == 'csv'
        return send_data generate_profit_loss_csv(@product_rows, @totals, @from_date, @to_date),
                         filename: "product_profit_#{@from_date.strftime('%Y%m%d')}_#{@to_date.strftime('%Y%m%d')}.csv",
                         type: 'text/csv', disposition: 'attachment'
      end
    elsif params[:download] == 'csv'
      send_data generate_pl_statement_csv,
                filename: "profit_and_loss_#{@from_date.strftime('%Y%m%d')}_#{@to_date.strftime('%Y%m%d')}.csv",
                type: 'text/csv', disposition: 'attachment'
    end
  end

  # GET /admin/reports/profit_loss/account?account=sales&...
  # Drill-down: the transactions behind one line of the statement.
  def profit_loss_account
    load_profit_loss_filters
    @account = params[:account].to_s
    @account_name = ProfitLossReport.account_name(@account)
    @report = ProfitLossReport.new(from_date: @from_date, to_date: @to_date, basis: @basis, store_id: @store_id)
    @transactions = @report.transactions_for(@account)
    @total = @transactions.sum { |t| t[:amount].to_f }.round(2)
  end

  PRODUCT_SALES_PERIODS = [
    ['today', 'Today'], ['last_7', 'Last 7 Days'], ['this_month', 'This Month'], ['last_month', 'Last Month'],
    ['last_30', 'Last 30 Days'], ['this_quarter', 'This Quarter'], ['this_fy', 'This Financial Year'],
    ['last_12_months', 'Last 12 Months'], ['custom', 'Custom Range']
  ].freeze

  # GET /admin/reports/product_sales
  # Product-wise sales: ranked best sellers, and (with product_id) one item's
  # full sales picture. ?download=csv exports the list or the item's orders.
  def product_sales
    today = Date.current
    @period = PRODUCT_SALES_PERIODS.map(&:first).include?(params[:period]) ? params[:period] : 'this_month'
    fy_start = Date.new(today.month >= 4 ? today.year : today.year - 1, 4, 1)
    @from_date, @to_date =
      case @period
      when 'today' then [today, today]
      when 'last_7' then [today - 6, today]
      when 'last_month' then [today.prev_month.beginning_of_month, today.prev_month.end_of_month]
      when 'last_30' then [today - 29, today]
      when 'this_quarter' then [today.beginning_of_quarter, today]
      when 'this_fy' then [fy_start, today]
      when 'last_12_months' then [(today - 11.months).beginning_of_month, today]
      when 'custom'
        f = (Date.parse(params[:from_date].to_s) rescue today.beginning_of_month)
        t = (Date.parse(params[:to_date].to_s) rescue today)
        [f, [t, f].max]
      else [today.beginning_of_month, today]
      end
    @sort = ProductSalesReport::SORTS.key?(params[:sort]) ? params[:sort] : 'qty'
    @search = params[:search].to_s.strip
    @stores = Store.order(:name)
    @categories = Category.order(:name)
    @store_id = params[:store_id].presence
    @category_id = params[:category_id].presence

    @report = ProductSalesReport.new(from_date: @from_date, to_date: @to_date, store_id: @store_id, category_id: @category_id)
    @product = Product.find_by(id: params[:product_id]) if params[:product_id].present?
    stamp = "#{@from_date.strftime('%Y%m%d')}_#{@to_date.strftime('%Y%m%d')}"

    if @product
      @summary = @report.product_summary(@product.id)
      if params[:download] == 'csv'
        return send_data product_sales_orders_csv(@report.order_lines(@product.id)),
                         filename: "product_sales_#{@product.name.parameterize}_#{stamp}.csv", type: 'text/csv', disposition: 'attachment'
      end
      @variants = @report.variant_rows(@product.id)
      @trend = @report.trend(@product.id)
      @top_customers = @report.top_customers(@product.id)
      @orders = @report.order_lines(@product.id, limit: 100)
    else
      @rows = @report.rows(sort: @sort, search: @search)
      if params[:download] == 'csv'
        return send_data product_sales_csv(@rows), filename: "product_sales_#{stamp}.csv", type: 'text/csv', disposition: 'attachment'
      end
    end
    @totals = @report.totals
    @product_options = @report.product_options
  end

  # GET /admin/reports/customer_bookings
  # Customer booking / delivery report: bookings with items, qty, customer and
  # delivery address. Filters: period (on booking or delivery date), statuses,
  # customer, delivery person, store, product, payment status, address.
  # ?download=csv exports the current view (bookings / items / customers).
  def customer_bookings
    today = Date.current
    @period = PRODUCT_SALES_PERIODS.map(&:first).include?(params[:period]) ? params[:period] : 'this_month'
    @from_date, @to_date = report_period_range(@period, today)
    @date_basis = CustomerBookingReport::DATE_BASES.key?(params[:date_basis]) ? params[:date_basis] : 'booking'
    @view = CustomerBookingReport::VIEWS.key?(params[:view]) ? params[:view] : 'bookings'
    @statuses = Array(params[:statuses]).reject(&:blank?) & CustomerBookingReport.status_labels.keys
    @filters = {
      from_date: @from_date, to_date: @to_date, date_basis: @date_basis, statuses: @statuses,
      customer: params[:customer].to_s.strip.presence, customer_id: params[:customer_id].presence,
      delivery_person_id: params[:delivery_person_id].presence, store_id: params[:store_id].presence,
      product_id: params[:product_id].presence, payment_status: params[:payment_status].presence,
      address: params[:address].to_s.strip.presence
    }
    @report = CustomerBookingReport.new(**@filters)
    @stores = Store.order(:name)
    @delivery_persons = DeliveryPerson.order(:first_name, :last_name)
    @products = Product.order(:name).pluck(:name, :id)
    @areas = CustomerBookingReport.area_options
    stamp = "#{@from_date.strftime('%Y%m%d')}_#{@to_date.strftime('%Y%m%d')}"

    if params[:download] == 'csv'
      return send_data customer_bookings_csv(@report, @view),
                       filename: "customer_bookings_#{@view}_#{stamp}.csv", type: 'text/csv', disposition: 'attachment'
    end

    @totals = @report.totals
    if params[:print].present?
      case @view
      when 'items' then @items = @report.items
      when 'customers' then @customer_rows = @report.customer_rows
      when 'products' then nil
      else @bookings = @report.bookings
      end
      @product_qty = @report.product_qty_rows
      return render :customer_bookings_print, layout: false
    end
    @status_counts = @report.status_counts
    @product_qty = @report.product_qty_rows.first(15)
    case @view
    when 'items' then @items = @report.items.page(params[:page]).per(100)
    when 'customers' then @customer_rows = @report.customer_rows
    when 'products' then @all_product_qty = @report.product_qty_rows
    else @bookings = @report.bookings.page(params[:page]).per(50)
    end
  end

  # GET /admin/reports/gstr1
  # GSTR-1 return in the accountant's workbook layout. Download as the full
  # Excel workbook (?download=xlsx) or one sheet as CSV (?download=csv&sheet=b2b).
  def gstr1
    @period = params[:period].presence || 'this_month'
    today = Date.current
    @from_date, @to_date =
      case @period
      when 'last_month' then [today.prev_month.beginning_of_month, today.prev_month.end_of_month]
      when 'this_quarter' then [today.beginning_of_quarter, today.end_of_quarter]
      when 'last_quarter' then [(today - 3.months).beginning_of_quarter, (today - 3.months).end_of_quarter]
      when 'this_fy' then [ProfitLossReport.fy_start(today), ProfitLossReport.fy_start(today) + 1.year - 1.day]
      when 'month'
        m = (Date.strptime(params[:month].to_s, '%Y-%m') rescue today)
        [m.beginning_of_month, m.end_of_month]
      when 'custom'
        f = (Date.parse(params[:from_date].to_s) rescue today.beginning_of_month)
        t = (Date.parse(params[:to_date].to_s) rescue today)
        [f, [t, f].max]
      else [today.beginning_of_month, today.end_of_month]
      end
    @month = params[:month].presence || @from_date.strftime('%Y-%m')
    @sheet = Gstr1Export::SHEETS.include?(params[:sheet]) ? params[:sheet] : 'gstr1'

    @report = Gstr1Report.new(from_date: @from_date, to_date: @to_date)
    @export = Gstr1Export.new(@report)
    stamp = "#{@from_date.strftime('%d%m%Y')}_#{@to_date.strftime('%d%m%Y')}"

    case params[:download]
    when 'xlsx'
      send_data @export.to_xlsx, filename: "GSTR1_#{stamp}.xlsx", disposition: 'attachment',
                type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    when 'csv'
      send_data @export.to_csv(@sheet), filename: "GSTR1_#{@sheet.tr('()', '_')}_#{stamp}.csv".sub('_.csv', '.csv'),
                type: 'text/csv', disposition: 'attachment'
    else
      @rows = @export.rows_for(@sheet)
      @styles = @export.bold_rows[@sheet]
    end
  end

  private

  def report_period_range(period, today)
    fy_start = Date.new(today.month >= 4 ? today.year : today.year - 1, 4, 1)
    case period
    when 'today' then [today, today]
    when 'last_7' then [today - 6, today]
    when 'last_month' then [today.prev_month.beginning_of_month, today.prev_month.end_of_month]
    when 'last_30' then [today - 29, today]
    when 'this_quarter' then [today.beginning_of_quarter, today]
    when 'this_fy' then [fy_start, today]
    when 'last_12_months' then [(today - 11.months).beginning_of_month, today]
    when 'custom'
      f = (Date.parse(params[:from_date].to_s) rescue today.beginning_of_month)
      t = (Date.parse(params[:to_date].to_s) rescue today)
      [f, [t, f].max]
    else [today.beginning_of_month, today.end_of_month]
    end
  end

  def customer_bookings_csv(report, view)
    require 'csv'
    CSV.generate do |csv|
      case view
      when 'items'
        csv << ['Booking Date', 'Delivery Date', 'Booking', 'Customer', 'Phone', 'Area', 'Delivery Address', 'Product', 'Qty', 'Unit', 'Unit Price (Rs)',
                'Discount (Rs)', 'Amount (Rs)', 'Status', 'Delivery Person', 'Store']
        items = report.items.to_a
        items.each do |i|
          b = i.booking
          csv << [report.booking_date(b)&.strftime('%d/%m/%Y'), b.expected_delivery_date&.strftime('%d/%m/%Y'), b.booking_number,
                  report.customer_name(b), report.customer_phone(b), report.area_for(b), report.address_for(b), CustomerBookingReport.item_label(i),
                  i.quantity.to_f, CustomerBookingReport.item_unit(i), i.price.to_f, i.try(:discount_amount).to_f, i.total.to_f, CustomerBookingReport.status_label(b.status),
                  report.delivery_person_name(b), b.store&.name]
        end
        csv << ['', '', '', '', '', '', '', 'TOTAL', items.sum { |i| i.quantity.to_f }.round(2), '', '', '', items.sum { |i| i.total.to_f }.round(2)]
      when 'products'
        csv << ['Product', 'Pack Size', 'Unit', 'Total Qty', 'Bookings', 'Amount (Rs)']
        rows = report.product_qty_rows
        rows.each { |r| csv << [r[:name], r[:pack], r[:unit], r[:qty].round(2), r[:bookings], r[:amount]] }
        csv << ['TOTAL', '', '', rows.sum { |r| r[:qty] }.round(2), '', rows.sum { |r| r[:amount] }.round(2)]
      when 'customers'
        csv << ['Customer', 'Phone', 'Area', 'Address', 'Bookings', 'Delivered', 'Total Qty', 'Amount (Rs)', 'Last Booking']
        report.customer_rows.each do |r|
          csv << [r[:name], r[:phone], r[:area], r[:address], r[:bookings], r[:delivered], r[:qty].round(2), r[:amount].round(2),
                  r[:last_date]&.strftime('%d/%m/%Y')]
        end
      else
        csv << ['Booking Date', 'Delivery Date', 'Booking', 'Customer', 'Phone', 'Area', 'Delivery Address', 'Items', 'Total Qty',
                'Amount (Rs)', 'Payment', 'Status', 'Delivery Person', 'Store']
        report.bookings.each do |b|
          items = b.booking_items.map { |i| "#{CustomerBookingReport.item_label(i)} x #{CustomerBookingReport.qty_with_unit(i)}" }.join("\n")
          csv << [report.booking_date(b)&.strftime('%d/%m/%Y'), b.expected_delivery_date&.strftime('%d/%m/%Y'), b.booking_number,
                  report.customer_name(b), report.customer_phone(b), report.area_for(b), report.address_for(b), items,
                  b.booking_items.sum { |i| i.quantity.to_f }, b.total_amount.to_f, b.payment_status.to_s.humanize,
                  CustomerBookingReport.status_label(b.status), report.delivery_person_name(b), b.store&.name]
        end
        t = report.totals
        csv << ['', '', '', "TOTAL (#{t[:bookings]} bookings)", '', '', '', '', t[:qty], t[:amount]]
      end
    end
  end

  def product_sales_csv(rows)
    require 'csv'
    CSV.generate do |csv|
      csv << ['Rank', 'Product', 'SKU', 'Category', 'Qty Sold', 'Unit', 'Orders', 'Customers', 'Revenue (Rs)', 'Avg Price (Rs)',
              'Share %', 'Returned Qty', 'Returned (Rs)', 'Last Sold']
      rows.each_with_index do |r, i|
        csv << [i + 1, r[:name], r[:sku], r[:category], r[:qty], r[:unit], r[:orders], r[:customers], r[:revenue], r[:avg_price],
                r[:share], r[:returned_qty], r[:returned_amount], r[:last_sold]&.strftime('%d/%m/%Y')]
      end
      csv << ['', 'TOTAL', '', '', rows.sum { |r| r[:qty] }.round(2), '', '', '', rows.sum { |r| r[:revenue] }.round(2)]
    end
  end

  def product_sales_orders_csv(lines)
    require 'csv'
    CSV.generate do |csv|
      csv << ['Date', 'Booking', 'Customer', 'Phone', 'Store', 'Pack Size', 'Qty', 'Unit Price (Rs)', 'Discount (Rs)', 'Amount (Rs)', 'Status']
      lines.each do |l|
        csv << [l[:date]&.strftime('%d/%m/%Y'), l[:number], l[:customer], l[:phone], l[:store], l[:variant], l[:qty], l[:unit_price],
                l[:discount], l[:total], l[:status]]
      end
      csv << ['', '', 'TOTAL', '', '', '', lines.sum { |l| l[:qty] }.round(2), '', '', lines.sum { |l| l[:total] }.round(2)]
    end
  end

  def load_profit_loss_filters
    @date_range = params[:date_range].presence
    @date_range = nil unless ProfitLossReport::DATE_RANGES.map(&:first).include?(@date_range)
    preset = @date_range && @date_range != 'custom' ? ProfitLossReport.range_for(@date_range) : nil

    if preset
      @from_date, @to_date = preset
    else
      @from_date = (Date.parse(params[:from_date]) rescue nil) if params[:from_date].present?
      @to_date   = (Date.parse(params[:to_date]) rescue nil) if params[:to_date].present?
      @date_range ||= (@from_date || @to_date) ? 'custom' : 'this_month'
      default_from, default_to = ProfitLossReport.range_for('this_month')
      @from_date ||= default_from
      @to_date   ||= default_to
    end
    @from_date, @to_date = @to_date, @from_date if @from_date > @to_date

    @basis   = params[:basis] == 'cash' ? 'cash' : 'accrual'
    @store_id = params[:store_id].presence
    @stores  = Store.order(:name)
    @compare = ProfitLossReport::COMPARE_OPTIONS.map(&:first).include?(params[:compare]) ? params[:compare] : 'none'
    @compare_count = params[:compare_count].to_i.clamp(1, 5)
    @view = params[:view] == 'products' ? 'products' : 'statement'
  end

  def profit_loss_params(extra = {})
    { date_range: @date_range, from_date: @from_date, to_date: @to_date, basis: @basis,
      store_id: @store_id, compare: @compare, compare_count: @compare_count, view: @view }.merge(extra).compact
  end
  helper_method :profit_loss_params

  def build_product_profit_rows
    items = BookingItem.joins(:booking)
                       .where.not(bookings: { status: ProfitLossReport::EXCLUDED_BOOKING_STATUSES })
                       .includes(:product)
                       .where(bookings: { booking_date: @from_date.beginning_of_day..@to_date.end_of_day })

    product_data = {}
    items.each do |item|
      product = item.product
      next unless product

      qty            = item.quantity.to_f
      revenue        = qty * item.price.to_f
      cost_each      = product.buying_price.to_f
      purchase_each  = product.purchase_price.to_f
      cost           = qty * cost_each
      profit         = revenue - cost

      if product_data[product.id]
        d = product_data[product.id]
        d[:qty_sold] += qty
        d[:revenue]  += revenue
        d[:cost]     += cost
        d[:profit]   += profit
      else
        product_data[product.id] = {
          name:           product.name,
          unit_type:      product.unit_type || 'Pcs',
          selling_price:  item.price.to_f,
          cost_price:     cost_each,
          purchase_price: purchase_each,
          qty_sold:       qty,
          revenue:        revenue,
          cost:           cost,
          profit:         profit
        }
      end
    end

    @product_rows = product_data.values.sort_by { |r| -r[:revenue] }
    @totals = {
      qty_sold: @product_rows.sum { |r| r[:qty_sold] },
      revenue:  @product_rows.sum { |r| r[:revenue] },
      cost:     @product_rows.sum { |r| r[:cost] },
      profit:   @product_rows.sum { |r| r[:profit] }
    }

  end

  def generate_pl_statement_csv
    require 'csv'
    r = @report
    cmp = @compare_columns
    CSV.generate do |csv|
      csv << ['Profit and Loss']
      csv << ["Basis: #{@basis.capitalize}"]
      csv << ["From #{@from_date.strftime('%d/%m/%Y')} To #{@to_date.strftime('%d/%m/%Y')}"]
      csv << []
      head = ['Account', "#{@from_date.strftime('%d/%m/%Y')} - #{@to_date.strftime('%d/%m/%Y')}"]
      csv << (cmp.any? ? head + cmp.map { |c| c[:label] } : ['Account', 'Total'])
      row = lambda do |label, key, amount|
        csv << [label, amount.to_f.round(2)] + cmp.map { |c| c[:amounts][key].to_f.round(2) }
      end
      section = lambda do |title, lines, total_key, total|
        csv << [title]
        lines.each { |l| row.call("  #{l.name}", l.key, l.amount) }
        row.call("Total for #{title}", total_key, total)
      end
      section.call('Operating Income', r.operating_income, 'total_operating_income', r.total_operating_income)
      section.call('Cost of Goods Sold', r.cost_of_goods_sold, 'total_cogs', r.total_cogs)
      row.call('Gross Profit', 'gross_profit', r.gross_profit)
      section.call('Operating Expense', r.operating_expense, 'total_operating_expense', r.total_operating_expense)
      row.call('Operating Profit', 'operating_profit', r.operating_profit)
      section.call('Non Operating Income', r.non_operating_income, 'total_non_operating_income', r.total_non_operating_income)
      section.call('Non Operating Expense', r.non_operating_expense, 'total_non_operating_expense', r.total_non_operating_expense)
      row.call('Net Profit/Loss', 'net_profit', r.net_profit)
    end
  end


  def build_enhanced_sales_data
    # Get all invoices in the date range (both regular and booking invoices)
    regular_invoices = Invoice.includes(:customer, invoice_items: :product)
                             .where(invoice_date: @from_date..@to_date)
                             .order(:invoice_date)

    booking_invoices = BookingInvoice.includes(:customer, booking: { booking_items: :product })
                                   .where(invoice_date: @from_date..@to_date)
                                   .order(:invoice_date)

    report_rows = []
    totals = {
      total_amount: 0,
      total_gst: 0,
      cgst: 0,
      sgst: 0,
      igst: 0
    }

    # Process regular invoices
    regular_invoices.each do |invoice|
      row_data = process_invoice_data(invoice, 'Invoice')
      report_rows << row_data
      add_to_totals(totals, row_data)
    end

    # Process booking invoices
    booking_invoices.each do |invoice|
      row_data = process_invoice_data(invoice, 'BookingInvoice')
      report_rows << row_data
      add_to_totals(totals, row_data)
    end

    {
      rows: report_rows.sort_by { |row| row[:invoice_date] },
      totals: totals
    }
  end

  def process_invoice_data(invoice, invoice_type)
    customer = invoice.customer

    # Calculate GST breakdown
    gst_data = calculate_gst_breakdown(invoice, invoice_type)

    # Count assignments (invoice items)
    assignments = invoice_type == 'BookingInvoice' ?
                  (invoice.respond_to?(:booking) ? invoice.booking&.booking_items&.size || 0 : 0) :
                  invoice.invoice_items.size

    {
      customer_name: customer&.display_name || 'N/A',
      customer_number: customer&.mobile || 'N/A',
      customer_address: format_customer_address(customer),
      invoice_number: invoice.invoice_number,
      invoice_date: invoice.invoice_date || invoice.created_at.to_date,
      assignments: assignments,
      total_amount: invoice.total_amount || 0,
      total_gst: gst_data[:total_gst],
      cgst: gst_data[:cgst],
      sgst: gst_data[:sgst],
      igst: gst_data[:igst]
    }
  end

  def calculate_gst_breakdown(invoice, invoice_type)
    total_gst = 0
    cgst = 0
    sgst = 0
    igst = 0

    if invoice_type == 'BookingInvoice' && invoice.respond_to?(:booking)
      # For booking invoices, get GST from booking items
      booking = invoice.booking
      if booking&.booking_items
        booking.booking_items.each do |item|
          if item.gst_charged? && item.product.gst_percentage > 0
            base_amount = (item.quantity || 0) * item.charged_unit_price
            gst_rate = item.product.gst_percentage
            item_gst = (base_amount * gst_rate / 100).round(2)

            total_gst += item_gst
            cgst += (item_gst / 2).round(2)
            sgst += (item_gst / 2).round(2)
          end
        end
      end
    else
      # For regular invoices, get GST from invoice items
      if invoice.invoice_items
        invoice.invoice_items.each do |item|
          if item.gst_charged? && item.product.gst_percentage > 0
            base_amount = (item.quantity || 0) * (item.unit_price || 0)
            gst_rate = item.product.gst_percentage
            item_gst = (base_amount * gst_rate / 100).round(2)

            total_gst += item_gst
            cgst += (item_gst / 2).round(2)
            sgst += (item_gst / 2).round(2)
          end
        end
      end
    end

    {
      total_gst: total_gst.round(2),
      cgst: cgst.round(2),
      sgst: sgst.round(2),
      igst: igst.round(2) # IGST is 0 for intra-state transactions
    }
  end

  def format_customer_address(customer)
    return 'N/A' unless customer

    address_parts = []
    address_parts << customer.address if customer.respond_to?(:address) && customer.address.present?
    address_parts << customer.city if customer.respond_to?(:city) && customer.city.present?

    address_parts.any? ? address_parts.join(', ') : 'N/A'
  end

  def add_to_totals(totals, row_data)
    totals[:total_amount] += row_data[:total_amount]
    totals[:total_gst] += row_data[:total_gst]
    totals[:cgst] += row_data[:cgst]
    totals[:sgst] += row_data[:sgst]
    totals[:igst] += row_data[:igst]
  end

  def generate_csv(report_data)
    require 'csv'

    CSV.generate(headers: true) do |csv|
      # Header row
      csv << [
        'Customer Name',
        'Customer Number',
        'Customer Address',
        'Invoice Number',
        'Invoice Date',
        'Assignments',
        'Total Amount',
        'Total GST',
        'CGST',
        'SGST',
        'IGST'
      ]

      # Data rows
      report_data[:rows].each do |row|
        csv << [
          row[:customer_name],
          row[:customer_number],
          row[:customer_address],
          row[:invoice_number],
          row[:invoice_date].strftime('%d/%m/%Y'),
          row[:assignments],
          "₹#{row[:total_amount]&.round(2)}",
          "₹#{row[:total_gst]&.round(2)}",
          "₹#{row[:cgst]&.round(2)}",
          "₹#{row[:sgst]&.round(2)}",
          "₹#{row[:igst]&.round(2)}"
        ]
      end

      # Totals row
      totals = report_data[:totals]
      csv << [
        '',
        '',
        '',
        '',
        '',
        'TOTALS:',
        "₹#{totals[:total_amount]&.round(2)}",
        "₹#{totals[:total_gst]&.round(2)}",
        "₹#{totals[:cgst]&.round(2)}",
        "₹#{totals[:sgst]&.round(2)}",
        "₹#{totals[:igst]&.round(2)}"
      ]
    end
  end

  def generate_profit_loss_csv(rows, totals, from_date, to_date)
    require 'csv'
    CSV.generate(headers: true) do |csv|
      csv << ["Profit & Loss Report", "#{from_date.strftime('%d/%m/%Y')} to #{to_date.strftime('%d/%m/%Y')}"]
      csv << []
      csv << ['Product', 'Unit', 'Qty Sold', 'Selling Price (₹)', 'Cost Price (₹)', 'Purchase Price (₹)', 'Revenue (₹)', 'Cost (₹)', 'Profit/Loss (₹)']
      rows.each do |r|
        csv << [
          r[:name],
          r[:unit_type],
          r[:qty_sold].to_s.sub(/\.0$/, ''),
          r[:selling_price].round(2),
          r[:cost_price].round(2),
          r[:purchase_price].round(2),
          r[:revenue].round(2),
          r[:cost].round(2),
          r[:profit].round(2)
        ]
      end
      csv << []
      csv << ['TOTAL', '', totals[:qty_sold].to_s.sub(/\.0$/, ''), '', '', '', totals[:revenue].round(2), totals[:cost].round(2), totals[:profit].round(2)]
    end
  end

  def generate_excel(report_data)
    require 'write_xlsx'

    # Create a temporary file
    temp_file = Tempfile.new(['enhanced_sales_report', '.xlsx'])
    temp_file.close

    begin
      workbook = WriteXLSX.new(temp_file.path)
      worksheet = workbook.add_worksheet('Enhanced Sales Report')

      # Header format
      header_format = workbook.add_format(
        bold: 1,
        bg_color: '#366092',
        color: 'white',
        border: 1
      )

      # Data format
      data_format = workbook.add_format(border: 1)
      currency_format = workbook.add_format(border: 1, num_format: '₹#,##0.00')

      # Headers
      headers = [
        'Customer Name', 'Customer Number', 'Customer Address', 'Invoice Number',
        'Invoice Date', 'Assignments', 'Total Amount', 'Total GST', 'CGST', 'SGST', 'IGST'
      ]

      headers.each_with_index do |header, col|
        worksheet.write(0, col, header, header_format)
      end

      # Data rows
      report_data[:rows].each_with_index do |row, row_idx|
        worksheet.write(row_idx + 1, 0, row[:customer_name], data_format)
        worksheet.write(row_idx + 1, 1, row[:customer_number], data_format)
        worksheet.write(row_idx + 1, 2, row[:customer_address], data_format)
        worksheet.write(row_idx + 1, 3, row[:invoice_number], data_format)
        worksheet.write(row_idx + 1, 4, row[:invoice_date].strftime('%d/%m/%Y'), data_format)
        worksheet.write(row_idx + 1, 5, row[:assignments], data_format)
        worksheet.write(row_idx + 1, 6, row[:total_amount], currency_format)
        worksheet.write(row_idx + 1, 7, row[:total_gst], currency_format)
        worksheet.write(row_idx + 1, 8, row[:cgst], currency_format)
        worksheet.write(row_idx + 1, 9, row[:sgst], currency_format)
        worksheet.write(row_idx + 1, 10, row[:igst], currency_format)
      end

      # Totals row
      totals_row = report_data[:rows].size + 1
      totals = report_data[:totals]

      worksheet.write(totals_row, 5, 'TOTALS:', header_format)
      worksheet.write(totals_row, 6, totals[:total_amount], currency_format)
      worksheet.write(totals_row, 7, totals[:total_gst], currency_format)
      worksheet.write(totals_row, 8, totals[:cgst], currency_format)
      worksheet.write(totals_row, 9, totals[:sgst], currency_format)
      worksheet.write(totals_row, 10, totals[:igst], currency_format)

      workbook.close

      # Read the file content
      content = File.binread(temp_file.path)
      content
    ensure
      temp_file.unlink if temp_file
    end
  end
end
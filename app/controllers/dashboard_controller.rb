class DashboardController < ApplicationController
  skip_load_and_authorize_resource

  def index
    # Handle session validation requests
    if request.headers['X-Session-Validation'] == 'true'
      # Lightweight session validation - just return 200 OK if authenticated
      head :ok
      return
    end

    authorize! :read, :dashboard
    load_ecommerce_dashboard_data
  end

  def beautiful
    authorize! :read, :dashboard
    load_dashboard_data
    render 'beautiful_dashboard', layout: false
  end

  def ultra
    authorize! :read, :dashboard
    load_dashboard_data
    render 'ultra_attractive_dashboard', layout: false
  end

  def ecommerce
    authorize! :read, :dashboard
    load_ecommerce_dashboard_data
    render 'ecommerce_dashboard', layout: false
  end

  def dummy
    authorize! :read, :dashboard
    render 'dummy', layout: false
  end

  def modern
    authorize! :read, :dashboard
    load_ecommerce_dashboard_data
    render 'modern', layout: false
  end

  def stats
    authorize! :read, :dashboard
    load_ecommerce_dashboard_data

    # Get recent orders with customer info
    recent_orders = Booking.includes(:customer)
                          .recent
                          .limit(10)
                          .map do |booking|
      {
        id: booking.booking_number,
        customer: booking.customer&.display_name || 'Guest Customer',
        status: booking.status.capitalize,
        amount: booking.total_amount.to_i,
        date: booking.created_at.strftime('%Y-%m-%d')
      }
    end

    # Get top products
    top_products = Product.joins(:booking_items)
                         .joins('JOIN bookings ON booking_items.booking_id = bookings.id')
                         .where('bookings.status IN (?)', ['delivered', 'completed'])
                         .group('products.id, products.name')
                         .select('products.id, products.name, products.category_id,
                                 SUM(booking_items.quantity * booking_items.price) as revenue,
                                 SUM(booking_items.quantity) as sold')
                         .order('revenue DESC')
                         .limit(5)
                         .map do |product|
      category_name = product.category&.name || 'General'
      {
        id: product.id,
        name: product.name,
        category: category_name,
        revenue: product.revenue.to_i,
        sold: product.sold.to_i
      }
    end

    # Get order status distribution
    order_status_data = {
      'Completed' => Booking.where(status: ['delivered', 'completed']).count,
      'Processing' => Booking.where(status: ['confirmed', 'processing', 'packed']).count,
      'Shipped' => Booking.where(status: ['shipped', 'out_for_delivery']).count,
      'Cancelled' => Booking.where(status: 'cancelled').count
    }

    # Generate sample activities
    activities = [
      {
        id: 1,
        type: 'order',
        title: 'New Order',
        description: "Order #{recent_orders.first&.dig(:id) || 'BK001'} placed",
        time: 2.minutes.ago
      },
      {
        id: 2,
        type: 'customer',
        title: 'New Customer',
        description: 'Customer registration completed',
        time: 5.minutes.ago
      },
      {
        id: 3,
        type: 'payment',
        title: 'Payment Received',
        description: "Payment of ₹#{recent_orders.first&.dig(:amount) || 2500} received",
        time: 8.minutes.ago
      }
    ]

    render json: {
      # E-commerce metrics
      total_revenue: @total_revenue,
      total_bookings: @total_bookings,
      total_customers: @total_customers,
      total_products: @total_products,
      active_products: @active_products,

      # Order metrics
      pending_bookings: @pending_bookings,
      completed_bookings: @completed_bookings,
      cancelled_bookings: @cancelled_bookings,

      # Revenue metrics
      today_revenue: @today_revenue,
      month_revenue: @month_revenue,
      avg_order_value: @avg_order_value,

      # Growth metrics
      revenue_growth: @revenue_growth,
      order_growth: @order_growth,
      customer_acquisition_growth: @customer_acquisition_growth,

      # Charts data
      monthly_revenue_trend: @monthly_revenue_trend,
      category_performance: @category_performance,
      order_status_distribution: order_status_data,
      sales_trend: @sales_trend,

      # Recent data
      recent_orders: recent_orders,
      top_products: top_products,
      activities: activities,

      # Timestamp
      last_updated: Time.current.strftime('%Y-%m-%d %H:%M:%S'),
      cache_key: "dashboard_#{Time.current.to_i}"
    }
  end

  private

  def load_dashboard_data
    # Load actual data from database instead of static zeros
    load_ecommerce_dashboard_data

    # Additional insurance-specific metrics that might be needed
    begin
      # Basic counts
      @total_customers = Customer.count
      @active_customers = Customer.where(status: true).count rescue @total_customers
      @inactive_customers = @total_customers - @active_customers

      # Insurance-specific data (if available)
      @total_affiliates = SubAgent.count rescue 0
      @total_sub_agents = SubAgent.count rescue 0

      # Get policy counts using optimized helper methods
      policy_counts = get_optimized_policy_counts
      @total_policies = policy_counts[:total_count]

      # Get premium data
      premium_data = get_optimized_premium_data
      @total_premium_collected = premium_data[:total_premium]
      @total_sum_insured = premium_data[:total_sum_insured]

      # Lead data (if available)
      @total_leads = Lead.count rescue 0
      @converted_leads = Lead.where(status: 'converted').count rescue 0
      @pending_leads = Lead.where(status: 'pending').count rescue 0
      @lead_conversion_percentage = @total_leads > 0 ? ((@converted_leads.to_f / @total_leads) * 100).round(1) : 0

      # Renewal and expiry counts
      thirty_days_from_now = 30.days.from_now.to_date
      @renewal_due_count = get_renewal_due_count(thirty_days_from_now)
      @expired_policies_count = get_expired_policies_count

      # Payout data
      payout_data = get_optimized_payout_data
      @pending_payouts = payout_data[:pending_amount]
      @paid_payouts = payout_data[:paid_amount]
      @total_payouts = payout_data[:total_amount]

      # Policy type distribution
      @policy_type_distribution = {
        'Health Insurance' => { count: policy_counts[:health_count], percentage: policy_counts[:total_count] > 0 ? (policy_counts[:health_count].to_f / policy_counts[:total_count] * 100).round(1) : 0 },
        'Life Insurance' => { count: policy_counts[:life_count], percentage: policy_counts[:total_count] > 0 ? (policy_counts[:life_count].to_f / policy_counts[:total_count] * 100).round(1) : 0 },
        'Motor Insurance' => { count: policy_counts[:motor_count], percentage: policy_counts[:total_count] > 0 ? (policy_counts[:motor_count].to_f / policy_counts[:total_count] * 100).round(1) : 0 },
        'Other Insurance' => { count: policy_counts[:other_count], percentage: policy_counts[:total_count] > 0 ? (policy_counts[:other_count].to_f / policy_counts[:total_count] * 100).round(1) : 0 }
      }

      # Chart and analysis data
      @customer_location = calculate_customer_locations
      @age_distribution = calculate_age_distribution
      @policy_status_distribution = calculate_policy_status_distribution
      @monthly_revenue_breakdown = calculate_monthly_revenue_breakdown
      @premium_by_type = {
        'Health Insurance' => HealthInsurance.sum(:total_premium) || 0,
        'Life Insurance' => LifeInsurance.sum(:total_premium) || 0,
        'Motor Insurance' => (MotorInsurance.sum(:total_premium) rescue 0)
      }

      # Growth metrics
      calculate_growth_metrics

      # Additional metrics
      @client_requests_count = 0 # Add actual model query if available
      @claims_processing = 0 # Add actual model query if available
      @docs_pending = 0 # Add actual model query if available
      @commissions_due = @pending_payouts
      @new_leads = Lead.where('created_at >= ?', Date.current.beginning_of_month).count rescue 0
      @support_tickets = 0 # Add actual model query if available

    rescue => e
      # Fallback to zero values if there are any errors
      Rails.logger.error "Dashboard data loading error: #{e.message}"

      @total_customers ||= 0
      @active_customers ||= 0
      @inactive_customers ||= 0
      @total_affiliates ||= 0
      @total_sub_agents ||= 0
      @total_policies ||= 0
      @total_premium_collected ||= 0
      @total_sum_insured ||= 0
      @total_leads ||= 0
      @converted_leads ||= 0
      @pending_leads ||= 0
      @lead_conversion_percentage ||= 0
      @renewal_due_count ||= 0
      @expired_policies_count ||= 0
      @pending_payouts ||= 0
      @paid_payouts ||= 0
      @total_payouts ||= 0
      @policy_type_distribution ||= {
        'Health Insurance' => { count: 0, percentage: 0 },
        'Life Insurance' => { count: 0, percentage: 0 },
        'Motor Insurance' => { count: 0, percentage: 0 },
        'Other Insurance' => { count: 0, percentage: 0 }
      }
      @customer_location ||= {}
      @age_distribution ||= {}
      @policy_status_distribution ||= {}
      @monthly_revenue_breakdown ||= {}
      @premium_by_type ||= { 'Health Insurance' => 0, 'Life Insurance' => 0, 'Motor Insurance' => 0 }
    end
  end

  # Optimized helper methods to avoid N+1 queries

  def get_optimized_policy_counts
    # Single query to get all policy counts
    health_count = HealthInsurance.count
    life_count = LifeInsurance.count
    motor_count = MotorInsurance.count rescue 0
    other_count = OtherInsurance.count rescue 0

    {
      health_count: health_count,
      life_count: life_count,
      motor_count: motor_count,
      other_count: other_count,
      total_count: health_count + life_count + motor_count + other_count
    }
  end

  def get_optimized_premium_data
    # Simpler direct sum queries
    health_premium = HealthInsurance.sum(:total_premium) || 0
    life_premium = LifeInsurance.sum(:total_premium) || 0
    motor_premium = begin
      MotorInsurance.sum(:total_premium) || 0
    rescue
      0
    end

    health_sum = HealthInsurance.sum(:sum_insured) || 0
    life_sum = LifeInsurance.sum(:sum_insured) || 0
    motor_sum = begin
      MotorInsurance.sum(:sum_insured) || 0
    rescue
      0
    end

    {
      total_premium: health_premium + life_premium + motor_premium,
      total_sum_insured: health_sum + life_sum + motor_sum
    }
  end

  def get_renewal_due_count(thirty_days_from_now)
    # Single query for renewal counts
    health_renewals = HealthInsurance.where('policy_end_date BETWEEN ? AND ?', Date.current, thirty_days_from_now).count
    life_renewals = LifeInsurance.where('policy_end_date BETWEEN ? AND ?', Date.current, thirty_days_from_now).count

    motor_renewals = begin
      MotorInsurance.where('policy_end_date BETWEEN ? AND ?', Date.current, thirty_days_from_now).count
    rescue
      0
    end

    other_renewals = begin
      OtherInsurance.where('policy_end_date BETWEEN ? AND ?', Date.current, thirty_days_from_now).count
    rescue
      0
    end

    health_renewals + life_renewals + motor_renewals + other_renewals
  end

  def get_expired_policies_count
    # Single query for expired policies
    health_expired = HealthInsurance.where('policy_end_date < ?', Date.current).count
    life_expired = LifeInsurance.where('policy_end_date < ?', Date.current).count

    motor_expired = begin
      MotorInsurance.where('policy_end_date < ?', Date.current).count
    rescue
      0
    end

    other_expired = begin
      OtherInsurance.where('policy_end_date < ?', Date.current).count
    rescue
      0
    end

    health_expired + life_expired + motor_expired + other_expired
  end

  def get_optimized_payout_data
    # Optimized payout queries
    commission_pending = CommissionPayout.where(status: 'pending').sum(:payout_amount) || 0
    commission_paid = CommissionPayout.where(status: 'paid').sum(:payout_amount) || 0
    commission_total = CommissionPayout.sum(:payout_amount) || 0

    distributor_pending = begin
      DistributorPayout.where(status: 'pending').sum(:payout_amount) || 0
    rescue
      0
    end

    distributor_paid = begin
      DistributorPayout.where(status: 'paid').sum(:payout_amount) || 0
    rescue
      0
    end

    distributor_total = begin
      DistributorPayout.sum(:payout_amount) || 0
    rescue
      0
    end

    {
      pending_amount: commission_pending + distributor_pending,
      paid_amount: commission_paid + distributor_paid,
      total_amount: commission_total + distributor_total
    }
  end

  def calculate_growth_metrics
    # Get data for current month and last month
    current_month_start = Date.current.beginning_of_month
    last_month_start = 1.month.ago.beginning_of_month
    last_month_end = 1.month.ago.end_of_month

    # Current month data
    current_customers = Customer.where('created_at >= ?', current_month_start).count
    current_policies = get_policies_count_for_period(current_month_start, Date.current)
    current_premium = get_premium_for_period(current_month_start, Date.current)
    current_affiliates = SubAgent.where('created_at >= ?', current_month_start).count
    current_leads = Lead.where('created_at >= ?', current_month_start).count
    current_renewals = get_renewals_count_for_period(current_month_start, Date.current)
    current_payouts = get_payouts_for_period(current_month_start, Date.current)
    current_sum_insured = get_sum_insured_for_period(current_month_start, Date.current)

    # Last month data
    last_customers = Customer.where(created_at: last_month_start..last_month_end).count
    last_policies = get_policies_count_for_period(last_month_start, last_month_end)
    last_premium = get_premium_for_period(last_month_start, last_month_end)
    last_affiliates = SubAgent.where(created_at: last_month_start..last_month_end).count
    last_leads = Lead.where(created_at: last_month_start..last_month_end).count
    last_renewals = get_renewals_count_for_period(last_month_start, last_month_end)
    last_payouts = get_payouts_for_period(last_month_start, last_month_end)
    last_sum_insured = get_sum_insured_for_period(last_month_start, last_month_end)

    # Calculate growth percentages
    @customer_growth = calculate_percentage_change(current_customers, last_customers)
    @policy_growth = calculate_percentage_change(current_policies, last_policies)
    @premium_growth = calculate_percentage_change(current_premium, last_premium)
    @affiliate_growth = calculate_percentage_change(current_affiliates, last_affiliates)
    @lead_growth = calculate_percentage_change(current_leads, last_leads)
    @renewal_growth = calculate_percentage_change(current_renewals, last_renewals)
    @payout_growth = calculate_percentage_change(current_payouts, last_payouts)
    @sum_insured_growth = calculate_percentage_change(current_sum_insured, last_sum_insured)

    # Additional metrics
    @conversion_rate = @total_leads > 0 ? ((@converted_leads.to_f / @total_leads) * 100).round(1) : 0
    @avg_policy_value = @total_policies > 0 ? (@total_premium_collected / @total_policies).round(0) : 0
    @customer_retention = calculate_customer_retention_rate
    @monthly_recurring_revenue = calculate_monthly_recurring_revenue
  end

  private

  def get_policies_count_for_period(start_date, end_date)
    health = HealthInsurance.where(created_at: start_date..end_date).count
    life = LifeInsurance.where(created_at: start_date..end_date).count
    motor = MotorInsurance.where(created_at: start_date..end_date).count rescue 0
    other = OtherInsurance.where(created_at: start_date..end_date).count rescue 0
    health + life + motor + other
  end

  def get_premium_for_period(start_date, end_date)
    health = HealthInsurance.where(created_at: start_date..end_date).sum(:total_premium) || 0
    life = LifeInsurance.where(created_at: start_date..end_date).sum(:total_premium) || 0
    motor = MotorInsurance.where(created_at: start_date..end_date).sum(:total_premium) rescue 0
    health + life + motor
  end

  def get_renewals_count_for_period(start_date, end_date)
    thirty_days_ahead = end_date + 30.days
    health = HealthInsurance.where(created_at: start_date..end_date)
                           .where('policy_end_date BETWEEN ? AND ?', end_date, thirty_days_ahead).count
    life = LifeInsurance.where(created_at: start_date..end_date)
                        .where('policy_end_date BETWEEN ? AND ?', end_date, thirty_days_ahead).count
    motor = MotorInsurance.where(created_at: start_date..end_date)
                          .where('policy_end_date BETWEEN ? AND ?', end_date, thirty_days_ahead).count rescue 0
    health + life + motor
  end

  def get_payouts_for_period(start_date, end_date)
    commission = CommissionPayout.where(created_at: start_date..end_date, status: 'pending').sum(:payout_amount) || 0
    distributor = DistributorPayout.where(created_at: start_date..end_date, status: 'pending').sum(:payout_amount) rescue 0
    commission + distributor
  end

  def get_sum_insured_for_period(start_date, end_date)
    health = HealthInsurance.where(created_at: start_date..end_date).sum(:sum_insured) || 0
    life = LifeInsurance.where(created_at: start_date..end_date).sum(:sum_insured) || 0
    motor = MotorInsurance.where(created_at: start_date..end_date).sum(:sum_insured) rescue 0
    health + life + motor
  end

  def calculate_percentage_change(current_value, previous_value)
    return 0 if previous_value == 0
    return 100 if previous_value == 0 && current_value > 0
    ((current_value.to_f - previous_value.to_f) / previous_value.to_f * 100).round(1)
  end

  def calculate_customer_retention_rate
    # Calculate retention rate for customers who joined 2+ months ago
    two_months_ago = 2.months.ago.beginning_of_month
    old_customers = Customer.where('created_at < ?', two_months_ago).count
    active_old_customers = Customer.where('created_at < ?', two_months_ago).where(status: true).count

    old_customers > 0 ? ((active_old_customers.to_f / old_customers.to_f) * 100).round(1) : 0
  end

  def calculate_monthly_recurring_revenue
    # Estimate based on average premium per month
    monthly_premium = @total_premium_collected / 12.0
    monthly_premium.round(0)
  end

  def calculate_age_distribution
    base = { '18-25' => 0, '26-35' => 0, '36-45' => 0, '46-55' => 0, '56-65' => 0, '65+' => 0 }
    rows = Customer.where.not(birth_date: nil)
                   .group(Arel.sql(
                     "CASE
                        WHEN EXTRACT(YEAR FROM AGE(birth_date)) BETWEEN 18 AND 25 THEN '18-25'
                        WHEN EXTRACT(YEAR FROM AGE(birth_date)) BETWEEN 26 AND 35 THEN '26-35'
                        WHEN EXTRACT(YEAR FROM AGE(birth_date)) BETWEEN 36 AND 45 THEN '36-45'
                        WHEN EXTRACT(YEAR FROM AGE(birth_date)) BETWEEN 46 AND 55 THEN '46-55'
                        WHEN EXTRACT(YEAR FROM AGE(birth_date)) BETWEEN 56 AND 65 THEN '56-65'
                        WHEN EXTRACT(YEAR FROM AGE(birth_date)) > 65             THEN '65+'
                        ELSE NULL
                      END"
                   ))
                   .count
    base.merge(rows.compact)
  rescue
    base
  end

  def calculate_policy_status_distribution
    active_policies = HealthInsurance.where('policy_end_date > ?', Date.current).count +
                     LifeInsurance.where('policy_end_date > ?', Date.current).count +
                     MotorInsurance.where('policy_end_date > ?', Date.current).count

    expired_policies = HealthInsurance.where('policy_end_date < ?', Date.current).count +
                      LifeInsurance.where('policy_end_date < ?', Date.current).count +
                      MotorInsurance.where('policy_end_date < ?', Date.current).count

    expiring_soon = HealthInsurance.where('policy_end_date BETWEEN ? AND ?', Date.current, 30.days.from_now).count +
                   LifeInsurance.where('policy_end_date BETWEEN ? AND ?', Date.current, 30.days.from_now).count +
                   MotorInsurance.where('policy_end_date BETWEEN ? AND ?', Date.current, 30.days.from_now).count

    {
      'Active' => active_policies,
      'Expired' => expired_policies,
      'Expiring Soon' => expiring_soon
    }
  end

  def calculate_monthly_revenue_breakdown
    start_date = 5.months.ago.beginning_of_month.beginning_of_day

    # Single query: revenue per category per month
    rows = BookingItem.joins(:booking, product: :category)
                      .where(bookings: { created_at: start_date..Time.current.end_of_month })
                      .group(
                        Arel.sql("TO_CHAR(bookings.created_at, 'Mon')"),
                        'categories.name'
                      )
                      .sum('booking_items.quantity * booking_items.price')

    # Single query: total monthly revenue for fallback distribution
    monthly_totals = Booking.where(created_at: start_date..Time.current.end_of_month)
                            .group(Arel.sql("TO_CHAR(created_at, 'Mon')"))
                            .sum(:total_amount)

    breakdown = {}
    6.times do |i|
      month_date = (Date.current - i.months).beginning_of_month
      month_name = month_date.strftime('%b')

      electronics = rows[[month_name, 'Electronics']].to_f
      clothing    = rows[[month_name, 'Clothing']].to_f
      home        = rows[[month_name, 'Home & Garden']] ||
                    rows[[month_name, 'Home']] ||
                    rows[[month_name, 'Garden']] || 0
      home = home.to_f

      if electronics == 0 && clothing == 0 && home == 0
        total = monthly_totals[month_name].to_f
        if total > 0
          electronics = (total * 0.4).round(0)
          clothing    = (total * 0.35).round(0)
          home        = (total * 0.25).round(0)
        end
      end

      breakdown[month_name] = {
        electronics: electronics,
        clothing:    clothing,
        home:        home,
        total:       electronics + clothing + home
      }
    end

    breakdown.to_a.reverse.to_h
  rescue
    {}
  end

  def load_ecommerce_dashboard_data
    # Product counts — two queries (status is a string enum, group by is the cleanest)
    product_status_counts = Product.group(:status).count rescue {}
    @total_products     = product_status_counts.values.sum
    @active_products    = product_status_counts['active'] || 0
    @draft_products     = product_status_counts['draft']  || 0

    category_counts = Category.group(:status).count rescue {}
    @total_categories  = category_counts.values.sum
    @active_categories = category_counts[true] || 0

    # All Booking counts + revenue in 2 queries instead of 7+
    booking_status_counts  = Booking.group(:status).count
    booking_payment_counts = Booking.group(:payment_status).count
    @total_bookings    = booking_status_counts.values.sum
    @pending_bookings  = booking_status_counts['ordered_and_delivery_pending'] || booking_status_counts['pending'] || 0
    @completed_bookings = booking_status_counts['completed'] || 0
    @cancelled_bookings = booking_status_counts['cancelled'] || 0

    # Revenue in 1 conditional SUM query instead of 3 separate full-table scans
    today_start = Date.current.beginning_of_day
    month_start = Date.current.beginning_of_month.beginning_of_day
    revenue_row = Booking.select(Arel.sql(
      "COALESCE(SUM(total_amount), 0)                                                    AS total_rev,
       COALESCE(SUM(CASE WHEN created_at >= '#{today_start}' THEN total_amount ELSE 0 END), 0) AS today_rev,
       COALESCE(SUM(CASE WHEN created_at >= '#{month_start}'  THEN total_amount ELSE 0 END), 0) AS month_rev"
    )).take
    @total_revenue = revenue_row.total_rev.to_f
    @today_revenue = revenue_row.today_rev.to_f
    @month_revenue = revenue_row.month_rev.to_f
    @avg_order_value = @total_bookings > 0 ? (@total_revenue / @total_bookings).round(2) : 0

    # Order metrics — 1 GROUP BY instead of 5 queries
    order_counts = begin Order.group(:status).count rescue {} end
    @total_orders     = order_counts.values.sum
    @pending_orders   = order_counts['pending']   || 0
    @shipped_orders   = order_counts['shipped']   || 0
    @delivered_orders = order_counts['delivered'] || 0
    @cancelled_orders = order_counts['cancelled'] || 0

    # Vendor metrics
    @total_vendors       = Vendor.count rescue 0
    @active_vendors      = Vendor.where(status: true).count rescue 0
    @total_purchases     = VendorPurchase.count rescue 0
    @pending_purchases   = VendorPurchase.where(status: 'pending').count rescue 0
    @total_purchase_value = VendorPurchase.sum(:total_amount) rescue 0
    @pending_payments    = VendorPayment.where(status: 'pending').sum(:amount) rescue 0

    # Store metrics
    @total_stores  = Store.count rescue 0
    @active_stores = Store.where(status: true).count rescue 0

    # Inventory metrics
    @total_stock_value    = Product.sum('price * stock').to_f
    @low_stock_products   = Product.where('stock <= 5 AND stock > 0').count
    @out_of_stock_products = Product.where(stock: 0).count
    @top_categories = calculate_top_categories

    # Low stock via stock_batches
    @low_stock_count = Product
      .joins("LEFT JOIN stock_batches ON stock_batches.product_id = products.id
              AND stock_batches.status = 'active'
              AND stock_batches.store_id IS NULL")
      .group("products.id")
      .having("COALESCE(SUM(stock_batches.quantity_remaining), 0) <= COALESCE(products.low_stock_threshold, 5)")
      .count.size rescue @low_stock_products

    # Pending payments — 1 query instead of 2
    unpaid_row = Booking.where(payment_status: 'unpaid')
                        .select(Arel.sql("COUNT(*) AS cnt, COALESCE(SUM(total_amount), 0) AS total"))
                        .take
    @pending_payments_count  = unpaid_row&.cnt.to_i
    @pending_payments_amount = unpaid_row&.total.to_f

    @pending_orders_count = @total_bookings -
      (booking_status_counts.slice('completed', 'cancelled', 'returned', 'delivered').values.sum)

    # Customer metrics — 1 query
    @total_customers         = Customer.count
    @new_customers_this_month = Customer.where(created_at: month_start..Date.current.end_of_month).count

    # Chart data
    @sales_trend               = calculate_sales_trend
    @category_performance      = calculate_category_performance
    @order_status_distribution = calculate_order_status_distribution
    @top_selling_products      = calculate_top_selling_products
    @monthly_revenue_trend     = calculate_monthly_revenue_trend
    @payment_method_distribution = calculate_payment_method_distribution
    @delivery_performance      = calculate_delivery_performance

    # Growth metrics
    calculate_ecommerce_growth_metrics

    @conversion_rate   = @total_customers > 0 ? ((@total_bookings.to_f / @total_customers) * 100).round(2) : 0
    @customer_location = calculate_customer_locations
  end

  private

  def calculate_top_categories
    # Get top 5 categories by product count
    begin
      Category.joins(:products)
              .group('categories.name')
              .order('COUNT(products.id) DESC')
              .limit(5)
              .count
    rescue
      # Return sample data if there's an error
      Category.limit(5).pluck(:name).map { |name| [name, rand(5..20)] }.to_h
    end
  end

  def calculate_sales_trend
    start_day = 6.days.ago.beginning_of_day
    rows = Booking.where(created_at: start_day..Time.current.end_of_day)
                  .group(Arel.sql("TO_CHAR(created_at, 'YYYY-MM-DD')"))
                  .sum(:total_amount)
    trend = {}
    7.times do |i|
      date = Date.current - i.days
      trend[date.strftime('%a')] = rows[date.strftime('%Y-%m-%d')].to_f
    end
    trend.to_a.reverse.to_h
  rescue
    {}
  end

  def calculate_category_performance
    BookingItem.joins(:booking, product: :category)
               .group('categories.name')
               .sum('booking_items.quantity * booking_items.price')
               .reject { |_, v| v.to_f == 0 }
               .sort_by { |_, v| -v }
               .to_h
  rescue
    {}
  end

  def calculate_order_status_distribution
    {
      'Pending' => @pending_orders,
      'Shipped' => @shipped_orders,
      'Delivered' => @delivered_orders,
      'Cancelled' => @cancelled_orders
    }
  end

  def calculate_top_selling_products
    # Top 5 products by quantity sold
    BookingItem.joins(:product, :booking)
               .group('products.name')
               .order('SUM(booking_items.quantity) DESC')
               .limit(5)
               .sum(:quantity)
  end

  def calculate_monthly_revenue_trend
    start_month = 5.months.ago.beginning_of_month.beginning_of_day
    rows = Booking.where(created_at: start_month..Time.current.end_of_month)
                  .group(Arel.sql("TO_CHAR(created_at, 'Mon YYYY')"))
                  .sum(:total_amount)
    trend = {}
    6.times do |i|
      month_date = (Date.current - i.months).beginning_of_month
      key = month_date.strftime('%b %Y')
      trend[key] = rows[key].to_f
    end
    trend.to_a.reverse.to_h
  rescue
    {}
  end

  def calculate_payment_method_distribution
    counts = Booking.group(:payment_method).count
    {
      'Cash'   => counts['cash'].to_i,
      'Card'   => counts['card'].to_i,
      'UPI'    => counts['upi'].to_i,
      'Online' => counts['online'].to_i
    }
  end

  def calculate_delivery_performance
    begin
      delivered_on_time = Order.where('delivered_at <= created_at + INTERVAL \'3 days\'').count
      total_delivered = Order.where.not(delivered_at: nil).count

      {
        on_time_percentage: total_delivered > 0 ? ((delivered_on_time.to_f / total_delivered) * 100).round(1) : 0,
        total_delivered: total_delivered,
        avg_delivery_days: total_delivered > 0 ? 3.2 : 0  # Sample data
      }
    rescue
      {
        on_time_percentage: 0,
        total_delivered: 0,
        avg_delivery_days: 0
      }
    end
  end

  def calculate_ecommerce_growth_metrics
    cur_start  = Date.current.beginning_of_month.beginning_of_day
    prev_start = 1.month.ago.beginning_of_month.beginning_of_day
    prev_end   = 1.month.ago.end_of_month.end_of_day

    # 2 queries instead of 6: one conditional SUM/COUNT for bookings, one for customers
    booking_row = Booking.select(Arel.sql(
      "COALESCE(SUM(CASE WHEN created_at >= '#{cur_start}'  THEN total_amount ELSE 0 END), 0) AS cur_rev,
       COUNT(CASE WHEN created_at >= '#{cur_start}'                             THEN 1 END)   AS cur_cnt,
       COALESCE(SUM(CASE WHEN created_at BETWEEN '#{prev_start}' AND '#{prev_end}' THEN total_amount ELSE 0 END), 0) AS prev_rev,
       COUNT(CASE WHEN created_at BETWEEN '#{prev_start}' AND '#{prev_end}'        THEN 1 END) AS prev_cnt"
    )).take

    customer_row = Customer.select(Arel.sql(
      "COUNT(CASE WHEN created_at >= '#{cur_start}'                                 THEN 1 END) AS cur_cnt,
       COUNT(CASE WHEN created_at BETWEEN '#{prev_start}' AND '#{prev_end}'         THEN 1 END) AS prev_cnt"
    )).take

    @revenue_growth              = calculate_percentage_change(booking_row.cur_rev.to_f,  booking_row.prev_rev.to_f)
    @order_growth                = calculate_percentage_change(booking_row.cur_cnt.to_i,  booking_row.prev_cnt.to_i)
    @customer_acquisition_growth = calculate_percentage_change(customer_row.cur_cnt.to_i, customer_row.prev_cnt.to_i)

    @conversion_rate     = @total_customers > 0 ? ((@total_bookings.to_f / @total_customers) * 100).round(1) : 0
    @inventory_turnover  = @total_stock_value > 0 ? (@total_revenue / @total_stock_value).round(2) : 0
  end

  def calculate_customer_locations
    # Get top customer locations by state/city
    begin
      customer_locations = Customer.where.not(state: [nil, ''])
                                  .group(:state)
                                  .count
                                  .sort_by { |state, count| -count }
                                  .first(10)

      # Return hash with state as key and count as value
      Hash[customer_locations]
    rescue
      # Return empty hash if there's any error or no data
      {}
    end
  end
end

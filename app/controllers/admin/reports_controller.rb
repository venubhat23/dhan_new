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

    @customer_growth = []
    (0..6).each do |i|
      date = (6-i).days.ago.to_date
      count = Customer.where('DATE(created_at) = ?', date).count
      @customer_growth << { date: date.strftime('%b %d'), count: count }
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

      @revenue_by_day = []
      (0..6).each do |i|
        date = (6-i).days.ago.to_date
        revenue = Order.where('DATE(created_at) = ?', date).sum(:total_amount)
        @revenue_by_day << { date: date.strftime('%b %d'), revenue: revenue }
      end
    elsif defined?(Booking)
      @total_revenue = Booking.where(created_at: start_date..Time.current).sum(:total_amount)
      @total_orders = Booking.where(created_at: start_date..Time.current).count
      @average_order_value = @total_orders > 0 ? (@total_revenue / @total_orders).round(2) : 0

      @revenue_by_day = []
      (0..6).each do |i|
        date = (6-i).days.ago.to_date
        revenue = Booking.where('DATE(created_at) = ?', date).sum(:total_amount)
        @revenue_by_day << { date: date.strftime('%b %d'), revenue: revenue }
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
  def profit_loss
    @from_date = params[:from_date].present? ? Date.parse(params[:from_date]) : Date.current.beginning_of_month
    @to_date   = params[:to_date].present?   ? Date.parse(params[:to_date])   : Date.current

    items = BookingItem.joins(:booking)
                       .includes(:product)
                       .where(bookings: { booking_date: @from_date.beginning_of_day..@to_date.end_of_day })

    product_data = {}
    items.each do |item|
      product = item.product
      next unless product

      qty       = item.quantity.to_f
      revenue   = qty * item.price.to_f
      cost_each = product.buying_price.to_f
      cost      = qty * cost_each
      profit    = revenue - cost

      if product_data[product.id]
        d = product_data[product.id]
        d[:qty_sold] += qty
        d[:revenue]  += revenue
        d[:cost]     += cost
        d[:profit]   += profit
      else
        product_data[product.id] = {
          name:          product.name,
          unit_type:     product.unit_type || 'Pcs',
          selling_price: item.price.to_f,
          cost_price:    cost_each,
          qty_sold:      qty,
          revenue:       revenue,
          cost:          cost,
          profit:        profit
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

    if params[:download] == 'csv'
      send_data generate_profit_loss_csv(@product_rows, @totals, @from_date, @to_date),
                filename: "profit_loss_#{@from_date.strftime('%Y%m%d')}_#{@to_date.strftime('%Y%m%d')}.csv",
                type: 'text/csv',
                disposition: 'attachment'
    end
  rescue => e
    Rails.logger.error "Error in profit_loss: #{e.message}"
    @product_rows = []
    @totals = { qty_sold: 0, revenue: 0, cost: 0, profit: 0 }
  end

  private

  def build_enhanced_sales_data
    # Get all invoices in the date range (both regular and booking invoices)
    regular_invoices = Invoice.includes(:customer, :invoice_items)
                             .where(invoice_date: @from_date..@to_date)
                             .order(:invoice_date)

    booking_invoices = BookingInvoice.includes(:customer, :booking)
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
                  (invoice.respond_to?(:booking) ? invoice.booking&.booking_items&.count || 0 : 0) :
                  invoice.invoice_items.count

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
          if item.product&.gst_enabled && item.product.gst_percentage > 0
            base_amount = (item.quantity || 0) * (item.price || 0)
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
          if item.product&.gst_enabled && item.product.gst_percentage > 0
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
      csv << ['Product', 'Unit', 'Qty Sold', 'Selling Price (₹)', 'Cost Price (₹)', 'Revenue (₹)', 'Cost (₹)', 'Profit/Loss (₹)']
      rows.each do |r|
        csv << [
          r[:name],
          r[:unit_type],
          r[:qty_sold].to_s.sub(/\.0$/, ''),
          r[:selling_price].round(2),
          r[:cost_price].round(2),
          r[:revenue].round(2),
          r[:cost].round(2),
          r[:profit].round(2)
        ]
      end
      csv << []
      csv << ['TOTAL', '', totals[:qty_sold].to_s.sub(/\.0$/, ''), '', '', totals[:revenue].round(2), totals[:cost].round(2), totals[:profit].round(2)]
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
class Admin::CustomerFormatsController < Admin::ApplicationController
  before_action :set_customer_format, only: [:show, :edit, :update, :destroy, :toggle_status]
  before_action :check_sidebar_permission
  skip_before_action :check_sidebar_permission, only: [:import_from_master]

  def index
    @customer_formats = CustomerFormat.includes(:customer, :product, :delivery_person)

    # Apply filters
    @customer_formats = filter_by_status(@customer_formats)
    @customer_formats = filter_by_customer(@customer_formats)
    @customer_formats = filter_by_pattern(@customer_formats)

    @customer_formats = @customer_formats.order(created_at: :desc).page(params[:page]).per(20)

    # For filter options
    @customers = Customer.all.pluck(:full_name, :id)
    @products = Product.where(status: 'active').pluck(:name, :id)
    @delivery_people = DeliveryPerson.where(status: true).pluck(:first_name, :last_name, :id).map { |f, l, id| ["#{f} #{l}".strip, id] }

    # Summary statistics
    @stats = calculate_customer_format_stats

    respond_to do |format|
      format.html
      format.json { render json: @customer_formats }
    end
  end

  def show
  end

  def new
    @customer_format = CustomerFormat.new
    load_form_data
  end

  def create
    @customer_format = CustomerFormat.new(customer_format_params)

    if @customer_format.save
      redirect_to admin_customer_format_path(@customer_format), notice: 'Customer format created successfully!'
    else
      load_form_data
      render :new
    end
  end

  def edit
    load_form_data
  end

  def update
    if @customer_format.update(customer_format_params)
      redirect_to admin_customer_format_path(@customer_format), notice: 'Customer format updated successfully!'
    else
      load_form_data
      render :edit
    end
  end

  def destroy
    @customer_format.destroy
    redirect_to admin_customer_formats_path, notice: 'Customer format deleted successfully!'
  end

  def toggle_status
    new_status = @customer_format.status == 'active' ? 'not_active' : 'active'
    @customer_format.update(status: new_status)
    status_text = new_status == 'active' ? 'activated' : 'deactivated'
    redirect_to admin_customer_formats_path, notice: "Customer format #{status_text} successfully!"
  end

  # Search helpers for AJAX calls
  def search_customers
    term = params[:q]
    customers = Customer.where("full_name ILIKE ?", "%#{term}%")
                       .limit(20)
                       .pluck(:full_name, :id)
                       .map { |name, id| { id: id, text: name } }
    render json: { results: customers }
  end

  def search_products
    term = params[:q]
    products = Product.where(status: 'active')
                     .where("name ILIKE ?", "%#{term}%")
                     .limit(20)
                     .pluck(:name, :id)
                     .map { |name, id| { id: id, text: name } }
    render json: { results: products }
  end

  def search_delivery_people
    term = params[:q]
    delivery_people = DeliveryPerson.where(status: true)
                                   .where("CONCAT(first_name, ' ', last_name) ILIKE ?", "%#{term}%")
                                   .limit(20)
                                   .pluck(:first_name, :last_name, :id)
                                   .map { |f, l, id| { id: id, text: "#{f} #{l}".strip } }
    render json: { results: delivery_people }
  end

  # Import page action
  def import_page
    # Summary statistics for the import page
    @stats = calculate_customer_format_stats

    # Get detailed format information
    @active_formats = CustomerFormat.includes(:customer, :product, :delivery_person).where(status: 'active').limit(50)

    respond_to do |format|
      format.html
    end
  end

  # Import from Master Subscription action
  def import_from_master
    month = params[:month].to_i
    year = params[:year].to_i

    # Validate parameters
    if month < 1 || month > 12 || year < Date.current.year || year > Date.current.year + 5
      respond_to do |format|
        format.json { render json: { success: false, message: 'Invalid month or year selected.' }, status: :bad_request }
      end
      return
    end

    begin
      Rails.logger.info "Starting master subscription import for #{month}/#{year}"

      start_date = Date.new(year, month, 1)
      end_date = start_date.end_of_month

      processed_count = 0
      subscription_count = 0
      task_count = 0

      # Process only active customer formats
      CustomerFormat.active.includes(:customer, :product, :delivery_person).find_each do |customer_format|
        Rails.logger.info "Processing customer format #{customer_format.id} for customer #{customer_format.customer.id}"

        # Step 1: Create Subscription (avoid duplicates)
        subscription = find_or_create_subscription(customer_format, start_date, end_date)

        if subscription
          subscription_count += 1 if subscription.persisted?

          # Step 2: Create Daily Tasks based on pattern
          tasks_created = create_daily_tasks(customer_format, subscription, start_date, end_date)
          task_count += tasks_created

          processed_count += 1
        end
      end

      message = "Import process completed successfully. #{processed_count} formats processed, #{subscription_count} subscriptions, #{task_count} tasks created."
      Rails.logger.info message

      respond_to do |format|
        format.json { render json: { success: true, message: message } }
      end
    rescue => e
      Rails.logger.error "Error in master subscription import: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      respond_to do |format|
        format.json { render json: { success: false, message: "Import failed: #{e.message}" }, status: :internal_server_error }
      end
    end
  end

  private

  def set_customer_format
    @customer_format = CustomerFormat.find_by(id: params[:id])
    unless @customer_format
      redirect_to admin_customer_formats_path, alert: 'Customer format not found.'
    end
  end

  def customer_format_params
    params.require(:customer_format).permit(:customer_id, :pattern, :quantity, :product_id, :delivery_person_id, :status, days: [])
  end

  def load_form_data
    @customers = Customer.all.map { |c| ["#{c.full_name} - #{c.mobile}", c.id] }
    @products = Product.where(status: 'active').map { |p| [p.name, p.id] }
    @delivery_people = DeliveryPerson.where(status: true).map { |dp| ["#{dp.first_name} #{dp.last_name}", dp.id] }
    @pattern_options = CustomerFormat::PATTERN_OPTIONS.map { |pattern| [pattern.humanize, pattern] }
    @status_options = CustomerFormat::STATUS_OPTIONS.map { |status| [status.humanize, status] }
  end

  def filter_by_status(customer_formats)
    if params[:status].present?
      customer_formats.where(status: params[:status])
    else
      customer_formats
    end
  end

  def filter_by_customer(customer_formats)
    if params[:customer_id].present?
      customer_formats.where(customer_id: params[:customer_id])
    else
      customer_formats
    end
  end

  def filter_by_pattern(customer_formats)
    if params[:pattern].present?
      customer_formats.where(pattern: params[:pattern])
    else
      customer_formats
    end
  end

  def calculate_customer_format_stats
    total = CustomerFormat.count
    active = CustomerFormat.where(status: 'active').count
    inactive = CustomerFormat.where(status: 'not_active').count

    pattern_counts = CustomerFormat.group(:pattern).count

    {
      total: total,
      active: active,
      inactive: inactive,
      pattern_counts: pattern_counts
    }
  end

  def find_or_create_subscription(customer_format, start_date, end_date)
    # Check for existing subscription to avoid duplicates
    existing_subscription = MilkSubscription.find_by(
      customer: customer_format.customer,
      product: customer_format.product,
      start_date: start_date,
      end_date: end_date
    )

    return existing_subscription if existing_subscription

    # Create new subscription
    MilkSubscription.create!(
      customer: customer_format.customer,
      product: customer_format.product,
      delivery_person: customer_format.delivery_person,
      quantity: customer_format.quantity,
      unit: 'liter', # Default unit
      start_date: start_date,
      end_date: end_date,
      delivery_time: '07:00', # Default delivery time
      is_active: true
    )
  rescue => e
    Rails.logger.error "Error creating subscription for customer format #{customer_format.id}: #{e.message}"
    nil
  end

  def create_daily_tasks(customer_format, subscription, start_date, end_date)
    tasks_created = 0
    task_dates = calculate_task_dates(customer_format, start_date, end_date)

    # Batch insert for performance
    tasks_to_insert = []

    task_dates.each do |task_date|
      # Check if task already exists to prevent duplicates
      existing_task = MilkDeliveryTask.find_by(
        subscription: subscription,
        customer: customer_format.customer,
        product: customer_format.product,
        delivery_date: task_date
      )

      next if existing_task

      tasks_to_insert << {
        subscription_id: subscription.id,
        customer_id: customer_format.customer.id,
        product_id: customer_format.product.id,
        delivery_person_id: customer_format.delivery_person.id,
        quantity: customer_format.quantity,
        delivery_date: task_date,
        status: 'pending',
        created_at: Time.current,
        updated_at: Time.current
      }
    end

    # Batch insert tasks
    if tasks_to_insert.any?
      MilkDeliveryTask.insert_all(tasks_to_insert)
      tasks_created = tasks_to_insert.size
    end

    Rails.logger.info "Created #{tasks_created} tasks for customer format #{customer_format.id}"
    tasks_created
  end

  def calculate_task_dates(customer_format, start_date, end_date)
    case customer_format.pattern
    when 'every_day'
      (start_date..end_date).to_a
    when 'alternative_day'
      dates = []
      current_date = start_date
      day_counter = 1
      while current_date <= end_date
        dates << current_date if day_counter.odd?
        current_date += 1.day
        day_counter += 1
      end
      dates
    when 'weekly_once'
      calculate_weekly_tasks(start_date, end_date, 1)
    when 'weekly_twice'
      calculate_weekly_tasks(start_date, end_date, 2)
    when 'weekly_thrice'
      calculate_weekly_tasks(start_date, end_date, 3)
    when 'weekly_four'
      calculate_weekly_tasks(start_date, end_date, 4)
    when 'weekly_five'
      calculate_weekly_tasks(start_date, end_date, 5)
    when 'weekly_six'
      calculate_weekly_tasks(start_date, end_date, 6)
    when 'random'
      calculate_random_tasks(customer_format, start_date, end_date)
    else
      []
    end
  end

  def calculate_weekly_tasks(start_date, end_date, tasks_per_week)
    dates = []
    current_week_start = start_date.beginning_of_week

    while current_week_start <= end_date
      week_end = [current_week_start.end_of_week, end_date].min

      # Get weekdays in this week that fall within our date range
      week_dates = (current_week_start..week_end).select do |date|
        date >= start_date && date <= end_date && date.wday.between?(1, 5) # Monday to Friday
      end

      # Take the first N days of the week based on tasks_per_week
      selected_dates = week_dates.take(tasks_per_week)
      dates.concat(selected_dates)

      current_week_start += 1.week
    end

    dates
  end

  def calculate_random_tasks(customer_format, start_date, end_date)
    # Use the model's selected_days method which properly handles JSON serialization
    selected_days = customer_format.selected_days
    return [] if selected_days.empty?

    dates = []
    current_date = start_date

    while current_date <= end_date
      # Check if current date's day of month is in selected days
      if selected_days.include?(current_date.day)
        dates << current_date
      end
      current_date += 1.day
    end

    Rails.logger.info "Random pattern for customer format #{customer_format.id}: selected days #{selected_days}, generated #{dates.size} task dates"
    dates
  end

  def check_sidebar_permission
    unless current_user && current_user.has_sidebar_permission?('customer_formats')
      redirect_to admin_dashboard_path, alert: 'You do not have permission to access this page.'
    end
  end
end

class ImportMasterSubscriptionJob < ApplicationJob
  queue_as :default

  def perform(month, year)
    Rails.logger.info "Starting master subscription import for #{month}/#{year}"

    begin
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

      Rails.logger.info "Master subscription import completed: #{processed_count} formats processed, #{subscription_count} subscriptions, #{task_count} tasks created"

    rescue => e
      Rails.logger.error "Error in master subscription import: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise e
    end
  end

  private

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

    # One query for all already-existing dates instead of a find_by per date
    # (this used to run ~30 queries per customer format for a month import).
    existing_dates = MilkDeliveryTask.where(
      subscription: subscription,
      customer: customer_format.customer,
      product: customer_format.product,
      delivery_date: task_dates
    ).pluck(:delivery_date).to_set

    # Batch insert for performance
    tasks_to_insert = []

    task_dates.each do |task_date|
      # Check if task already exists to prevent duplicates
      next if existing_dates.include?(task_date)

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
end
class Admin::SubscriptionsController < Admin::ApplicationController
  before_action :set_subscription, only: [:show, :edit, :update, :destroy, :toggle_status, :pause_subscription, :resume_subscription, :delivery_schedule, :generate_tasks, :daily_tasks]
  before_action :check_sidebar_permission

  def index
    @subscriptions = MilkSubscription.includes(:customer, :product, milk_delivery_tasks: :delivery_person)

    # Apply filters
    @subscriptions = filter_by_status(@subscriptions)
    @subscriptions = filter_by_date_range(@subscriptions)
    @subscriptions = filter_by_customer(@subscriptions)
    @subscriptions = filter_by_delivery_person(@subscriptions)

    @subscriptions = @subscriptions.order(created_at: :desc).page(params[:page]).per(20)

    # For filter options
    @customers = Customer.all.pluck(:full_name, :id)
    @products = Product.where(product_type: 'milk').pluck(:name, :id)
    @delivery_people = DeliveryPerson.where(status: true).pluck(:first_name, :last_name, :id).map { |f, l, id| ["#{f} #{l}".strip, id] }

    # Summary statistics
    @stats = calculate_subscription_stats

    respond_to do |format|
      format.html
      format.json { render json: @subscriptions }
    end
  end

  def show
    @delivery_tasks = @subscription.milk_delivery_tasks.includes(:delivery_person).order(:delivery_date)
    @summary = @subscription.subscription_summary

    # Customer pattern data for sidebar
    @customer_patterns = MilkSubscription.joins(:customer)
                                        .joins("LEFT JOIN milk_delivery_tasks ON milk_subscriptions.id = milk_delivery_tasks.subscription_id AND DATE(milk_delivery_tasks.delivery_date) = DATE(NOW())")
                                        .select("customers.full_name, customers.id as customer_id,
                                               COUNT(DISTINCT milk_subscriptions.id) as total_subscriptions,
                                               COUNT(milk_delivery_tasks.id) as daily_tasks_count")
                                        .group("customers.id, customers.full_name")
                                        .order("customers.full_name")
  end

  def new
    @subscription = MilkSubscription.new
    @customers = Customer.all.map { |c| ["#{c.full_name} - #{c.mobile}", c.id] }
    # Show all active products or products suitable for subscriptions
    @products = Product.where(status: 'active').map { |p| [p.name, p.id] }
    @delivery_people = DeliveryPerson.where(status: true).map { |dp| ["#{dp.first_name} #{dp.last_name}", dp.id] }
  end

  def create
    products_data = params[:subscription][:products] || {}

    if products_data.empty?
      flash.now[:alert] = 'Please select at least one product for the subscription.'
      @customers = Customer.all.map { |c| ["#{c.full_name} - #{c.mobile}", c.id] }
      @products = Product.where(status: 'active').map { |p| [p.name, p.id] }
      @delivery_people = DeliveryPerson.where(status: true).map { |dp| ["#{dp.first_name} #{dp.last_name}", dp.id] }
      render :new
      return
    end

    created_subscriptions = []
    created_tasks = []
    errors = []

    MilkSubscription.transaction do
      products_data.each do |index, product_data|
        next if product_data[:product_id].blank?

        subscription_attributes = subscription_params.merge(
          product_id: product_data[:product_id],
          quantity: product_data[:quantity],
          unit: product_data[:unit] || 'liter',
          created_by: current_user.id
        )

        subscription = MilkSubscription.new(subscription_attributes)
        subscription.total_amount = subscription.calculate_total_amount

        if subscription.save
          created_subscriptions << subscription

          # Generate daily delivery tasks for this subscription
          tasks_count = generate_delivery_tasks_for_subscription(subscription)
          created_tasks << { subscription: subscription, tasks_count: tasks_count }
        else
          errors << "Product #{Product.find(product_data[:product_id]).name}: #{subscription.errors.full_messages.join(', ')}"
        end
      end

      if errors.any?
        raise ActiveRecord::Rollback
      end
    end

    if errors.any?
      flash.now[:alert] = "Failed to create subscriptions: #{errors.join('; ')}"
      @customers = Customer.all.map { |c| ["#{c.full_name} - #{c.mobile}", c.id] }
      @products = Product.where(status: 'active').map { |p| [p.name, p.id] }
      @delivery_people = DeliveryPerson.where(status: true).map { |dp| ["#{dp.first_name} #{dp.last_name}", dp.id] }
      render :new
    else
      total_tasks = created_tasks.sum { |ct| ct[:tasks_count] }
      message = "Successfully created #{created_subscriptions.count} subscriptions with #{total_tasks} delivery tasks!"

      if created_subscriptions.count == 1
        redirect_to admin_subscription_path(created_subscriptions.first), notice: message
      else
        redirect_to admin_subscriptions_path, notice: message
      end
    end
  end

  def edit
    @customers = Customer.all.map { |c| ["#{c.full_name} - #{c.mobile}", c.id] }
    @products = Product.where(status: 'active').map { |p| [p.name, p.id] }
    @delivery_people = DeliveryPerson.where(status: true).map { |dp| ["#{dp.first_name} #{dp.last_name}", dp.id] }
  end

  def update
    # Check if delivery person is being changed
    delivery_person_changed = @subscription.delivery_person_id != subscription_params[:delivery_person_id].to_i
    old_delivery_person = @subscription.delivery_person
    new_delivery_person_id = subscription_params[:delivery_person_id]

    if @subscription.update(subscription_params)
      # If delivery person changed, update all related delivery tasks
      if delivery_person_changed
        update_result = update_delivery_tasks_for_subscription(@subscription, new_delivery_person_id)

        new_delivery_person = DeliveryPerson.find(new_delivery_person_id) if new_delivery_person_id.present?
        old_name = old_delivery_person&.display_name || 'Not Assigned'
        new_name = new_delivery_person&.display_name || 'Not Assigned'

        update_message = "Subscription updated successfully! Delivery person changed from #{old_name} to #{new_name}."

        if update_result[:tasks] > 0 || update_result[:formats] > 0
          update_message += " Updated #{update_result[:tasks]} delivery tasks (including completed ones) and #{update_result[:formats]} customer formats."
        else
          update_message += " No delivery tasks found to update."
        end

        redirect_to admin_subscription_path(@subscription), notice: update_message
      else
        redirect_to admin_subscription_path(@subscription), notice: 'Subscription updated successfully!'
      end
    else
      @customers = Customer.all.map { |c| ["#{c.full_name} - #{c.mobile}", c.id] }
      @products = Product.where(status: 'active').map { |p| [p.name, p.id] }
      @delivery_people = DeliveryPerson.where(status: true).map { |dp| ["#{dp.first_name} #{dp.last_name}", dp.id] }
      render :edit
    end
  end

  def destroy
    @subscription.destroy
    redirect_to admin_subscriptions_path, notice: 'Subscription deleted successfully!'
  end

  def toggle_status
    new_status = @subscription.is_active? ? false : true
    @subscription.update(is_active: new_status)
    status_text = new_status ? 'activated' : 'deactivated'
    redirect_to admin_subscriptions_path, notice: "Subscription #{status_text} successfully!"
  end

  def pause_subscription
    @subscription.update(status: 'paused', is_active: false)
    # Pause all future delivery tasks (not completed ones)
    @subscription.milk_delivery_tasks.where(status: 'pending', delivery_date: Date.current..).update_all(status: 'paused')

    paused_tasks_count = @subscription.milk_delivery_tasks.where(status: 'paused').count
    redirect_to admin_subscription_path(@subscription),
                notice: "Subscription paused successfully! #{paused_tasks_count} pending delivery tasks have been paused."
  end

  def resume_subscription
    @subscription.update(status: 'active', is_active: true)
    # Resume all paused delivery tasks
    resumed_tasks_count = @subscription.milk_delivery_tasks.where(status: 'paused').update_all(status: 'pending')

    redirect_to admin_subscription_path(@subscription),
                notice: "Subscription resumed successfully! #{resumed_tasks_count} delivery tasks have been resumed."
  end

  def delivery_schedule
    @delivery_tasks = @subscription.milk_delivery_tasks.includes(:delivery_person).order(:delivery_date)
    render json: @delivery_tasks.as_json(include: { delivery_person: { only: [:first_name, :last_name] } })
  end

  def generate_tasks
    # Regenerate tasks (useful if subscription was modified)
    @subscription.milk_delivery_tasks.destroy_all
    @subscription.generate_all_delivery_tasks
    redirect_to admin_subscription_path(@subscription), notice: 'Delivery tasks regenerated successfully!'
  end

  def daily_tasks
    unless @subscription
      render json: { error: 'Subscription not found' }, status: :not_found and return
    end

    @delivery_tasks = @subscription.milk_delivery_tasks.includes(:delivery_person).order(:delivery_date)

    # Calculate current average quantity from tasks
    current_avg_quantity = @delivery_tasks.any? ? @delivery_tasks.average(:quantity).round(2) : @subscription.quantity
    current_total_quantity = @delivery_tasks.sum(:quantity).round(2)

    # Prepare data for JSON response
    subscription_data = {
      customer_name: @subscription.customer.full_name,
      product_name: @subscription.product.name,
      original_quantity: @subscription.quantity,
      current_avg_quantity: current_avg_quantity,
      current_total_quantity: current_total_quantity,
      quantity: current_avg_quantity, # For backward compatibility
      unit: @subscription.unit,
      delivery_pattern: @subscription.delivery_pattern.humanize,
      start_date: @subscription.start_date.strftime('%d %b %Y'),
      end_date: @subscription.end_date.strftime('%d %b %Y')
    }

    # Calculate summary
    total_tasks = @delivery_tasks.count
    completed_tasks = @delivery_tasks.where(status: 'completed').count
    pending_tasks = @delivery_tasks.where(status: 'pending').count
    completion_rate = total_tasks > 0 ? (completed_tasks.to_f / total_tasks * 100).round(1) : 0

    summary_data = {
      total: total_tasks,
      completed: completed_tasks,
      pending: pending_tasks,
      completion_rate: completion_rate
    }

    # Prepare tasks data
    tasks_data = @delivery_tasks.map do |task|
      {
        id: task.id,
        delivery_date: task.delivery_date.strftime('%Y-%m-%d'),
        quantity: task.quantity,
        unit: @subscription.unit,
        status: task.status,
        completed_at: task.completed_at,
        delivery_person: task.delivery_person ? {
          id: task.delivery_person.id,
          name: "#{task.delivery_person.first_name} #{task.delivery_person.last_name}".strip
        } : nil
      }
    end

    render json: {
      subscription: subscription_data,
      summary: summary_data,
      tasks: tasks_data
    }
  end

  # Filter actions
  def active
    redirect_to admin_subscriptions_path(status: 'active')
  end

  def paused
    redirect_to admin_subscriptions_path(status: 'paused')
  end

  def expired
    redirect_to admin_subscriptions_path(status: 'expired')
  end

  # Generate daily tasks for all active subscriptions
  def generate_all_daily_tasks
    begin
      active_subscriptions = MilkSubscription.where(status: 'active', is_active: true)

      if active_subscriptions.empty?
        render json: {
          success: false,
          message: 'No active subscriptions found to generate tasks for.'
        }
        return
      end

      total_tasks_generated = 0
      subscriptions_processed = 0
      failed_subscriptions = []

      active_subscriptions.find_each do |subscription|
        begin
          tasks_count = generate_delivery_tasks_for_subscription(subscription)
          total_tasks_generated += tasks_count
          subscriptions_processed += 1
        rescue => e
          failed_subscriptions << {
            subscription_id: subscription.id,
            error: e.message
          }
        end
      end

      if failed_subscriptions.any?
        render json: {
          success: false,
          message: "Partially completed. Generated #{total_tasks_generated} tasks for #{subscriptions_processed} subscriptions. #{failed_subscriptions.count} subscriptions failed.",
          details: {
            total_tasks: total_tasks_generated,
            processed: subscriptions_processed,
            failed: failed_subscriptions.count,
            failed_details: failed_subscriptions
          }
        }
      else
        render json: {
          success: true,
          message: "Successfully generated #{total_tasks_generated} daily tasks for #{subscriptions_processed} active subscriptions!",
          details: {
            total_tasks: total_tasks_generated,
            processed: subscriptions_processed,
            active_subscriptions: active_subscriptions.count
          }
        }
      end

    rescue => e
      render json: {
        success: false,
        message: "Error generating daily tasks: #{e.message}"
      }
    end
  end

  private

  def set_subscription
    @subscription = MilkSubscription.find_by(id: params[:id])
    unless @subscription
      respond_to do |format|
        format.html { redirect_to admin_subscriptions_path, alert: 'Subscription not found.' }
        format.json { render json: { error: 'Subscription not found' }, status: :not_found }
      end
    end
  end

  def subscription_params
    params.require(:milk_subscription).permit(
      :customer_id, :product_id, :quantity, :unit, :start_date, :end_date,
      :delivery_time, :delivery_pattern, :specific_dates, :status,
      :is_active, :delivery_person_id
    )
  end

  def filter_by_status(subscriptions)
    if params[:status].present?
      subscriptions.where(status: params[:status])
    else
      subscriptions
    end
  end

  def filter_by_date_range(subscriptions)
    if params[:start_date].present? && params[:end_date].present?
      start_date = Date.parse(params[:start_date])
      end_date = Date.parse(params[:end_date])
      subscriptions.for_date_range(start_date, end_date)
    else
      subscriptions
    end
  end

  def filter_by_customer(subscriptions)
    if params[:customer_id].present?
      subscriptions.where(customer_id: params[:customer_id])
    else
      subscriptions
    end
  end

  def filter_by_delivery_person(subscriptions)
    if params[:delivery_person_id].present?
      subscriptions.joins(:milk_delivery_tasks)
                  .where(milk_delivery_tasks: { delivery_person_id: params[:delivery_person_id] })
                  .distinct
    else
      subscriptions
    end
  end

  def calculate_subscription_stats
    total = MilkSubscription.count
    active = MilkSubscription.where(status: 'active').count
    paused = MilkSubscription.where(status: 'paused').count
    expired = MilkSubscription.where(status: 'expired').count

    today_deliveries = MilkDeliveryTask.for_today.count
    pending_today = MilkDeliveryTask.for_today.pending.count

    # Delivery person statistics
    total_delivery_people = DeliveryPerson.where(status: true).count
    # Count delivery people who have tasks assigned (pending or assigned status)
    assigned_delivery_people = MilkDeliveryTask
      .joins(:delivery_person)
      .where(status: ['pending', 'assigned'])
      .where(delivery_people: { status: true })
      .select(:delivery_person_id)
      .distinct
      .count

    {
      total: total,
      active: active,
      paused: paused,
      expired: expired,
      today_deliveries: today_deliveries,
      pending_today: pending_today,
      total_delivery_people: total_delivery_people,
      assigned_delivery_people: assigned_delivery_people
    }
  end

  def generate_delivery_tasks_for_subscription(subscription)
    return 0 unless subscription.persisted?

    # Delete existing tasks if any
    subscription.milk_delivery_tasks.destroy_all

    delivery_dates = calculate_delivery_dates(subscription)
    tasks_created = 0

    delivery_dates.each do |date|
      task = subscription.milk_delivery_tasks.create!(
        customer: subscription.customer,
        product: subscription.product,
        quantity: subscription.quantity,
        unit: subscription.unit,
        delivery_date: date,
        status: 'pending',
        delivery_person: subscription.delivery_person
      )

      tasks_created += 1 if task.persisted?
    end

    tasks_created
  end

  def calculate_delivery_dates(subscription)
    dates = []
    start_date = subscription.start_date
    end_date = subscription.end_date

    case subscription.delivery_pattern
    when 'daily'
      current_date = start_date
      while current_date <= end_date
        dates << current_date
        current_date += 1.day
      end
    when 'alternate'
      current_date = start_date
      while current_date <= end_date
        dates << current_date
        current_date += 2.days
      end
    when 'specific_dates'
      if subscription.specific_dates.present?
        specific_dates = JSON.parse(subscription.specific_dates)
        specific_dates.each do |date_str|
          date = Date.parse(date_str)
          dates << date if date >= start_date && date <= end_date
        end
      end
    end

    dates.sort
  end

  def check_sidebar_permission
    return if action_name == 'daily_tasks' # Allow daily_tasks without sidebar permission check
    unless current_user && current_user.has_sidebar_permission?('subscriptions')
      respond_to do |format|
        format.html { redirect_to admin_dashboard_path, alert: 'You do not have permission to access this page.' }
        format.json { render json: { error: 'Permission denied' }, status: :forbidden }
      end
    end
  end

  def update_delivery_tasks_for_subscription(subscription, new_delivery_person_id)
    # Update ALL delivery tasks for this subscription (including completed ones)
    all_tasks = subscription.milk_delivery_tasks

    updated_tasks_count = 0
    updated_formats_count = 0

    MilkDeliveryTask.transaction do
      # Update ALL delivery tasks for this subscription
      all_tasks.find_each do |task|
        if new_delivery_person_id.present?
          task.update!(delivery_person_id: new_delivery_person_id)
        else
          task.update!(delivery_person_id: nil)
        end
        updated_tasks_count += 1
      end

      # Update CustomerFormat records for this customer and product combination
      if defined?(CustomerFormat)
        customer_formats = CustomerFormat.where(
          customer: subscription.customer,
          product: subscription.product
        )

        customer_formats.find_each do |format|
          if new_delivery_person_id.present?
            format.update!(delivery_person_id: new_delivery_person_id)
          else
            format.update!(delivery_person_id: nil)
          end
          updated_formats_count += 1
        end
      end
    end

    Rails.logger.info "Updated #{updated_tasks_count} delivery tasks (all tasks) and #{updated_formats_count} customer formats for subscription #{subscription.id}"
    { tasks: updated_tasks_count, formats: updated_formats_count }
  rescue => e
    Rails.logger.error "Failed to update delivery tasks for subscription #{subscription.id}: #{e.message}"
    raise e
  end
end
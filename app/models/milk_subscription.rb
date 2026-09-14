class MilkSubscription < ApplicationRecord
  belongs_to :customer
  belongs_to :product
  belongs_to :delivery_person, optional: true
  has_many :milk_delivery_tasks, foreign_key: 'subscription_id', dependent: :destroy

  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :start_date, :end_date, presence: true
  validate :end_date_after_start_date

  enum :status, { active: 'active', paused: 'paused', expired: 'expired', cancelled: 'cancelled' }
  enum :delivery_pattern, { daily: 'daily', alternate: 'alternate', specific_dates: 'specific_dates' }

  scope :active_subscriptions, -> { where(status: 'active', is_active: true) }
  scope :for_date_range, ->(start_date, end_date) { where('start_date <= ? AND end_date >= ?', end_date, start_date) }

  after_create :generate_all_delivery_tasks

  def total_days
    return 0 unless start_date && end_date
    (end_date - start_date).to_i + 1
  end

  def delivery_dates_array
    return [] unless start_date && end_date

    case delivery_pattern
    when 'daily'
      (start_date..end_date).to_a
    when 'alternate'
      dates = []
      current_date = start_date
      while current_date <= end_date
        dates << current_date
        current_date += 2.days
      end
      dates
    when 'specific_dates'
      return [] unless specific_dates.present?
      JSON.parse(specific_dates).map { |date| Date.parse(date) } rescue []
    else
      []
    end
  end

  def generate_all_delivery_tasks
    delivery_dates_array.each do |date|
      milk_delivery_tasks.create!(
        customer: customer,
        product: product,
        quantity: quantity,
        unit: unit,
        delivery_date: date,
        status: 'pending',
        delivery_person: delivery_person
      )
    end
  end

  # These four run 4 separate COUNT queries each by default (`.where(...).count`
  # always hits the DB, ignoring any preload) — the subscriptions index page
  # preloads `milk_delivery_tasks` specifically so this can tally in Ruby instead.
  def completed_deliveries_count
    task_status_counts['completed'] || 0
  end

  def pending_deliveries_count
    task_status_counts['pending'] || 0
  end

  def total_deliveries_count
    milk_delivery_tasks.loaded? ? milk_delivery_tasks.size : milk_delivery_tasks.count
  end

  def completion_percentage
    return 0 if total_deliveries_count == 0
    (completed_deliveries_count.to_f / total_deliveries_count * 100).round(2)
  end

  def paused_deliveries_count
    task_status_counts['paused'] || 0
  end

  def task_status_counts
    @task_status_counts ||= if milk_delivery_tasks.loaded?
      milk_delivery_tasks.group_by(&:status).transform_values(&:size)
    else
      milk_delivery_tasks.group(:status).count
    end
  end

  def can_be_paused?
    status == 'active' && is_active?
  end

  def can_be_resumed?
    status == 'paused'
  end

  def pause_all_tasks!
    milk_delivery_tasks.where(status: 'pending', delivery_date: Date.current..).update_all(status: 'paused')
    update!(status: 'paused', is_active: false)
  end

  def resume_all_tasks!
    milk_delivery_tasks.where(status: 'paused').update_all(status: 'pending')
    update!(status: 'active', is_active: true)
  end

  def subscription_summary
    {
      total_days: total_days,
      total_deliveries: total_deliveries_count,
      completed: completed_deliveries_count,
      pending: pending_deliveries_count,
      paused: paused_deliveries_count,
      completion_rate: completion_percentage
    }
  end

  def total_quantity
    (delivery_dates_array.count * quantity).round(2)
  end

  def calculate_total_amount
    price_per_unit = product&.price || 0
    (total_quantity * price_per_unit).round(2)
  end

  def current_delivery_person
    # Get the delivery person from the most recent assigned task or upcoming task
    recent_task = milk_delivery_tasks
                    .joins(:delivery_person)
                    .where('delivery_date >= ?', Date.current - 7.days)
                    .where.not(delivery_person_id: nil)
                    .order(:delivery_date)
                    .first

    return recent_task&.delivery_person if recent_task

    # If no recent assigned task, get from the next upcoming task
    upcoming_task = milk_delivery_tasks
                      .joins(:delivery_person)
                      .where('delivery_date >= ?', Date.current)
                      .where.not(delivery_person_id: nil)
                      .order(:delivery_date)
                      .first

    upcoming_task&.delivery_person
  end

  def self.generate_subscription_number
    last_subscription = MilkSubscription.order(:created_at).last
    if last_subscription && last_subscription.id
      "SUB-#{Date.current.strftime('%Y')}-#{sprintf('%04d', last_subscription.id + 1)}"
    else
      "SUB-#{Date.current.strftime('%Y')}-0001"
    end
  end

  # Current quantity methods for showing updated quantities
  def current_average_quantity
    return quantity unless milk_delivery_tasks.any?
    (current_total_quantity_raw / milk_delivery_tasks.size).round(2)
  end

  def current_total_quantity
    return total_quantity unless milk_delivery_tasks.any?
    current_total_quantity_raw.round(2)
  end

  # `.sum(:quantity)`/`.average(:quantity)` (a column-arg sum) always hit the
  # DB even when milk_delivery_tasks is preloaded — reuse the loaded records.
  def current_total_quantity_raw
    if milk_delivery_tasks.loaded?
      milk_delivery_tasks.sum { |t| t.quantity.to_f }
    else
      milk_delivery_tasks.sum(:quantity).to_f
    end
  end

  def has_quantity_changes?
    return false unless milk_delivery_tasks.any?
    current_average_quantity != quantity
  end

  private

  def end_date_after_start_date
    return unless start_date && end_date
    errors.add(:end_date, 'must be after start date') if end_date < start_date
  end
end
class StaffMember < ApplicationRecord
  belongs_to :store
  has_many :staff_attendances, dependent: :destroy
  has_many :staff_payments, dependent: :destroy

  STATUSES = %w[active inactive].freeze

  validates :name, presence: true
  validates :monthly_salary, numericality: { greater_than_or_equal_to: 0 }
  validates :status, inclusion: { in: STATUSES }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  scope :active, -> { where(status: 'active') }
  scope :inactive, -> { where(status: 'inactive') }

  def active?
    status == 'active'
  end

  # Filters the preloaded association in Ruby when it's loaded (index pages
  # call this per row after `.includes(:staff_payments)`) instead of issuing
  # a fresh scoped query every call.
  def paid_for(month, year)
    if staff_payments.loaded?
      staff_payments.select { |p| p.month == month && p.year == year }.sum { |p| p.amount.to_f }
    else
      staff_payments.where(month: month, year: year).sum(:amount)
    end
  end

  def pending_for(month, year)
    [monthly_salary.to_f - paid_for(month, year).to_f, 0].max
  end

  def attendance_summary_for(month, year)
    counts = staff_attendances
             .where(attendance_date: Date.new(year, month, 1)..Date.new(year, month, -1))
             .group(:status).count
    {
      'present'  => counts['present'] || 0,
      'absent'   => counts['absent'] || 0,
      'half_day' => counts['half_day'] || 0,
      'leave'    => counts['leave'] || 0
    }
  end
end

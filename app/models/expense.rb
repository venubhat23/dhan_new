class Expense < ApplicationRecord
  belongs_to :store
  belongs_to :created_by, class_name: 'User'

  validates :title, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :expense_date, presence: true
  validates :category, presence: true
  validates :store_id, presence: true

  CATEGORIES = [
    'Rent & Utilities',
    'Staff Salaries',
    'Inventory Purchase',
    'Equipment & Maintenance',
    'Marketing & Advertising',
    'Transportation',
    'Office Supplies',
    'Professional Services',
    'Insurance',
    'Withdrawal for Self',
    'Miscellaneous'
  ].freeze

  scope :by_date_range, ->(start_date, end_date) { where(expense_date: start_date..end_date) }
  scope :by_category, ->(category) { where(category: category) }
  scope :recent, -> { order(expense_date: :desc, created_at: :desc) }

  def formatted_amount
    "₹#{amount.to_f.round(2)}"
  end

  def category_icon
    case category
    when 'Rent & Utilities' then 'bi bi-building'
    when 'Staff Salaries' then 'bi bi-people'
    when 'Inventory Purchase' then 'bi bi-boxes'
    when 'Equipment & Maintenance' then 'bi bi-tools'
    when 'Marketing & Advertising' then 'bi bi-megaphone'
    when 'Transportation' then 'bi bi-truck'
    when 'Office Supplies' then 'bi bi-pencil'
    when 'Professional Services' then 'bi bi-briefcase'
    when 'Insurance' then 'bi bi-shield-check'
    when 'Withdrawal for Self' then 'bi bi-person-dash'
    else 'bi bi-receipt'
    end
  end
end

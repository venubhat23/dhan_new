# Chart of Accounts used by Manual Journals (Zoho Books style). Income/expense
# type accounts feed the Profit & Loss report; the rest (cash, bank, assets,
# liabilities, equity) are the balancing side of a journal.
class LedgerAccount < ApplicationRecord
  TYPES = [
    ['income',             'Income',              'Income'],
    ['other_income',       'Other Income',        'Income'],
    ['expense',            'Expense',             'Expense'],
    ['cost_of_goods_sold', 'Cost of Goods Sold',  'Expense'],
    ['other_expense',      'Other Expense',       'Expense'],
    ['cash',               'Cash',                'Asset'],
    ['bank',               'Bank',                'Asset'],
    ['asset',              'Other Asset',         'Asset'],
    ['liability',          'Liability',           'Liability'],
    ['equity',             'Equity',              'Equity']
  ].freeze
  TYPE_LABELS = TYPES.to_h { |k, l, _| [k, l] }.freeze
  TYPE_GROUPS = TYPES.to_h { |k, _, g| [k, g] }.freeze
  PL_TYPES = %w[income other_income expense cost_of_goods_sold other_expense].freeze
  CREDIT_NATURE = %w[income other_income liability equity].freeze

  has_many :manual_journal_lines, dependent: :restrict_with_error
  has_many :receipt_lines, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :account_type, inclusion: { in: TYPE_LABELS.keys }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name) }

  def type_label = TYPE_LABELS[account_type]
  def group_label = TYPE_GROUPS[account_type]
  def pl_account? = PL_TYPES.include?(account_type)

  # Net movement in the account's natural direction (expense: Dr − Cr,
  # income/liability/equity: Cr − Dr) from published journal lines.
  def balance(lines = manual_journal_lines.joins(:manual_journal).merge(ManualJournal.published))
    dr = lines.sum(:debit).to_f
    cr = lines.sum(:credit).to_f
    (CREDIT_NATURE.include?(account_type) ? cr - dr : dr - cr).round(2)
  end

  # [[group label, [[name, id], ...]], ...] for a grouped <select>.
  def self.grouped_options(scope = active.ordered)
    accounts = scope.to_a
    TYPES.filter_map do |key, label, _|
      list = accounts.select { |a| a.account_type == key }
      [label, list.map { |a| [a.name, a.id] }] if list.any?
    end
  end
end

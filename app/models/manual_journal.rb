# Zoho-Books-style Manual Journal: a dated, balanced set of debit/credit lines
# against Chart of Accounts entries. Published journals feed the Profit & Loss
# report (expense/income accounts); drafts are ignored everywhere.
class ManualJournal < ApplicationRecord
  include DashboardCacheBust

  REPORTING_METHODS = [
    ['accrual_and_cash', 'Accrual and Cash'],
    ['accrual_only',     'Accrual Only'],
    ['cash_only',        'Cash Only']
  ].freeze
  STATUSES = %w[draft published].freeze

  belongs_to :store, optional: true
  belongs_to :created_by, class_name: 'User', optional: true
  has_many :manual_journal_lines, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :manual_journal
  has_many :ledger_accounts, through: :manual_journal_lines

  accepts_nested_attributes_for :manual_journal_lines, allow_destroy: true,
                                reject_if: ->(a) { a['ledger_account_id'].blank? && a['debit'].to_f.zero? && a['credit'].to_f.zero? }

  validates :journal_number, presence: true, uniqueness: true, numericality: { only_integer: true, greater_than: 0 }
  validates :journal_date, presence: true
  validates :notes, presence: true, length: { maximum: 500 }
  validates :reporting_method, inclusion: { in: REPORTING_METHODS.map(&:first) }
  validates :status, inclusion: { in: STATUSES }
  validate :lines_are_valid

  before_validation :assign_journal_number, on: :create
  before_save :compute_total

  scope :published, -> { where(status: 'published') }
  # System journals posted by AutoJournal (invoices, payments, purchases) vs. ones typed in by hand.
  scope :automatic, -> { where.not(source_type: nil) }
  scope :manual_only, -> { where(source_type: nil) }
  scope :drafts, -> { where(status: 'draft') }
  scope :recent, -> { order(journal_date: :desc, journal_number: :desc) }
  # Journals that count for a given P&L basis.
  scope :for_basis, ->(basis) { where(reporting_method: basis == 'cash' ? %w[accrual_and_cash cash_only] : %w[accrual_and_cash accrual_only]) }

  def self.next_number = (maximum(:journal_number) || 0) + 1

  def published? = status == 'published'
  def draft? = status == 'draft'
  def automatic? = source_type.present?
  def entry_kind_label = AutoJournal::KINDS[entry_kind]

  # The invoice / purchase / payment an auto journal was posted from.
  def source_record
    return unless automatic?
    @source_record ||= source_type.safe_constantize&.find_by(id: source_id)
  end

  def reporting_method_label = REPORTING_METHODS.to_h[reporting_method]

  def live_lines = manual_journal_lines.reject(&:marked_for_destruction?)
  def total_debit  = live_lines.sum { |l| l.debit.to_f }.round(2)
  def total_credit = live_lines.sum { |l| l.credit.to_f }.round(2)
  def difference   = (total_debit - total_credit).round(2)

  def publish!
    update!(status: 'published', published_at: Time.current)
  end

  def mark_draft!
    update!(status: 'draft', published_at: nil)
  end

  private

  def assign_journal_number
    self.journal_number ||= self.class.next_number
  end

  def compute_total
    self.total_amount = total_debit
  end

  def lines_are_valid
    lines = live_lines
    if lines.size < 2
      errors.add(:base, 'A journal needs at least two lines (one debit and one credit)')
      return
    end
    lines.each_with_index do |l, i|
      errors.add(:base, "Line #{i + 1}: choose an account") if l.ledger_account_id.blank?
      if l.debit.to_f.positive? && l.credit.to_f.positive?
        errors.add(:base, "Line #{i + 1}: enter either a debit or a credit, not both")
      elsif l.debit.to_f <= 0 && l.credit.to_f <= 0
        errors.add(:base, "Line #{i + 1}: enter a debit or credit amount")
      end
      errors.add(:base, "Line #{i + 1}: amounts can't be negative") if l.debit.to_f.negative? || l.credit.to_f.negative?
    end
    if difference.nonzero?
      errors.add(:base, "Debits (₹#{format('%.2f', total_debit)}) and credits (₹#{format('%.2f', total_credit)}) must be equal — difference ₹#{format('%.2f', difference.abs)}")
    end
  end
end

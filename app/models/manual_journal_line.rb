class ManualJournalLine < ApplicationRecord
  belongs_to :manual_journal, inverse_of: :manual_journal_lines
  belongs_to :ledger_account

  # Signed amount in the account's natural direction (positive = increases it).
  def natural_amount
    dr, cr = debit.to_f, credit.to_f
    LedgerAccount::CREDIT_NATURE.include?(ledger_account&.account_type) ? cr - dr : dr - cr
  end
end

class ReceiptLine < ApplicationRecord
  belongs_to :receipt, inverse_of: :receipt_lines
  belongs_to :ledger_account

  # The empty side is stored as 0 (NOT NULL columns), so a blank box doesn't fail the insert.
  before_validation { self.debit ||= 0; self.credit ||= 0 }
end

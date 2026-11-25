class AddPaymentDetailsToManualJournals < ActiveRecord::Migration[8.0]
  def change
    # How the journal was settled (cash / bank / upi) plus bank-statement details.
    add_column :manual_journals, :payment_mode, :string
    add_column :manual_journals, :bank_date, :date
    add_column :manual_journals, :bank_narration, :string
    add_column :manual_journals, :opening_balance, :decimal, precision: 14, scale: 2
    add_column :manual_journals, :closing_balance, :decimal, precision: 14, scale: 2
  end
end

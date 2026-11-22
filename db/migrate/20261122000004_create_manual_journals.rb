class CreateManualJournals < ActiveRecord::Migration[8.0]
  def change
    create_table :ledger_accounts do |t|
      t.string  :name, null: false
      t.string  :account_type, null: false
      t.string  :code
      t.text    :description
      t.boolean :active, null: false, default: true
      t.boolean :system, null: false, default: false
      t.timestamps
    end
    add_index :ledger_accounts, 'LOWER(name)', unique: true, name: 'index_ledger_accounts_on_lower_name'
    add_index :ledger_accounts, :account_type

    create_table :manual_journals do |t|
      t.integer    :journal_number, null: false
      t.date       :journal_date, null: false
      t.string     :reference_number
      t.text       :notes, null: false
      t.string     :reporting_method, null: false, default: 'accrual_and_cash'
      t.string     :currency, null: false, default: 'INR'
      t.string     :status, null: false, default: 'draft'
      t.decimal    :total_amount, precision: 14, scale: 2, null: false, default: 0
      t.references :store, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.datetime   :published_at
      t.timestamps
    end
    add_index :manual_journals, :journal_number, unique: true
    add_index :manual_journals, [:status, :journal_date]

    create_table :manual_journal_lines do |t|
      t.references :manual_journal, null: false, foreign_key: true
      t.references :ledger_account, null: false, foreign_key: true
      t.string  :description
      t.string  :contact_name
      t.decimal :debit,  precision: 14, scale: 2, null: false, default: 0
      t.decimal :credit, precision: 14, scale: 2, null: false, default: 0
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    reversible do |dir|
      dir.up do
        now = Time.current
        rows = {
          'expense' => ['Advertising And Marketing', 'Bank Fees and Charges', 'Delivery Associate Wages', 'Fuel Expenses',
                        'IT and Internet Expenses', 'Meals and Entertainment', 'Other Expenses', 'Professional Charges',
                        'Rent Expense', 'Repairs and Maintenance', 'Salaries and Employee Wages', 'Software Expenses',
                        'Staff Welfare Exp', 'Printing and Stationery', 'Telephone Expense', 'Travel Expense',
                        'Electricity Expense', 'Packing Materials', 'Postage and Courier', 'Insurance Expense'],
          'cost_of_goods_sold' => ['Purchase Freight', 'Job Work Charges'],
          'income' => ['Other Charges Income'],
          'other_income' => ['Interest Income', 'Discount Received', 'Other Income'],
          'other_expense' => ['Interest Expense', 'Depreciation', 'Bad Debts'],
          'cash' => ['Petty Cash', 'Cash in Hand', 'Undeposited Funds'],
          'bank' => ['Bank Account'],
          'asset' => ['Advance to Staff', 'Prepaid Expenses', 'Accounts Receivable', 'Furniture and Equipment'],
          'liability' => ['Accounts Payable', 'GST Payable', 'TDS Payable', 'Salary Payable', 'Expenses Payable'],
          'equity' => ["Owner's Capital", "Owner's Drawings", 'Opening Balance Adjustments']
        }
        records = rows.flat_map do |type, names|
          names.map { |n| { name: n, account_type: type, active: true, system: true, created_at: now, updated_at: now } }
        end
        execute <<~SQL.squish if records.any?
          INSERT INTO ledger_accounts (name, account_type, active, system, created_at, updated_at) VALUES
          #{records.map { |r| "(#{quote(r[:name])}, #{quote(r[:account_type])}, true, true, #{quote(now)}, #{quote(now)})" }.join(', ')}
          ON CONFLICT DO NOTHING
        SQL
      end
    end
  end
end

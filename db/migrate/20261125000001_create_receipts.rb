class CreateReceipts < ActiveRecord::Migration[8.0]
  def change
    create_table :receipts do |t|
      t.integer :receipt_number, null: false
      t.date :receipt_date, null: false
      t.string :reference_number
      t.text :notes, null: false
      t.string :reporting_method, null: false, default: 'accrual_and_cash'
      t.string :currency, null: false, default: 'INR'
      t.string :status, null: false, default: 'draft'
      t.decimal :total_amount, precision: 14, scale: 2, null: false, default: 0
      t.references :store, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.datetime :published_at
      t.timestamps
    end
    add_index :receipts, :receipt_number, unique: true
    add_index :receipts, [:status, :receipt_date]

    create_table :receipt_lines do |t|
      t.references :receipt, null: false, foreign_key: { on_delete: :cascade }
      t.references :ledger_account, null: false, foreign_key: true
      t.string :description
      t.string :contact_name
      t.decimal :debit, precision: 14, scale: 2, null: false, default: 0
      t.decimal :credit, precision: 14, scale: 2, null: false, default: 0
      t.integer :position, null: false, default: 0
      t.timestamps
    end
  end
end

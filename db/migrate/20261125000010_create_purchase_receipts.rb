class CreatePurchaseReceipts < ActiveRecord::Migration[8.0]
  def change
    create_table :purchase_receipts do |t|
      t.string :receipt_number, null: false
      t.date :receipt_date, null: false
      # one receipt per vendor purchase; nil = manual receipt
      t.references :vendor_purchase, foreign_key: { on_delete: :nullify }, index: { unique: true }
      t.references :vendor, foreign_key: { on_delete: :nullify }
      t.references :created_by, foreign_key: { to_table: :users }
      t.string :source, null: false, default: 'manual' # auto (vendor purchase created) / manual

      # Snapshot of the vendor purchase
      t.string :purchase_number
      t.date :purchase_date
      t.string :vendor_name
      t.string :vendor_phone
      t.string :vendor_email
      t.text :vendor_address
      t.string :vendor_gst_no
      t.jsonb :items, null: false, default: []
      t.decimal :amount, precision: 14, scale: 2, null: false, default: 0
      t.string :payment_mode # cash / upi / bank
      t.string :reference_number
      t.text :notes

      # Bank reconciliation (Update Bank Info modal)
      t.date :bank_date
      t.text :bank_narration
      t.decimal :bank_opening_balance, precision: 14, scale: 2
      t.decimal :bank_closing_balance, precision: 14, scale: 2

      t.timestamps
    end
    add_index :purchase_receipts, :receipt_number, unique: true
    add_index :purchase_receipts, :receipt_date
  end
end

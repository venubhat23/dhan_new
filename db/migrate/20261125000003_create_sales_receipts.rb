class CreateSalesReceipts < ActiveRecord::Migration[8.0]
  def change
    create_table :sales_receipts do |t|
      t.string :receipt_number, null: false
      t.date :receipt_date, null: false
      t.references :booking, foreign_key: true, index: { unique: true } # one receipt per booking; nil = manual
      t.references :customer, foreign_key: true
      t.references :store, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.string :source, null: false, default: 'manual' # auto (booking marked paid) / manual

      # Snapshot of the booking at the time it was paid
      t.string :booking_number
      t.string :invoice_number
      t.string :customer_name
      t.string :customer_phone
      t.string :customer_email
      t.text :customer_address
      t.string :gstin
      t.datetime :booking_date
      t.jsonb :items, null: false, default: []
      t.decimal :subtotal, precision: 14, scale: 2, default: 0
      t.decimal :tax_amount, precision: 14, scale: 2, default: 0
      t.decimal :discount_amount, precision: 14, scale: 2, default: 0
      t.decimal :shipping_charges, precision: 14, scale: 2, default: 0
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
    add_index :sales_receipts, :receipt_number, unique: true
    add_index :sales_receipts, :receipt_date
  end
end

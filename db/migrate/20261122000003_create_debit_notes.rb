class CreateDebitNotes < ActiveRecord::Migration[8.0]
  def change
    create_table :debit_notes do |t|
      t.string     :debit_note_number, null: false
      t.references :vendor_purchase, null: false, foreign_key: true
      t.references :vendor,          null: false, foreign_key: true
      t.references :user,            foreign_key: true # admin who issued it
      t.date       :debit_date, null: false
      t.decimal    :total_amount, precision: 12, scale: 2, null: false, default: 0
      t.string     :settlement_method
      t.string     :reason
      t.text       :notes
      t.timestamps
    end
    add_index :debit_notes, :debit_note_number, unique: true
    add_index :debit_notes, :debit_date

    create_table :debit_note_items do |t|
      t.references :debit_note,           null: false, foreign_key: true
      t.references :vendor_purchase_item, null: false, foreign_key: true
      t.references :stock_batch,          foreign_key: true
      t.references :product,              null: false, foreign_key: true
      t.references :product_variant,      foreign_key: true
      t.decimal :quantity,   precision: 10, scale: 2, null: false
      t.decimal :unit_price, precision: 12, scale: 2, null: false, default: 0
      t.decimal :amount,     precision: 12, scale: 2, null: false, default: 0
      t.timestamps
    end
  end
end

class CreateCreditNotes < ActiveRecord::Migration[8.0]
  def change
    create_table :credit_notes do |t|
      t.string     :credit_note_number, null: false
      t.references :booking,  null: false, foreign_key: true
      t.references :customer, foreign_key: true
      t.references :store,    foreign_key: true
      t.references :user,     foreign_key: true # admin who issued it
      t.date       :credit_date, null: false
      t.decimal    :total_amount, precision: 12, scale: 2, null: false, default: 0
      t.string     :refund_method
      t.string     :reason
      t.text       :notes
      t.timestamps
    end
    add_index :credit_notes, :credit_note_number, unique: true
    add_index :credit_notes, :credit_date

    create_table :credit_note_items do |t|
      t.references :credit_note,  null: false, foreign_key: true
      t.references :booking_item, null: false, foreign_key: true
      t.references :product,      null: false, foreign_key: true
      t.references :product_variant, foreign_key: true
      t.decimal :quantity,   precision: 8,  scale: 2, null: false
      t.decimal :unit_price, precision: 12, scale: 2, null: false, default: 0
      t.decimal :amount,     precision: 12, scale: 2, null: false, default: 0
      t.timestamps
    end
  end
end

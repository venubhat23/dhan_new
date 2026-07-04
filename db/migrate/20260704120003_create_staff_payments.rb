class CreateStaffPayments < ActiveRecord::Migration[7.1]
  def change
    create_table :staff_payments do |t|
      t.references :staff_member, null: false, foreign_key: true
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.date :payment_date, null: false
      t.integer :month, null: false
      t.integer :year, null: false
      t.text :notes

      t.timestamps
    end

    add_index :staff_payments, [:staff_member_id, :year, :month], name: 'index_staff_payments_on_member_and_period'
  end
end

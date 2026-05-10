class CreateStockTransfers < ActiveRecord::Migration[7.1]
  def change
    create_table :stock_transfers do |t|
      t.references :from_store, null: true, foreign_key: { to_table: :stores }
      t.references :to_store, null: false, foreign_key: { to_table: :stores }
      t.references :product, null: false, foreign_key: true
      t.references :requested_by, null: false, foreign_key: { to_table: :users }
      t.references :approved_by, null: true, foreign_key: { to_table: :users }
      t.decimal :quantity, precision: 10, scale: 2, null: false
      t.string :status, null: false, default: 'pending'
      t.text :notes
      t.text :rejection_reason
      t.datetime :approved_at
      t.datetime :completed_at
      t.timestamps
    end

    add_index :stock_transfers, :status
  end
end

class CreateExpenses < ActiveRecord::Migration[8.0]
  def change
    create_table :expenses do |t|
      t.references :store, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.text :description
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :category, null: false
      t.date :expense_date, null: false

      t.timestamps
    end

    add_index :expenses, [:store_id, :expense_date]
    add_index :expenses, :category
  end
end

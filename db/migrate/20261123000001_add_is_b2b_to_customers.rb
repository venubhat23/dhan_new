class AddIsB2bToCustomers < ActiveRecord::Migration[8.0]
  def change
    add_column :customers, :is_b2b, :boolean, default: false, null: false
    add_index :customers, :is_b2b
  end
end

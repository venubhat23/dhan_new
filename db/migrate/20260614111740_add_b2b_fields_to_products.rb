class AddB2bFieldsToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :b2b_price, :decimal, precision: 10, scale: 2
    add_column :products, :b2b_percentage, :decimal, precision: 5, scale: 2
  end
end

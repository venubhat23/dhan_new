class AddCommissionPercentageToStores < ActiveRecord::Migration[8.0]
  def change
    add_column :stores, :commission_percentage, :decimal, precision: 5, scale: 2, default: 0.0
  end
end

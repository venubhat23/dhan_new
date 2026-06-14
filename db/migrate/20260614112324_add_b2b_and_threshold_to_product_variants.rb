class AddB2bAndThresholdToProductVariants < ActiveRecord::Migration[8.0]
  def change
    add_column :product_variants, :purchase_price, :decimal, precision: 10, scale: 2
    add_column :product_variants, :b2b_price,      :decimal, precision: 10, scale: 2
    add_column :product_variants, :b2b_percentage, :decimal, precision: 5,  scale: 2
    add_column :product_variants, :low_stock_threshold, :integer, default: 10
  end
end

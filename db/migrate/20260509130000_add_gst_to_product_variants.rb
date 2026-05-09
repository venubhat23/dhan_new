class AddGstToProductVariants < ActiveRecord::Migration[8.0]
  def change
    add_column :product_variants, :gst_percentage, :decimal, precision: 5, scale: 2
    add_column :product_variants, :gst_amount,     :decimal, precision: 10, scale: 2
    add_column :product_variants, :final_price_with_gst, :decimal, precision: 10, scale: 2
  end
end

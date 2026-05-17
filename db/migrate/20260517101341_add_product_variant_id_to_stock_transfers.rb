class AddProductVariantIdToStockTransfers < ActiveRecord::Migration[8.0]
  def change
    add_column :stock_transfers, :product_variant_id, :bigint
  end
end

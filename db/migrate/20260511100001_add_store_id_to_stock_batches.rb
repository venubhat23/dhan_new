class AddStoreIdToStockBatches < ActiveRecord::Migration[7.1]
  def change
    add_reference :stock_batches, :store, null: true, foreign_key: true, index: true
    add_index :stock_batches, [:product_id, :store_id]
  end
end

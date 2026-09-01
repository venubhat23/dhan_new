class AddStoreInventories < ActiveRecord::Migration[8.0]
  def change
    create_table :store_inventories do |t|
      t.references :store, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.references :product_variant, null: true, foreign_key: true
      t.decimal :quantity, precision: 12, scale: 3, default: 0, null: false
      t.integer :low_stock_threshold, default: 10, null: false

      t.timestamps
    end

    add_index :store_inventories,
              [:store_id, :product_id, :product_variant_id],
              unique: true,
              name: "index_store_inventories_uniqueness"

    unless column_exists?(:stock_batches, :product_variant_id)
      add_reference :stock_batches, :product_variant, null: true, foreign_key: true
    end
  end
end

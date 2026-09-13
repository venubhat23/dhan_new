class AddStoreShowPerformanceIndexes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    # admin/stores#show filters this store's bookings by status and by a
    # created_at window on top of store_id; only single-column indexes existed
    # so Postgres had to bitmap-AND two indexes (or scan) instead of a single
    # index scan.
    add_index :bookings, [:store_id, :status], algorithm: :concurrently, if_not_exists: true
    add_index :bookings, [:store_id, :created_at], algorithm: :concurrently, if_not_exists: true

    # Store#store_inventory_summary (fallback path) filters stock_batches by
    # store_id + status.
    add_index :stock_batches, [:store_id, :status], algorithm: :concurrently, if_not_exists: true

    # Store#store_inventory_summary's pending transfer counts filter
    # stock_transfers by status plus to_store_id/from_store_id.
    add_index :stock_transfers, [:to_store_id, :status], algorithm: :concurrently, if_not_exists: true
    add_index :stock_transfers, [:from_store_id, :status], algorithm: :concurrently, if_not_exists: true
  end
end

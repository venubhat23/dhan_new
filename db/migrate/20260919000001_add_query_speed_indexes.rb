class AddQuerySpeedIndexes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    # admin/customers#index (and the store_admin copy, and the dashboard's
    # "new customers" figures) order/filter by created_at; only name/mobile/email
    # indexes existed, so every page load sorted the whole table.
    add_index :customers, :created_at, algorithm: :concurrently, if_not_exists: true

    # Status-filtered booking lists (/bookings/pending, /confirmed, ...) filter on
    # status and sort newest-first; a status-only index still left a sort.
    add_index :bookings, [:status, :created_at], algorithm: :concurrently, if_not_exists: true,
              name: 'index_bookings_on_status_and_created_at'

    # A customer's order history (mobile app + customer portal + customer show)
    # is `where(customer_id:).order(created_at: :desc)`.
    add_index :bookings, [:customer_id, :created_at], algorithm: :concurrently, if_not_exists: true,
              name: 'index_bookings_on_customer_id_and_created_at'

    # Active-stock sums (StockBatch.active / Product::REAL_STOCK_SQL / store stock
    # overlay) run on almost every list and picker. This partial, covering index
    # holds exactly the rows they read, so they can be answered index-only.
    add_index :stock_batches, [:product_id, :store_id], algorithm: :concurrently, if_not_exists: true,
              where: "status = 'active' AND quantity_remaining > 0",
              include: [:quantity_remaining, :product_variant_id],
              name: 'index_stock_batches_active_stock'

    # Role has_many :users — the roles screen counts/loads users per role_id,
    # and only the legacy string `role` column was indexed.
    add_index :users, :role_id, algorithm: :concurrently, if_not_exists: true

    # leads had no indexes at all; the index screen groups by stage and sorts
    # newest-first.
    add_index :leads, :current_stage, algorithm: :concurrently, if_not_exists: true
    add_index :leads, :created_at, algorithm: :concurrently, if_not_exists: true
  end
end

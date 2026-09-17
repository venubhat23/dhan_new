class AddProductsBookingsInventoryPerfIndexes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    # admin/products#index orders by created_at (the `recent` scope) under
    # Kaminari pagination with no supporting index — Postgres had to sort the
    # entire filtered result set to satisfy LIMIT/OFFSET.
    add_index :products, :created_at, algorithm: :concurrently, if_not_exists: true

    # store_admin/bookings#index (and #new/#edit) order the customer picker by
    # Customer.order(:full_name).limit(500). Only a trigram GIN index existed
    # on full_name, which speeds up ILIKE but doesn't help an ORDER BY sort.
    add_index :customers, :full_name, algorithm: :concurrently, if_not_exists: true,
              name: 'index_customers_on_full_name'

    # Product#booking_items (has_many) had no index on the FK at all — used by
    # admin/products#dependencies, #destroy/#bulk_action (DEPENDENT_RELATIONS),
    # and store_admin's store_products lookup.
    add_index :booking_items, :product_id, algorithm: :concurrently, if_not_exists: true
  end
end

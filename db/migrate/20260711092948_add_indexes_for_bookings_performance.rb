class AddIndexesForBookingsPerformance < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    # booking_items had NO index on booking_id — every eager load of
    # admin/bookings#index (and the booking show/edit pages) did a full
    # table scan of booking_items to join back to the current page of bookings.
    add_index :booking_items, :booking_id, algorithm: :concurrently, if_not_exists: true

    # admin/bookings#index filters/sorts on these — currently full table scans
    # once the bookings table grows past what fits in memory.
    add_index :bookings, :status, algorithm: :concurrently, if_not_exists: true
    add_index :bookings, :created_at, algorithm: :concurrently, if_not_exists: true
    add_index :bookings, :user_id, algorithm: :concurrently, if_not_exists: true
    add_index :bookings, :payment_status, algorithm: :concurrently, if_not_exists: true

    # The "associated invoice" lookup for bookings without a BookingInvoice
    # scans invoice_items.description with a leading-wildcard LIKE on every
    # single page load. A trigram GIN index lets Postgres use an index scan
    # for that instead of a sequential scan.
    enable_extension 'pg_trgm' unless extension_enabled?('pg_trgm')
    add_index :invoice_items, :description,
              using: :gin, opclass: :gin_trgm_ops,
              name: 'index_invoice_items_on_description_trgm',
              algorithm: :concurrently, if_not_exists: true
  end
end

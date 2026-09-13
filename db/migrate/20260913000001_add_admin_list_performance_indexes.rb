class AddAdminListPerformanceIndexes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    enable_extension 'pg_trgm' unless extension_enabled?('pg_trgm')

    # Customer#mobile has a `presence, uniqueness: true` validation and is looked
    # up constantly (quick_create, check_mobile, booking creation, login) but had
    # no DB index at all -- every lookup/uniqueness check was a full table scan.
    # NOTE: existing data has duplicate mobiles, so this can't be made unique yet
    # (see admin/customers -- flagged separately, not fixed here since dedup is
    # a data decision, not a perf one).
    add_index :customers, :mobile, algorithm: :concurrently, if_not_exists: true

    # Customer#email also has a uniqueness validation with no backing index.
    add_index :customers, :email, unique: true, algorithm: :concurrently, if_not_exists: true

    # admin/customers#search_by_name and the customer picker do unanchored
    # ILIKE("%term%") on full_name -- a trigram GIN index lets that use an index
    # scan instead of a sequential scan.
    add_index :customers, :full_name,
              using: :gin, opclass: :gin_trgm_ops,
              name: 'index_customers_on_full_name_trgm',
              algorithm: :concurrently, if_not_exists: true

    # Matches the exact tsvector expression pg_search_scope :search_customers
    # builds (against: [:full_name, :email, :mobile], tsearch) so Postgres can
    # use an index instead of computing to_tsvector for every row on every call.
    execute <<~SQL
      CREATE INDEX CONCURRENTLY IF NOT EXISTS index_customers_on_pg_search_tsvector
      ON customers
      USING gin (
        (
          to_tsvector('simple', coalesce((full_name)::text, '')) ||
          to_tsvector('simple', coalesce((email)::text, '')) ||
          to_tsvector('simple', coalesce((mobile)::text, ''))
        )
      );
    SQL

    # Booking#booking_number has a `presence, uniqueness: true` validation with
    # no backing index; admin/bookings#index also does unanchored LIKE search
    # across all four of these columns on every filtered/searched page load.
    add_index :bookings, :booking_number, unique: true, algorithm: :concurrently, if_not_exists: true
    add_index :bookings, :booking_number,
              using: :gin, opclass: :gin_trgm_ops,
              name: 'index_bookings_on_booking_number_trgm',
              algorithm: :concurrently, if_not_exists: true
    add_index :bookings, :customer_name,
              using: :gin, opclass: :gin_trgm_ops,
              name: 'index_bookings_on_customer_name_trgm',
              algorithm: :concurrently, if_not_exists: true
    add_index :bookings, :customer_email,
              using: :gin, opclass: :gin_trgm_ops,
              name: 'index_bookings_on_customer_email_trgm',
              algorithm: :concurrently, if_not_exists: true
    add_index :bookings, :customer_phone,
              using: :gin, opclass: :gin_trgm_ops,
              name: 'index_bookings_on_customer_phone_trgm',
              algorithm: :concurrently, if_not_exists: true

    # admin/products#index and Product.search do unanchored ILIKE on name & sku.
    add_index :products, :name,
              using: :gin, opclass: :gin_trgm_ops,
              name: 'index_products_on_name_trgm',
              algorithm: :concurrently, if_not_exists: true
    add_index :products, :sku,
              using: :gin, opclass: :gin_trgm_ops,
              name: 'index_products_on_sku_trgm',
              algorithm: :concurrently, if_not_exists: true

    # admin/invoices#index search does unanchored ILIKE on invoice_number.
    add_index :invoices, :invoice_number,
              using: :gin, opclass: :gin_trgm_ops,
              name: 'index_invoices_on_invoice_number_trgm',
              algorithm: :concurrently, if_not_exists: true
  end
end

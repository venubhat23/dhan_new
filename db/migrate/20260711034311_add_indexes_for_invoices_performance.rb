class AddIndexesForInvoicesPerformance < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    # admin/invoices#index filters/joins/orders on these — currently full table scans
    add_index :invoices, :customer_id, algorithm: :concurrently, if_not_exists: true
    add_index :invoices, :payment_status, algorithm: :concurrently, if_not_exists: true
    add_index :invoices, :created_at, algorithm: :concurrently, if_not_exists: true
    add_index :invoices, :invoice_date, algorithm: :concurrently, if_not_exists: true

    # Booking.find_by(invoice_number:) is called from several Invoice callbacks/lookups;
    # customer.bookings is scanned for every customer during invoice generation
    add_index :bookings, :invoice_number, algorithm: :concurrently, if_not_exists: true
    add_index :bookings, :customer_id, algorithm: :concurrently, if_not_exists: true

    # delivery_person_id filter on the invoices page looks these up
    add_index :milk_subscriptions, :delivery_person_id, algorithm: :concurrently, if_not_exists: true
  end
end

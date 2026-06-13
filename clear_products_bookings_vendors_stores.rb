#!/usr/bin/env ruby
# Clears products, bookings, vendors, and stores from the database.
# Run with: RAILS_ENV=production rails runner clear_products_bookings_vendors_stores.rb

puts "=" * 60
puts "CLEARING: Products, Bookings, Vendors, Stores"
puts "=" * 60

# Deletion order respects foreign key constraints:
# Booking dependents -> Bookings -> Product dependents -> Products
# -> Vendor dependents -> Vendors -> Store dependents -> Stores

deletion_order = [
  # Booking dependents
  "BookingInvoice",
  "SaleItem",
  "BookingItem",
  "BookingSchedule",
  "Booking",
  # Product dependents
  "ProductReview",
  "ProductRating",
  "DeliveryRule",
  "StockMovement",
  "VendorInvoice",
  "VendorPayment",
  "VendorPurchaseItem",
  "StockBatch",
  "VendorPurchase",
  "Vendor",
  # All tables referencing products (must go before Product)
  "StockTransfer",
  "Expense",
  "InvoiceItem",
  "Wishlist",
  "MilkDeliveryTask",
  "MilkSubscription",
  "SubscriptionTemplate",
  "CustomerFormat",
  "ProductVariant",
  "Product",
  "Store",
]

puts "\nCounts before deletion:"
deletion_order.each do |model_name|
  klass = model_name.safe_constantize
  next unless klass
  puts "  #{model_name.ljust(22)} #{klass.count}"
end

puts "\nDeleting..."
total_deleted = 0

deletion_order.each do |model_name|
  klass = model_name.safe_constantize
  unless klass
    puts "  SKIP #{model_name} (model not found)"
    next
  end

  count = klass.count
  if count == 0
    puts "  SKIP #{model_name} (0 records)"
    next
  end

  begin
    klass.delete_all
    puts "  DELETED #{model_name}: #{count} records"
    total_deleted += count
  rescue => e
    puts "  ERROR #{model_name}: #{e.message}"
  end
end

puts "\nTotal records deleted: #{total_deleted}"
puts "Done."

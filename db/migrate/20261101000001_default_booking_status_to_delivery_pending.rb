# New bookings now start at Delivery Pending instead of Delivered. Existing rows
# keep their status. Shop Pickup is a new enum value on this string column, so it
# needs no schema change.
class DefaultBookingStatusToDeliveryPending < ActiveRecord::Migration[8.0]
  def change
    change_column_default :bookings, :status, from: 'delivered', to: 'ordered_and_delivery_pending'
  end
end

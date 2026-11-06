# Optional delivery time set alongside expected_delivery_date from the bookings
# list / show modal. Stored as a 24h "HH:MM" string rather than a time column so
# Rails' time-zone-aware casting can't shift it; shown in 12h AM/PM format.
class AddExpectedDeliveryTimeToBookings < ActiveRecord::Migration[8.0]
  def change
    add_column :bookings, :expected_delivery_time, :string, limit: 5
  end
end

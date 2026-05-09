class AddIsB2bToBookings < ActiveRecord::Migration[8.0]
  def change
    add_column :bookings, :is_b2b, :boolean, default: false, null: false
  end
end

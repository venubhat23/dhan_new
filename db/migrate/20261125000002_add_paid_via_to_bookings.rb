class AddPaidViaToBookings < ActiveRecord::Migration[8.0]
  def change
    # How a booking was settled when marked paid from admin: cash / upi / bank.
    add_column :bookings, :paid_via, :string
  end
end

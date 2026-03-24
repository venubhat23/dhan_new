class AddCashfreeFieldsToBookings < ActiveRecord::Migration[8.0]
  def change
    add_column :bookings, :cashfree_order_id, :string
    add_column :bookings, :payment_session_id, :string
    add_column :bookings, :cashfree_payment_id, :string
    add_column :bookings, :gateway_response, :text
    add_column :bookings, :payment_gateway, :string, default: 'cash'
    add_column :bookings, :payment_initiated_at, :datetime
    add_column :bookings, :payment_completed_at, :datetime

    add_index :bookings, :cashfree_order_id
    add_index :bookings, :cashfree_payment_id
    add_index :bookings, :payment_gateway
  end
end

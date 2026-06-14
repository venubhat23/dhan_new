class AddShareTokenToBookings < ActiveRecord::Migration[8.0]
  def up
    add_column :bookings, :share_token, :string
    add_index  :bookings, :share_token, unique: true

    # Back-fill tokens for all existing bookings
    Booking.find_each do |b|
      loop do
        token = SecureRandom.urlsafe_base64(16)
        next if Booking.where(share_token: token).exists?
        b.update_column(:share_token, token)
        break
      end
    end
  end

  def down
    remove_index  :bookings, :share_token
    remove_column :bookings, :share_token
  end
end

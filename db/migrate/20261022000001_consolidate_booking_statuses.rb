# Bookings now use only the eight delivery stages in Booking::STATUS_LABELS
# (Delivery Pending, Packed, Shipped, Delivered, Cancelled, Returned, Refund,
# Reconfirm order). Moves rows still on retired statuses onto the matching
# stage and makes Delivered the column default.
class ConsolidateBookingStatuses < ActiveRecord::Migration[8.0]
  STATUS_MAP = {
    'draft'            => 'ordered_and_delivery_pending',
    'confirmed'        => 'ordered_and_delivery_pending',
    'processing'       => 'ordered_and_delivery_pending',
    'out_for_delivery' => 'shipped',
    'completed'        => 'delivered'
  }.freeze

  def up
    STATUS_MAP.each do |old_status, new_status|
      execute <<~SQL.squish
        UPDATE bookings SET status = #{connection.quote(new_status)}
        WHERE status = #{connection.quote(old_status)}
      SQL
    end
    execute "UPDATE bookings SET status = 'delivered' WHERE status IS NULL OR status = ''"

    change_column_default :bookings, :status, from: nil, to: 'delivered'
  end

  def down
    # The old statuses can't be told apart once merged; only the default is reverted.
    change_column_default :bookings, :status, from: 'delivered', to: nil
  end
end

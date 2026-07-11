class AddBookingItemsCounterCache < ActiveRecord::Migration[8.0]
  def up
    add_column :bookings, :booking_items_count, :integer, default: 0, null: false unless column_exists?(:bookings, :booking_items_count)

    # admin/bookings#index (and several other list views) call booking.booking_items.size
    # per row — this backfills the counter so those become free once the belongs_to
    # declares counter_cache instead of a COUNT/preload per booking.
    execute <<~SQL
      UPDATE bookings SET booking_items_count = sub.cnt
      FROM (
        SELECT booking_id, COUNT(*) AS cnt FROM booking_items GROUP BY booking_id
      ) sub
      WHERE bookings.id = sub.booking_id AND bookings.booking_items_count IS DISTINCT FROM sub.cnt
    SQL
  end

  def down
    remove_column :bookings, :booking_items_count if column_exists?(:bookings, :booking_items_count)
  end
end

namespace :bookings do
  # Repairs bookings whose stored figures drifted from their actual line items:
  #  - booking_items_count was double-incremented on create (Booking#booking_items_count
  #    used to override the counter-cache reader), so list pages showed too many items.
  #  - total_amount went stale when an invoice edit removed booking items
  #    (Booking#rebuild_items_from_invoice! recalculated from the pre-delete items).
  #
  # Dry run by default; pass APPLY=1 to write.
  #   bin/rails bookings:repair_counts_and_totals
  #   APPLY=1 bin/rails bookings:repair_counts_and_totals
  desc "Fix drifted booking_items_count and stale total_amount on bookings"
  task repair_counts_and_totals: :environment do
    apply = ENV["APPLY"] == "1"
    counts_fixed = 0
    totals_fixed = 0

    Booking.includes(booking_items: :product).find_each do |booking|
      actual_count = booking.booking_items.size
      stored_count = booking.read_attribute(:booking_items_count)
      if stored_count != actual_count
        counts_fixed += 1
        puts "#{booking.booking_number}: items #{stored_count} -> #{actual_count}"
        booking.update_columns(booking_items_count: actual_count) if apply
      end

      stored_total = booking.total_amount.to_f
      booking.calculate_totals
      booking.calculate_final_amount_after_discount
      next if (stored_total - booking.total_amount.to_f).abs < 0.01

      totals_fixed += 1
      puts "#{booking.booking_number}: total ₹#{stored_total} -> ₹#{booking.total_amount}"
      if apply
        booking.update_columns(subtotal: booking.subtotal, tax_amount: booking.tax_amount,
                               discount_amount: booking.discount_amount, total_amount: booking.total_amount,
                               final_amount_after_discount: booking.final_amount_after_discount)
      end
    end

    FastCache.bust_dashboard! if apply
    puts "#{apply ? 'Fixed' : 'Would fix'}: #{counts_fixed} item counts, #{totals_fixed} totals#{apply ? '' : ' (dry run; APPLY=1 to write)'}"
  end
end

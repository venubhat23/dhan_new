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

namespace :bookings do
  # Repairs line items where GST was added on top of an already GST-inclusive
  # price (e.g. ₹450 stored as ₹472.50). The invoice edit form used to prefill
  # the inclusive price as the pre-GST unit_price; on save that synced back to
  # booking_items as price * (1 + rate). A line is fixed only when its price is
  # exactly a known product/variant price grossed up by the product's GST rate.
  # Saving the booking re-syncs its generated invoice's items.
  # Also resets product_variants.final_price_with_gst, which used to add GST on top.
  #
  # Dry run by default; pass APPLY=1 to write.
  #   bin/rails bookings:repair_double_gst
  #   APPLY=1 bin/rails bookings:repair_double_gst
  desc "Fix booking items whose price had GST added on top of a GST-inclusive price"
  task repair_double_gst: :environment do
    apply = ENV["APPLY"] == "1"
    items_fixed = 0
    variants_fixed = 0

    ProductVariant.find_each do |variant|
      next if (variant.final_price_with_gst.to_f - variant.effective_price.to_f).abs < 0.01

      variants_fixed += 1
      puts "Variant ##{variant.id} (#{variant.product&.name} #{variant.label}): final_price_with_gst ₹#{variant.final_price_with_gst} -> ₹#{variant.effective_price}"
      variant.update_columns(final_price_with_gst: variant.effective_price) if apply
    end

    Booking.includes(booking_items: { product: :product_variants }).find_each do |booking|
      bad_items = booking.booking_items.filter_map do |item|
        product = item.product
        next unless product&.gst_enabled? && product.gst_percentage.to_f > 0

        rate = product.gst_percentage.to_f
        candidates = [product.price, product.selling_price, *product.product_variants.map(&:effective_price)]
                       .compact.map(&:to_f).uniq
        next if candidates.any? { |c| (item.price.to_f - c).abs < 0.01 }

        correct = candidates.find { |c| (item.price.to_f - (c * (1 + rate / 100)).round(2)).abs < 0.01 }
        [item, correct] if correct
      end
      next if bad_items.empty?

      bad_items.each do |item, correct|
        items_fixed += 1
        puts "#{booking.booking_number} (##{booking.id}): #{item.product.name} ₹#{item.price} -> ₹#{correct}"
      end
      next unless apply

      Booking.transaction do
        bad_items.each { |item, correct| item.update!(price: correct) }
        booking.booking_items.reset
        booking.save!
      end
      puts "  total now ₹#{booking.total_amount}"
    end

    FastCache.bust_dashboard! if apply && items_fixed > 0
    puts "#{apply ? 'Fixed' : 'Would fix'} #{items_fixed} booking item(s), #{variants_fixed} variant(s).#{' Re-run with APPLY=1 to write.' unless apply}"
  end
end

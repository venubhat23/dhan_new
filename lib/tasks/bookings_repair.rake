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
  # exactly a known price (product/variant current, discount, previous or B2B
  # price, or a price charged on another booking) grossed up by the GST rate.
  # Lines/totals that look off but can't be matched are listed for review only.
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

    # Known GST-inclusive prices per product: current/discount/previous/B2B prices
    # on the product and its variants, plus prices charged on any booking line.
    # A value that is itself another known price grossed up by GST is the bug, not
    # a real price, so it is dropped from the set.
    peer_prices = BookingItem.distinct.pluck(:product_id, :price).group_by(&:first)
                             .transform_values { |rows| rows.map { |_, pr| pr.to_f } }
    known_prices = Hash.new do |hash, product|
      rate = product.gst_percentage.to_f
      raw = [product.price, product.selling_price, product.try(:discount_price), product.try(:today_price),
             product.try(:yesterday_price), product.try(:b2b_price),
             *product.product_variants.flat_map { |v| [v.selling_price, v.effective_price, v.try(:b2b_price)] },
             *peer_prices.fetch(product.id, [])]
              .compact.map(&:to_f).select(&:positive?).map { |v| v.round(2) }.uniq
      hash[product] = raw.reject { |v| raw.any? { |c| c != v && (v - (c * (1 + rate / 100)).round(2)).abs < 0.01 } }
    end
    gst_product = ->(product) { product&.gst_enabled? && product.gst_percentage.to_f > 0 }
    review = []

    Booking.includes(booking_items: { product: :product_variants }).find_each do |booking|
      bad_items = booking.booking_items.filter_map do |item|
        product = item.product
        next unless gst_product.(product)

        rate = product.gst_percentage.to_f
        known = known_prices[product]
        next if known.any? { |c| (item.price.to_f - c).abs < 0.01 }

        correct = known.find { |c| (item.price.to_f - (c * (1 + rate / 100)).round(2)).abs < 0.01 }
        review << "#{booking.booking_number} (##{booking.id}): #{product.name} ₹#{item.price} matches no known price" unless correct
        [item, correct] if correct
      end
      next if bad_items.empty?

      bad_items.each do |item, correct|
        items_fixed += 1
        puts "#{booking.booking_number} (##{booking.id}): #{item.product.name} ₹#{item.price} -> ₹#{correct}"
      end
      next unless apply

      Booking.transaction do
        # Price-only change: stock was allocated when the line was created.
        bad_items.each { |item, correct| item.price = correct; item.save!(validate: false) }
        booking.booking_items.reset
        booking.save!
      end
      puts "  total now ₹#{booking.total_amount}"
    end

    # Invoices with no linked booking (or whose lines weren't caught above): a
    # line whose base unit_price is exactly a known GST-inclusive price.
    invoice_items_fixed = 0
    Invoice.includes(invoice_items: { product: :product_variants }).find_each do |invoice|
      bad_items = invoice.invoice_items.filter_map do |item|
        product = item.product
        next unless gst_product.(product)

        rate = product.gst_percentage.to_f
        inclusive = known_prices[product]
        next if inclusive.any? { |c| (item.unit_price.to_f - c / (1 + rate / 100)).abs < 0.01 }

        match = inclusive.find { |c| (item.unit_price.to_f - c).abs < 0.01 }
        [item, (match / (1 + rate / 100)).round(2)] if match
      end
      next if bad_items.empty?

      bad_items.each do |item, base|
        invoice_items_fixed += 1
        puts "#{invoice.invoice_number} (##{invoice.id}): #{item.product.name} unit_price ₹#{item.unit_price} -> ₹#{base}"
      end
      next unless apply

      Invoice.transaction do
        bad_items.each do |item, base|
          attrs = { unit_price: base }
          attrs[:original_unit_price] = base if (item.original_unit_price.to_f - item.unit_price.to_f).abs < 0.01
          item.update!(attrs)
        end
        invoice.invoice_items.reset
        invoice.save!
      end
      puts "  total now ₹#{invoice.total_amount}"
    end

    # Report-only: booking and its generated invoice disagree on the total.
    Booking.where(invoice_generated: true).where.not(invoice_number: [nil, ""]).find_each do |booking|
      invoice = Invoice.find_by(invoice_number: booking.invoice_number)
      next unless invoice
      next if (invoice.total_amount.to_f - booking.total_amount.to_f).abs < 1

      review << "#{booking.booking_number} (##{booking.id}): booking total ₹#{booking.total_amount} vs #{invoice.invoice_number} ₹#{invoice.total_amount}"
    end

    if review.any?
      puts "\nReview manually (not changed):"
      review.each { |line| puts "  #{line}" }
    end

    FastCache.bust_dashboard! if apply && (items_fixed + invoice_items_fixed) > 0
    puts "#{apply ? 'Fixed' : 'Would fix'} #{items_fixed} booking item(s), #{invoice_items_fixed} invoice item(s), #{variants_fixed} variant(s).#{' Re-run with APPLY=1 to write.' unless apply}"
  end
end

namespace :bookings do
  # Bookings whose generated invoice was edited (prices changed) before the
  # booking<->invoice line sync existed, so the two disagree. The invoice is what
  # the customer received, so its lines are copied onto the booking via
  # Booking#rebuild_items_from_invoice! (updates lines in place, no stock churn).
  # Differences under ₹5 are bulk-discount rounding and are skipped.
  #
  # Dry run by default; pass APPLY=1 to write. IDS=44,50 limits to those bookings.
  #   bin/rails bookings:sync_from_invoice
  #   APPLY=1 bin/rails bookings:sync_from_invoice
  desc "Make bookings match their edited invoices (invoice prices win)"
  task sync_from_invoice: :environment do
    apply = ENV["APPLY"] == "1"
    ids = ENV["IDS"].to_s.split(",").map(&:strip).reject(&:empty?)
    synced = 0
    failed = 0

    scope = Booking.where(invoice_generated: true).where.not(invoice_number: [nil, ""])
    scope = scope.where(id: ids) if ids.any?
    scope.includes(booking_items: :product).find_each do |booking|
      invoice = Invoice.find_by(invoice_number: booking.invoice_number)
      next unless invoice
      next if (invoice.total_amount.to_f - booking.total_amount.to_f).abs < 5
      next if booking.items_match_invoice?(invoice)

      synced += 1
      puts "#{booking.booking_number} (##{booking.id}) vs #{invoice.invoice_number}: booking ₹#{booking.total_amount} -> invoice ₹#{invoice.total_amount}"
      by_product = booking.booking_items.index_by(&:product_id)
      invoice.invoice_items.includes(:product).each do |ii|
        next unless ii.product
        new_price = booking.final_price_for(ii.product, booking.invoice_item_list_price(ii)).round(2)
        old = by_product.delete(ii.product_id)
        if old.nil?
          puts "  + #{ii.product.name}: qty #{ii.quantity.to_f} @ ₹#{new_price} (new line)"
        elsif old.quantity.to_f.round(3) != ii.quantity.to_f.round(3) || (old.price.to_f - new_price).abs >= 0.01
          puts "  ~ #{ii.product.name}: qty #{old.quantity.to_f} -> #{ii.quantity.to_f}, price ₹#{old.price.to_f} -> ₹#{new_price}"
        end
      end
      by_product.each_value { |bi| puts "  - #{bi.product&.name}: removed (not on invoice)" }
      next unless apply

      booking.rebuild_items_from_invoice!(invoice)
      booking.reload
      if booking.items_match_invoice?(invoice)
        puts "  synced, booking total now ₹#{booking.total_amount}"
      else
        failed += 1
        puts "  FAILED to sync (see log/production.log)"
      end
    end

    FastCache.bust_dashboard! if apply && synced > 0
    puts "#{apply ? 'Synced' : 'Would sync'} #{synced - failed} booking(s)#{", #{failed} failed" if failed > 0}.#{' Re-run with APPLY=1 to write.' unless apply}"
  end
end

# Links existing records to receipts: every paid booking gets its Sales Receipt
# and every vendor purchase gets its Purchase Receipt (new ones are created by the
# model callbacks; this covers records from before receipts existed). Idempotent.
class ReceiptBackfill
  def self.run!
    counts = { sales: 0, purchases: 0, failed: 0 }

    Booking.payment_status_paid.where.missing(:sales_receipt).find_each do |booking|
      receipt = SalesReceipt.create_from_booking!(booking)
      # Older bookings have no payment_completed_at, so date them from the booking, not today.
      receipt.update_column(:receipt_date, historic_date(booking)) unless booking.payment_completed_at
      counts[:sales] += 1
    rescue => e
      counts[:failed] += 1
      Rails.logger.error "[ReceiptBackfill] booking #{booking.id}: #{e.message}"
    end

    VendorPurchase.where.missing(:purchase_receipt).find_each do |purchase|
      PurchaseReceipt.sync_from_vendor_purchase!(purchase)
      counts[:purchases] += 1
    rescue => e
      counts[:failed] += 1
      Rails.logger.error "[ReceiptBackfill] vendor purchase #{purchase.id}: #{e.message}"
    end

    counts
  end

  def self.historic_date(booking)
    (booking.updated_at || booking.booking_date || booking.created_at).to_date
  end
end

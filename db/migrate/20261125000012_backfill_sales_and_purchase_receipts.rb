# Data migration: give existing paid bookings / vendor purchases their receipts.
class BackfillSalesAndPurchaseReceipts < ActiveRecord::Migration[8.0]
  def up
    result = ReceiptBackfill.run!
    say "Sales receipts: #{result[:sales]}, purchase receipts: #{result[:purchases]}, failed: #{result[:failed]}"
  end

  def down; end
end

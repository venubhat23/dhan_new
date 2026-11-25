namespace :receipts do
  desc 'Create missing Sales Receipts for paid bookings and Purchase Receipts for vendor purchases'
  task backfill: :environment do
    result = ReceiptBackfill.run!
    puts "Sales receipts created: #{result[:sales]} · Purchase receipts created: #{result[:purchases]} · Failed: #{result[:failed]}"
  end
end

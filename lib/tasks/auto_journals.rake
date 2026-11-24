namespace :journals do
  desc 'Rebuild auto journals for all invoices, customer payments, vendor purchases and vendor payments'
  task sync_auto: :environment do
    AutoJournal.sync_all!
    puts "Auto journals: #{ManualJournal.automatic.count} (#{ManualJournal.automatic.group(:entry_kind).count.map { |k, v| "#{k}=#{v}" }.join(', ')})"
  end
end

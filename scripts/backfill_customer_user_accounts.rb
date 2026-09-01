# Backfill linked User (login) accounts for customers that were imported
# before the importer created them automatically.
#
#   Dry run (default) — just report what would be created:
#     bin/rails runner scripts/backfill_customer_user_accounts.rb
#
#   Actually create the accounts:
#     APPLY=1 bin/rails runner scripts/backfill_customer_user_accounts.rb
#
#   Limit to specific customer ids:
#     APPLY=1 IDS=13,14 bin/rails runner scripts/backfill_customer_user_accounts.rb

PASSWORD = ImportService::CustomerImporter::DEFAULT_CUSTOMER_PASSWORD
apply    = ENV["APPLY"] == "1"
ids      = ENV["IDS"].to_s.split(",").map(&:strip).reject(&:blank?)

scope = Customer.where.not(email: [nil, ""])
scope = scope.where(id: ids) if ids.any?

created = 0
skipped = 0

scope.find_each do |c|
  if User.exists?(email: c.email) || (c.mobile.present? && User.exists?(mobile: c.mobile))
    skipped += 1
    next
  end

  names = c.full_name.to_s.split(" ")
  attrs = {
    first_name:            names.first.presence || "Unknown",
    last_name:             (names[1..-1] || []).join(" ").presence || "Unknown",
    email:                 c.email,
    mobile:                c.mobile,
    password:              PASSWORD,
    password_confirmation: PASSWORD,
    user_type:             "customer",
    address:               c.address,
    city:                  "Unknown",
    state:                 "Unknown",
    pincode:               "000000",
    country:               "India",
    status:                true,
    is_active:             true,
    is_verified:           false
  }

  if apply
    begin
      User.create!(attrs)
      c.update_columns(auto_generated_password: PASSWORD) if c.auto_generated_password.blank?
      created += 1
      puts "  created user for ##{c.id} #{c.full_name} <#{c.email}>"
    rescue => e
      puts "  FAILED ##{c.id} #{c.email}: #{e.message}"
    end
  else
    created += 1
    puts "  would create user for ##{c.id} #{c.full_name} <#{c.email}>"
  end
end

puts ""
puts "#{apply ? 'Created' : 'Would create'}: #{created}   Already had an account: #{skipped}"
puts "Run again with APPLY=1 to make the changes." unless apply

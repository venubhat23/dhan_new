#!/usr/bin/env ruby

puts "🔧 Cashfree Production Setup"
puts "=" * 50

puts "\n📝 To set up production Cashfree credentials, you need to:"
puts "1. Get your production Client ID and Secret from Cashfree Dashboard"
puts "2. Set environment variables or update Rails credentials"

puts "\n🔑 Current Configuration:"
puts "  CASHFREE_APP_ID: #{ENV['CASHFREE_APP_ID'] ? 'SET' : 'NOT SET'}"
puts "  CASHFREE_SECRET_KEY: #{ENV['CASHFREE_SECRET_KEY'] ? 'SET' : 'NOT SET'}"

puts "\n📋 To fix the authentication error:"
puts "Option 1 - Environment Variables:"
puts "  export CASHFREE_APP_ID='your_production_app_id'"
puts "  export CASHFREE_SECRET_KEY='your_production_secret_key'"

puts "\nOption 2 - Rails Credentials:"
puts "  EDITOR=nano rails credentials:edit"
puts "  Add:"
puts "  cashfree:"
puts "    client_id: your_production_app_id"
puts "    client_secret: your_production_secret_key"

puts "\n🌐 Production API Endpoint:"
puts "  https://api.cashfree.com/pg"
puts "  (Will be used automatically when production credentials are detected)"

puts "\n⚠️  Important Notes:"
puts "  - Production credentials should NOT start with 'TEST'"
puts "  - Keep credentials secure and never commit them to git"
puts "  - Test in sandbox first before using production"

if File.exist?('.env')
  puts "\n📄 Found .env file. You can also add credentials there:"
  puts "  CASHFREE_APP_ID=your_production_app_id"
  puts "  CASHFREE_SECRET_KEY=your_production_secret_key"
end

puts "\n🔄 After setting credentials, restart the Rails server"
puts "=" * 50
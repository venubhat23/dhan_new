#!/bin/bash

echo "🧪 Testing Cashfree Payment Flow End-to-End"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
LOCALHOST_URL="http://localhost:3000"

echo "📋 Step-by-step testing guide:"
echo ""

echo "1️⃣ Start Rails Server:"
echo "   cd $(pwd)"
echo -e "   ${YELLOW}bundle exec rails server -p 3000${NC}"
echo ""

echo "2️⃣ Start ngrok in another terminal:"
echo -e "   ${YELLOW}./setup_ngrok.sh${NC}"
echo "   (This will show you the ngrok URL to use)"
echo ""

echo "3️⃣ Test the checkout flow:"
echo "   • Go to: $LOCALHOST_URL/customer/shop"
echo "   • Add items to cart"
echo "   • Click 'Checkout'"
echo "   • Select payment method: 'Pay Online'"
echo "   • Click 'Pay Now'"
echo ""

echo "4️⃣ Monitor Rails logs for:"
echo "   • Order creation success"
echo "   • Cashfree API calls"
echo "   • Payment gateway redirection"
echo ""

echo "5️⃣ After payment (in Cashfree sandbox):"
echo "   • Complete test payment"
echo "   • Check webhook logs in Rails console"
echo "   • Verify order status in customer dashboard"
echo ""

echo "🔧 Testing Commands:"
echo ""

echo "📊 Check current bookings:"
echo -e "   ${YELLOW}bundle exec rails runner \"puts Booking.last(5).map { |b| [b.booking_number, b.payment_method, b.status, b.payment_status].join(' | ') }\"${NC}"
echo ""

echo "📧 Test customer exists:"
echo -e "   ${YELLOW}bundle exec rails runner \"puts Customer.count > 0 ? 'Customers available' : 'No customers - create one first'\"${NC}"
echo ""

echo "📦 Check products with stock:"
echo -e "   ${YELLOW}bundle exec rails runner \"Product.limit(3).each { |p| puts \\\"\#{p.id}: \#{p.name} - Stock: \#{p.cached_total_batch_stock || 0}\\\" }\"${NC}"
echo ""

echo "🔍 Test webhook endpoint:"
echo -e "   ${YELLOW}curl -X POST $LOCALHOST_URL/cashfree/webhook -H \"Content-Type: application/json\" -d '{\"type\":\"test\",\"data\":{\"order\":{\"order_id\":\"TEST123\"}}}' -v${NC}"
echo ""

echo "🚨 Common Issues & Solutions:"
echo "───────────────────────────"
echo ""
echo "❌ Cart empty error:"
echo "   → Add products to cart in browser first"
echo ""
echo "❌ Customer not found:"
echo "   → Make sure you're logged in as customer"
echo "   → Check: $LOCALHOST_URL/customer/login"
echo ""
echo "❌ Stock insufficient:"
echo "   → Run: bundle exec rails runner \"Product.find(ID).stock_batches.create!(vendor: Vendor.first, quantity_remaining: 10, purchase_price: 100, selling_price: 120, batch_date: Date.current, status: 'active')\""
echo ""
echo "❌ Webhook not received:"
echo "   → Check ngrok is running"
echo "   → Verify webhook URL in Cashfree dashboard"
echo "   → Check Rails logs for incoming requests"
echo ""

# Check if Rails server is running
if curl -s -o /dev/null -w "%{http_code}" "$LOCALHOST_URL" | grep -q "200\|302"; then
    echo -e "✅ ${GREEN}Rails server is running${NC}"
    echo "🌐 Access your app: $LOCALHOST_URL/customer/shop"
else
    echo -e "⚠️  ${YELLOW}Rails server not running. Start it with:${NC}"
    echo "   bundle exec rails server -p 3000"
fi

echo ""
echo "🎯 Quick Test URLs:"
echo "   Shop: $LOCALHOST_URL/customer/shop"
echo "   Login: $LOCALHOST_URL/customer/login"
echo "   Dashboard: $LOCALHOST_URL/customer/dashboard"
echo ""
echo -e "${GREEN}Ready to test! 🚀${NC}"
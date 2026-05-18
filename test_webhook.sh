#!/bin/bash

# Webhook Testing Utility for Cashfree Integration
echo "🔗 Cashfree Webhook Testing Utility"
echo "=================================="

# Configuration
LOCALHOST_URL="http://localhost:3001"
WEBHOOK_ENDPOINT="$LOCALHOST_URL/cashfree/webhook"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "📡 Testing webhook endpoint: $WEBHOOK_ENDPOINT"
echo ""

# Test 1: Basic connectivity
echo "1️⃣ Testing basic webhook connectivity..."
response=$(curl -s -w "%{http_code}" -X POST $WEBHOOK_ENDPOINT -H "Content-Type: application/json" -d '{"type":"test"}' -o /dev/null)

if [ "$response" = "200" ] || [ "$response" = "422" ]; then
    echo -e "   ✅ ${GREEN}Webhook endpoint is accessible${NC}"
else
    echo -e "   ❌ ${RED}Webhook endpoint not accessible (HTTP $response)${NC}"
    echo "   Make sure Rails server is running on port 3000"
    exit 1
fi

# Test 2: Payment Success Webhook
echo ""
echo "2️⃣ Testing payment success webhook..."

# Get a test order ID (latest booking with cashfree_order_id)
echo "   📋 Getting test booking data..."
test_order_id=$(bundle exec rails runner "booking = Booking.where.not(cashfree_order_id: nil).last; puts booking ? booking.cashfree_order_id : 'MKS_TEST_' + Time.current.strftime('%Y%m%d%H%M%S')" 2>/dev/null | tail -1)

if [ -z "$test_order_id" ]; then
    test_order_id="MKS_TEST_$(date +%Y%m%d%H%M%S)_ABCD"
    echo -e "   ⚠️  ${YELLOW}No existing bookings found, using mock order ID: $test_order_id${NC}"
else
    echo -e "   ✅ ${GREEN}Using existing order ID: $test_order_id${NC}"
fi

# Payment Success Webhook Payload
success_payload=$(cat <<EOF
{
  "type": "PAYMENT_SUCCESS_WEBHOOK",
  "data": {
    "order": {
      "order_id": "$test_order_id",
      "order_amount": 130.00,
      "order_currency": "INR"
    },
    "payment": {
      "cf_payment_id": "12345",
      "payment_method": "UPI",
      "payment_amount": 130.00,
      "bank_reference": "123456789",
      "auth_id": "A123456"
    }
  }
}
EOF
)

echo "   📤 Sending payment success webhook..."
success_response=$(curl -s -w "%{http_code}" -X POST $WEBHOOK_ENDPOINT \
    -H "Content-Type: application/json" \
    -d "$success_payload" \
    -o /tmp/webhook_response.json)

echo "   📥 Response code: $success_response"
if [ -f /tmp/webhook_response.json ]; then
    echo "   📥 Response body: $(cat /tmp/webhook_response.json)"
fi

# Test 3: Payment Failed Webhook
echo ""
echo "3️⃣ Testing payment failed webhook..."

failed_payload=$(cat <<EOF
{
  "type": "PAYMENT_FAILED_WEBHOOK",
  "data": {
    "order": {
      "order_id": "$test_order_id",
      "order_amount": 130.00,
      "order_currency": "INR"
    },
    "payment": {
      "payment_method": "UPI",
      "payment_message": "Transaction failed"
    }
  }
}
EOF
)

echo "   📤 Sending payment failed webhook..."
failed_response=$(curl -s -w "%{http_code}" -X POST $WEBHOOK_ENDPOINT \
    -H "Content-Type: application/json" \
    -d "$failed_payload" \
    -o /tmp/webhook_failed_response.json)

echo "   📥 Response code: $failed_response"
if [ -f /tmp/webhook_failed_response.json ]; then
    echo "   📥 Response body: $(cat /tmp/webhook_failed_response.json)"
fi

# Test 4: Invalid JSON
echo ""
echo "4️⃣ Testing invalid JSON handling..."
invalid_response=$(curl -s -w "%{http_code}" -X POST $WEBHOOK_ENDPOINT \
    -H "Content-Type: application/json" \
    -d '{"invalid_json":' \
    -o /tmp/webhook_invalid_response.json)

echo "   📥 Response code: $invalid_response"
if [ -f /tmp/webhook_invalid_response.json ]; then
    echo "   📥 Response body: $(cat /tmp/webhook_invalid_response.json)"
fi

# Cleanup
rm -f /tmp/webhook_*.json

echo ""
echo "🏁 Webhook testing completed!"
echo ""
echo "📋 Summary:"
echo "   - Webhook endpoint: $WEBHOOK_ENDPOINT"
echo "   - Test order ID used: $test_order_id"
echo ""
echo "🔍 Check Rails logs for detailed webhook processing information"
echo "   tail -f log/development.log | grep webhook"
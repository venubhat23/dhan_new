#!/bin/bash

# Ngrok Setup Script for Cashfree Webhook Testing
echo "🚀 Setting up ngrok for Cashfree webhook testing..."

# Check if ngrok is installed
if ! command -v ngrok &> /dev/null; then
    echo "❌ ngrok is not installed. Please install it first:"
    echo "   Visit: https://ngrok.com/download"
    echo "   Or run: brew install ngrok (on macOS)"
    echo "   Or run: snap install ngrok (on Ubuntu)"
    exit 1
fi

# Kill any existing ngrok processes
echo "🧹 Stopping any existing ngrok processes..."
pkill -f ngrok

# Start ngrok for local Rails server (port 3000)
echo "🌐 Starting ngrok tunnel for localhost:3000..."
ngrok http 3000 --log stdout &

# Wait a moment for ngrok to start
sleep 3

# Get the ngrok URL
echo "📡 Getting ngrok URL..."
NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url')

if [ "$NGROK_URL" != "null" ] && [ -n "$NGROK_URL" ]; then
    echo "✅ ngrok tunnel is running!"
    echo "🌍 Public URL: $NGROK_URL"
    echo "📲 Webhook URL: $NGROK_URL/cashfree/webhook"
    echo "🎯 Return URL: $NGROK_URL/payment/success"

    # Set environment variable
    export NGROK_URL=$NGROK_URL
    echo "export NGROK_URL=$NGROK_URL" >> ~/.bashrc

    echo ""
    echo "📋 Cashfree Configuration:"
    echo "   Return URL: $NGROK_URL/payment/success?booking_id={{booking_id}}"
    echo "   Webhook URL: $NGROK_URL/cashfree/webhook"
    echo ""
    echo "🎮 Access your app at: $NGROK_URL/customer/shop"
    echo "🔧 ngrok dashboard at: http://localhost:4040"
    echo ""
    echo "⚠️  NOTE: Update your Cashfree dashboard with the webhook URL above!"
else
    echo "❌ Failed to start ngrok. Please check if it's properly installed."
    exit 1
fi

# Keep the script running
echo "✋ Press Ctrl+C to stop ngrok..."
wait
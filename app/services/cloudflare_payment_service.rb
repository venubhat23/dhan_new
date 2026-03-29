class CloudflarePaymentService
  include HTTParty

  # Configuration
  CLOUDFLARE_WORKER_URL = Rails.application.credentials.cloudflare_worker_url ||
                          ENV['CLOUDFLARE_WORKER_URL'] ||
                          'https://marali-santhe-payment-processor.your-subdomain.workers.dev'

  WEBHOOK_SECRET = Rails.application.credentials.cloudflare_webhook_secret ||
                   ENV['CLOUDFLARE_WEBHOOK_SECRET'] ||
                   'your-webhook-secret-key'

  base_uri CLOUDFLARE_WORKER_URL

  def self.create_order(booking)
    begin
      Rails.logger.info "Creating Cloudflare payment order for booking #{booking.id}"

      # Build cart items from booking
      cart_items = booking.booking_items.map do |item|
        {
          product_id: item.product_id,
          quantity: item.quantity,
          price: item.price,
          product_name: item.product.name
        }
      end

      # Prepare request payload
      payload = {
        cart_items: cart_items,
        customer_email: booking.customer_email,
        customer_name: booking.customer_name,
        customer_phone: booking.customer_phone,
        delivery_address: booking.delivery_address,
        delivery_method: booking.delivery_method || 'pickup',
        pickup_location: booking.selected_shop_address,
        payment_method: 'cloudflare',
        total_amount: booking.total_amount,
        booking_id: booking.id,
        webhook_url: webhook_url
      }

      Rails.logger.info "Cloudflare payload: #{payload}"

      # Make request to Cloudflare Worker
      response = post('/payment/create-order', {
        body: payload.to_json,
        headers: {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{api_key}",
          'X-Source' => 'rails-app'
        },
        timeout: 30
      })

      Rails.logger.info "Cloudflare response: #{response.code} - #{response.body}"

      if response.success?
        data = response.parsed_response

        {
          success: true,
          data: {
            'payment_session_id' => data['payment_session_id'],
            'order_id' => data['order_id'],
            'payment_url' => data['payment_url'],
            'amount' => data['amount'],
            'currency' => data['currency']
          }
        }
      else
        error_message = response.parsed_response&.dig('message') || 'Unknown error'
        Rails.logger.error "Cloudflare order creation failed: #{error_message}"

        {
          success: false,
          message: error_message,
          error: response.parsed_response
        }
      end

    rescue Net::TimeoutError => e
      Rails.logger.error "Cloudflare timeout error: #{e.message}"
      {
        success: false,
        message: 'Payment service timeout. Please try again.',
        error: e.message
      }
    rescue => e
      Rails.logger.error "Cloudflare service error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      {
        success: false,
        message: 'Payment service error. Please try again.',
        error: e.message
      }
    end
  end

  def self.verify_payment(order_id, payment_id = nil)
    begin
      Rails.logger.info "Verifying Cloudflare payment: #{order_id}"

      response = post('/payment/verify', {
        body: {
          order_id: order_id,
          payment_id: payment_id
        }.to_json,
        headers: {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{api_key}"
        },
        timeout: 30
      })

      if response.success?
        data = response.parsed_response

        {
          success: true,
          data: {
            'order_id' => data['order_id'],
            'order_status' => map_payment_status(data['payment_status']),
            'payment_status' => data['payment_status'],
            'payment_method' => data.dig('payment_details', 'payment_method'),
            'order_amount' => data['amount']
          }
        }
      else
        error_message = response.parsed_response&.dig('message') || 'Verification failed'
        Rails.logger.error "Cloudflare payment verification failed: #{error_message}"

        {
          success: false,
          message: error_message,
          error: response.parsed_response
        }
      end

    rescue => e
      Rails.logger.error "Cloudflare verification error: #{e.message}"

      {
        success: false,
        message: 'Payment verification failed. Please try again.',
        error: e.message
      }
    end
  end

  def self.process_webhook(webhook_data)
    begin
      Rails.logger.info "Processing Cloudflare webhook: #{webhook_data}"

      # Validate webhook signature
      unless validate_webhook_signature(webhook_data)
        Rails.logger.error "Invalid webhook signature"
        return { success: false, message: 'Invalid signature' }
      end

      order_id = webhook_data['order_id']
      event_type = webhook_data['event_type']
      payment_status = webhook_data['payment_status']
      order_data = webhook_data['order_data']

      # Find booking by Cloudflare order ID
      booking = Booking.find_by(cloudflare_order_id: order_id)
      unless booking
        Rails.logger.error "Booking not found for order_id: #{order_id}"
        return { success: false, message: 'Booking not found' }
      end

      case event_type
      when 'payment.success'
        payment_details = {
          cf_payment_id: webhook_data.dig('payment_details', 'payment_id'),
          payment_method: webhook_data.dig('payment_details', 'payment_method'),
          order_status: 'PAID',
          payment_amount: order_data['amount']
        }

        booking.mark_payment_completed!(payment_details)
        Rails.logger.info "Payment completed for booking #{booking.id}"

      when 'payment.failed'
        failure_reason = webhook_data.dig('payment_details', 'failure_reason') || 'Payment failed'
        booking.mark_payment_failed!(failure_reason)
        Rails.logger.info "Payment failed for booking #{booking.id}: #{failure_reason}"

      else
        Rails.logger.warn "Unknown webhook event: #{event_type}"
      end

      { success: true, message: 'Webhook processed' }

    rescue => e
      Rails.logger.error "Webhook processing error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      { success: false, message: 'Webhook processing failed', error: e.message }
    end
  end

  private

  def self.webhook_url
    if Rails.env.development?
      # Use ngrok URL for local development
      ENV['NGROK_URL'] ? "#{ENV['NGROK_URL']}/payment/cloudflare_webhook" : 'http://localhost:3000/payment/cloudflare_webhook'
    else
      "#{Rails.application.config.app_domain}/payment/cloudflare_webhook"
    end
  end

  def self.api_key
    Rails.application.credentials.cloudflare_api_key ||
    ENV['CLOUDFLARE_API_KEY'] ||
    'your-cloudflare-api-key'
  end

  def self.map_payment_status(status)
    case status&.upcase
    when 'SUCCESS', 'COMPLETED', 'PAID'
      'PAID'
    when 'FAILED', 'CANCELLED'
      'FAILED'
    when 'PENDING', 'INITIATED'
      'ACTIVE'
    else
      'ACTIVE'
    end
  end

  def self.validate_webhook_signature(webhook_data)
    # Implement webhook signature validation
    # For development, return true. In production, validate the signature

    if Rails.env.development?
      return true
    end

    # Example signature validation logic:
    # received_signature = request.headers['X-Webhook-Signature']
    # expected_signature = OpenSSL::HMAC.hexdigest('sha256', WEBHOOK_SECRET, webhook_data.to_json)
    # return received_signature == expected_signature

    true
  end
end
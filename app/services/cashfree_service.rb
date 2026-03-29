class CashfreeService
  include HTTParty

  base_uri Rails.env.production? ? 'https://api.cashfree.com/pg' : 'https://sandbox.cashfree.com/pg'
  headers 'Content-Type' => 'application/json'

  API_VERSION = '2022-09-01'

  class << self
    def create_order(booking)
      response = post('/orders', {
        headers: auth_headers,
        body: build_order_request(booking).to_json
      })

      handle_response(response)
    end

    def verify_payment(payment_id)
      response = get("/payments/#{payment_id}", {
        headers: auth_headers
      })

      handle_response(response)
    end

    def verify_signature(request_body, signature, timestamp)
      # Generate signature for webhook verification
      computed_signature = compute_signature(request_body, timestamp)
      ActiveSupport::SecurityUtils.secure_compare(computed_signature, signature)
    end

    private

    def auth_headers
      {
        'x-client-id' => client_id,
        'x-client-secret' => client_secret,
        'x-api-version' => API_VERSION,
        'Content-Type' => 'application/json'
      }
    end

    def build_order_request(booking)
      customer = booking.customer

      {
        order_id: booking.cashfree_order_id,
        order_amount: booking.total_amount.to_f,
        order_currency: 'INR',
        customer_details: {
          customer_id: customer.id.to_s,
          customer_name: customer.display_name,
          customer_email: customer.email,
          customer_phone: customer.mobile
        },
        order_meta: {
          return_url: return_url(booking.id),
          notify_url: webhook_url
        }
      }
    end

    def handle_response(response)
      case response.code
      when 200, 201
        {
          success: true,
          data: JSON.parse(response.body)
        }
      when 400..499
        {
          success: false,
          error: 'Client Error',
          message: parse_error_message(response),
          code: response.code
        }
      when 500..599
        {
          success: false,
          error: 'Server Error',
          message: 'Cashfree server error. Please try again.',
          code: response.code
        }
      else
        {
          success: false,
          error: 'Unknown Error',
          message: 'An unexpected error occurred',
          code: response.code
        }
      end
    rescue JSON::ParserError => e
      {
        success: false,
        error: 'Parse Error',
        message: 'Failed to parse response from Cashfree',
        details: e.message
      }
    rescue => e
      {
        success: false,
        error: 'Network Error',
        message: 'Failed to connect to Cashfree',
        details: e.message
      }
    end

    def parse_error_message(response)
      body = JSON.parse(response.body)
      body.dig('message') || body.dig('error', 'message') || 'Unknown error occurred'
    rescue JSON::ParserError
      'Invalid response from payment gateway'
    end

    def compute_signature(request_body, timestamp)
      # Cashfree webhook signature verification
      data = "#{timestamp}.#{request_body}"
      OpenSSL::HMAC.hexdigest('sha256', client_secret, data)
    end

    def client_id
      Rails.application.credentials.dig(:cashfree, :client_id) ||
      ENV['CASHFREE_APP_ID'] ||
      'CASHFREE_APPID_REMOVED'
    end

    def client_secret
      Rails.application.credentials.dig(:cashfree, :client_secret) ||
      ENV['CASHFREE_SECRET_KEY'] ||
      'CASHFREE_SECRET_REMOVED'
    end

    def return_url(booking_id)
      "#{base_url}/payment/success?booking_id=#{booking_id}"
    end

    def webhook_url
      "#{base_url}/cashfree/webhook"
    end

    def base_url
      if Rails.env.development?
        ENV['BASE_URL'] || 'http://localhost:3000'
      elsif Rails.env.production?
        ENV['BASE_URL'] || 'https://maralisanthe.com'
      else
        'http://localhost:3000'
      end
    end
  end
end
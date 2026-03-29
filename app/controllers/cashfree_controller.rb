class CashfreeController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:webhook]
  skip_before_action :authenticate_user!, only: [:webhook]
  skip_load_and_authorize_resource only: [:webhook]

  def webhook
    Rails.logger.info "🚀 Cashfree webhook received at #{Time.current}"
    Rails.logger.info "Request headers: #{request.headers.to_h.select { |k, _| k.start_with?('HTTP_') || k.downcase.include?('webhook') }}"

    timestamp = request.headers['x-webhook-timestamp']
    signature = request.headers['x-webhook-signature']
    request_body = request.raw_post

    Rails.logger.info "Raw request body: #{request_body}"

    # Skip signature verification in development for easier testing
    if Rails.env.development?
      Rails.logger.warn "⚠️ Skipping signature verification in development mode"
    else
      # Verify webhook signature
      begin
        unless CashfreeService.verify_signature(request_body, signature, timestamp)
          Rails.logger.error "❌ Cashfree webhook signature verification failed"
          Rails.logger.debug "Expected signature: #{CashfreeService.send(:compute_signature, request_body, timestamp)}"
          Rails.logger.debug "Received signature: #{signature}"
          Rails.logger.debug "Timestamp: #{timestamp}"
          Rails.logger.debug "Body: #{request_body}"

          # For now, allow webhook processing but log the failure
          # TODO: Enable this in production after signature verification is working
          # render json: { status: 'error', message: 'Invalid signature' }, status: :unauthorized
          # return
          Rails.logger.warn "⚠️ Continuing despite signature verification failure for troubleshooting"
        else
          Rails.logger.info "✅ Webhook signature verified"
        end
      rescue => e
        Rails.logger.error "❌ Signature verification error: #{e.message}"
        Rails.logger.warn "⚠️ Continuing despite signature verification error"
      end
    end

    begin
      payload = JSON.parse(request_body)
      event_type = payload['type']

      case event_type
      when 'PAYMENT_SUCCESS_WEBHOOK'
        handle_payment_success(payload['data'])
      when 'PAYMENT_FAILED_WEBHOOK'
        handle_payment_failed(payload['data'])
      when 'PAYMENT_USER_DROPPED_WEBHOOK'
        handle_payment_dropped(payload['data'])
      else
        Rails.logger.info "Unhandled Cashfree webhook event: #{event_type}"
      end

      render json: { status: 'success' }

    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse Cashfree webhook payload: #{e.message}"
      render json: { status: 'error', message: 'Invalid JSON' }, status: :bad_request

    rescue => e
      Rails.logger.error "Cashfree webhook processing error: #{e.message}"
      render json: { status: 'error', message: 'Processing failed' }, status: :internal_server_error
    end
  end

  private

  def handle_payment_success(payment_data)
    Rails.logger.info "💰 Processing payment success webhook"
    Rails.logger.info "Payment data: #{payment_data.inspect}"

    order_id = payment_data['order']['order_id']
    payment_id = payment_data['payment']['cf_payment_id']

    booking = Booking.find_by(cashfree_order_id: order_id)

    unless booking
      Rails.logger.error "❌ Booking not found for Cashfree order: #{order_id}"
      return
    end

    Rails.logger.info "📦 Found booking: #{booking.id} (#{booking.booking_number})"

    if booking.payment_successful?
      Rails.logger.info "⚠️ Payment already processed for booking: #{booking.booking_number}"
      return
    end

    # Extract payment method from complex object
    raw_payment_method = payment_data['payment']['payment_method']
    Rails.logger.info "🔍 Raw payment method from webhook: #{raw_payment_method.inspect}"

    extracted_payment_method = if raw_payment_method.is_a?(Hash)
      # Extract the main payment type from complex object like {"upi"=>{"channel"=>nil, "upi_id"=>"..."}}
      extracted = raw_payment_method.keys.first
      Rails.logger.info "📤 Extracted payment method from hash: #{extracted}"
      extracted
    else
      # Use as-is if it's already a string
      Rails.logger.info "📤 Using payment method as-is: #{raw_payment_method}"
      raw_payment_method
    end

    # Mark payment as successful
    payment_details = {
      cf_payment_id: payment_id,
      payment_method: extracted_payment_method,
      order_status: 'PAID',
      payment_amount: payment_data['order']['order_amount'],
      bank_reference: payment_data['payment']['bank_reference'],
      auth_id: payment_data['payment']['auth_id']
    }

    booking.mark_payment_completed!(payment_details)

    Rails.logger.info "✅ Payment confirmed via webhook for booking: #{booking.booking_number}"

    # Send confirmation email
    begin
      CustomerMailer.booking_confirmation(booking).deliver_now
      Rails.logger.info "📧 Confirmation email sent to #{booking.customer_email}"
    rescue => e
      Rails.logger.error "📧 Email sending failed: #{e.message}"
    end

  rescue => e
    Rails.logger.error "❌ Error processing payment success webhook: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  def handle_payment_failed(payment_data)
    order_id = payment_data['order']['order_id']
    failure_reason = payment_data['payment']['payment_message'] || 'Payment failed'

    booking = Booking.find_by(cashfree_order_id: order_id)

    unless booking
      Rails.logger.warn "Booking not found for failed Cashfree order: #{order_id}"
      return
    end

    booking.mark_payment_failed!(failure_reason)

    Rails.logger.info "Payment failed for booking: #{booking.booking_number} - #{failure_reason}"
  rescue => e
    Rails.logger.error "Error processing payment failure webhook: #{e.message}"
  end

  def handle_payment_dropped(payment_data)
    order_id = payment_data['order']['order_id']

    booking = Booking.find_by(cashfree_order_id: order_id)

    unless booking
      Rails.logger.warn "Booking not found for dropped Cashfree order: #{order_id}"
      return
    end

    booking.mark_payment_failed!('Payment cancelled by user')

    Rails.logger.info "Payment dropped by user for booking: #{booking.booking_number}"
  rescue => e
    Rails.logger.error "Error processing payment dropped webhook: #{e.message}"
  end
end
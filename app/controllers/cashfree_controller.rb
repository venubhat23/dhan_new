class CashfreeController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:webhook]

  def webhook
    timestamp = request.headers['x-webhook-timestamp']
    signature = request.headers['x-webhook-signature']
    request_body = request.raw_post

    # Verify webhook signature
    unless CashfreeService.verify_signature(request_body, signature, timestamp)
      Rails.logger.warn "Cashfree webhook signature verification failed"
      render json: { status: 'error', message: 'Invalid signature' }, status: :unauthorized
      return
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
    order_id = payment_data['order']['order_id']
    payment_id = payment_data['payment']['cf_payment_id']

    booking = Booking.find_by(cashfree_order_id: order_id)

    unless booking
      Rails.logger.warn "Booking not found for Cashfree order: #{order_id}"
      return
    end

    if booking.payment_successful?
      Rails.logger.info "Payment already processed for booking: #{booking.booking_number}"
      return
    end

    # Mark payment as successful
    booking.mark_payment_completed!({
      cf_payment_id: payment_id,
      payment_method: payment_data['payment']['payment_method'],
      order_status: 'PAID',
      payment_amount: payment_data['order']['order_amount'],
      bank_reference: payment_data['payment']['bank_reference'],
      auth_id: payment_data['payment']['auth_id']
    })

    Rails.logger.info "Payment confirmed via webhook for booking: #{booking.booking_number}"

    # Send confirmation email/SMS if needed
    # PaymentNotificationMailer.payment_success(booking).deliver_later
  rescue => e
    Rails.logger.error "Error processing payment success webhook: #{e.message}"
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
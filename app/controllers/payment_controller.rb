class PaymentController < ApplicationController
  before_action :authenticate_customer!
  before_action :set_booking, only: [:create_order, :success]

  def create_order
    unless @booking.can_initiate_payment?
      return render json: {
        success: false,
        message: 'Invalid booking for payment initiation'
      }, status: :unprocessable_entity
    end

    # Mark payment as initiated
    @booking.mark_payment_initiated!('cashfree')

    # Generate unique Cashfree order ID
    cashfree_order_id = Booking.generate_cashfree_order_id
    @booking.update!(cashfree_order_id: cashfree_order_id)

    # Create order with Cashfree
    response = CashfreeService.create_order(@booking)

    if response[:success]
      order_data = response[:data]

      # Store payment session ID
      @booking.update!(
        payment_session_id: order_data['payment_session_id']
      )

      render json: {
        success: true,
        payment_session_id: order_data['payment_session_id'],
        order_id: @booking.cashfree_order_id,
        amount: @booking.total_amount,
        customer_id: @booking.customer.id,
        booking_id: @booking.id
      }
    else
      @booking.mark_payment_failed!(response[:message])

      render json: {
        success: false,
        message: response[:message] || 'Failed to create payment order',
        error: response[:error]
      }, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "Payment order creation failed: #{e.message}"

    @booking&.mark_payment_failed!(e.message)

    render json: {
      success: false,
      message: 'Payment initialization failed. Please try again.'
    }, status: :internal_server_error
  end

  def success
    payment_id = params[:cf_payment_id]
    order_id = params[:order_id]

    if payment_id.blank?
      redirect_to customer_dashboard_path, alert: 'Payment verification failed'
      return
    end

    # Verify payment with Cashfree
    response = CashfreeService.verify_payment(payment_id)

    if response[:success]
      payment_data = response[:data]

      if payment_data['order_status'] == 'PAID' && payment_data['order_id'] == @booking.cashfree_order_id
        # Payment successful
        @booking.mark_payment_completed!({
          cf_payment_id: payment_id,
          payment_method: payment_data['payment_method'],
          order_status: payment_data['order_status'],
          payment_amount: payment_data['order_amount']
        })

        redirect_to customer_dashboard_path,
                   notice: "Payment successful! Your order ##{@booking.booking_number} has been confirmed."
      else
        # Payment verification failed
        @booking.mark_payment_failed!("Payment status: #{payment_data['order_status']}")

        redirect_to customer_dashboard_path,
                   alert: 'Payment verification failed. Please contact support.'
      end
    else
      @booking.mark_payment_failed!(response[:message])

      redirect_to customer_dashboard_path,
                 alert: 'Payment verification failed. Please try again or contact support.'
    end
  rescue => e
    Rails.logger.error "Payment verification failed: #{e.message}"

    @booking&.mark_payment_failed!(e.message)

    redirect_to customer_dashboard_path,
               alert: 'Payment verification error. Please contact support.'
  end

  def failure
    booking_id = params[:booking_id]
    reason = params[:reason] || 'Payment failed'

    if booking_id.present?
      booking = current_customer.bookings.find_by(id: booking_id)
      booking&.mark_payment_failed!(reason)
    end

    redirect_to customer_dashboard_path,
               alert: 'Payment failed. You can try again from your orders.'
  end

  private

  def set_booking
    @booking = current_customer.bookings.find_by(id: params[:booking_id])

    unless @booking
      if request.format.json?
        render json: { success: false, message: 'Booking not found' }, status: :not_found
      else
        redirect_to customer_dashboard_path, alert: 'Order not found'
      end
      return
    end
  end

  def authenticate_customer!
    unless current_customer
      if request.format.json?
        render json: { success: false, message: 'Authentication required' }, status: :unauthorized
      else
        redirect_to customer_login_path, alert: 'Please login to continue'
      end
    end
  end
end
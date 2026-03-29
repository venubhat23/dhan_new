class PaymentController < Customer::BaseController
  before_action :set_booking, only: [:success]

  def create_order
    # Create booking from cart data
    cart_items = params[:cart_items] || []

    if cart_items.empty?
      return render json: {
        success: false,
        message: 'Cart is empty'
      }, status: :unprocessable_entity
    end

    begin
      ActiveRecord::Base.transaction do
        # Handle delivery method and address
        delivery_method = params[:delivery_method] || 'home'

        if delivery_method == 'pickup'
          # For pickup orders, use pickup location as delivery address
          pickup_location = params[:pickup_location] || 'Shop location not specified'
          delivery_address = "PICKUP: #{pickup_location}"
        else
          # For home delivery, use provided delivery address
          delivery_address = params[:delivery_address] || 'Address not specified'
        end

        # Create booking
        @booking = Booking.new(
          customer: current_customer,
          booking_date: Time.current,
          booking_number: generate_booking_number,
          customer_name: params[:customer_name] || current_customer&.display_name,
          customer_email: params[:customer_email] || current_customer&.email,
          customer_phone: params[:customer_phone] || current_customer&.mobile,
          delivery_address: delivery_address,
          payment_method: params[:payment_method] == 'cod' ? 'cod' : 'cashfree',
          payment_gateway: params[:payment_method] == 'cod' ? 'cash' : 'cashfree',
          status: 'draft'
        )

        # Create booking items
        total_amount = 0
        cart_items.each do |item_data|
          product = Product.find(item_data[:product_id])
          quantity = item_data[:quantity].to_f
          price = item_data[:price].to_f

          # Validate stock
          if product.total_batch_stock < quantity
            raise "Insufficient stock for #{product.name}. Only #{product.total_batch_stock} available."
          end

          # Create booking item
          @booking.booking_items.build(
            product: product,
            quantity: quantity,
            price: price
          )

          total_amount += (price * quantity)
        end

        # Calculate totals
        @booking.calculate_totals
        @booking.save!

        if @booking.payment_method == 'cloudflare'
          # Mark payment as initiated for Cloudflare
          @booking.mark_payment_initiated!('cloudflare')

          # Generate unique Cloudflare order ID
          cloudflare_order_id = Booking.generate_cloudflare_order_id
          @booking.update!(cloudflare_order_id: cloudflare_order_id)

          # Create order with Cloudflare Worker
          response = CloudflarePaymentService.create_order(@booking)

          if response[:success]
            order_data = response[:data]

            # Store payment session ID
            @booking.update!(
              payment_session_id: order_data['payment_session_id']
            )

            render json: {
              success: true,
              payment_session_id: order_data['payment_session_id'],
              order_id: @booking.cloudflare_order_id,
              payment_url: order_data['payment_url'],
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
        elsif @booking.payment_method == 'cashfree'
          # Keep existing Cashfree logic for backward compatibility
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
        else
          # COD Order - mark as completed immediately
          @booking.mark_payment_completed!({
            payment_method: 'cod',
            order_status: 'COMPLETED',
            payment_amount: @booking.total_amount
          })

          render json: {
            success: true,
            order_id: @booking.booking_number,
            amount: @booking.total_amount,
            customer_id: @booking.customer.id,
            booking_id: @booking.id,
            message: 'COD order placed successfully'
          }
        end
      end
    end
  rescue => e
    Rails.logger.error "Payment order creation failed: #{e.message}"

    render json: {
      success: false,
      message: "Payment initialization failed: #{e.message}"
    }, status: :internal_server_error
  end

  def success
    payment_id = params[:cf_payment_id]
    order_id = params[:order_id]

    # Check if payment was already processed by webhook
    if @booking.payment_successful?
      Rails.logger.info "✅ Payment already processed by webhook for booking: #{@booking.booking_number}"
      redirect_to customer_order_path(@booking),
                 notice: "Payment successful! Your order ##{@booking.booking_number} has been confirmed."
      return
    end

    if payment_id.blank?
      # If no payment ID but booking exists, redirect to specific order page
      redirect_to customer_order_path(@booking), alert: 'Payment verification failed'
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

        # Generate invoice after successful payment
        generate_invoice_for_booking(@booking)

        # Redirect to the specific order page
        redirect_to customer_order_path(@booking),
                   notice: "Payment successful! Your order ##{@booking.booking_number} has been confirmed."
      else
        # Payment verification failed
        @booking.mark_payment_failed!("Payment status: #{payment_data['order_status']}")

        redirect_to customer_order_path(@booking),
                   alert: 'Payment verification failed. Please contact support.'
      end
    else
      @booking.mark_payment_failed!(response[:message])

      redirect_to customer_order_path(@booking),
                 alert: 'Payment verification failed. Please try again or contact support.'
    end
  rescue => e
    Rails.logger.error "Payment verification failed: #{e.message}"

    @booking&.mark_payment_failed!(e.message)

    redirect_to customer_order_path(@booking),
               alert: 'Payment verification error. Please contact support.'
  end

  def failure
    booking_id = params[:booking_id]
    reason = params[:reason] || 'Payment failed'

    if booking_id.present?
      booking = current_customer.bookings.find_by(id: booking_id)
      booking&.mark_payment_failed!(reason)
    end

    redirect_to customer_orders_path,
               alert: 'Payment failed. You can try again from your orders.'
  end

  def cloudflare_webhook
    Rails.logger.info "Cloudflare webhook received: #{request.body.read}"

    begin
      request_body = request.body.read
      webhook_data = JSON.parse(request_body)

      # Process webhook
      result = CloudflarePaymentService.process_webhook(webhook_data)

      if result[:success]
        render json: { status: 'success', message: 'Webhook processed' }, status: :ok
      else
        render json: { status: 'error', message: result[:message] }, status: :unprocessable_entity
      end

    rescue JSON::ParserError => e
      Rails.logger.error "Invalid JSON in webhook: #{e.message}"
      render json: { status: 'error', message: 'Invalid JSON' }, status: :bad_request
    rescue => e
      Rails.logger.error "Webhook processing error: #{e.message}"
      render json: { status: 'error', message: 'Processing failed' }, status: :internal_server_error
    end
  end

  private

  def set_booking
    @booking = current_customer.bookings.find_by(id: params[:booking_id])

    unless @booking
      if request.format.json?
        render json: { success: false, message: 'Booking not found' }, status: :not_found
      else
        redirect_to customer_orders_path, alert: 'Order not found'
      end
      return
    end
  end


  def generate_booking_number
    "BK#{Date.current.strftime('%Y%m%d')}#{rand(1000..9999)}"
  end

  def generate_invoice_for_booking(booking)
    # Check if invoice already exists
    return if booking.booking_invoices.exists?

    begin
      # Create invoice for the booking using existing method
      booking.create_booking_invoice_record

      Rails.logger.info "📄 Generated invoice for booking ##{booking.booking_number}"

      # Get the created invoice
      invoice = booking.booking_invoices.first

      # Mark as paid since payment was successful
      invoice&.mark_as_paid!

      # Send invoice email to customer
      send_invoice_email(invoice) if invoice&.customer_email.present?

      invoice
    rescue => e
      Rails.logger.error "❌ Failed to generate invoice for booking ##{booking.booking_number}: #{e.message}"
      nil
    end
  end

  def generate_invoice_number
    "INV#{Date.current.strftime('%Y%m%d')}#{rand(1000..9999)}"
  end

  def send_invoice_email(invoice)
    # Send invoice email (implement based on your mailer)
    begin
      # Assuming you have InvoiceMailer
      if defined?(InvoiceMailer)
        InvoiceMailer.invoice_generated(invoice).deliver_now
        Rails.logger.info "📧 Invoice email sent to #{invoice.customer_email}"
      end
    rescue => e
      Rails.logger.error "❌ Failed to send invoice email: #{e.message}"
    end
  end
end
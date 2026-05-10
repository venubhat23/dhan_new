class Customer::ShopController < Customer::BaseController
  def index
    @booking = Booking.new
    @booking.booking_items.build

    # Get categories for filters
    @categories = Category.where(status: true).order(:display_order, :name)

    # Simple query without complex SQL to avoid syntax errors
    @products = Product.active
                      .includes(:category, :stock_batches, :product_reviews, :product_variants)
                      .by_stock_availability

    # Apply search filter if present
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @products = @products.joins(:category)
                          .where("products.name ILIKE ? OR products.sku ILIKE ? OR categories.name ILIKE ?",
                                 search_term, search_term, search_term)
    end

    # Apply category filter
    if params[:category_id].present? && params[:category_id] != ''
      @products = @products.where(category_id: params[:category_id])
    end

    # Get customer info if logged in
    @customer_addresses = current_customer&.customer_addresses || []
  end

  def category
    @category = Category.find(params[:id])
    @products = @category.products.where(status: 'active')

    # Apply same filtering logic as index
    if params[:search].present?
      @search_query = params[:search]
      @products = @products.where("name ILIKE ? OR description ILIKE ?",
                                  "%#{params[:search]}%", "%#{params[:search]}%")
    end

    # Price range filter
    if params[:min_price].present?
      @products = @products.where("price >= ?", params[:min_price].to_f)
    end

    if params[:max_price].present?
      @products = @products.where("price <= ?", params[:max_price].to_f)
    end

    # Sorting
    case params[:sort]
    when 'price_low'
      @products = @products.order(:price)
    when 'price_high'
      @products = @products.order(price: :desc)
    when 'name'
      @products = @products.order(:name)
    when 'newest'
      @products = @products.order(created_at: :desc)
    else
      @products = @products.by_stock_availability
    end

    @products = @products.page(params[:page]).per(12)
  end

  def product
    @product = Product.find(params[:id])
    @related_products = Product.where(category_id: @product.category_id)
                               .where.not(id: @product.id)
                               .where(status: 'active')
                               .limit(4)
  end

  def success
    @booking = current_customer&.bookings&.find_by(booking_number: params[:booking_id])

    unless @booking
      flash[:error] = 'Order not found.'
      redirect_to customer_shop_path and return
    end
  end

  def check_delivery_pincode
    pincode = params[:pincode].to_s.strip
    if pincode.blank? || !pincode.match?(/\A\d{6}\z/)
      return render json: { success: false, message: 'Please enter a valid 6-digit pincode' }
    end

    charge_record = DeliveryCharge.for_pincode(pincode)
    if charge_record
      render json: {
        success: true,
        deliverable: true,
        delivery_charge: charge_record.charge_amount.to_f,
        area: charge_record.area,
        message: charge_record.charge_amount.to_f > 0 ?
          "Delivery charge: ₹#{charge_record.charge_amount}" :
          'Free delivery available'
      }
    else
      render json: {
        success: true,
        deliverable: false,
        delivery_charge: 0,
        message: 'Delivery not available to this pincode'
      }
    end
  end

  def cart_order
    # Create order from cart data
    cart_data = params[:cart_items] || []

    if cart_data.empty?
      render json: { error: 'Cart is empty' }, status: :unprocessable_entity
      return
    end

    begin
      ActiveRecord::Base.transaction do
        # Initialize booking with minimal attributes to avoid callbacks
        @booking = Booking.new
        @booking.customer = current_customer
        @booking.booking_date = Time.current
        @booking.customer_name = current_customer&.display_name
        @booking.customer_email = current_customer&.email
        @booking.customer_phone = current_customer&.mobile
        @booking.payment_method = params[:payment_method] || 'cod'

        # Create booking items from cart
        total_amount = 0
        cart_data.each do |item_data|
          product = Product.find(item_data[:product_id])
          quantity = item_data[:quantity].to_f
          price = item_data[:price].to_f

          # Validate stock
          if !product.can_fulfill_order?(quantity)
            render json: {
              error: "Insufficient stock for #{product.name}. Only #{product.available_quantity} available."
            }, status: :unprocessable_entity
            return
          end

          # Create booking item
          booking_item = @booking.booking_items.build(
            product: product,
            quantity: quantity,
            price: price
          )

          total_amount += (price * quantity)
        end

        # Set totals
        @booking.subtotal = total_amount
        @booking.total_amount = total_amount

        # Set status after all other attributes
        @booking.status = 'confirmed'
        @booking.payment_status = 'unpaid'

        @booking.save!

        render json: {
          success: true,
          booking_number: @booking.booking_number,
          redirect_url: customer_shop_success_path(booking_id: @booking.booking_number)
        }
      end

    rescue => e
      render json: { error: "Failed to create order: #{e.message}" }, status: :internal_server_error
    end
  end

  def create_booking
    # Initialize booking with customer information
    @booking = Booking.new(booking_params)
    @booking.customer = current_customer
    @booking.booking_date = Date.current

    # Handle customer information from form
    @booking.customer_name = params.dig(:booking, :customer_name) || current_customer&.display_name
    @booking.customer_email = params.dig(:booking, :customer_email) || current_customer&.email
    @booking.customer_phone = params.dig(:booking, :customer_phone) || current_customer&.mobile

    # Set initial status and payment status
    @booking.status = 'confirmed'
    @booking.payment_status = 'unpaid' # Default to unpaid, can be updated based on payment method

    begin
      # Process booking items from cart data
      if params[:booking_items].present?
        ActiveRecord::Base.transaction do
          params[:booking_items].each do |index, item_data|
            quantity = item_data[:quantity].to_f
            next if quantity <= 0

            product = Product.find(item_data[:product_id])

            # Check stock availability
            available_stock = product.stock_batches.where(status: 'active').sum(:quantity_remaining) || 0
            if quantity > available_stock
              flash[:error] = "Insufficient stock for #{product.name}. Only #{available_stock} available."
              redirect_to customer_shop_path and return
            end

            # Create booking item
            booking_item = @booking.booking_items.build(
              product_id: item_data[:product_id],
              quantity: quantity,
              price: item_data[:price].to_f
            )
          end

          # Save booking if items exist
          if @booking.booking_items.any?
            @booking.save!

            # Calculate totals after saving
            @booking.calculate_totals
            @booking.save!

            # Handle payment method specific logic
            if @booking.payment_method == 'cash'
              @booking.update(payment_status: 'unpaid')
              success_message = "Order placed successfully! Payment will be collected on delivery."
            else
              success_message = "Order placed successfully! Booking number: #{@booking.booking_number}"
            end

            # Successful order creation - redirect to success page with booking ID
            redirect_to customer_shop_success_path(booking_id: @booking.booking_number)
          else
            flash[:error] = 'Please add items to your cart before placing the order.'
            redirect_to customer_shop_path
          end
        end
      else
        flash[:error] = 'No items found in your cart. Please add items before placing an order.'
        redirect_to customer_shop_path
      end

    rescue ActiveRecord::RecordInvalid => e
      # Handle validation errors
      flash[:error] = "Order could not be placed: #{e.record.errors.full_messages.join(', ')}"
      redirect_to customer_shop_path

    rescue StandardError => e
      # Handle any other errors
      Rails.logger.error "Checkout Error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      flash[:error] = 'An error occurred while processing your order. Please try again.'
      redirect_to customer_shop_path
    end
  end

  private

  def booking_params
    params.require(:booking).permit(
      :customer_name, :customer_email, :customer_phone,
      :delivery_address, :notes, :payment_method,
      :booking_date, :discount_amount
    )
  end
end
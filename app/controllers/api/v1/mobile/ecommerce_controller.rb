class Api::V1::Mobile::EcommerceController < Api::V1::Mobile::BaseController
  before_action :authenticate_customer!, except: [:products, :banners, :featured_products]
  before_action :set_category, only: [:category_details, :category_products]
  before_action :set_product, only: [:product_details, :check_delivery]

  # GET /api/v1/mobile/ecommerce/categories
  def categories
    @categories = Category.active.ordered.includes(:products)

    categories_data = @categories.map do |category|
      {
        id: category.id,
        name: category.name,
        description: category.description,
        image_url: category.image.attached? ? url_for(category.image) : nil,
        products_count: category.products_count,
        display_order: category.display_order
      }
    end

    render json: {
      success: true,
      data: categories_data,
      message: 'Categories retrieved successfully'
    }
  end

  # GET /api/v1/mobile/ecommerce/categories/:id
  def category_details
    category_data = {
      id: @category.id,
      name: @category.name,
      description: @category.description,
      image_url: @category.image.attached? ? url_for(@category.image) : nil,
      products_count: @category.products_count,
      display_order: @category.display_order
    }

    json_response({
      success: true,
      data: category_data,
      message: 'Category details retrieved successfully'
    })
  end

  # GET /api/v1/mobile/ecommerce/products
  def products
    page = params[:page]&.to_i || 1
    per_page = params[:per_page]&.to_i || 20
    per_page = [per_page, 50].min

    @products = Product.active.in_stock

    # Apply filters
    @products = @products.where(category_id: params[:category_id]) if params[:category_id].present?
    @products = @products.where('price >= ?', params[:min_price]) if params[:min_price].present?
    @products = @products.where('price <= ?', params[:max_price]) if params[:max_price].present?
    @products = @products.search(params[:search]) if params[:search].present?

    # Apply sorting
    case params[:sort_by]
    when 'price_low' then @products = @products.order(:price)
    when 'price_high' then @products = @products.order(price: :desc)
    when 'name' then @products = @products.order(:name)
    when 'newest' then @products = @products.recent
    when 'rating'
      @products = @products.joins(:product_reviews)
                           .group('products.id')
                           .order('AVG(product_reviews.rating) DESC NULLS LAST')
    else
      @products = @products.order(:name)
    end

    # Handle count for grouped queries (like rating sort)
    total_count = case params[:sort_by]
    when 'rating'
      @products.count.size
    else
      @products.count
    end
    @products = @products.offset((page - 1) * per_page).limit(per_page)

    products_data = @products.map { |product| format_product_data(product) }

    json_response({
      success: true,
      data: {
        products: products_data,
        pagination: {
          current_page: page,
          per_page: per_page,
          total_count: total_count,
          total_pages: (total_count.to_f / per_page).ceil,
          has_next_page: page < (total_count.to_f / per_page).ceil,
          has_prev_page: page > 1
        },
        applied_filters: {
          category_id: params[:category_id],
          min_price: params[:min_price],
          max_price: params[:max_price],
          search: params[:search],
          sort_by: params[:sort_by]
        }
      },
      message: 'Products retrieved successfully'
    })
  end

  # GET /api/v1/mobile/ecommerce/categories/:id/products
  def category_products
    page = params[:page]&.to_i || 1
    per_page = params[:per_page]&.to_i || 20
    per_page = [per_page, 50].min

    @products = Product.active.in_stock.where(category_id: @category.id)

    @products = @products.where('price >= ?', params[:min_price]) if params[:min_price].present?
    @products = @products.where('price <= ?', params[:max_price]) if params[:max_price].present?
    @products = @products.search(params[:search]) if params[:search].present?

    case params[:sort_by]
    when 'price_low' then @products = @products.order(:price)
    when 'price_high' then @products = @products.order(price: :desc)
    when 'name' then @products = @products.order(:name)
    when 'newest' then @products = @products.recent
    when 'rating'
      @products = @products.joins(:product_reviews)
                           .group('products.id')
                           .order('AVG(product_reviews.rating) DESC NULLS LAST')
    else
      @products = @products.order(:name)
    end

    # Handle count properly when grouping is involved
    total_count = case sort_by
    when 'rating'
      @products.group('products.id').count.size
    else
      @products.count
    end

    @products = @products.offset((page - 1) * per_page).limit(per_page)

    products_data = @products.map { |product| format_product_data(product) }

    json_response({
      success: true,
      data: {
        products: products_data,
        pagination: {
          current_page: page,
          per_page: per_page,
          total_count: total_count,
          total_pages: (total_count.to_f / per_page).ceil,
          has_next_page: page < (total_count.to_f / per_page).ceil,
          has_prev_page: page > 1
        },
        category: {
          id: @category.id,
          name: @category.name
        },
        applied_filters: {
          min_price: params[:min_price],
          max_price: params[:max_price],
          search: params[:search],
          sort_by: params[:sort_by]
        }
      },
      message: 'Category products retrieved successfully'
    })
  end

  # POST /api/v1/mobile/ecommerce/bookings
  def create_booking
    booking_params = params.require(:booking).permit(
      :customer_id, :customer_name, :customer_email, :customer_phone, :delivery_address,
      :payment_method, :notes, :pincode, :latitude, :longitude,
      booking_items_attributes: [:product_id, :quantity, :price]
    )

    # Validate required fields
    required_fields = [:customer_id, :delivery_address, :pincode]
    missing_fields = required_fields.select { |field| booking_params[field].blank? }

    if missing_fields.any?
      return render json: {
        success: false,
        message: 'Required fields are missing',
        missing_fields: missing_fields,
        required_fields: {
          customer_id: 'Customer ID is required',
          delivery_address: 'Delivery address is required',
          pincode: 'Pincode is required'
        }
      }, status: :unprocessable_entity
    end

    # Find customer from customer_id parameter
    customer = Customer.find_by(id: booking_params[:customer_id])

    unless customer
      return render json: {
        success: false,
        message: 'Customer not found',
        error: 'Please provide a valid customer_id'
      }, status: :not_found
    end

    # Extract location data for validation
    pincode = booking_params[:pincode]
    latitude = booking_params[:latitude]
    longitude = booking_params[:longitude]

    # Validate pincode if provided
    # if pincode.present?
    #   pincode_validation = validate_pincode(pincode)
    #   unless pincode_validation[:valid]
    #     return json_response({
    #       success: false,
    #       message: 'Invalid pincode provided',
    #       error_details: pincode_validation
    #     }, :unprocessable_entity)
    #   end
    # end

    # Validate products availability and delivery
    unavailable_products = []
    available_products = []

    booking_params[:booking_items_attributes]&.each do |item_params|
      product_id = item_params[:product_id]
      quantity = item_params[:quantity].to_i

      begin
        product = Product.active.find(product_id)

        # Check stock availability
        if product.stock < quantity
          unavailable_products << {
            product_id: product.id,
            product_name: product.name,
            requested_quantity: quantity,
            available_stock: product.stock,
            reason: 'Insufficient stock'
          }
          next
        end

        # Check delivery availability if pincode provided
        # if pincode.present?
        #   delivery_info = product.delivery_info_for(pincode)
        #   unless delivery_info[:deliverable]
        #     unavailable_products << {
        #       product_id: product.id,
        #       product_name: product.name,
        #       requested_quantity: quantity,
        #       available_stock: product.stock,
        #       reason: 'Delivery not available to this pincode'
        #     }
        #     next
        #   end
        # end

        # Product is available
        available_products << {
          product_id: product.id,
          product_name: product.name,
          requested_quantity: quantity,
          available_stock: product.stock,
          price: product.selling_price,
          delivery_charge: pincode.present? ? product.delivery_info_for(pincode)[:delivery_charge] : 0
        }

      rescue ActiveRecord::RecordNotFound
        unavailable_products << {
          product_id: product_id,
          product_name: 'Unknown',
          requested_quantity: quantity,
          available_stock: 0,
          reason: 'Product not found'
        }
      end
    end

    # If any products are unavailable, return error with details
    if unavailable_products.any?
      return render json: {
        success: false,
        message: 'Some products are not available for booking',
        data: {
          unavailable_products: unavailable_products,
          available_products: available_products,
          # pincode_info: pincode.present? ? pincode_validation : nil,
          pincode_info: nil,
          location_info: {
            pincode: pincode,
            latitude: latitude,
            longitude: longitude
          }
        }
      }, status: :unprocessable_entity
    end

    # All products are available, proceed with booking creation in transaction
    begin
      Rails.logger.info "Creating booking with params: #{booking_params.except(:booking_items_attributes)}"
      Rails.logger.info "Booking items: #{booking_params[:booking_items_attributes]}"
      Rails.logger.info "Customer: #{customer&.display_name} (ID: #{customer&.id})"
      Rails.logger.info "Current user: #{@current_user&.id}"

      ActiveRecord::Base.transaction do
        @booking = Booking.new(booking_params.except(:pincode, :latitude, :longitude))

        # Ensure customer association is properly set
        @booking.customer_id = customer.id
        @booking.customer = customer
        @booking.user = nil # Mobile bookings don't have associated admin users
        @booking.booking_date = Time.current
        @booking.status = 'ordered_and_delivery_pending'

        Rails.logger.info "Booking created with customer_id: #{@booking.customer_id}"
        Rails.logger.info "Booking valid? #{@booking.valid?}"
        unless @booking.valid?
          Rails.logger.error "Booking validation errors: #{@booking.errors.full_messages}"
        end

        # Save location data to customer if provided
        if customer && (latitude.present? || longitude.present? || pincode.present?)
          customer_updates = {}
          customer_updates[:latitude] = latitude if latitude.present?
          customer_updates[:longitude] = longitude if longitude.present?
          customer_updates[:location_obtained_at] = Time.current
          customer.update!(customer_updates)
        end

        @booking.save!

        # Update product stock
        @booking.booking_items.each do |item|
          product = item.product
          new_stock = product.stock - item.quantity
          product.update!(stock: new_stock)
        end

        booking_response_data = format_booking_data(@booking).merge({
          location_saved: {
            latitude: latitude,
            longitude: longitude,
            pincode: pincode
          },
          available_products: available_products,
          stock_updated: true
        })

        render json: {
          success: true,
          data: booking_response_data,
          message: 'Booking created successfully with product availability verified'
        }, status: :created
      end

    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Booking validation failed: #{e.record.errors.full_messages}"
      Rails.logger.error "Booking attributes: #{e.record.attributes}"
      render json: {
        success: false,
        message: 'Booking creation failed',
        errors: e.record.errors.full_messages,
        booking_attributes: e.record.attributes,
        available_products: available_products
      }, status: :unprocessable_entity
    rescue => e
      render json: {
        success: false,
        message: 'Booking creation failed due to system error',
        error: e.message,
        available_products: available_products
      }, status: :internal_server_error
    end
  end

  # GET /api/v1/mobile/ecommerce/bookings
  def bookings
    page = params[:page]&.to_i || 1
    per_page = params[:per_page]&.to_i || 20
    per_page = [per_page, 50].min

    # Mobile API is only for customers
    customer = Customer.find_by(email: @current_user&.email) if @current_user
    return json_response({ success: false, message: 'Customer not found' }, :not_found) unless customer

    @bookings = customer.bookings.recent.includes(:booking_items => :product)
    user_type = 'customer'

    # Filter by status if provided
    @bookings = @bookings.where(status: params[:status]) if params[:status].present?

    total_count = @bookings.count
    @bookings = @bookings.offset((page - 1) * per_page).limit(per_page)

    bookings_data = @bookings.map { |booking| format_booking_data(booking) }

    json_response({
      success: true,
      data: {
        bookings: bookings_data,
        user_type: user_type,
        pagination: {
          current_page: page,
          per_page: per_page,
          total_count: total_count,
          total_pages: (total_count.to_f / per_page).ceil,
          has_next_page: page < (total_count.to_f / per_page).ceil,
          has_prev_page: page > 1
        }
      },
      message: 'Bookings retrieved successfully'
    })
  end

  # GET /api/v1/mobile/ecommerce/orders
  def orders
    customer = Customer.find_by(email: @current_user&.email) if @current_user
    return json_response({ success: false, message: 'Customer not found' }, :not_found) unless customer

    page = params[:page]&.to_i || 1
    per_page = params[:per_page]&.to_i || 20
    per_page = [per_page, 50].min

    @orders = customer.orders.recent.includes(:order_items => :product)

    # Filter by status if provided
    @orders = @orders.where(status: params[:status]) if params[:status].present?

    total_count = @orders.count
    @orders = @orders.offset((page - 1) * per_page).limit(per_page)

    orders_data = @orders.map { |order| format_order_data(order) }

    json_response({
      success: true,
      data: {
        orders: orders_data,
        pagination: {
          current_page: page,
          per_page: per_page,
          total_count: total_count,
          total_pages: (total_count.to_f / per_page).ceil,
          has_next_page: page < (total_count.to_f / per_page).ceil,
          has_prev_page: page > 1
        }
      },
      message: 'Orders retrieved successfully'
    })
  end

  # GET /api/v1/mobile/ecommerce/orders/:id
  def order_details
    customer = Customer.find_by(email: @current_user&.email) if @current_user
    return json_response({ success: false, message: 'Customer not found' }, :not_found) unless customer

    @order = customer.orders.includes(:order_items => :product).find(params[:id])

    json_response({
      success: true,
      data: format_order_data(@order, include_items: true),
      message: 'Order details retrieved successfully'
    })
  rescue ActiveRecord::RecordNotFound
    json_response({ success: false, message: 'Order not found' }, :not_found)
  end

  # GET /api/v1/mobile/ecommerce/profile
  def customer_profile
    customer = Customer.find_by(email: @current_user&.email) if @current_user
    return json_response({ success: false, message: 'Customer not found' }, :not_found) unless customer

    # Get statistics
    total_orders = customer.orders.count
    total_bookings = customer.bookings.count
    total_spent = customer.orders.where.not(status: ['cancelled', 'returned']).sum(:total_amount)

    # Get recent activity
    recent_orders = customer.orders.recent.limit(5)
    recent_bookings = customer.bookings.recent.limit(5)

    profile_data = {
      id: customer.id,
      customer_type: "individual", # Default customer type since column doesn't exist
      first_name: customer.first_name,
      last_name: customer.last_name,
      middle_name: customer.middle_name,
      full_name: customer.display_name,
      email: customer.email,
      mobile: customer.mobile,
      whatsapp_number: customer.whatsapp_number,
      address: customer.address,
      gender: customer.gender,
      marital_status: customer.marital_status,
      birth_date: customer.birth_date,
      pan_no: customer.pan_no,
      gst_no: customer.gst_no,
      company_name: customer.company_name,
      occupation: customer.occupation,
      annual_income: customer.annual_income,
      nationality: customer.nationality,
      blood_group: customer.blood_group,
      emergency_contact_name: customer.emergency_contact_name,
      emergency_contact_number: customer.emergency_contact_number,
      preferred_language: customer.preferred_language,
      longitude: customer.longitude,
      latitude: customer.latitude,
      notes: customer.notes,
      status: customer.status,
      statistics: {
        total_orders: total_orders,
        total_bookings: total_bookings,
        total_spent: total_spent.to_f,
        member_since: customer.created_at
      },
      recent_activity: {
        orders: recent_orders.map { |order| format_order_data(order, basic: true) },
        bookings: recent_bookings.map { |booking| format_booking_data(booking, basic: true) }
      }
    }

    json_response({
      success: true,
      data: profile_data,
      message: 'Profile retrieved successfully'
    })
  end

  # PUT /api/v1/mobile/ecommerce/profile
  def update_profile
    Rails.logger.info "=== UPDATE PROFILE START ==="
    Rails.logger.info "Current user: #{@current_user.inspect}"
    Rails.logger.info "Params received: #{params.except(:controller, :action).inspect}"

    customer = Customer.find_by(email: @current_user&.email) if @current_user
    return json_response({ success: false, message: 'Customer not found' }, :not_found) unless customer

    Rails.logger.info "Customer found: #{customer.email}"

    # Handle both 'customer' and 'ecommerce' parameter formats for flexibility
    profile_params = if params[:customer].present?
      params.require(:customer).permit(
        :first_name, :last_name, :middle_name, :mobile, :whatsapp_number,
        :address, :gender, :marital_status, :birth_date, :pan_no, :gst_no,
        :company_name, :occupation, :annual_income, :nationality, :blood_group,
        :emergency_contact_name, :emergency_contact_number, :preferred_language,
        :longitude, :latitude, :notes
      )
    elsif params[:ecommerce].present?
      params.require(:ecommerce).permit(
        :first_name, :last_name, :middle_name, :mobile, :whatsapp_number,
        :address, :gender, :marital_status, :birth_date, :pan_no, :gst_no,
        :company_name, :occupation, :annual_income, :nationality, :blood_group,
        :emergency_contact_name, :emergency_contact_number, :preferred_language,
        :longitude, :latitude, :notes
      )
    else
      # Handle direct parameters (backwards compatibility)
      params.permit(
        :first_name, :last_name, :middle_name, :mobile, :whatsapp_number,
        :address, :gender, :marital_status, :birth_date, :pan_no, :gst_no,
        :company_name, :occupation, :annual_income, :nationality, :blood_group,
        :emergency_contact_name, :emergency_contact_number, :preferred_language,
        :longitude, :latitude, :notes
      )
    end

    if customer.update(profile_params)
      json_response({
        success: true,
        data: {
          id: customer.id,
          first_name: customer.first_name,
          last_name: customer.last_name,
          middle_name: customer.middle_name,
          full_name: customer.display_name,
          email: customer.email,
          mobile: customer.mobile,
          whatsapp_number: customer.whatsapp_number,
          address: customer.address,
          gender: customer.gender,
          marital_status: customer.marital_status,
          birth_date: customer.birth_date,
          pan_no: customer.pan_no,
          gst_no: customer.gst_no,
          company_name: customer.company_name,
          occupation: customer.occupation,
          annual_income: customer.annual_income,
          nationality: customer.nationality,
          blood_group: customer.blood_group,
          emergency_contact_name: customer.emergency_contact_name,
          emergency_contact_number: customer.emergency_contact_number,
          preferred_language: customer.preferred_language,
          longitude: customer.longitude,
          latitude: customer.latitude,
          notes: customer.notes,
          status: customer.status
        },
        message: 'Profile updated successfully'
      })
    else
      json_response({
        success: false,
        message: 'Profile update failed',
        errors: customer.errors.full_messages
      }, :unprocessable_entity)
    end
  end

  # GET /api/v1/mobile/ecommerce/search
  def search
    query = params[:query] || params[:q] || params[:search]
    if query.blank?
      return json_response({
        success: false,
        message: 'Search query is required',
        data: {
          products: [],
          search_query: query,
          pagination: {
            current_page: 1,
            per_page: 20,
            total_count: 0,
            total_pages: 0,
            has_next_page: false,
            has_prev_page: false
          }
        }
      }, :bad_request)
    end

    page = params[:page]&.to_i || 1
    per_page = params[:per_page]&.to_i || 20
    per_page = [per_page, 50].min

    begin
      @products = Product.active.in_stock.search(query)

      # Apply additional filters
      @products = @products.where(category_id: params[:category_id]) if params[:category_id].present?
      @products = @products.where('price >= ?', params[:min_price]) if params[:min_price].present?
      @products = @products.where('price <= ?', params[:max_price]) if params[:max_price].present?

      # Handle count for queries with GROUP BY
      has_grouping = false

      # Apply sorting
      case params[:sort_by]
      when 'price_low' then @products = @products.order(:price)
      when 'price_high' then @products = @products.order(price: :desc)
      when 'name' then @products = @products.order(:name)
      when 'newest' then @products = @products.recent
      when 'rating'
        @products = @products.joins(:product_reviews)
                             .group('products.id')
                             .order('AVG(product_reviews.rating) DESC NULLS LAST')
        has_grouping = true
      else
        @products = @products.order(:name)
      end

      # Get count properly based on whether we have grouping
      if has_grouping
        total_count = @products.count.size
      else
        total_count = @products.count
      end

      @products = @products.offset((page - 1) * per_page).limit(per_page)
      products_data = @products.map { |product| format_product_data(product) }

      json_response({
        success: true,
        data: {
          products: products_data,
          search_query: query,
          pagination: {
            current_page: page,
            per_page: per_page,
            total_count: total_count,
            total_pages: (total_count.to_f / per_page).ceil,
            has_next_page: page < (total_count.to_f / per_page).ceil,
            has_prev_page: page > 1
          },
          applied_filters: {
            category_id: params[:category_id],
            min_price: params[:min_price],
            max_price: params[:max_price],
            sort_by: params[:sort_by]
          }
        },
        message: "Found #{total_count} products for '#{query}'"
      })
    rescue => e
      Rails.logger.error "Search API Error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      json_response({
        success: false,
        message: 'An error occurred while searching products',
        data: {
          products: [],
          search_query: query,
          pagination: {
            current_page: page,
            per_page: per_page,
            total_count: 0,
            total_pages: 0,
            has_next_page: false,
            has_prev_page: false
          }
        }
      }, :internal_server_error)
    end
  end

  # GET /api/v1/mobile/ecommerce/featured_products
  def featured_products
    # Get top 5 most recent products that came to market (based on created_at)
    limit = params[:limit]&.to_i || 5
    limit = [limit, 10].min # Maximum 10 products

    begin
      @products = Product.active.in_stock
                          .order(created_at: :desc)
                          .limit(limit)

      products_data = @products.map { |product| format_product_data(product) }

      json_response({
        success: true,
        data: {
          products: products_data,
          total_count: products_data.length,
          limit: limit,
          message_info: "Showing #{products_data.length} most recent products that came to market"
        },
        message: "Top #{products_data.length} recent products retrieved successfully"
      })
    rescue => e
      Rails.logger.error "Featured Products API Error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      json_response({
        success: false,
        message: 'Unable to retrieve featured products',
        error: e.message,
        data: {
          products: [],
          total_count: 0,
          limit: limit
        }
      }, :internal_server_error)
    end
  end

  # GET /api/v1/mobile/ecommerce/filters
  def filters
    # Get available filter options
    categories = Category.active.root_categories.pluck(:id, :name)

    # Get price range
    price_stats = Product.active.in_stock
    min_price = price_stats.minimum(:price) || 0
    max_price = price_stats.maximum(:price) || 10000

    # Get available brands/companies (if you have a brand field)
    brands = Product.active.distinct.where.not(brand: [nil, '']).pluck(:brand) rescue []

    filter_data = {
      categories: categories.map { |id, name| { id: id, name: name } },
      price_range: {
        min: min_price.to_f,
        max: max_price.to_f,
        suggested_ranges: [
          { label: 'Under ₹500', min: 0, max: 500 },
          { label: '₹500 - ₹1000', min: 500, max: 1000 },
          { label: '₹1000 - ₹5000', min: 1000, max: 5000 },
          { label: '₹5000 - ₹10000', min: 5000, max: 10000 },
          { label: 'Above ₹10000', min: 10000, max: nil }
        ]
      },
      brands: brands,
      sort_options: [
        { key: 'newest', label: 'Newest First' },
        { key: 'price_low', label: 'Price: Low to High' },
        { key: 'price_high', label: 'Price: High to Low' },
        { key: 'name', label: 'Name A-Z' },
        { key: 'rating', label: 'Highest Rated' }
      ]
    }

    json_response({
      success: true,
      data: filter_data,
      message: 'Filter options retrieved successfully'
    })
  end

  # GET /api/v1/mobile/ecommerce/products/:id
  def product_details
    @product = Product.active.includes(:category, :product_reviews, image_attachment: :blob, additional_images_attachments: :blob).find(params[:id])

    # Get related products from same category
    related_products = Product.active.in_stock
                              .where(category_id: @product.category_id)
                              .where.not(id: @product.id)
                              .limit(5)

    # Get recent reviews
    recent_reviews = @product.product_reviews.approved.recent.limit(10).includes(:customer)

    product_data = format_product_data(@product).merge({
      related_products: related_products.map { |p| format_product_data(p) },
      reviews: recent_reviews.map do |review|
        {
          id: review.id,
          rating: review.rating,
          comment: review.comment,
          reviewer_name: review.reviewer_name || review.customer&.display_name,
          verified_purchase: review.verified_purchase?,
          helpful_count: review.helpful_count || 0,
          created_at: review.created_at
        }
      end,
      delivery_info: {
        available_locations: ['All India'], # You can customize this
        estimated_delivery: '3-5 business days',
        shipping_charges: 'Free shipping above ₹500'
      }
    })

    json_response({
      success: true,
      data: product_data,
      message: 'Product details retrieved successfully'
    })
  rescue ActiveRecord::RecordNotFound
    json_response({ success: false, message: 'Product not found' }, :not_found)
  end

  # POST /api/v1/mobile/ecommerce/products/:id/check_delivery
  def check_delivery
    @product = Product.find(params[:id])
    pincode = params[:pincode]

    return json_response({ success: false, message: 'Pincode is required' }, :bad_request) if pincode.blank?

    # Check if product can be delivered to pincode
    delivery_info = @product.delivery_info_for(pincode)

    json_response({
      success: true,
      data: {
        product_id: @product.id,
        pincode: pincode,
        deliverable: delivery_info[:deliverable],
        estimated_days: delivery_info[:delivery_days],
        delivery_charge: delivery_info[:delivery_charge].to_f,
        message: delivery_info[:deliverable] ?
          "Delivery available in #{delivery_info[:delivery_days]} days" :
          "Delivery not available in this area"
      },
      message: delivery_info[:deliverable] ? 'Delivery available' : 'Delivery not available'
    })
  rescue ActiveRecord::RecordNotFound
    json_response({ success: false, message: 'Product not found' }, :not_found)
  end

  # POST /api/v1/mobile/ecommerce/subscriptions
  def create_subscription
    customer = @current_user if @current_user.is_a?(Customer)
    return render json: { success: false, message: 'Customer not found' }, status: :not_found unless customer

    subscription_params = params.require(:subscription).permit(
      :product_id, :frequency, :start_date, :end_date,
      :quantity, :delivery_time, :delivery_address, :pincode,
      :latitude, :longitude, :notes
    )

    # Validate pincode first
    pincode_validation = validate_pincode(subscription_params[:pincode])
    unless pincode_validation[:valid]
      return render json: {
        success: false,
        message: 'Invalid pincode or delivery not available',
        error_details: pincode_validation
      }, status: :unprocessable_entity
    end

    # Map mobile API params to MilkSubscription params
    milk_subscription_params = {
      customer_id: customer.id,
      product_id: subscription_params[:product_id],
      quantity: subscription_params[:quantity] || 1,
      unit: 'ltr', # Default unit for milk subscriptions
      start_date: subscription_params[:start_date],
      end_date: subscription_params[:end_date],
      delivery_time: subscription_params[:delivery_time] || 'morning',
      delivery_pattern: map_frequency_to_pattern(subscription_params[:frequency]),
      is_active: true,
      status: 'active'
    }

    @subscription = MilkSubscription.new(milk_subscription_params)

    if @subscription.save
      render json: {
        success: true,
        data: format_milk_subscription_data(@subscription),
        message: 'Subscription created successfully'
      }, status: :created
    else
      render json: {
        success: false,
        message: 'Subscription creation failed',
        errors: @subscription.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/mobile/ecommerce/subscriptions
  def subscriptions
    customer = @current_user if @current_user.is_a?(Customer)
    return render json: { success: false, message: 'Customer not found' }, status: :not_found unless customer

    page = params[:page]&.to_i || 1
    per_page = params[:per_page]&.to_i || 20
    per_page = [per_page, 50].min

    @subscriptions = MilkSubscription.where(customer: customer).includes(:product, :milk_delivery_tasks)

    # Filter by status if provided
    @subscriptions = @subscriptions.where(status: params[:status]) if params[:status].present?

    total_count = @subscriptions.count
    @subscriptions = @subscriptions.offset((page - 1) * per_page).limit(per_page)

    subscriptions_data = @subscriptions.map { |subscription| format_milk_subscription_data(subscription) }

    render json: {
      success: true,
      data: {
        subscriptions: subscriptions_data,
        pagination: {
          current_page: page,
          per_page: per_page,
          total_count: total_count,
          total_pages: (total_count.to_f / per_page).ceil,
          has_next_page: page < (total_count.to_f / per_page).ceil,
          has_prev_page: page > 1
        }
      },
      message: 'Subscriptions retrieved successfully'
    }
  end

  # GET /api/v1/mobile/ecommerce/subscriptions/:id
  def subscription_details
    customer = @current_user if @current_user.is_a?(Customer)
    return render json: { success: false, message: 'Customer not found' }, status: :not_found unless customer

    @subscription = MilkSubscription.where(customer: customer).includes(:product, :milk_delivery_tasks).find(params[:id])

    # Get recent delivery tasks from this subscription
    recent_tasks = @subscription.milk_delivery_tasks.order(delivery_date: :desc).limit(10)

    subscription_data = format_milk_subscription_data(@subscription)
    subscription_data[:recent_delivery_tasks] = recent_tasks.map do |task|
      {
        id: task.id,
        delivery_date: task.delivery_date,
        quantity: task.quantity,
        status: task.status,
        completed_at: task.completed_at,
        delivery_person: task.delivery_person ? {
          id: task.delivery_person.id,
          name: "#{task.delivery_person.first_name} #{task.delivery_person.last_name}".strip
        } : nil
      }
    end

    render json: {
      success: true,
      data: subscription_data,
      message: 'Subscription details retrieved successfully'
    }
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, message: 'Subscription not found' }, status: :not_found
  end

  # PUT /api/v1/mobile/ecommerce/subscriptions/:id/pause
  def pause_subscription
    customer = @current_user if @current_user.is_a?(Customer)
    return render json: { success: false, message: 'Customer not found' }, status: :not_found unless customer

    @subscription = MilkSubscription.where(customer: customer).find(params[:id])

    if @subscription.status == 'active'
      @subscription.update!(status: 'paused')
      render json: {
        success: true,
        data: format_milk_subscription_data(@subscription),
        message: 'Subscription paused successfully'
      }
    else
      render json: {
        success: false,
        message: "Cannot pause subscription. Current status: #{@subscription.status}"
      }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, message: 'Subscription not found' }, status: :not_found
  end

  # PUT /api/v1/mobile/ecommerce/subscriptions/:id/resume
  def resume_subscription
    customer = @current_user if @current_user.is_a?(Customer)
    return render json: { success: false, message: 'Customer not found' }, status: :not_found unless customer

    @subscription = MilkSubscription.where(customer: customer).find(params[:id])

    if @subscription.status == 'paused'
      @subscription.update!(status: 'active')
      render json: {
        success: true,
        data: format_milk_subscription_data(@subscription),
        message: 'Subscription resumed successfully'
      }
    else
      render json: {
        success: false,
        message: "Cannot resume subscription. Current status: #{@subscription.status}"
      }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, message: 'Subscription not found' }, status: :not_found
  end

  # PUT /api/v1/mobile/ecommerce/subscriptions/:id/cancel
  def cancel_subscription
    customer = @current_user if @current_user.is_a?(Customer)
    return render json: { success: false, message: 'Customer not found' }, status: :not_found unless customer

    @subscription = MilkSubscription.where(customer: customer).find(params[:id])

    unless @subscription.status == 'cancelled'
      @subscription.update!(status: 'cancelled')
      render json: {
        success: true,
        data: format_milk_subscription_data(@subscription),
        message: 'Subscription cancelled successfully'
      }
    else
      render json: {
        success: false,
        message: 'Subscription is already cancelled'
      }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, message: 'Subscription not found' }, status: :not_found
  end

  # GET /api/v1/mobile/ecommerce/banners
  def banners
    location = params[:location] || 'home'

    @banners = Banner.active
                    .current
                    .by_location(location)
                    .ordered

    banners_data = @banners.map do |banner|
      {
        id: banner.id,
        title: banner.title,
        description: banner.description,
        image_url: banner.main_image_url,
        thumbnail_url: banner.cloudinary_thumbnail_url,
        redirect_link: banner.redirect_link,
        display_location: banner.display_location,
        display_order: banner.display_order,
        display_start_date: banner.display_start_date,
        display_end_date: banner.display_end_date,
        is_active: banner.active?,
        has_image: banner.has_image?
      }
    end

    render json: {
      success: true,
      data: {
        banners: banners_data,
        total_count: banners_data.length,
        location: location
      },
      message: 'Banners retrieved successfully'
    }
  end

  # GET /api/v1/mobile/ecommerce/delivery/check-pincode/:pincode
  def check_pincode
    pincode = params[:pincode]
    return json_response({ success: false, message: 'Pincode is required' }, :bad_request) if pincode.blank?

    validation_result = validate_pincode(pincode)

    json_response({
      success: validation_result[:valid],
      data: validation_result,
      message: validation_result[:valid] ? 'Pincode is serviceable' : 'Pincode not serviceable'
    })
  end

  # POST /api/v1/mobile/ecommerce/delivery/validate
  def validate_delivery
    # Handle both direct parameters and nested parameters
    pincode = params[:pincode] || params.dig(:ecommerce, :pincode)
    product_ids = params[:product_ids] || params.dig(:ecommerce, :product_ids) || [params[:product_id] || params.dig(:ecommerce, :product_id)].compact
    delivery_date = params[:delivery_date] || params.dig(:ecommerce, :delivery_date)

    return json_response({ success: false, message: 'Pincode and Product IDs are required' }, :bad_request) if pincode.blank? || product_ids.blank?

    begin
      pincode_validation = validate_pincode(pincode)

      unless pincode_validation[:valid]
        return json_response({
          success: false,
          data: {
            pincode: pincode,
            pincode_valid: false,
            location_info: pincode_validation,
            delivery_available: false,
            products: []
          },
          message: 'Invalid pincode'
        })
      end

      # Process each product
      products_results = []
      all_deliverable = true
      unavailable_products = []

      product_ids.each do |product_id|
        begin
          product = Product.find(product_id)

          # Check product availability and delivery rules
          delivery_info = product.delivery_info_for(pincode)
          stock_available = product.in_stock?

          product_result = {
            product_id: product.id,
            product_name: product.name,
            product_sku: product.sku,
            price: product.selling_price.to_f,
            stock_available: stock_available,
            stock_quantity: product.stock,
            delivery_available: delivery_info[:deliverable] && stock_available,
            estimated_delivery_days: delivery_info[:delivery_days],
            delivery_charge: delivery_info[:delivery_charge].to_f,
            reasons: []
          }

          unless stock_available
            product_result[:reasons] << 'Product is out of stock'
            all_deliverable = false
            unavailable_products << product_result
          end

          unless delivery_info[:deliverable]
            product_result[:reasons] << 'Delivery not available in this area'
            all_deliverable = false
            unavailable_products << product_result
          end

          products_results << product_result

        rescue ActiveRecord::RecordNotFound
          product_result = {
            product_id: product_id,
            product_name: 'Unknown',
            product_sku: nil,
            price: 0,
            stock_available: false,
            stock_quantity: 0,
            delivery_available: false,
            estimated_delivery_days: 0,
            delivery_charge: 0,
            reasons: ['Product not found']
          }

          products_results << product_result
          unavailable_products << product_result
          all_deliverable = false
        end
      end

      # Prepare response data
      response_data = {
        pincode: pincode,
        delivery_date: delivery_date,
        pincode_valid: true,
        location_info: pincode_validation || { pincode: pincode, valid: true },
        overall_delivery_available: all_deliverable,
        products: products_results,
        unavailable_products: unavailable_products,
        summary: {
          total_products: products_results.length,
          deliverable_products: products_results.count { |p| p[:delivery_available] },
          unavailable_products: unavailable_products.length,
          total_delivery_charge: products_results.sum { |p| p[:delivery_charge] }
        }
      }

      message = if all_deliverable
        "All products can be delivered to #{pincode}"
      else
        "#{unavailable_products.length} out of #{products_results.length} products cannot be delivered to #{pincode}"
      end

      json_response({
        success: all_deliverable,
        data: response_data,
        message: message
      })

    rescue => e
      Rails.logger.error "Delivery validation error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      json_response({
        success: false,
        message: 'An error occurred while validating delivery',
        error: e.message
      }, :internal_server_error)
    end
  end

  # POST /api/v1/mobile/ecommerce/location/save
  def save_location
    customer = Customer.find_by(email: @current_user&.email) if @current_user
    return json_response({ success: false, message: 'Customer not found' }, :not_found) unless customer

    latitude = params[:latitude]
    longitude = params[:longitude]
    address = params[:address]
    pincode = params[:pincode]

    return json_response({ success: false, message: 'Latitude and longitude are required' }, :bad_request) if latitude.blank? || longitude.blank?

    update_params = {
      latitude: latitude,
      longitude: longitude,
      location_obtained_at: Time.current
    }

    update_params[:address] = address if address.present?
    # Note: Customer model doesn't have pincode column, so we don't store it

    if customer.update(update_params)
      json_response({
        success: true,
        data: {
          customer_id: customer.id,
          latitude: customer.latitude.to_f,
          longitude: customer.longitude.to_f,
          address: customer.address,
          pincode: pincode, # Return the provided pincode parameter
          location_saved_at: customer.location_obtained_at
        },
        message: 'Location saved successfully'
      })
    else
      json_response({
        success: false,
        message: 'Failed to save location',
        errors: customer.errors.full_messages
      }, :unprocessable_entity)
    end
  end

  # POST /api/v1/mobile/ecommerce/delivery_charges
  def delivery_charges
    pincode = params[:pincode]
    address = params[:address]

    begin
      # Validate required parameters
      if pincode.blank?
        return json_response({
          success: false,
          message: 'Pincode is required',
          error: 'Missing pincode parameter'
        }, :unprocessable_entity)
      end

      # Sanitize pincode (remove any non-numeric characters)
      sanitized_pincode = pincode.to_s.gsub(/[^0-9]/, '')

      # Validate pincode format (should be 6 digits)
      unless sanitized_pincode.match?(/^\d{6}$/)
        return json_response({
          success: false,
          message: 'Invalid pincode format. Pincode should be 6 digits.',
          error: 'Invalid pincode format',
          data: {
            pincode: sanitized_pincode,
            address: address,
            delivery_charge: 0.0,
            is_deliverable: false
          }
        }, :unprocessable_entity)
      end

      # Find delivery charge for the pincode
      delivery_charge_record = DeliveryCharge.for_pincode(sanitized_pincode)

      if delivery_charge_record
        # Pincode is deliverable
        json_response({
          success: true,
          message: 'Delivery charges calculated successfully',
          data: {
            pincode: sanitized_pincode,
            address: address,
            area: delivery_charge_record.area,
            delivery_charge: delivery_charge_record.charge_amount,
            formatted_charge: delivery_charge_record.formatted_charge,
            is_deliverable: true,
            delivery_available: true
          }
        })
      else
        # Pincode not available for delivery
        json_response({
          success: false,
          message: 'Delivery not available for this pincode',
          error: 'Pincode not serviceable',
          data: {
            pincode: sanitized_pincode,
            address: address,
            delivery_charge: 0.0,
            is_deliverable: false,
            delivery_available: false,
            suggested_message: "We don't currently deliver to pincode #{sanitized_pincode}. Please contact support for more information."
          }
        }, :unprocessable_entity)
      end

    rescue => e
      Rails.logger.error "Delivery Charges API Error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      json_response({
        success: false,
        message: 'An error occurred while calculating delivery charges',
        error: e.message,
        data: {
          pincode: pincode,
          address: address,
          delivery_charge: 0.0,
          is_deliverable: false
        }
      }, :internal_server_error)
    end
  end

  private

  def set_category
    @category = Category.find(params[:id] || params[:category_id])
  rescue ActiveRecord::RecordNotFound
    json_response({ success: false, message: 'Category not found' }, :not_found)
  end

  def set_product
    @product = Product.active.find(params[:id] || params[:product_id])
  rescue ActiveRecord::RecordNotFound
    json_response({ success: false, message: 'Product not found' }, :not_found)
  end

  def format_product_data(product)
    {
      id: product.id,
      name: product.name,
      description: product.description,
      price: product.price.to_f,
      discount_price: product.discount_price&.to_f,
      selling_price: product.selling_price.to_f,
      final_price: product.final_price_after_discount.to_f,
      discount_percentage: product.discount_percentage,
      stock: product.stock,
      sku: product.sku,
      weight: product.weight&.to_f,
      dimensions: product.dimensions,
      category: {
        id: product.category_id,
        name: product.category&.name
      },
      image: product.images_attached? ? url_for(product.images.first) : nil,
      images: product.images_attached? ? product.images.map { |img| url_for(img) } : [],
      rating: {
        average: product.average_rating.to_f,
        count: product.total_reviews
      },
      is_in_stock: product.in_stock?,
      is_discounted: product.discounted?,
      stock_status: product.stock_status,
      created_at: product.created_at,
      updated_at: product.updated_at
    }
  end

  def format_booking_data(booking, basic: false)
    base_data = {
      id: booking.id,
      booking_number: booking.booking_number,
      booking_date: booking.booking_date,
      status: booking.status,
      payment_status: booking.payment_status,
      payment_method: booking.payment_method,
      subtotal: booking.subtotal.to_f,
      tax_amount: booking.tax_amount.to_f,
      discount_amount: booking.discount_amount&.to_f || 0,
      total_amount: booking.total_amount.to_f,
      customer_name: booking.customer_name,
      customer_email: booking.customer_email,
      customer_phone: booking.customer_phone,
      delivery_address: booking.delivery_address,
      notes: booking.notes,
      invoice_number: booking.invoice_number,
      invoice_generated: booking.invoice_generated,
      created_at: booking.created_at,
      updated_at: booking.updated_at
    }

    # Add franchise details for customer view (if booking has franchise)
    if booking.franchise
      base_data[:franchise] = {
        id: booking.franchise.id,
        name: booking.franchise.name,
        contact_person: booking.franchise.contact_person_name,
        mobile: booking.franchise.mobile,
        city: booking.franchise.city
      }
    end

    unless basic
      base_data[:items] = booking.booking_items.map do |item|
        {
          id: item.id,
          product_id: item.product_id,
          product_name: item.product&.name,
          product_sku: item.product&.sku,
          quantity: item.quantity,
          price: item.price.to_f,
          total: item.total.to_f
        }
      end
    end

    base_data
  end

  def format_order_data(order, basic: false, include_items: false)
    base_data = {
      id: order.id,
      order_number: order.order_number,
      order_date: order.order_date,
      status: order.status,
      payment_status: order.payment_status,
      payment_method: order.payment_method,
      subtotal: order.subtotal.to_f,
      tax_amount: order.tax_amount.to_f,
      discount_amount: order.discount_amount&.to_f || 0,
      shipping_amount: order.shipping_amount&.to_f || 0,
      total_amount: order.total_amount.to_f,
      customer_name: order.customer_name,
      customer_email: order.customer_email,
      customer_phone: order.customer_phone,
      delivery_address: order.delivery_address,
      tracking_number: order.tracking_number,
      delivered_at: order.delivered_at,
      notes: order.notes,
      created_at: order.created_at,
      updated_at: order.updated_at
    }

    if include_items || !basic
      base_data[:items] = order.order_items.map do |item|
        {
          id: item.id,
          product_id: item.product_id,
          product_name: item.product&.name,
          product_sku: item.product&.sku,
          product_image: item.product&.images&.attached? ? url_for(item.product.images.first) : nil,
          quantity: item.quantity,
          price: item.price.to_f,
          total: item.total.to_f
        }
      end
    end

    base_data
  end

  def format_subscription_data(subscription, include_bookings: false)
    base_data = {
      id: subscription.id,
      schedule_type: subscription.schedule_type,
      frequency: subscription.frequency,
      start_date: subscription.start_date,
      end_date: subscription.end_date,
      quantity: subscription.quantity,
      delivery_time: subscription.delivery_time,
      delivery_address: subscription.delivery_address,
      pincode: subscription.pincode,
      latitude: subscription.latitude&.to_f,
      longitude: subscription.longitude&.to_f,
      status: subscription.status,
      next_booking_date: subscription.next_booking_date,
      total_bookings_generated: subscription.total_bookings_generated || 0,
      notes: subscription.notes,
      product: {
        id: subscription.product.id,
        name: subscription.product.name,
        price: subscription.product.selling_price.to_f,
        image: subscription.product.images_attached? ? url_for(subscription.product.images.first) : nil
      },
      created_at: subscription.created_at,
      updated_at: subscription.updated_at
    }

    if include_bookings
      base_data[:bookings_count] = subscription.bookings.count
      base_data[:completed_bookings] = subscription.bookings.where(status: ['delivered', 'completed']).count
    end

    base_data
  end

  def validate_pincode(pincode)
    return { valid: false, error: 'Pincode is required' } if pincode.blank?

    pincode_str = pincode.to_s
    return { valid: false, error: 'Pincode must be 6 digits' } unless pincode_str.match?(/\A\d{6}\z/)

    begin
      require 'net/http'
      require 'json'

      uri = URI("https://api.postalpincode.in/pincode/#{pincode}")
      response = Net::HTTP.get_response(uri)

      if response.code == '200'
        data = JSON.parse(response.body)

        if data.is_a?(Array) && data.first && data.first['Status'] == 'Success'
          post_office_data = data.first['PostOffice']
          if post_office_data && post_office_data.any?
            first_office = post_office_data.first
            return {
              valid: true,
              pincode: pincode,
              district: first_office['District'],
              state: first_office['State'],
              country: first_office['Country'],
              post_offices: post_office_data.map { |po| po['Name'] },
              serviceable: true # You can add your own logic here
            }
          end
        end
      end

      { valid: false, error: 'Invalid pincode or area not serviceable', pincode: pincode }
    rescue => e
      { valid: false, error: 'Unable to validate pincode at this time', details: e.message }
    end
  end

  def map_frequency_to_pattern(frequency)
    case frequency&.downcase
    when 'daily'
      'daily'
    when 'weekly', 'alternate'
      'alternate'
    when 'specific', 'custom'
      'specific_dates'
    else
      'daily'
    end
  end

  def format_milk_subscription_data(subscription)
    {
      id: subscription.id,
      customer: {
        id: subscription.customer.id,
        name: subscription.customer.display_name,
        email: subscription.customer.email,
        mobile: subscription.customer.mobile
      },
      product: {
        id: subscription.product.id,
        name: subscription.product.name,
        price: subscription.product.selling_price
      },
      quantity: subscription.quantity,
      unit: subscription.unit,
      start_date: subscription.start_date,
      end_date: subscription.end_date,
      delivery_time: subscription.delivery_time,
      delivery_pattern: subscription.delivery_pattern,
      status: subscription.status,
      is_active: subscription.is_active,
      created_at: subscription.created_at
    }
  end
end

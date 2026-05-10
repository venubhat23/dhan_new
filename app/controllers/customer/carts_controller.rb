class Customer::CartsController < Customer::BaseController
  before_action :initialize_cart

  def show
    @cart_items = @cart[:items] || []
    @cart_total = calculate_cart_total
    @cart_count = @cart_items.sum { |item| item['quantity'] }
  end

  def add_item
    product = Product.active.find(params[:product_id])
    quantity = params[:quantity].to_i

    if quantity <= 0
      redirect_back(fallback_location: customer_products_path, alert: 'Invalid quantity.')
      return
    end

    if !product.can_fulfill_order?(quantity)
      redirect_back(fallback_location: customer_products_path,
                   alert: "Only #{product.available_quantity} units available in stock.")
      return
    end

    existing_item = @cart[:items].find { |item| item['product_id'] == product.id }

    if existing_item
      new_quantity = existing_item['quantity'] + quantity
      if product.can_fulfill_order?(new_quantity)
        existing_item['quantity'] = new_quantity
      else
        redirect_back(fallback_location: customer_products_path,
                     alert: "Cannot add more items. Only #{product.available_quantity} units available.")
        return
      end
    else
      @cart[:items] << {
        'product_id' => product.id,
        'product_name' => product.name,
        'price' => product.selling_price,
        'quantity' => quantity,
        'image_url' => product.main_image_url
      }
    end

    save_cart
    redirect_back(fallback_location: customer_products_path, notice: 'Item added to cart!')
  end

  def update_item
    product_id = params[:product_id].to_i
    quantity = params[:quantity].to_i

    item = @cart[:items].find { |item| item['product_id'] == product_id }

    if item.nil?
      redirect_to customer_cart_path, alert: 'Item not found in cart.'
      return
    end

    if quantity <= 0
      @cart[:items].reject! { |item| item['product_id'] == product_id }
      save_cart
      redirect_to customer_cart_path, notice: 'Item removed from cart.'
      return
    end

    product = Product.find(product_id)

    if product.can_fulfill_order?(quantity)
      item['quantity'] = quantity
      save_cart
      redirect_to customer_cart_path, notice: 'Cart updated!'
    else
      redirect_to customer_cart_path,
                  alert: "Only #{product.available_quantity} units available."
    end
  end

  def remove_item
    product_id = params[:product_id].to_i
    @cart[:items].reject! { |item| item['product_id'] == product_id }
    save_cart
    redirect_to customer_cart_path, notice: 'Item removed from cart.'
  end

  def create
    # Handle AJAX cart sync from localStorage to session
    cart_items = params[:cart_items] || []

    # Clear existing session cart
    @cart[:items] = []

    # Add items from localStorage
    cart_items.each do |item_data|
      product = Product.find_by(id: item_data[:product_id])
      next unless product && product.status == 'active'

      # Validate quantity
      quantity = item_data[:quantity].to_f
      next if quantity <= 0

      # Check stock availability
      if !product.can_fulfill_order?(quantity)
        render json: {
          error: "Insufficient stock for #{product.name}. Only #{product.available_quantity} available."
        }, status: :unprocessable_entity
        return
      end

      @cart[:items] << {
        'product_id' => product.id,
        'product_name' => product.name,
        'price' => item_data[:price].to_f,
        'quantity' => quantity,
        'basePrice' => item_data[:basePrice].to_f,
        'gstRate' => item_data[:gstRate].to_f,
        'image_url' => product.main_image_url
      }
    end

    save_cart
    render json: { success: true, message: 'Cart synced successfully' }

  rescue => e
    render json: { error: "Failed to sync cart: #{e.message}" }, status: :internal_server_error
  end

  def clear
    @cart[:items] = []
    save_cart
    redirect_to customer_cart_path, notice: 'Cart cleared!'
  end

  def verify_stock
    cart_items = params[:cart_items] || []
    out_of_stock = []
    insufficient_stock = []

    cart_items.each do |item_data|
      product = Product.active.find_by(id: item_data[:id])

      if product.nil?
        out_of_stock << { id: item_data[:id], name: item_data[:name].to_s }
        next
      end

      quantity = item_data[:quantity].to_f
      available = product.available_quantity.to_f

      if available <= 0
        out_of_stock << { id: product.id, name: product.name, available: 0 }
      elsif quantity > available
        insufficient_stock << { id: product.id, name: product.name, requested: quantity.to_i, available: available.to_i }
      end
    end

    render json: {
      success: true,
      out_of_stock: out_of_stock,
      insufficient_stock: insufficient_stock,
      has_issues: out_of_stock.any? || insufficient_stock.any?
    }
  rescue => e
    render json: { success: false, error: e.message }, status: :internal_server_error
  end

  private

  def initialize_cart
    @cart = session[:cart] ||= { items: [] }
  end

  def save_cart
    session[:cart] = @cart
  end

  def calculate_cart_total
    @cart[:items].sum { |item| item['price'].to_f * item['quantity'].to_i }
  end
end
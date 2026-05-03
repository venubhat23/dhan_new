class Admin::ProductsController < Admin::ApplicationController
  include LocationHelper

  before_action :set_product, only: [:show, :edit, :update, :destroy, :toggle_status, :detail]
  before_action :authenticate_user!

  def index
    @products = Product.includes(:category, image_attachment: :blob, additional_images_attachments: :blob)

    if params[:search].present?
      @products = @products.search(params[:search])
    end

    if params[:category_id].present?
      @products = @products.by_category(params[:category_id])
    end

    if params[:status].present?
      @products = @products.where(status: params[:status])
    end

    if params[:stock_status].present?
      case params[:stock_status]
      when 'in_stock'
        @products = @products.in_stock
      when 'out_of_stock'
        @products = @products.out_of_stock
      end
    end

    @products = @products.recent.page(params[:page]).per(20)
    @categories = Category.active.ordered
  end

  def show
    @delivery_rules = @product.delivery_rules.includes(:product)
  end

  def new
    @product = Product.new

    # Set category if provided in params
    if params[:category_id].present?
      category = Category.find_by(id: params[:category_id])
      @product.category_id = category.id if category
    end

    @product.delivery_rules.build(rule_type: 'everywhere') # Default rule
    @categories = Category.active.ordered
  end

  def create
    # Process delivery rule location data before creating product
    process_params_delivery_rule_data

    @product = Product.new(product_params)
    if @product.save
      # Handle Cloudinary uploads
      handle_cloudinary_uploads if params[:product][:cloudinary_images].present?

      # Handle automatic R2 uploads for regular file uploads
      handle_automatic_r2_uploads

      redirect_to admin_product_path(@product), notice: 'Product was successfully created.'
    else
      @categories = Category.active.ordered
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @categories = Category.active.ordered
    @existing_rule = @product.delivery_rules.first
  end

  def update
    # Handle image removal before updating
    handle_image_removal if params[:remove_images].present?

    # Process delivery rule location data before updating
    process_params_delivery_rule_data

    # Store vendor purchase ID for stock batch linking before updating
    vendor_purchase_id = params[:vendor_purchase_id].presence

    if @product.update(product_params)
      # Handle Cloudinary uploads
      handle_cloudinary_uploads if params[:product][:cloudinary_images].present?

      # Handle automatic R2 uploads for regular file uploads
      handle_automatic_r2_uploads

      # Link stock changes to vendor purchase if provided
      handle_stock_vendor_purchase_linking(vendor_purchase_id) if vendor_purchase_id && @product.saved_change_to_stock?

      # Handle main image reordering after update
      handle_main_image_setting if params[:main_image_id].present?

      redirect_to admin_product_path(@product), notice: 'Product was successfully updated.'
    else
      @categories = Category.active.ordered
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    product_name = @product.name

    # Preserve historical booking/order records — clear product reference instead of deleting
    @product.booking_items.update_all(product_id: nil)
    @product.order_items.update_all(product_id: nil) if @product.respond_to?(:order_items)

    @product.destroy!
    redirect_to admin_products_path, notice: "Product '#{product_name}' was deleted successfully."
  rescue => e
    redirect_to admin_products_path, alert: "Could not delete product: #{e.message}"
  end

  def toggle_status
    new_status = case @product.status
                 when 'active'
                   'inactive'
                 when 'inactive'
                   'active'
                 else
                   'active'
                 end

    @product.update(status: new_status)

    respond_to do |format|
      format.json { render json: { status: @product.status, message: "Product #{@product.status} successfully" } }
      format.html { redirect_to admin_products_path, notice: "Product #{@product.status} successfully" }
    end
  end

  def detail
    # Comprehensive product detail page with all e-commerce features
    @related_products = Product.where(category: @product.category).where.not(id: @product.id).limit(4)

    # Real reviews from database
    @reviews = @product.approved_reviews.recent.limit(10)
    @review_summary = {
      average_rating: @product.average_rating,
      total_reviews: @product.total_reviews,
      distribution: @product.review_percentage_distribution
    }

    # Initialize new review for the form
    @new_review = @product.product_reviews.build

    # Price tracking data for all products
    @all_products_with_prices = Product.active
      .where.not(today_price: nil)
      .select(:id, :name, :price, :today_price, :yesterday_price, :price_change_percentage, :last_price_update, :price_history)
      .limit(10)
      .order(:name)

    # Market overview statistics
    @market_stats = calculate_market_stats

    @specifications = get_product_specifications
    render layout: 'application'
  end

  def bulk_action
    case params[:bulk_action]
    when 'activate'
      Product.where(id: params[:product_ids]).update_all(status: 'active')
      message = 'Products activated successfully'
    when 'deactivate'
      Product.where(id: params[:product_ids]).update_all(status: 'inactive')
      message = 'Products deactivated successfully'
    when 'delete'
      Product.where(id: params[:product_ids]).destroy_all
      message = 'Products deleted successfully'
    else
      message = 'Invalid action'
    end

    redirect_to admin_products_path, notice: message
  end

  def products_chart
    # Get all products with price tracking
    @products_with_prices = Product.active
      .where.not(today_price: nil)
      .includes(:category)
      .order(:name)

    # Calculate market statistics
    @market_stats = calculate_market_stats

    render layout: 'application'
  end

  # Cloudinary upload action - MUST be public
  def upload_cloudinary_image
    respond_to do |format|
      if params[:image].present?
        begin
          Rails.logger.info "🔄 Starting Cloudinary upload for file: #{params[:image].original_filename}"
          Rails.logger.info "📁 File size: #{params[:image].size} bytes"
          Rails.logger.info "🎯 Content type: #{params[:image].content_type}"

          # Upload to Cloudinary
          result = Cloudinary::Uploader.upload(
            params[:image].tempfile,
            folder: 'products',
            public_id: "product-temp-#{SecureRandom.hex(8)}",
            overwrite: true,
            resource_type: :auto,
            transformation: [
              { width: 1200, height: 1200, crop: :limit, quality: :auto, fetch_format: :auto }
            ]
          )

          Rails.logger.info "✅ Cloudinary upload successful: #{result['public_id']}"

          format.json {
            render json: {
              success: true,
              public_id: result['public_id'],
              url: result['secure_url'],
              thumbnail_url: Cloudinary::Utils.cloudinary_url(result['public_id'], width: 300, height: 300, crop: :fill)
            }
          }
        rescue => e
          Rails.logger.error "❌ Cloudinary upload failed: #{e.message}"
          Rails.logger.error "📋 Error class: #{e.class.name}"
          Rails.logger.error "🔍 Backtrace: #{e.backtrace.first(3).join(' | ')}"

          format.json {
            render json: {
              success: false,
              error: "Upload failed: #{e.message}",
              error_class: e.class.name
            }, status: :unprocessable_entity
          }
        end
      else
        Rails.logger.warn "⚠️ No image provided in upload request"
        format.json {
          render json: {
            success: false,
            error: "No image provided"
          }, status: :bad_request
        }
      end
    end
  end

  def upload_r2_image
    respond_to do |format|
      if params[:image].present?
        begin
          Rails.logger.info "🔄 Starting R2 upload for file: #{params[:image].original_filename}"
          Rails.logger.info "📁 File size: #{params[:image].size} bytes"
          Rails.logger.info "🎯 Content type: #{params[:image].content_type}"

          # Upload to R2
          result = R2Service.upload(params[:image], folder: 'products')

          if result[:error]
            Rails.logger.error "❌ R2 upload failed: #{result[:error]}"
            format.json { render json: { error: result[:error] }, status: :unprocessable_entity }
          else
            Rails.logger.info "✅ R2 upload successful: #{result[:key]}"
            format.json { render json: {
              key: result[:key],
              filename: result[:filename],
              public_url: result[:public_url],
              size: result[:size]
            }}
          end

        rescue => e
          Rails.logger.error "💥 R2 upload exception: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          format.json { render json: { error: "Upload failed: #{e.message}" }, status: :internal_server_error }
        end
      else
        Rails.logger.warn "⚠️ No image provided in R2 upload request"
        format.json { render json: { error: "No image provided" }, status: :bad_request }
      end
    end
  end

  def delete_r2_image
    respond_to do |format|
      image_url = params[:image_url]
      delete_from_storage = params[:permanent] == 'true'

      if image_url.blank?
        format.json { render json: { error: "Image URL is required" }, status: :bad_request }
        return
      end

      begin
        Rails.logger.info "🗑️ Starting R2 image deletion for URL: #{image_url}"
        Rails.logger.info "🔥 Permanent deletion: #{delete_from_storage}"

        # Extract key from URL for R2 deletion
        if delete_from_storage
          # Extract the key from the public URL
          # URL format: https://pub-xxx.r2.dev/products/20240318_123456_filename.jpg
          key = extract_r2_key_from_url(image_url)

          if key
            Rails.logger.info "🔑 Extracted key: #{key}"
            success = R2Service.delete(key)

            if success
              Rails.logger.info "✅ R2 image permanently deleted: #{key}"
              format.json { render json: {
                success: true,
                message: "Image permanently deleted from R2 storage",
                deleted_from_storage: true
              }}
            else
              Rails.logger.error "❌ Failed to delete from R2 storage: #{key}"
              format.json { render json: {
                success: true,
                message: "Image unlinked from product (R2 deletion failed)",
                deleted_from_storage: false
              }}
            end
          else
            Rails.logger.warn "⚠️ Could not extract key from URL: #{image_url}"
            format.json { render json: {
              success: true,
              message: "Image unlinked from product (could not delete from storage)",
              deleted_from_storage: false
            }}
          end
        else
          Rails.logger.info "🔗 Only unlinking image from product"
          format.json { render json: {
            success: true,
            message: "Image unlinked from product",
            deleted_from_storage: false
          }}
        end

      rescue => e
        Rails.logger.error "💥 R2 image deletion exception: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        format.json { render json: { error: "Deletion failed: #{e.message}" }, status: :internal_server_error }
      end
    end
  end

  private

  def extract_r2_key_from_url(image_url)
    # Extract key from R2 public URL
    # URL format: https://pub-63bb824effac95b1f3b291eb9385d33c.r2.dev/products/20240318_123456_filename.jpg
    # Key format: products/20240318_123456_filename.jpg

    begin
      uri = URI.parse(image_url)
      # Remove leading slash and return the path as key
      key = uri.path[1..-1] if uri.path
      Rails.logger.info "🔍 Extracted key from URL: #{image_url} -> #{key}"
      key
    rescue => e
      Rails.logger.error "❌ Failed to parse URL: #{image_url} - #{e.message}"
      nil
    end
  end

  def handle_stock_vendor_purchase_linking(vendor_purchase_id)
    return unless vendor_purchase_id

    begin
      vendor_purchase = VendorPurchase.find(vendor_purchase_id)

      # Find the most recent stock batch for this product
      latest_batch = @product.stock_batches.by_fifo.last

      # Update the stock batch to link to the vendor purchase
      if latest_batch && latest_batch.vendor_purchase_id.nil?
        latest_batch.update!(
          vendor_purchase: vendor_purchase,
          vendor: vendor_purchase.vendor
        )

        Rails.logger.info "Linked stock batch #{latest_batch.id} to vendor purchase #{vendor_purchase.purchase_number}"
      end
    rescue ActiveRecord::RecordNotFound
      Rails.logger.warn "Vendor purchase #{vendor_purchase_id} not found for stock linking"
    rescue => e
      Rails.logger.error "Failed to link stock to vendor purchase: #{e.message}"
    end
  end

  def process_params_delivery_rule_data
    return unless params[:product] && params[:product][:delivery_rules_attributes]

    params[:product][:delivery_rules_attributes].each do |index, rule_attrs|
      next unless rule_attrs

      rule_type = rule_attrs[:rule_type]

      # Handle legacy 'all' rule type for backward compatibility
      if rule_type == 'all'
        rule_attrs[:rule_type] = 'everywhere'
        rule_type = 'everywhere'
      end

      case rule_type
      when 'state'
        if rule_attrs[:location_data_states].present?
          location_data = rule_attrs[:location_data_states].reject(&:blank?)
          rule_attrs[:location_data] = location_data.to_json
        end
      when 'city'
        if rule_attrs[:location_data_cities].present?
          location_data = rule_attrs[:location_data_cities].reject(&:blank?)
          rule_attrs[:location_data] = location_data.to_json
        end
      when 'pincode'
        if rule_attrs[:location_data_pincodes].present?
          pincodes = rule_attrs[:location_data_pincodes].split(',').map(&:strip).reject(&:blank?)
          rule_attrs[:location_data] = pincodes.to_json
        end
      when 'everywhere'
        rule_attrs[:location_data] = '[]'
      end

      # Clean up the temporary parameters BEFORE they get to the model
      rule_attrs.delete(:location_data_states)
      rule_attrs.delete(:location_data_cities)
      rule_attrs.delete(:location_data_pincodes)
    end
  end

  def set_product
    @product = Product.find(params[:id])
  end

  def calculate_market_stats
    products_with_prices = Product.active.where.not(today_price: nil, yesterday_price: nil)

    return {} if products_with_prices.empty?

    price_increases = products_with_prices.where('price_change_percentage > 0').count
    price_decreases = products_with_prices.where('price_change_percentage < 0').count
    price_stable = products_with_prices.where('price_change_percentage = 0').count

    total_products = products_with_prices.count
    avg_change = products_with_prices.average(:price_change_percentage)&.round(2) || 0

    biggest_gainer = products_with_prices.order(price_change_percentage: :desc).first
    biggest_loser = products_with_prices.order(price_change_percentage: :asc).first

    {
      total_products: total_products,
      price_increases: price_increases,
      price_decreases: price_decreases,
      price_stable: price_stable,
      avg_change: avg_change,
      biggest_gainer: biggest_gainer,
      biggest_loser: biggest_loser,
      market_trend: avg_change > 0 ? 'bullish' : (avg_change < 0 ? 'bearish' : 'stable')
    }
  end

  def handle_image_removal
    return unless params[:remove_images].present?

    image_ids_to_remove = params[:remove_images].map(&:to_i)

    # Handle main image removal
    if @product.image.attached? && image_ids_to_remove.include?(@product.image.id)
      Rails.logger.info "Removing main image: #{@product.image.filename}"
      @product.image.purge
    end

    # Handle additional images removal
    images_to_remove = @product.additional_images.where(id: image_ids_to_remove)
    images_to_remove.each do |image|
      Rails.logger.info "Removing additional image: #{image.filename}"
      image.purge
    end

    Rails.logger.info "Removed #{images_to_remove.count} additional images from product #{@product.id}"
  end

  def handle_main_image_setting
    return unless params[:main_image_id].present?

    main_image_id = params[:main_image_id].to_i

    # Check if it's currently an additional image
    main_image = @product.additional_images.find_by(id: main_image_id)
    return unless main_image

    # Move the selected image from additional_images to main image
    current_main = @product.image if @product.image.attached?

    # Detach from additional images
    @product.additional_images.detach(main_image.blob)

    # If there was a main image, move it to additional images
    if current_main
      @product.additional_images.attach(current_main.blob)
      @product.image.detach
    end

    # Set as main image
    @product.image.attach(main_image.blob)

    Rails.logger.info "Set image #{main_image_id} as main image for product #{@product.id}"
  end

  def get_product_specifications
    if @product.name.downcase.include?('iphone')
      {
        'Display' => '6.7-inch Super Retina XDR display with ProMotion technology',
        'Chip' => 'A17 Pro chip with 6-core GPU',
        'Camera System' => '48MP Main | 12MP Ultra Wide | 12MP Telephoto with 5x optical zoom',
        'Video' => '4K Dolby Vision recording up to 60 fps',
        'Battery' => 'Up to 29 hours video playback',
        'Storage Options' => '256GB, 512GB, 1TB',
        'Operating System' => 'iOS 17',
        'Connectivity' => '5G, Wi-Fi 6E, Bluetooth 5.3',
        'Materials' => 'Titanium design with textured matte glass back',
        'Water Resistance' => 'IP68 (maximum depth of 6 meters up to 30 minutes)',
        'Face ID' => 'Enabled by TrueDepth camera for secure authentication',
        'Action Button' => 'Customizable Action Button for quick shortcuts'
      }
    else
      {
        'Brand' => @product.category&.name || 'Premium Brand',
        'Model' => @product.name,
        'Weight' => @product.weight || 'Not specified',
        'Dimensions' => @product.dimensions || 'Not specified',
        'Warranty' => '1 Year Manufacturer Warranty',
        'In the Box' => 'Product, User Manual, Warranty Card',
        'Country of Origin' => 'Made in India',
        'Material' => 'Premium Quality Materials'
      }
    end
  end

  def process_delivery_rule_location_data
    return unless params[:product] && params[:product][:delivery_rules_attributes]

    params[:product][:delivery_rules_attributes].each do |index, rule_attrs|
      next unless rule_attrs

      rule_type = rule_attrs[:rule_type]

      # Handle legacy 'all' rule type for backward compatibility
      if rule_type == 'all'
        rule_attrs[:rule_type] = 'everywhere'
        rule_type = 'everywhere'
      end

      case rule_type
      when 'state'
        if rule_attrs[:location_data_states].present?
          location_data = rule_attrs[:location_data_states].reject(&:blank?)
          rule_attrs[:location_data] = location_data.to_json
        end
      when 'city'
        if rule_attrs[:location_data_cities].present?
          location_data = rule_attrs[:location_data_cities].reject(&:blank?)
          rule_attrs[:location_data] = location_data.to_json
        end
      when 'pincode'
        if rule_attrs[:location_data_pincodes].present?
          pincodes = rule_attrs[:location_data_pincodes].split(',').map(&:strip).reject(&:blank?)
          rule_attrs[:location_data] = pincodes.to_json
        end
      when 'everywhere'
        rule_attrs[:location_data] = '[]'
      end

      # Clean up the temporary parameters
      rule_attrs.delete(:location_data_states)
      rule_attrs.delete(:location_data_cities)
      rule_attrs.delete(:location_data_pincodes)
    end
  end

  def product_params
    params.require(:product).permit(
      :name, :description, :category_id, :price, :discount_price, :stock, :initial_stock,
      :status, :sku, :weight, :dimensions, :meta_title, :meta_description, :tags,
      :buying_price, :discount_type, :discount_value, :original_price, :discount_amount, :is_discounted,
      :product_type, :unit_type, :is_subscription_enabled,
      :is_occasional_product, :occasional_start_date, :occasional_end_date, :occasional_description, :occasional_auto_hide,
      :occasional_schedule_type, :occasional_recurring_from_day, :occasional_recurring_from_time,
      :occasional_recurring_to_day, :occasional_recurring_to_time,
      :image_url, :additional_images_urls, :r2_image_url, :r2_additional_images,
      # GST Configuration Parameters
      :gst_enabled, :gst_percentage, :cgst_percentage, :sgst_percentage, :igst_percentage,
      :gst_amount, :cgst_amount, :sgst_amount, :igst_amount, :final_amount_with_gst, :base_price_excluding_gst,
      :image,
      additional_images: [],
      remove_images: [],
      cloudinary_images: [],
      delivery_rules_attributes: [
        :id, :rule_type, :location_data, :is_excluded, :delivery_days, :delivery_charge, :_destroy,
        :location_data_pincodes, { location_data_states: [] }, { location_data_cities: [] }
      ]
    )
  end

  private

  def handle_cloudinary_uploads
    return unless params[:product][:cloudinary_images].is_a?(Array)

    uploaded_images = []

    params[:product][:cloudinary_images].each_with_index do |image_file, index|
      next unless image_file.respond_to?(:tempfile) || image_file.respond_to?(:read)

      begin
        result = Cloudinary::Uploader.upload(
          image_file.tempfile || image_file,
          folder: 'products',
          public_id: "product-#{@product.id}-#{index}-#{SecureRandom.hex(4)}",
          overwrite: true,
          resource_type: :auto,
          transformation: [
            { width: 1200, height: 1200, crop: :limit, quality: :auto, fetch_format: :auto }
          ]
        )

        uploaded_images << result['public_id']

        # Set first image as main image
        if index == 0 && @product.image_url.blank?
          @product.update_column(:image_url, result['public_id'])
        end
      rescue => e
        Rails.logger.error "Cloudinary upload failed: #{e.message}"
      end
    end

    # Add additional images to existing array
    if uploaded_images.any?
      if uploaded_images.length > 1
        additional_images = uploaded_images[1..-1] # Skip first image (main)
        current_additional = @product.additional_cloudinary_images
        @product.update_column(:additional_images_urls, (current_additional + additional_images).to_json)
      end
    end
  end

  def handle_automatic_r2_uploads
    uploaded_r2_images = []

    # Handle main image upload to R2
    if @product.image.attached?
      begin
        Rails.logger.info "🔄 Uploading main image to R2: #{@product.image.filename}"

        # Convert the Active Storage attachment to a format R2Service can handle
        temp_file = create_temp_file_from_attachment(@product.image)

        result = R2Service.upload(temp_file, folder: 'products')

        if result[:error]
          Rails.logger.error "❌ R2 main image upload failed: #{result[:error]}"
        else
          Rails.logger.info "✅ R2 main image upload successful: #{result[:key]}"
          @product.update_column(:r2_image_url, result[:public_url])
          uploaded_r2_images << result
        end

        # Clean up temp file
        temp_file.unlink if temp_file && File.exist?(temp_file.path)
      rescue => e
        Rails.logger.error "💥 R2 main image upload exception: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end

    # Handle additional images upload to R2
    if @product.additional_images.attached?
      additional_r2_urls = []

      @product.additional_images.each_with_index do |additional_image, index|
        begin
          Rails.logger.info "🔄 Uploading additional image #{index + 1} to R2: #{additional_image.filename}"

          # Convert the Active Storage attachment to a format R2Service can handle
          temp_file = create_temp_file_from_attachment(additional_image)

          result = R2Service.upload(temp_file, folder: 'products')

          if result[:error]
            Rails.logger.error "❌ R2 additional image #{index + 1} upload failed: #{result[:error]}"
          else
            Rails.logger.info "✅ R2 additional image #{index + 1} upload successful: #{result[:key]}"
            additional_r2_urls << result[:public_url]
            uploaded_r2_images << result
          end

          # Clean up temp file
          temp_file.unlink if temp_file && File.exist?(temp_file.path)
        rescue => e
          Rails.logger.error "💥 R2 additional image #{index + 1} upload exception: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
        end
      end

      # Update additional R2 images if any were uploaded
      if additional_r2_urls.any?
        # Parse existing additional images or create empty array
        existing_additional = begin
          JSON.parse(@product.r2_additional_images || '[]')
        rescue JSON::ParserError
          []
        end

        # Merge with new uploads
        combined_additional = (existing_additional + additional_r2_urls).uniq
        @product.update_column(:r2_additional_images, combined_additional.to_json)
      end
    end

    if uploaded_r2_images.any?
      Rails.logger.info "✅ Successfully uploaded #{uploaded_r2_images.count} image(s) to R2 for product #{@product.id}"
    else
      Rails.logger.info "ℹ️ No new images to upload to R2 for product #{@product.id}"
    end

    uploaded_r2_images
  end

  def create_temp_file_from_attachment(attachment)
    # Create a temporary file that mimics the uploaded file format
    temp_file = Tempfile.new([File.basename(attachment.filename.to_s, ".*"), File.extname(attachment.filename.to_s)])
    temp_file.binmode
    temp_file.write(attachment.download)
    temp_file.rewind

    # Create a wrapper object that has the methods R2Service expects
    temp_file_wrapper = OpenStruct.new(
      tempfile: temp_file,
      original_filename: attachment.filename.to_s,
      content_type: attachment.content_type,
      size: attachment.byte_size
    )

    temp_file_wrapper
  end
end
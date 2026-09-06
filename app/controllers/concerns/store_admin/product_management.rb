# Shared product-form plumbing for StoreAdmin::ProductsController. This is a
# store-login copy of the private helpers in Admin::ProductsController (delivery
# rules, R2 / Cloudinary uploads, image handling, dependency purge, stock
# reconciliation). Kept separate so the admin controller is never touched.
module StoreAdmin::ProductManagement
  extend ActiveSupport::Concern

  # Every table that references products via product_id, in a foreign-key-safe
  # deletion order. Used to show what is connected (dependencies) and to wipe it
  # on hard delete (purge_dependent_records!).
  DEPENDENT_RELATIONS = [
    ['Booking line items',      ->(p) { p.booking_items }],
    ['Order line items',        ->(p) { OrderItem.where(product_id: p.id) }],
    ['Invoice line items',      ->(p) { InvoiceItem.where(product_id: p.id) }],
    ['Milk delivery tasks',     ->(p) { MilkDeliveryTask.where(product_id: p.id) }],
    ['Milk subscriptions',      ->(p) { MilkSubscription.where(product_id: p.id) }],
    ['Subscription templates',  ->(p) { SubscriptionTemplate.where(product_id: p.id) }],
    ['Booking schedules',       ->(p) { BookingSchedule.where(product_id: p.id) }],
    ['Customer formats',        ->(p) { CustomerFormat.where(product_id: p.id) }],
    ['Store inventory records', ->(p) { StoreInventory.where(product_id: p.id) }],
    ['Stock transfers',         ->(p) { StockTransfer.where(product_id: p.id) }],
    ['Wishlist entries',        ->(p) { Wishlist.where(product_id: p.id) }],
    ['Sale items',              ->(p) { p.sale_items }],
    ['Stock movements',         ->(p) { p.stock_movements }],
    ['Stock batches',           ->(p) { p.stock_batches }],
    ['Vendor purchase items',   ->(p) { p.vendor_purchase_items }],
    ['Delivery rules',          ->(p) { p.delivery_rules }],
    ['Product ratings',         ->(p) { p.product_ratings }],
    ['Product reviews',         ->(p) { p.product_reviews }],
    ['Product variants',        ->(p) { p.product_variants }]
  ].freeze

  private

  def purge_dependent_records!(product)
    DEPENDENT_RELATIONS.each { |_label, scope| scope.call(product).delete_all }
  end

  # Reconcile a product/variant's stock **at this store** to new_stock: an
  # increase creates a store FIFO StockBatch for the delta, a decrease draws it
  # down from this store's active batches, and store_inventories is resynced.
  # Returns an error string on failure, nil on success.
  def apply_store_stock_change(product, variant, old_stock, new_stock, cost:, sell:, label:)
    return nil unless product
    delta = new_stock.to_f - old_stock.to_f
    return nil if delta.zero?

    if delta.positive?
      cost_f = cost.to_f
      sell_f = sell.to_f
      sell_f = cost_f if sell_f <= 0
      return "enter a Cost Price to add #{delta.to_i} unit(s) of stock (a batch needs a cost)" if cost_f <= 0

      product.stock_batches.create!(
        vendor:              default_stock_vendor,
        store_id:            @current_store.id,
        product_variant_id:  variant&.id,
        quantity_purchased:  delta,
        quantity_remaining:  delta,
        purchase_price:      cost_f,
        selling_price:       sell_f,
        batch_date:          Date.current,
        status:              'active'
      )
      @bulk_batches_created = @bulk_batches_created.to_i + 1
    else
      reduce_store_batches(product, variant, delta.abs)
    end

    sync_store_inventory_row(product, variant)
    log_store_stock_movement(product, delta, label)
    nil
  rescue ActiveRecord::RecordInvalid => e
    e.message
  end

  def reduce_store_batches(product, variant, amount)
    scope = product.stock_batches.where(store_id: @current_store.id, status: 'active')
                   .where('quantity_remaining > 0').order(:batch_date, :id)
    scope = scope.where(product_variant_id: variant.id) if variant
    remaining = amount
    scope.each do |batch|
      break if remaining <= 0
      take = [batch.quantity_remaining, remaining].min
      batch.respond_to?(:reduce_stock!) ? batch.reduce_stock!(take) : batch.decrement!(:quantity_remaining, take)
      remaining -= take
    end
  end

  # Keep a store_inventories row in step with this store's active batch total.
  def sync_store_inventory_row(product, variant)
    on_hand = product.stock_batches
                     .where(store_id: @current_store.id, product_variant_id: variant&.id, status: 'active')
                     .sum(:quantity_remaining)
    row = @current_store.store_inventories
                        .find_or_initialize_by(product_id: product.id, product_variant_id: variant&.id)
    row.low_stock_threshold ||= (variant&.low_stock_threshold || product.low_stock_threshold || 10)
    row.quantity = on_hand
    row.save
  end

  def log_store_stock_movement(product, delta, label)
    product.stock_movements.create!(
      reference_type: 'adjustment',
      reference_id:   nil,
      movement_type:  delta.positive? ? 'added' : 'adjusted',
      quantity:       delta,
      stock_before:   nil,
      stock_after:    nil,
      notes:          "Store bulk edit (#{@current_store.name}): #{label}"
    )
  rescue => e
    Rails.logger.error "Store bulk edit movement log failed for Product ##{product.id}: #{e.message}"
  end

  def default_stock_vendor
    @default_stock_vendor ||= Vendor.find_or_create_by(name: 'System Default') do |v|
      v.email = 'system@default.com'
      v.phone = '0000000000'
      v.address = 'System Generated'
      v.payment_type = 'Paid'
      v.status = true
    end
  end

  # ---- product form: delivery rules --------------------------------------

  def process_params_delivery_rule_data
    return unless params[:product] && params[:product][:delivery_rules_attributes]

    params[:product][:delivery_rules_attributes].each do |_index, rule_attrs|
      next unless rule_attrs
      rule_type = rule_attrs[:rule_type]
      if rule_type == 'all'
        rule_attrs[:rule_type] = 'everywhere'
        rule_type = 'everywhere'
      end

      case rule_type
      when 'state'
        rule_attrs[:location_data] = rule_attrs[:location_data_states].reject(&:blank?).to_json if rule_attrs[:location_data_states].present?
      when 'city'
        rule_attrs[:location_data] = rule_attrs[:location_data_cities].reject(&:blank?).to_json if rule_attrs[:location_data_cities].present?
      when 'pincode'
        rule_attrs[:location_data] = rule_attrs[:location_data_pincodes].split(',').map(&:strip).reject(&:blank?).to_json if rule_attrs[:location_data_pincodes].present?
      when 'everywhere'
        rule_attrs[:location_data] = '[]'
      end

      rule_attrs.delete(:location_data_states)
      rule_attrs.delete(:location_data_cities)
      rule_attrs.delete(:location_data_pincodes)
    end
  end

  # ---- product form: images (R2 primary, Cloudinary optional) -----------

  def extract_r2_key_from_url(image_url)
    uri = URI.parse(image_url)
    uri.path && uri.path[1..-1]
  rescue => e
    Rails.logger.error "Failed to parse R2 URL #{image_url}: #{e.message}"
    nil
  end

  def handle_image_removal
    return unless params[:remove_images].present?
    ids = params[:remove_images].map(&:to_i)
    @product.image.purge if @product.image.attached? && ids.include?(@product.image.id)
    @product.additional_images.where(id: ids).each(&:purge)
  end

  def handle_main_image_setting
    return unless params[:main_image_id].present?
    main_image = @product.additional_images.find_by(id: params[:main_image_id].to_i)
    return unless main_image
    current_main = @product.image if @product.image.attached?
    @product.additional_images.detach(main_image.blob)
    if current_main
      @product.additional_images.attach(current_main.blob)
      @product.image.detach
    end
    @product.image.attach(main_image.blob)
  end

  def handle_automatic_r2_uploads
    if @product.image.attached?
      begin
        temp = create_temp_file_from_attachment(@product.image)
        result = R2Service.upload(temp, folder: 'products')
        @product.update_column(:r2_image_url, result[:public_url]) unless result[:error]
        temp.tempfile.unlink if temp.respond_to?(:tempfile)
      rescue => e
        Rails.logger.error "R2 main image upload failed: #{e.message}"
      end
    end

    if @product.additional_images.attached?
      urls = []
      @product.additional_images.each do |img|
        begin
          temp = create_temp_file_from_attachment(img)
          result = R2Service.upload(temp, folder: 'products')
          urls << result[:public_url] unless result[:error]
          temp.tempfile.unlink if temp.respond_to?(:tempfile)
        rescue => e
          Rails.logger.error "R2 additional image upload failed: #{e.message}"
        end
      end
      if urls.any?
        existing = (JSON.parse(@product.r2_additional_images || '[]') rescue [])
        @product.update_column(:r2_additional_images, (existing + urls).uniq.to_json)
      end
    end
  end

  def handle_cloudinary_uploads
    return unless defined?(Cloudinary) && params[:product][:cloudinary_images].is_a?(Array)
    uploaded = []
    params[:product][:cloudinary_images].each_with_index do |file, index|
      next unless file.respond_to?(:tempfile) || file.respond_to?(:read)
      begin
        result = Cloudinary::Uploader.upload(
          file.try(:tempfile) || file,
          folder: 'products',
          public_id: "product-#{@product.id}-#{index}-#{SecureRandom.hex(4)}",
          overwrite: true, resource_type: :auto,
          transformation: [{ width: 1200, height: 1200, crop: :limit, quality: :auto, fetch_format: :auto }]
        )
        uploaded << result['public_id']
        @product.update_column(:image_url, result['public_id']) if index.zero? && @product.image_url.blank?
      rescue => e
        Rails.logger.error "Cloudinary upload failed: #{e.message}"
      end
    end
    if uploaded.length > 1
      current = @product.additional_cloudinary_images
      @product.update_column(:additional_images_urls, (current + uploaded[1..-1]).to_json)
    end
  end

  def create_temp_file_from_attachment(attachment)
    temp_file = Tempfile.new([File.basename(attachment.filename.to_s, '.*'), File.extname(attachment.filename.to_s)])
    temp_file.binmode
    temp_file.write(attachment.download)
    temp_file.rewind
    OpenStruct.new(
      tempfile: temp_file,
      original_filename: attachment.filename.to_s,
      content_type: attachment.content_type,
      size: attachment.byte_size
    )
  end

  # ---- product detail / chart helpers ----------------------------------

  def calculate_market_stats
    scope = Product.active.where.not(today_price: nil, yesterday_price: nil)
    return {} if scope.empty?

    avg_change = scope.average(:price_change_percentage)&.round(2) || 0
    {
      total_products:  scope.count,
      price_increases: scope.where('price_change_percentage > 0').count,
      price_decreases: scope.where('price_change_percentage < 0').count,
      price_stable:    scope.where('price_change_percentage = 0').count,
      avg_change:      avg_change,
      biggest_gainer:  scope.order(price_change_percentage: :desc).first,
      biggest_loser:   scope.order(price_change_percentage: :asc).first,
      market_trend:    avg_change > 0 ? 'bullish' : (avg_change < 0 ? 'bearish' : 'stable')
    }
  end

  def get_product_specifications
    {
      'Brand'  => @product.category&.name || 'Premium Brand',
      'Model'  => @product.name,
      'Weight' => @product.weight || 'Not specified',
      'Dimensions' => @product.dimensions || 'Not specified',
      'Warranty' => '1 Year Manufacturer Warranty',
      'In the Box' => 'Product, User Manual, Warranty Card',
      'Country of Origin' => 'Made in India',
      'Material' => 'Premium Quality Materials'
    }
  end

  def product_params
    params.require(:product).permit(
      :name, :description, :category_id, :price, :discount_price, :stock, :initial_stock, :low_stock_threshold, :b2b_price, :b2b_percentage,
      :status, :sku, :barcode, :hsn_code, :weight, :dimensions, :meta_title, :meta_description, :tags,
      :buying_price, :purchase_price, :discount_type, :discount_value, :original_price, :discount_amount, :is_discounted,
      :product_type, :unit_type, :is_subscription_enabled,
      :is_occasional_product, :occasional_start_date, :occasional_end_date, :occasional_description, :occasional_auto_hide,
      :occasional_schedule_type, :occasional_recurring_from_day, :occasional_recurring_from_time,
      :occasional_recurring_to_day, :occasional_recurring_to_time,
      :image_url, :additional_images_urls, :r2_image_url, :r2_additional_images,
      :gst_enabled, :gst_percentage, :cgst_percentage, :sgst_percentage, :igst_percentage,
      :gst_amount, :cgst_amount, :sgst_amount, :igst_amount, :final_amount_with_gst, :base_price_excluding_gst,
      :has_multiple_quantities, :image,
      additional_images: [], remove_images: [], cloudinary_images: [],
      product_variants_attributes: [
        :id, :weight, :unit, :buying_price, :purchase_price, :selling_price,
        :b2b_price, :b2b_percentage, :low_stock_threshold,
        :discount_enabled, :discount_type, :discount_value, :discount_amount,
        :available_stock, :is_default, :display_order,
        :gst_percentage, :gst_amount, :final_price_with_gst, :_destroy
      ],
      delivery_rules_attributes: [
        :id, :rule_type, :location_data, :is_excluded, :delivery_days, :delivery_charge, :_destroy,
        :location_data_pincodes, { location_data_states: [] }, { location_data_cities: [] }
      ]
    )
  end
end

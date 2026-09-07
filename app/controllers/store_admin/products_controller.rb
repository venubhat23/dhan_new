class StoreAdmin::ProductsController < StoreAdmin::ApplicationController
  include StoreAdmin::ProductManagement

  before_action :set_product, only: [:show, :edit, :update, :destroy, :toggle_status, :detail,
                                     :dependencies, :manage_images, :upload_main_image,
                                     :upload_additional_image, :destroy_gallery_image]
  before_action :load_categories, only: [:new, :create, :edit, :update]

  # Products stocked at (or sold by) the current store.
  def index
    scope = store_products.includes(:category, :product_variants, image_attachment: :blob)

    scope = scope.search(params[:search])                if params[:search].present?
    scope = scope.by_category(params[:category_id])      if params[:category_id].present?
    scope = scope.where(status: params[:status])         if params[:status].present?

    if params[:stock_status].present?
      inv_ids = @current_store.store_inventories
      case params[:stock_status]
      when 'in_stock'      then scope = scope.where(id: inv_ids.where('quantity > 0').select(:product_id))
      when 'out_of_stock'  then scope = scope.where(id: inv_ids.where('quantity <= 0').select(:product_id))
      when 'low_stock'     then scope = scope.where(id: inv_ids.where('quantity > 0 AND quantity <= COALESCE(low_stock_threshold, 10)').select(:product_id))
      end
    end

    @products = scope.order(:name).page(params[:page]).per(20)
    @filter_categories = Category.where(id: store_products.distinct.pluck(:category_id).compact)
                                .order(:display_order, :name)
    @categories = @filter_categories

    # Store on-hand per product (store_inventories first, active batches as fallback).
    inv_stock   = @current_store.store_inventories.group(:product_id).sum(:quantity)
    batch_stock = @current_store.stock_batches.where(status: 'active').group(:product_id).sum(:quantity_remaining)
    @store_stock = batch_stock.merge(inv_stock)
    @variant_store_stock = @current_store.store_inventories.where.not(product_variant_id: nil)
                                         .group(:product_variant_id).sum(:quantity)
    @total_products = store_products.count
  end

  def show
    @store_quantity = @current_store.available_stock_for(@product.id)
    @variants = @product.product_variants.ordered.to_a
    @variant_store_stock = @current_store.store_inventories.where(product_id: @product.id)
                                         .where.not(product_variant_id: nil)
                                         .group(:product_variant_id).sum(:quantity)
    @delivery_rules = @product.delivery_rules.includes(:product)
    @recent_bookings = store_bookings.joins(:booking_items)
                                     .where(booking_items: { product_id: @product.id })
                                     .distinct.order(created_at: :desc).limit(10)
  end

  def new
    @product = Product.new(status: 'active')
    @product.category_id = params[:category_id] if params[:category_id].present?
    @product.name = params[:name] if params[:name].present?
    @product.delivery_rules.build(rule_type: 'everywhere')
  end

  def create
    process_params_delivery_rule_data
    @product = Product.new(product_params)

    if @product.save
      handle_cloudinary_uploads if params.dig(:product, :cloudinary_images).present?
      handle_automatic_r2_uploads
      carry_product_at_store(@product, initial_stock: @product.stock.to_f)
      respond_to do |format|
        format.html { redirect_to store_admin_product_path(@product), notice: 'Product was successfully created.' }
        format.json { render json: { success: true, product: { id: @product.id, name: @product.name, unit_type: @product.unit_type, default_selling_price: @product.default_selling_price || 0 } } }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { success: false, errors: @product.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def edit
    @existing_rule = @product.delivery_rules.first
  end

  def update
    handle_image_removal if params[:remove_images].present?
    process_params_delivery_rule_data

    if @product.update(product_params)
      @product.product_variants.destroy_all unless @product.has_multiple_quantities?
      handle_cloudinary_uploads if params.dig(:product, :cloudinary_images).present?
      handle_automatic_r2_uploads
      handle_main_image_setting if params[:main_image_id].present?
      carry_product_at_store(@product)
      redirect_to store_admin_product_path(@product), notice: 'Product was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def dependencies
    groups = DEPENDENT_RELATIONS.filter_map do |label, scope|
      count = (scope.call(@product).count rescue 0)
      { label: label, count: count } if count.positive?
    end
    render json: { product_name: @product.name, total: groups.sum { |g| g[:count] }, groups: groups }
  end

  def destroy
    name = @product.name
    ActiveRecord::Base.transaction do
      purge_dependent_records!(@product)
      @product.destroy!
    end
    redirect_to store_admin_products_path, notice: "Product '#{name}' and all associated data were deleted successfully."
  rescue => e
    redirect_to store_admin_products_path, alert: "Could not delete product: #{e.message}"
  end

  def toggle_status
    new_status = @product.status == 'active' ? 'inactive' : 'active'
    @product.update(status: new_status)
    respond_to do |format|
      format.json { render json: { status: @product.status, message: "Product #{@product.status} successfully" } }
      format.html { redirect_to store_admin_products_path, notice: "Product #{@product.status} successfully" }
    end
  end

  def detail
    @related_products = store_products.where(category: @product.category).where.not(id: @product.id).limit(4)
    @reviews = @product.approved_reviews.recent.limit(10)
    @review_summary = {
      average_rating: @product.average_rating,
      total_reviews: @product.total_reviews,
      distribution: @product.review_percentage_distribution
    }
    @new_review = @product.product_reviews.build
    @market_stats = calculate_market_stats
    @specifications = get_product_specifications
  end

  def bulk_update
    ids_here = store_products.pluck(:id).map(&:to_s).to_set
    product_updates = (params[:products] || {}).select { |id, _| ids_here.include?(id.to_s) }
    variant_ids_here = ProductVariant.where(product_id: store_products.select(:id)).pluck(:id).map(&:to_s).to_set
    variant_updates = (params[:variants] || {}).select { |vid, _| variant_ids_here.include?(vid.to_s) }

    updated = 0
    @bulk_batches_created = 0
    errors = []

    product_updates.each do |id, attrs|
      product = Product.find_by(id: id)
      next unless product
      permitted = attrs.permit(:name, :price, :buying_price, :purchase_price, :stock, :unit_type, :status, :category_id)
      track_stock = permitted.key?(:stock) && !product.has_multiple_quantities?
      old_stock = @current_store.available_stock_for(product.id).to_f
      new_stock = permitted[:stock].to_f if track_stock

      unless product.update(permitted.except(:stock))
        errors << "#{product.name}: #{product.errors.full_messages.join(', ')}"
        next
      end

      if track_stock && new_stock != old_stock
        err = apply_store_stock_change(product, nil, old_stock, new_stock,
                                       cost: permitted[:purchase_price].presence || product.purchase_price.presence || product.buying_price,
                                       sell: permitted[:price].presence || product.price,
                                       label: "stock #{old_stock.to_i} → #{new_stock.to_i}")
        errors << "#{product.name}: #{err}" if err
      end
      updated += 1
    end

    variant_updates.each do |vid, attrs|
      variant = ProductVariant.find_by(id: vid)
      next unless variant
      permitted = attrs.permit(:selling_price, :buying_price, :purchase_price, :available_stock, :unit)
      row = @current_store.store_inventories.find_by(product_variant_id: variant.id)
      old_stock = (row&.quantity || variant.available_stock).to_f
      new_stock = permitted[:available_stock].to_f if permitted.key?(:available_stock)

      unless variant.update(permitted.except(:available_stock))
        errors << "#{variant.product&.name} #{variant.label}: #{variant.errors.full_messages.join(', ')}"
        next
      end

      if new_stock && new_stock != old_stock
        err = apply_store_stock_change(variant.product, variant, old_stock, new_stock,
                                       cost: permitted[:purchase_price].presence || variant.purchase_price.presence || variant.buying_price,
                                       sell: permitted[:selling_price].presence || variant.selling_price,
                                       label: "variant #{variant.label} stock #{old_stock.to_i} → #{new_stock.to_i}")
        errors << "#{variant.product&.name} #{variant.label}: #{err}" if err
      end
      updated += 1
    end

    batch_note = @bulk_batches_created > 0 ? " (#{@bulk_batches_created} stock batch#{'es' if @bulk_batches_created != 1} created)" : ""
    if errors.empty?
      redirect_to store_admin_products_path, notice: "#{updated} product(s) updated successfully#{batch_note}"
    else
      redirect_to store_admin_products_path, alert: "Updated #{updated}#{batch_note}. Issues: #{errors.join(' | ')}"
    end
  rescue => e
    redirect_to store_admin_products_path, alert: "Bulk update failed: #{e.message}"
  end

  def bulk_action
    ids = Array(params[:product_ids]) & store_products.pluck(:id).map(&:to_s)
    case params[:bulk_action]
    when 'activate'
      Product.where(id: ids).update_all(status: 'active')
      message = 'Products activated successfully'
    when 'deactivate'
      Product.where(id: ids).update_all(status: 'inactive')
      message = 'Products deactivated successfully'
    when 'delete'
      products = Product.where(id: ids).to_a
      ActiveRecord::Base.transaction do
        products.each do |product|
          purge_dependent_records!(product)
          product.destroy!
        end
      end
      message = "#{products.size} product(s) and all associated data deleted successfully"
    else
      message = 'Invalid action'
    end
    redirect_to store_admin_products_path, notice: message
  rescue => e
    redirect_to store_admin_products_path, alert: "Could not complete bulk action: #{e.message}"
  end

  def search
    term = "%#{params[:q].to_s.strip}%"
    results = store_products.where('products.name ILIKE ? OR products.sku ILIKE ?', term, term).limit(15)
    render json: results.map { |p| { id: p.id, name: p.name, sku: p.sku, price: p.price.to_f } }
  end

  def categories_for_select
    render json: Category.active.ordered.map { |c| { id: c.id, name: c.name } }
  end

  def products_chart
    @products_with_prices = store_products.where.not(today_price: nil).includes(:category).order(:name)
    @market_stats = calculate_market_stats
  end

  # ---- image manager --------------------------------------------------------

  def manage_images
    @variants = @product.product_variants.ordered
    @gallery = @product.image_gallery
  end

  def upload_main_image
    return redirect_to(manage_images_store_admin_product_path(@product), alert: 'Please choose an image to upload.') if params[:image].blank?
    result = R2Service.upload(params[:image], folder: 'products')
    if result[:error]
      redirect_to manage_images_store_admin_product_path(@product), alert: "Upload failed: #{result[:error]}"
    else
      old_url = @product.r2_image_url
      @product.update!(r2_image_url: result[:public_url])
      if old_url.present? && (old_key = extract_r2_key_from_url(old_url))
        R2Service.delete(old_key)
      end
      redirect_to manage_images_store_admin_product_path(@product), notice: 'Main image updated successfully.'
    end
  end

  def upload_additional_image
    return redirect_to(manage_images_store_admin_product_path(@product), alert: 'Please choose an image to upload.') if params[:image].blank?
    result = R2Service.upload(params[:image], folder: 'products')
    if result[:error]
      redirect_to manage_images_store_admin_product_path(@product), alert: "Upload failed: #{result[:error]}"
    else
      @product.add_additional_r2_image(result[:public_url])
      @product.save!
      redirect_to manage_images_store_admin_product_path(@product), notice: 'Image added successfully.'
    end
  end

  def destroy_gallery_image
    removed_url = @product.remove_gallery_image!(params[:gallery_id])
    if removed_url.present? && (removed_key = extract_r2_key_from_url(removed_url))
      R2Service.delete(removed_key)
    end
    redirect_to manage_images_store_admin_product_path(@product), notice: 'Image removed successfully.'
  end

  def upload_r2_image
    return render(json: { error: 'No image provided' }, status: :bad_request) if params[:image].blank?
    result = R2Service.upload(params[:image], folder: 'products')
    if result[:error]
      render json: { error: result[:error] }, status: :unprocessable_entity
    else
      render json: { key: result[:key], filename: result[:filename], public_url: result[:public_url], size: result[:size] }
    end
  rescue => e
    render json: { error: "Upload failed: #{e.message}" }, status: :internal_server_error
  end

  def upload_cloudinary_image
    return render(json: { success: false, error: 'No image provided' }, status: :bad_request) if params[:image].blank?
    return render(json: { success: false, error: 'Cloudinary not configured' }, status: :unprocessable_entity) unless defined?(Cloudinary)

    result = Cloudinary::Uploader.upload(
      params[:image].tempfile, folder: 'products',
      public_id: "product-temp-#{SecureRandom.hex(8)}", overwrite: true, resource_type: :auto,
      transformation: [{ width: 1200, height: 1200, crop: :limit, quality: :auto, fetch_format: :auto }]
    )
    render json: {
      success: true, public_id: result['public_id'], url: result['secure_url'],
      thumbnail_url: Cloudinary::Utils.cloudinary_url(result['public_id'], width: 300, height: 300, crop: :fill)
    }
  rescue => e
    render json: { success: false, error: "Upload failed: #{e.message}" }, status: :unprocessable_entity
  end

  def delete_r2_image
    image_url = params[:image_url]
    return render(json: { error: 'Image URL is required' }, status: :bad_request) if image_url.blank?
    if params[:permanent] == 'true' && (key = extract_r2_key_from_url(image_url))
      R2Service.delete(key)
    end
    render json: { success: true, message: 'Image unlinked' }
  rescue => e
    render json: { error: "Deletion failed: #{e.message}" }, status: :internal_server_error
  end

  private

  def set_product
    @product = store_products.includes(:product_variants).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to store_admin_products_path, alert: 'Product not found for this store.'
  end

  def load_categories
    @categories = Category.active.ordered
  end

  # Attach a product created/edited here to this store: claim the just-created
  # unassigned batches, keep a store_inventories row in sync, carry each variant.
  def carry_product_at_store(product, initial_stock: nil)
    product.stock_batches.where(store_id: nil).where('created_at > ?', 2.minutes.ago)
           .update_all(store_id: @current_store.id)

    row = @current_store.store_inventories.find_or_initialize_by(product_id: product.id, product_variant_id: nil)
    row.low_stock_threshold = product.low_stock_threshold if row.new_record?
    on_hand = @current_store.stock_batches.where(product_id: product.id, status: 'active').sum(:quantity_remaining)
    row.quantity = on_hand.positive? ? on_hand : (initial_stock.to_f.positive? ? initial_stock.to_f : row.quantity.to_f)
    row.save

    product.product_variants.reload.each do |variant|
      vrow = @current_store.store_inventories.find_or_initialize_by(product_id: product.id, product_variant_id: variant.id)
      vrow.low_stock_threshold = variant.low_stock_threshold || product.low_stock_threshold || 10 if vrow.new_record?
      vrow.quantity = variant.available_stock.to_f
      vrow.save
    end
  rescue => e
    Rails.logger.error "carry_product_at_store failed for product #{product.id}: #{e.message}"
  end
end

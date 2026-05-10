class Product < ApplicationRecord
  # Product Type Constants
  PRODUCT_TYPES = [
    ['Milk', 'Milk'],
    ['Grocery', 'Grocery'],
    ['Fruit & Vegetable', 'Fruit & Vegetable']
  ].freeze

  PRODUCT_TYPE_OPTIONS = {
    'Milk' => { icon: 'bi-cup-straw', color: '#e3f2fd', border: '#2196f3', text: '#1976d2' },
    'Grocery' => { icon: 'bi-basket', color: '#f3e5f5', border: '#9c27b0', text: '#7b1fa2' },
    'Fruit & Vegetable' => { icon: 'bi-flower1', color: '#e8f5e8', border: '#4caf50', text: '#388e3c' }
  }.freeze

  # Unit Type Constants - Fixed Options Only
  UNIT_TYPES = [
    ['Kg', 'Kg'],
    ['Bottle', 'Bottle'],
    ['Box', 'Box'],
    ['Liter', 'Liter'],
    ['Piece', 'Piece'],
    ['Gram', 'Gram']
  ].freeze

  belongs_to :category
  has_many :product_variants, dependent: :destroy
  has_many :delivery_rules, dependent: :destroy
  has_many :booking_items
  has_many :order_items
  has_many :bookings, through: :booking_items
  has_many :orders, through: :order_items
  has_many :product_reviews, dependent: :destroy
  has_many :approved_reviews, -> { approved }, class_name: 'ProductReview'
  # Keep old ratings for backward compatibility
  has_many :product_ratings, dependent: :destroy
  has_many :approved_ratings, -> { approved }, class_name: 'ProductRating'

  # Vendor management associations
  has_many :vendor_purchase_items, dependent: :destroy
  has_many :vendor_purchases, through: :vendor_purchase_items
  has_many :vendors, through: :vendor_purchases
  has_many :stock_batches, dependent: :destroy
  has_many :sale_items, dependent: :destroy
  has_many :stock_movements, dependent: :destroy

  # Cloudinary image uploads - store URLs in database
  # image_url and additional_images_urls columns will be added via migration

  # R2 image uploads - store URLs in database
  # r2_image_url and r2_additional_images columns for Cloudflare R2

  # Keep Active Storage for backward compatibility if needed
  has_one_attached :image
  has_many_attached :additional_images

  validates :name, presence: true
  validates :sku, presence: true, uniqueness: { case_sensitive: false }
  validates :price, presence: true, numericality: { greater_than: 0 }, unless: :has_multiple_quantities?
  validates :discount_price, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true
  validates :stock, presence: true, numericality: { greater_than_or_equal_to: 0 }, unless: :has_multiple_quantities?
  validates :status, presence: true
  validates :product_type, presence: true, inclusion: { in: PRODUCT_TYPES.map(&:last) }
  validates :weight, numericality: { greater_than: 0 }, allow_blank: true
  validates :buying_price, numericality: { greater_than: 0 }, allow_blank: true, unless: :has_multiple_quantities?
  validates :unit_type, presence: true, inclusion: { in: UNIT_TYPES.map(&:last) }
  # validates :minimum_stock_alert, numericality: { greater_than: 0 }, allow_blank: true
  # validates :default_selling_price, numericality: { greater_than: 0 }, allow_blank: true
  validates :discount_type, inclusion: { in: ['percentage', 'fixed'], message: 'must be percentage or fixed' }, allow_blank: true
  validates :discount_value, numericality: { greater_than: 0 }, allow_blank: true
  validates :original_price, numericality: { greater_than: 0 }, allow_blank: true
  validates :occasional_start_date, presence: true, if: :requires_occasional_dates?
  validates :occasional_end_date, presence: true, if: :requires_occasional_dates?

  # GST validations (skipped entirely when multi-qty is on — each variant has its own GST)
  validates :gst_percentage, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 50 }, if: -> { gst_enabled? && !has_multiple_quantities? }
  validates :cgst_percentage, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 25 }, allow_blank: true
  validates :sgst_percentage, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 25 }, allow_blank: true
  validates :igst_percentage, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 50 }, allow_blank: true
  validates :gst_amount, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true
  validates :cgst_amount, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true
  validates :sgst_amount, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true
  validates :igst_amount, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true
  validates :final_amount_with_gst, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true

  validate :discount_price_validation
  validate :discount_value_validation
  validate :occasional_dates_validation
  validate :gst_rates_validation, unless: :has_multiple_quantities?
  validate :variants_required_when_multi_qty, if: :has_multiple_quantities?

  accepts_nested_attributes_for :product_variants, allow_destroy: true, reject_if: ->(attrs) { attrs['weight'].blank? || attrs['selling_price'].blank? }
  accepts_nested_attributes_for :delivery_rules, allow_destroy: true, reject_if: :all_blank

  enum :status, { active: 'active', inactive: 'inactive', draft: 'draft' }

  scope :active, -> { where(status: :active) }
  scope :inactive, -> { where(status: :inactive) }
  scope :draft, -> { where(status: :draft) }
  scope :in_stock, -> {
    joins(:stock_batches)
      .where(stock_batches: { status: 'active' })
      .group('products.id')
      .having('SUM(stock_batches.quantity_remaining) > 0')
  }
  # For the mobile/customer API: multi-qty products use variant stock, not stock_batches
  scope :available_for_sale, -> {
    batch_stock_ids = joins(:stock_batches)
                        .where(stock_batches: { status: 'active' }, has_multiple_quantities: false)
                        .group('products.id')
                        .having('SUM(stock_batches.quantity_remaining) > 0')
                        .select('products.id')
    variant_stock_ids = joins(:product_variants)
                          .where(has_multiple_quantities: true)
                          .where('product_variants.available_stock > 0')
                          .select('DISTINCT products.id')
    where(id: batch_stock_ids).or(where(id: variant_stock_ids))
  }
  scope :out_of_stock, -> {
    left_joins(:stock_batches)
      .group('products.id')
      .having('COALESCE(SUM(CASE WHEN stock_batches.status = ? THEN stock_batches.quantity_remaining ELSE 0 END), 0) = 0', 'active')
  }
  scope :by_category, ->(category_id) { where(category_id: category_id) }
  scope :search, ->(query) { where('name ILIKE ?', "%#{query}%") }
  scope :recent, -> { order(created_at: :desc) }
  scope :occasional, -> { where(is_occasional_product: true) }
  scope :regular, -> { where(is_occasional_product: false) }
  scope :occasional_active_now, -> { occasional.where('occasional_start_date <= ? AND occasional_end_date >= ?', Time.current, Time.current) }
  scope :occasional_upcoming, -> { occasional.where('occasional_start_date > ?', Time.current) }
  scope :occasional_expired, -> { occasional.where('occasional_end_date < ?', Time.current) }
  scope :subscription_enabled, -> { where(is_subscription_enabled: true) }
  scope :subscription_disabled, -> { where(is_subscription_enabled: false) }

  before_validation :generate_sku, if: -> { sku.blank? }
  before_validation :set_default_status, if: :new_record?
  before_validation :sync_price_from_variants, if: :has_multiple_quantities?
  before_save :process_delivery_rules_location_data
  before_save :calculate_discount_fields
  before_save :update_price_tracking
  after_create :create_initial_stock_movement, if: -> { stock.present? && stock > 0 }
  after_create :create_initial_stock_batch, if: -> { stock.present? && stock > 0 }
  after_update :update_stock_batch, if: -> { saved_change_to_stock? && stock.present? }
  after_commit :bust_mobile_api_cache

  def bust_mobile_api_cache
    MobileApiCache.bust_products!
  end

  def in_stock?
    cached_total_batch_stock > 0
  end

  def default_variant
    product_variants.default_first.first
  end

  def display_price
    if has_multiple_quantities? && (dv = default_variant)
      dv.effective_price
    else
      price
    end
  end

  # Inventory tracking methods
  def total_sold_quantity
    # Get total quantity sold from booking items
    booking_items.joins(:booking)
                 .where(bookings: { status: ['confirmed', 'processing', 'packed', 'shipped', 'out_for_delivery', 'delivered', 'completed'] })
                 .sum(:quantity)
  end

  def available_quantity
    if has_multiple_quantities?
      product_variants.sum(:available_stock).to_f
    else
      total_batch_stock
    end
  end

  def available_stock
    available_quantity
  end

  def track_stock?
    # Products track stock by default unless explicitly disabled
    # You can add a track_stock attribute to products table if needed
    true
  end

  def update_stock_for_invoice(qty_difference)
    # Update stock when invoice items are modified
    if qty_difference > 0
      # Increasing invoice quantity - reduce available stock
      update_stock(-qty_difference, 'invoice_update', Time.current.to_i, "Stock reduced due to invoice quantity increase by #{qty_difference}")
    elsif qty_difference < 0
      # Decreasing invoice quantity - increase available stock
      update_stock(qty_difference.abs, 'invoice_update', Time.current.to_i, "Stock increased due to invoice quantity decrease by #{qty_difference.abs}")
    end
    # If qty_difference is 0, no stock update needed
  end

  def sold_quantity
    # Calculate sold quantity as initial_stock - available_quantity
    return 0 if initial_stock.nil? || initial_stock == 0
    [initial_stock - available_quantity, 0].max
  end

  def inventory_status_text
    if initial_stock.present? && initial_stock > 0
      "#{available_quantity} available / #{sold_quantity} sold / #{initial_stock} total"
    else
      "#{available_quantity} available"
    end
  end

  # Initial stock - calculated as the first stock batch's quantity
  def initial_stock
    # Use cached value if available (from controller query)
    if respond_to?(:initial_stock_value) && initial_stock_value.present?
      return initial_stock_value.to_f
    end

    # Use loaded association if available
    if stock_batches.loaded?
      oldest_batch = stock_batches.min_by { |b| [b.batch_date, b.created_at] }
      return oldest_batch&.quantity_purchased || stock || 0
    end

    # Get the oldest stock batch (the original one) or fall back to current stock
    first_batch = stock_batches.by_fifo.first
    first_batch&.quantity_purchased || stock || 0
  end

  # Optimized method for cached initial stock
  def cached_initial_stock
    if respond_to?(:initial_stock_value)
      initial_stock_value.to_f
    elsif stock_batches.loaded?
      oldest_batch = stock_batches.min_by { |b| [b.batch_date, b.created_at] }
      oldest_batch&.quantity_purchased || stock || 0
    else
      initial_stock
    end
  end

  def inventory_percentage_sold
    return 0 if initial_stock.nil? || initial_stock == 0
    ((sold_quantity.to_f / initial_stock) * 100).round(1)
  end

  def inventory_percentage_available
    return 100 if initial_stock.nil? || initial_stock == 0
    ((available_quantity.to_f / initial_stock) * 100).round(1)
  end

  def discounted?
    is_discounted? || (discount_price.present? && discount_price > 0 && discount_price < price)
  end

  def selling_price
    discounted? ? final_price_after_discount : price
  end

  def final_price_after_discount
    return price unless discounted?

    if discount_type.present? && discount_value.present?
      calculate_discounted_price(original_price || price, discount_type, discount_value)
    else
      discount_price || price
    end
  end

  def discount_percentage
    return 0 unless discounted?

    if discount_type == 'percentage' && discount_value.present?
      discount_value
    elsif discount_amount.present? && (original_price || price) > 0
      ((discount_amount / (original_price || price)) * 100).round(2)
    elsif discount_price.present?
      ((price - discount_price) / price * 100).round(2)
    else
      0
    end
  end

  def savings_amount
    return 0 unless discounted?

    if discount_amount.present?
      discount_amount
    elsif original_price.present?
      original_price - final_price_after_discount
    else
      price - final_price_after_discount
    end
  end

  # Profit margin calculations
  def profit_amount
    return 0 unless buying_price.present?
    final_price_after_discount - buying_price
  end

  def profit_percentage
    return 0 unless buying_price.present? && buying_price > 0
    ((profit_amount / buying_price) * 100).round(2)
  end

  def profit_margin_percentage
    return 0 unless buying_price.present? && final_price_after_discount > 0
    ((profit_amount / final_price_after_discount) * 100).round(2)
  end

  def cost_percentage
    return 0 unless buying_price.present? && final_price_after_discount > 0
    ((buying_price / final_price_after_discount) * 100).round(2)
  end

  def profitable?
    buying_price.present? && profit_amount > 0
  end

  def formatted_buying_price
    buying_price.present? ? "₹#{buying_price}" : 'Not set'
  end

  def profit_status
    return 'Unknown' unless buying_price.present?

    if profit_amount > 0
      'Profitable'
    elsif profit_amount == 0
      'Break Even'
    else
      'Loss Making'
    end
  end

  def profit_status_class
    return 'text-muted' unless buying_price.present?

    if profit_amount > 0
      'text-success'
    elsif profit_amount == 0
      'text-warning'
    else
      'text-danger'
    end
  end

  # Review methods (using new ProductReview model)
  def average_rating
    return 0 if approved_reviews.empty?
    (approved_reviews.average(:rating) || 0).round(1)
  end

  def total_reviews
    approved_reviews.count
  end

  def review_distribution
    return {} if approved_reviews.empty?

    distribution = approved_reviews.group(:rating).count
    (1..5).map { |rating| [rating, distribution[rating] || 0] }.to_h
  end

  def review_percentage_distribution
    total = total_reviews
    return {} if total == 0

    review_distribution.transform_values { |count| ((count.to_f / total) * 100).round(1) }
  end

  def star_display
    full_stars = average_rating.floor
    half_star = (average_rating - full_stars) >= 0.5 ? 1 : 0
    empty_stars = 5 - full_stars - half_star

    ('⭐' * full_stars) + ('⭐' * half_star) + ('☆' * empty_stars)
  end

  def has_reviews?
    total_reviews > 0
  end

  def highly_rated?
    average_rating >= 4.0 && total_reviews >= 5
  end

  # Occasional product methods
  def occasional_active?
    return false unless is_occasional_product?
    return false if occasional_start_date.blank? || occasional_end_date.blank?

    current_time = Time.current
    current_time >= occasional_start_date && current_time <= occasional_end_date
  end

  def occasional_upcoming?
    return false unless is_occasional_product?
    return false if occasional_start_date.blank?

    Time.current < occasional_start_date
  end

  def occasional_expired?
    return false unless is_occasional_product?
    return false if occasional_end_date.blank?

    Time.current > occasional_end_date
  end

  def requires_occasional_dates?
    return false unless is_occasional_product?
    # For now, we'll make dates optional for all occasional products
    # In future, this could be based on occasional_schedule_type or other logic
    false
  end

  def occasional_status_text
    return 'Regular Product' unless is_occasional_product?

    if occasional_active?
      'Active Now'
    elsif occasional_upcoming?
      "Starts #{occasional_start_date.strftime('%b %d, %Y at %I:%M %p')}"
    elsif occasional_expired?
      "Ended #{occasional_end_date.strftime('%b %d, %Y at %I:%M %p')}"
    else
      'Not Configured'
    end
  end

  def occasional_days_remaining
    return nil unless is_occasional_product? && occasional_active?

    days = ((occasional_end_date - Time.current) / 1.day).ceil
    days > 0 ? days : 0
  end

  def should_display_now?
    return true unless is_occasional_product?

    if occasional_auto_hide?
      occasional_active?
    else
      true # Always show if auto-hide is disabled
    end
  end

  def review_summary_text
    return 'No reviews yet' unless has_reviews?
    "#{average_rating}/5 (#{total_reviews} #{'review'.pluralize(total_reviews)})"
  end

  def latest_reviews(limit = 5)
    approved_reviews.recent.limit(limit)
  end

  def featured_reviews(limit = 3)
    approved_reviews.helpful.limit(limit)
  end

  # Product Type Methods
  def product_type_icon
    return 'bi-box' unless product_type.present?
    PRODUCT_TYPE_OPTIONS[product_type]&.dig(:icon) || 'bi-box'
  end

  def product_type_color
    return '#6c757d' unless product_type.present?
    PRODUCT_TYPE_OPTIONS[product_type]&.dig(:text) || '#6c757d'
  end

  def product_type_badge_class
    case product_type
    when 'Milk'
      'bg-primary-subtle text-primary'
    when 'Grocery'
      'bg-purple-subtle text-purple'
    when 'Fruit & Vegetable'
      'bg-success-subtle text-success'
    else
      'bg-secondary-subtle text-secondary'
    end
  end

  # Subscription Methods
  def subscription_enabled?
    is_subscription_enabled == true
  end

  def subscription_badge_class
    subscription_enabled? ? 'bg-success-subtle text-success' : 'bg-secondary-subtle text-secondary'
  end

  def subscription_icon
    subscription_enabled? ? 'bi-arrow-repeat' : 'bi-bag'
  end

  def subscription_status_text
    subscription_enabled? ? 'Subscription Available' : 'One-time Purchase Only'
  end

  # Price tracking methods
  def update_price_tracking
    return unless price_changed? || yesterday_price.nil?

    # Store current price as yesterday's price if it's a new day
    if last_price_update.nil? || last_price_update < Date.current.beginning_of_day
      self.yesterday_price = price_was || price
      self.today_price = price
      self.last_price_update = Time.current
      calculate_price_change_percentage
      update_price_history
    elsif price_changed?
      # Update today's price if changed within the same day
      self.today_price = price
      calculate_price_change_percentage
      update_price_history
    end
  end

  def price_trend
    return 'stable' if yesterday_price.nil? || yesterday_price == today_price

    today_price > yesterday_price ? 'up' : 'down'
  end

  def price_change_amount
    return 0 if yesterday_price.nil?
    (today_price || price) - yesterday_price
  end

  def formatted_price_change
    change = price_change_amount
    return '₹0' if change == 0

    sign = change > 0 ? '+' : ''
    "#{sign}₹#{change}"
  end

  def price_change_percentage_formatted
    return '0%' if price_change_percentage.nil? || price_change_percentage == 0

    sign = price_change_percentage > 0 ? '+' : ''
    "#{sign}#{price_change_percentage}%"
  end

  def price_trend_class
    case price_trend
    when 'up'
      'text-success'
    when 'down'
      'text-danger'
    else
      'text-muted'
    end
  end

  def price_trend_icon
    case price_trend
    when 'up'
      'bi-arrow-up'
    when 'down'
      'bi-arrow-down'
    else
      'bi-dash'
    end
  end

  def get_price_history_array
    return [] if price_history.blank?
    JSON.parse(price_history)
  rescue JSON::ParserError
    []
  end

  def formatted_today_price
    "₹#{today_price || price}"
  end

  def formatted_yesterday_price
    return 'N/A' if yesterday_price.nil?
    "₹#{yesterday_price}"
  end

  # Vendor Management Methods
  def total_batch_stock
    # Use cached value if available (from controller query)
    if respond_to?(:cached_stock) && cached_stock.present?
      return cached_stock.to_f
    end

    # Fallback to regular stock if stock_batches table doesn't exist
    return stock if !ActiveRecord::Base.connection.table_exists?('stock_batches')
    stock_batches.active.sum(:quantity_remaining)
  rescue
    stock
  end

  # Optimized method for when we have preloaded stock_batches
  def cached_total_batch_stock
    if respond_to?(:cached_stock)
      cached_stock.to_f
    elsif stock_batches.loaded?
      stock_batches.select { |b| b.status == 'active' && b.quantity_remaining > 0 }.sum(&:quantity_remaining)
    else
      total_batch_stock
    end
  end

  def total_batch_value
    stock_batches.active.sum { |batch| batch.quantity_remaining * batch.purchase_price }
  end

  def average_purchase_price
    active_batches = stock_batches.active
    return 0 if active_batches.empty?

    total_cost = active_batches.sum { |batch| batch.quantity_remaining * batch.purchase_price }
    total_quantity = active_batches.sum(:quantity_remaining)

    return 0 if total_quantity.zero?
    (total_cost / total_quantity).round(2)
  end

  def below_minimum_stock?
    return false unless minimum_stock_alert.present?
    total_batch_stock < minimum_stock_alert
  end

  def stock_alert_message
    return nil unless below_minimum_stock?
    "Stock is below minimum level of #{minimum_stock_alert} units"
  end

  def unit_display
    unit_type || 'units'
  end

  def can_fulfill_order?(requested_quantity, variant_id: nil)
    if has_multiple_quantities?
      if variant_id.present?
        variant = product_variants.find_by(id: variant_id)
        return variant ? variant.available_stock.to_f >= requested_quantity : false
      else
        # No specific variant given — allow if any variant has enough stock
        return product_variants.any? { |v| v.available_stock.to_f >= requested_quantity }
      end
    end
    total_batch_stock >= requested_quantity
  end

  def get_fifo_allocation(requested_quantity)
    StockBatch.fifo_allocation(id, requested_quantity)
  end

  def vendor_count
    vendors.distinct.count
  end

  def latest_purchase_price
    stock_batches.by_fifo.last&.purchase_price || 0
  end

  def earliest_batch_date
    stock_batches.active.minimum(:batch_date)
  end

  def batch_summary
    {
      total_batches: stock_batches.count,
      active_batches: stock_batches.active.count,
      exhausted_batches: stock_batches.exhausted.count,
      total_quantity: total_batch_stock,
      total_value: total_batch_value,
      vendors: vendor_count
    }
  end

  # Legacy methods for backward compatibility
  alias_method :total_ratings, :total_reviews
  alias_method :has_ratings?, :has_reviews?
  alias_method :rating_summary_text, :review_summary_text

  # Cloudinary helper methods
  def cloudinary_image_url(transformation = {})
    return nil unless image_url.present?

    begin
      # Check if Cloudinary is properly configured
      unless Cloudinary.config.cloud_name.present?
        Rails.logger.warn "Cloudinary not properly configured. Returning original image URL."
        return image_url
      end

      default_transformations = {
        width: 800,
        height: 600,
        crop: :fill,
        quality: :auto,
        fetch_format: :auto
      }

      Cloudinary::Utils.cloudinary_url(image_url, default_transformations.merge(transformation))
    rescue => e
      Rails.logger.error "Error generating Cloudinary URL: #{e.message}"
      image_url # Fallback to original URL
    end
  end

  def cloudinary_thumbnail_url(size = 300)
    cloudinary_image_url(width: size, height: size, crop: :fill)
  end

  def cloudinary_small_thumbnail_url(size = 150)
    cloudinary_image_url(width: size, height: size, crop: :fill)
  end

  def additional_cloudinary_images
    return [] unless additional_images_urls.present?

    begin
      urls = JSON.parse(additional_images_urls)
      urls.is_a?(Array) ? urls : []
    rescue JSON::ParserError
      []
    end
  end

  def cloudinary_additional_image_url(index, transformation = {})
    urls = additional_cloudinary_images
    return nil unless urls[index].present?

    default_transformations = {
      width: 800,
      height: 600,
      crop: :fill,
      quality: :auto,
      fetch_format: :auto
    }

    Cloudinary::Utils.cloudinary_url(urls[index], default_transformations.merge(transformation))
  end

  # Helper method to get all images (Cloudinary + Active Storage) for views
  def images
    all_images = []

    # Add R2 main image with highest priority
    if r2_image_url.present?
      all_images << r2_image_url
    end

    # Add R2 additional images
    r2_additional_images_array.each do |r2_url|
      all_images << r2_url
    end

    # Add Cloudinary main image (if no R2 images)
    if image_url.present? && all_images.empty?
      all_images << cloudinary_image_url
    end

    # Add Cloudinary additional images (if no R2 images)
    if all_images.empty?
      additional_cloudinary_images.each do |cloudinary_url|
        all_images << Cloudinary::Utils.cloudinary_url(cloudinary_url,
          width: 800, height: 600, crop: :fill, quality: :auto, fetch_format: :auto
        )
      end
    end

    # Add Active Storage images for backward compatibility (if no cloud images)
    if all_images.empty?
      all_images << image if image.attached?
      all_images.concat(additional_images.to_a) if additional_images.attached?
    end

    all_images
  end

  # Helper method with metadata for admin views
  def images_with_metadata
    all_images = []

    # Add Cloudinary main image
    if image_url.present?
      all_images << { type: 'cloudinary', url: cloudinary_image_url, source: 'Cloudinary' }
    end

    # Add Cloudinary additional images
    additional_cloudinary_images.each do |cloudinary_url|
      all_images << {
        type: 'cloudinary',
        url: Cloudinary::Utils.cloudinary_url(cloudinary_url,
          width: 800, height: 600, crop: :fill, quality: :auto, fetch_format: :auto
        ),
        source: 'Cloudinary'
      }
    end

    # Add Active Storage images for backward compatibility
    all_images << { type: 'active_storage', attachment: image, source: 'Local Storage' } if image.attached?
    all_images.concat(additional_images.map { |img| { type: 'active_storage', attachment: img, source: 'Local Storage' } }) if additional_images.attached?

    all_images
  end

  # Check if any images are available (R2, Cloudinary or Active Storage)
  def images_attached?
    r2_image_url.present? || r2_additional_images.present? || image_url.present? || additional_images_urls.present? || image.attached? || additional_images.attached?
  end

  def main_image
    if r2_image_url.present?
      { type: 'r2', url: r2_image_url }
    elsif image_url.present?
      cloudinary_url = cloudinary_image_url
      if cloudinary_url.present?
        { type: 'cloudinary', url: cloudinary_url }
      else
        { type: 'cloudinary_fallback', url: image_url }
      end
    elsif image.attached?
      { type: 'active_storage', attachment: image }
    else
      nil
    end
  end

  def main_image_url(transformation = {})
    if r2_image_url.present?
      r2_image_url
    elsif image_url.present?
      cloudinary_url = cloudinary_image_url(transformation)
      cloudinary_url.present? ? cloudinary_url : image_url
    elsif image.attached?
      Rails.application.routes.url_helpers.rails_blob_url(image, only_path: true)
    else
      nil
    end
  end

  # Upload to Cloudinary method
  def upload_to_cloudinary(file, folder = 'products')
    return nil unless file

    begin
      result = Cloudinary::Uploader.upload(
        file.tempfile || file,
        folder: folder,
        public_id: "#{folder}/#{id}-#{SecureRandom.hex(8)}",
        overwrite: true,
        resource_type: :auto,
        transformation: [
          { width: 1200, height: 1200, crop: :limit, quality: :auto, fetch_format: :auto }
        ]
      )

      result['public_id']
    rescue => e
      Rails.logger.error "Cloudinary upload failed: #{e.message}"
      nil
    end
  end

  def add_additional_cloudinary_image(cloudinary_public_id)
    current_urls = additional_cloudinary_images
    current_urls << cloudinary_public_id
    self.additional_images_urls = current_urls.to_json
  end

  # R2 helper methods
  def upload_to_r2(file, folder = 'products')
    return nil unless file

    begin
      result = R2Service.upload(file, folder: folder)

      if result[:error]
        Rails.logger.error "R2 upload failed: #{result[:error]}"
        return nil
      end

      result[:public_url]
    rescue => e
      Rails.logger.error "R2 upload failed: #{e.message}"
      nil
    end
  end

  def r2_additional_images_array
    return [] unless r2_additional_images.present?

    begin
      urls = JSON.parse(r2_additional_images)
      urls.is_a?(Array) ? urls : []
    rescue JSON::ParserError
      []
    end
  end

  def add_additional_r2_image(r2_url)
    current_urls = r2_additional_images_array
    current_urls << r2_url
    self.r2_additional_images = current_urls.to_json
  end

  def formatted_price
    "₹#{price}"
  end

  def formatted_selling_price
    "₹#{selling_price}"
  end

  def stock_status
    current_stock = total_batch_stock
    case current_stock
    when 0
      'Out of Stock'
    when 1..5
      'Low Stock'
    else
      'In Stock'
    end
  end

  def stock_status_class
    current_stock = total_batch_stock
    case current_stock
    when 0
      'text-danger'
    when 1..5
      'text-warning'
    else
      'text-success'
    end
  end

  # Stock Movement Tracking Methods
  def total_consumed
    stock_movements.consumptions.sum(:quantity).abs
  end

  def total_added
    stock_movements.additions.sum(:quantity)
  end

  def total_adjusted
    stock_movements.adjustments.sum(:quantity)
  end

  def out_of_stock?
    cached_total_batch_stock <= 0
  end

  def low_stock?
    # Use minimum_stock_alert if it exists, otherwise default threshold of 10
    threshold = respond_to?(:minimum_stock_alert) && minimum_stock_alert.present? ? minimum_stock_alert : 10
    stock_amount = cached_total_batch_stock
    stock_amount > 0 && stock_amount <= threshold
  end

  def stock_status_enhanced
    current_stock = total_batch_stock
    if current_stock <= 0
      'out_of_stock'
    elsif low_stock?
      'low_stock'
    else
      'in_stock'
    end
  end

  def stock_status_text_enhanced
    case stock_status_enhanced
    when 'out_of_stock'
      'Out of Stock'
    when 'low_stock'
      'Low Stock'
    when 'in_stock'
      'In Stock'
    else
      'Unknown'
    end
  end

  def minimum_stock_threshold
    # Use minimum_stock_alert if it exists, otherwise default threshold of 10
    respond_to?(:minimum_stock_alert) && minimum_stock_alert.present? ? minimum_stock_alert : 10
  end

  # Update stock with movement tracking
  def update_stock(quantity, reference_type, reference_id, notes = nil)
    return false unless quantity != 0

    current_stock = total_batch_stock
    movement_type = quantity > 0 ? 'added' : 'consumed'
    new_stock = current_stock + quantity

    # Prevent negative stock
    if new_stock < 0
      errors.add(:stock, "Insufficient stock. Available: #{current_stock}")
      return false
    end

    # Use transaction to ensure data consistency
    ActiveRecord::Base.transaction do
      # Create stock movement record
      stock_movements.create!(
        reference_type: reference_type,
        reference_id: reference_id,
        movement_type: movement_type,
        quantity: quantity,
        stock_before: current_stock,
        stock_after: new_stock,
        notes: notes
      )

      # Update product stock for backward compatibility
      update_column(:stock, new_stock)
    end

    true
  rescue ActiveRecord::RecordInvalid => e
    errors.add(:base, e.message)
    false
  end

  # Stock movement history
  def recent_stock_movements(limit = 10)
    stock_movements.recent.limit(limit)
  end

  def stock_movements_for_date_range(start_date, end_date)
    stock_movements.where(created_at: start_date..end_date).recent
  end

  # Stock summary
  def stock_summary
    {
      current_stock: total_batch_stock,
      total_consumed: total_consumed,
      total_added: total_added,
      total_adjusted: total_adjusted,
      stock_status: stock_status_enhanced,
      last_movement: stock_movements.recent.first&.created_at
    }
  end

  # Check if product can be delivered to a specific pincode
  def deliverable_to?(pincode)
    return false if delivery_rules.empty?

    # Validate pincode format first
    return false unless valid_pincode_format?(pincode)

    # Check if there's an 'everywhere' rule
    return true if delivery_rules.everywhere.exists?

    # Check pincode-specific rules
    pincode_rules = delivery_rules.pincode
    pincode_rules.any? do |rule|
      location_data = JSON.parse(rule.location_data || '[]')
      location_data.include?(pincode.to_s)
    end
  rescue JSON::ParserError
    false
  end

  # Get delivery information for a pincode
  def delivery_info_for(pincode)
    return { deliverable: false } unless deliverable_to?(pincode)

    # Find the most specific rule that matches
    rule = find_matching_rule(pincode)

    {
      deliverable: true,
      delivery_days: rule&.delivery_days || 7,
      delivery_charge: rule&.delivery_charge || 0
    }
  end

  # GST utility methods
  def calculate_final_price_with_gst
    return price unless gst_enabled? && gst_percentage.present?

    base_price = calculate_base_price
    gst_amount = calculate_gst_amount(base_price, gst_percentage)
    base_price + gst_amount
  end

  def calculate_base_price
    # If price includes GST, extract base price
    # If price excludes GST, use price as base
    return price unless gst_enabled? && gst_percentage.present?

    # Assuming price includes GST by default
    price / (1 + (gst_percentage / 100.0))
  end

  def gst_breakdown
    return {} unless gst_enabled? && gst_percentage.present?

    base_price = calculate_base_price
    total_gst = calculate_gst_amount(base_price, gst_percentage)

    {
      base_price: base_price.round(2),
      cgst_rate: cgst_percentage || (gst_percentage / 2.0),
      sgst_rate: sgst_percentage || (gst_percentage / 2.0),
      igst_rate: igst_percentage || gst_percentage,
      cgst_amount: cgst_amount || (total_gst / 2.0),
      sgst_amount: sgst_amount || (total_gst / 2.0),
      igst_amount: igst_amount || total_gst,
      total_gst_amount: total_gst.round(2),
      final_price: (base_price + total_gst).round(2)
    }
  end

  def effective_selling_price
    if gst_enabled?
      final_amount_with_gst.presence || calculate_final_price_with_gst
    else
      final_price_after_discount
    end
  end

  def display_gst_info
    return 'GST Not Applicable' unless gst_enabled?
    return 'GST Rate Not Set' unless gst_percentage.present?

    "GST #{gst_percentage}% (₹#{gst_amount&.round(2) || 0})"
  end

  private

  # Validate pincode format - must be exactly 6 digits
  def valid_pincode_format?(pincode)
    return false if pincode.blank?
    pincode.to_s.strip.match?(/\A\d{6}\z/)
  end

  def variants_required_when_multi_qty
    active_variants = product_variants.reject { |v| v.marked_for_destruction? }
    if active_variants.empty?
      errors.add(:base, "Add at least one variant when 'Product has multiple quantity options' is enabled")
    end
  end

  def sync_price_from_variants
    # Keep product.price in sync with default variant so all other code that
    # reads product.price continues to work (invoices, bookings, etc.)
    all_variants = product_variants.reject { |v| v.marked_for_destruction? }
    return if all_variants.empty?
    default_v = all_variants.find(&:is_default) || all_variants.min_by { |v| v.weight.to_f }
    self.price = default_v.selling_price if default_v&.selling_price.present?
  end

  def generate_sku
    # Generate SKU based on category and random number
    category_prefix = category&.name&.strip&.first(3)&.upcase || 'PRD'
    random_suffix = SecureRandom.hex(3).upcase
    self.sku = "#{category_prefix}#{random_suffix}"

    # Ensure uniqueness
    while Product.exists?(sku: self.sku)
      random_suffix = SecureRandom.hex(3).upcase
      self.sku = "#{category_prefix}#{random_suffix}"
    end
  end

  def set_default_status
    self.status ||= :draft
  end

  def discount_price_validation
    if discount_price.present? && price.present? && discount_price >= price
      errors.add(:discount_price, 'must be less than regular price')
    end
  end

  def discount_value_validation
    return unless discount_type.present? && discount_value.present?

    case discount_type
    when 'percentage'
      if discount_value > 100
        errors.add(:discount_value, 'percentage cannot be more than 100%')
      end
    when 'fixed'
      base_price = original_price || price
      if discount_value >= base_price
        errors.add(:discount_value, 'fixed discount cannot be more than or equal to the product price')
      end
    end
  end

  def calculate_discount_fields
    return unless discount_type.present? && discount_value.present?

    base_price = original_price || price

    # Calculate discount amount and final price
    case discount_type
    when 'percentage'
      self.discount_amount = (base_price * discount_value / 100).round(2)
    when 'fixed'
      self.discount_amount = discount_value
    end

    # Calculate final price after discount
    final_price = base_price - discount_amount

    # Update discount_price for backward compatibility
    self.discount_price = final_price

    # Set discounted flag
    self.is_discounted = discount_amount > 0
  end

  def calculate_discounted_price(base_price, type, value)
    case type
    when 'percentage'
      base_price - (base_price * value / 100)
    when 'fixed'
      base_price - value
    else
      base_price
    end
  end

  def find_matching_rule(pincode)
    # Try to find the most specific rule

    # First check for pincode-specific rules
    pincode_rules = delivery_rules.pincode
    matching_pincode_rule = pincode_rules.find do |rule|
      location_data = JSON.parse(rule.location_data || '[]')
      location_data.include?(pincode.to_s)
    end
    return matching_pincode_rule if matching_pincode_rule

    # Then check for 'everywhere' rules
    delivery_rules.everywhere.first
  end

  def process_delivery_rules_location_data
    delivery_rules.each do |rule|
      next if rule.everywhere? || rule.location_data.blank?

      # If location_data is a string (from form), convert to JSON array
      if rule.location_data.is_a?(String) && !rule.location_data.start_with?('[')
        locations = rule.location_data.split(',').map(&:strip).reject(&:blank?)
        rule.location_data = locations.to_json
      end
    end
  end

  def calculate_price_change_percentage
    return if yesterday_price.nil? || yesterday_price == 0

    current_price = today_price || price
    change = ((current_price - yesterday_price) / yesterday_price * 100).round(2)
    self.price_change_percentage = change
  end

  def update_price_history
    current_price = today_price || price
    history = get_price_history_array

    # Add current price with timestamp
    history << {
      date: Date.current.to_s,
      price: current_price,
      timestamp: Time.current.to_i
    }

    # Keep only last 30 days of history
    history = history.last(30)
    self.price_history = history.to_json
  end

  def occasional_dates_validation
    return unless is_occasional_product?

    if occasional_start_date.present? && occasional_end_date.present?
      if occasional_start_date >= occasional_end_date
        errors.add(:occasional_end_date, 'must be after the start date')
      end

      # Warn if dates are in the past
      if occasional_end_date < Time.current
        errors.add(:occasional_end_date, 'should not be in the past for new occasional products')
      end

      # Check for reasonable duration (not more than 1 year)
      if (occasional_end_date - occasional_start_date) > 1.year
        errors.add(:occasional_end_date, 'duration cannot be more than 1 year')
      end
    end
  end

  def gst_rates_validation
    return unless gst_enabled?

    # Validate GST percentage is set when enabled
    if gst_percentage.blank? || gst_percentage <= 0
      errors.add(:gst_percentage, 'must be specified when GST is enabled')
      return
    end

    # Validate CGST + SGST = Total GST (for intrastate transactions)
    if cgst_percentage.present? && sgst_percentage.present?
      total_intrastate = cgst_percentage + sgst_percentage
      if (total_intrastate - gst_percentage).abs > 0.01 # Allow for minor rounding differences
        errors.add(:base, "CGST (#{cgst_percentage}%) + SGST (#{sgst_percentage}%) must equal Total GST (#{gst_percentage}%)")
      end
    end

    # Validate IGST = Total GST (for interstate transactions)
    if igst_percentage.present?
      if (igst_percentage - gst_percentage).abs > 0.01 # Allow for minor rounding differences
        errors.add(:igst_percentage, "must equal Total GST rate (#{gst_percentage}%)")
      end
    end

    # Validate that at least one GST configuration is present
    # Allow simple GST (only gst_percentage) OR detailed GST (CGST/SGST or IGST)
    if gst_percentage.present? && gst_percentage > 0
      # Simple GST mode - gst_percentage is sufficient
      return
    elsif cgst_percentage.blank? && sgst_percentage.blank? && igst_percentage.blank?
      errors.add(:base, 'At least one GST configuration (GST percentage, CGST/SGST, or IGST) must be specified')
    end

    # Validate individual GST rates are reasonable
    if cgst_percentage.present? && (cgst_percentage < 0 || cgst_percentage > 25)
      errors.add(:cgst_percentage, 'must be between 0% and 25%')
    end

    if sgst_percentage.present? && (sgst_percentage < 0 || sgst_percentage > 25)
      errors.add(:sgst_percentage, 'must be between 0% and 25%')
    end

    if igst_percentage.present? && (igst_percentage < 0 || igst_percentage > 50)
      errors.add(:igst_percentage, 'must be between 0% and 50%')
    end

    # Validate GST amounts are consistent with percentages if present
    # Using reverse calculation (price inclusive of GST)
    if gst_amount.present? && price.present? && gst_percentage.present?
      # Reverse calculation: base_price = inclusive_price / (1 + gst_rate)
      base_price = price / (1 + (gst_percentage / 100.0))
      expected_gst_amount = price - base_price

      # Allow for small rounding differences (up to ₹1)
      if (gst_amount - expected_gst_amount).abs > 1.0
        errors.add(:gst_amount, "should be approximately ₹#{expected_gst_amount.round(2)} based on inclusive price and GST rate")
      end
    end
  end

  def calculate_gst_amount(base_price, rate)
    (base_price * rate) / 100.0
  end

  def create_initial_stock_movement
    stock_movements.create!(
      reference_type: 'adjustment',
      reference_id: nil,
      movement_type: 'added',
      quantity: stock,
      stock_before: 0,
      stock_after: stock,
      notes: 'Initial stock when product was created'
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to create initial stock movement for Product #{id}: #{e.message}"
  end

  def create_initial_stock_batch
    # Get or create a default vendor for initial stock
    default_vendor = get_or_create_default_vendor

    stock_batches.create!(
      vendor: default_vendor,
      quantity_purchased: stock,
      quantity_remaining: stock,
      purchase_price: buying_price || price || 0,
      selling_price: price,
      batch_date: Date.current,
      status: 'active'
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to create initial stock batch for Product #{id}: #{e.message}"
  end

  def update_stock_batch
    return unless saved_change_to_stock?

    # Get the old and new stock values from saved changes
    stock_changes = saved_change_to_stock
    old_stock = stock_changes[0]
    new_stock = stock_changes[1]


    # Store the stock difference
    stock_difference = new_stock - old_stock

    # Find the most recent batch
    latest_batch = stock_batches.by_fifo.last

    ActiveRecord::Base.transaction do
      if latest_batch && latest_batch.quantity_purchased == old_stock && stock_batches.count == 1
        # Update the initial batch if it's the only batch and matches original stock
        new_quantity = latest_batch.quantity_remaining + stock_difference


        if new_quantity > 0
          latest_batch.update!(
            quantity_purchased: new_stock,
            quantity_remaining: new_quantity,
            selling_price: price
          )
        else
          latest_batch.update!(status: 'exhausted', quantity_remaining: 0)
        end
      else
        # Create adjustment batch for stock changes
        adjustment_vendor = get_or_create_default_vendor

        if stock_difference > 0
          # Stock increase - create new batch
          stock_batches.create!(
            vendor: adjustment_vendor,
            quantity_purchased: stock_difference,
            quantity_remaining: stock_difference,
            purchase_price: buying_price || price || 0,
            selling_price: price,
            batch_date: Date.current,
            status: 'active'
          )
        elsif stock_difference < 0
          # Stock decrease - reduce from existing batches using FIFO
          reduce_stock_from_batches(stock_difference.abs)
        end
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to update stock batch for Product #{id}: #{e.message}"
  end

  def get_or_create_default_vendor
    Vendor.find_or_create_by(name: 'System Default') do |vendor|
      vendor.email = 'system@default.com'
      vendor.phone = '0000000000'
      vendor.address = 'System Generated'
      vendor.payment_type = 'Cash'
      vendor.status = true
    end
  end

  def reduce_stock_from_batches(quantity_to_reduce)
    remaining_to_reduce = quantity_to_reduce
    active_batches = stock_batches.active.by_fifo

    active_batches.each do |batch|
      break if remaining_to_reduce <= 0

      if batch.quantity_remaining >= remaining_to_reduce
        batch.update!(quantity_remaining: batch.quantity_remaining - remaining_to_reduce)
        remaining_to_reduce = 0
      else
        remaining_to_reduce -= batch.quantity_remaining
        batch.update!(quantity_remaining: 0, status: 'exhausted')
      end
    end
  end
end
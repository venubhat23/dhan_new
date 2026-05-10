module MobileApiCache
  extend ActiveSupport::Concern

  PRODUCT_V_KEY  = 'mobile_api/v/products'
  CATEGORY_V_KEY = 'mobile_api/v/categories'
  BANNER_V_KEY   = 'mobile_api/v/banners'

  PRODUCT_TTL   = 10.minutes
  CATEGORY_TTL  = 10.minutes
  BANNER_TTL    = 30.minutes
  FILTER_TTL    = 30.minutes
  PINCODE_TTL   = 24.hours

  # --- Version accessors ---

  def self.product_version
    Rails.cache.fetch(PRODUCT_V_KEY) { SecureRandom.hex(4) }
  end

  def self.category_version
    Rails.cache.fetch(CATEGORY_V_KEY) { SecureRandom.hex(4) }
  end

  def self.banner_version(location)
    Rails.cache.fetch("#{BANNER_V_KEY}/#{location}") { SecureRandom.hex(4) }
  end

  # --- Cache busters ---

  def self.bust_products!
    Rails.cache.write(PRODUCT_V_KEY, SecureRandom.hex(4))
    # Product changes affect category product counts too
    Rails.cache.write(CATEGORY_V_KEY, SecureRandom.hex(4))
  end

  def self.bust_categories!
    Rails.cache.write(CATEGORY_V_KEY, SecureRandom.hex(4))
  end

  def self.bust_banners!(location = nil)
    locations = location ? [location.to_s] : %w[home dashboard login sidebar]
    locations.each { |loc| Rails.cache.write("#{BANNER_V_KEY}/#{loc}", SecureRandom.hex(4)) }
  end

  # --- Cache key helpers ---

  def self.products_key(params_hash = {})
    stable = params_hash.sort.to_h.to_json
    "mobile_api/products/#{product_version}/#{Digest::MD5.hexdigest(stable)}"
  end

  def self.featured_products_key(limit)
    "mobile_api/featured/#{product_version}/limit_#{limit}"
  end

  def self.product_detail_key(id)
    "mobile_api/product/#{product_version}/#{id}"
  end

  def self.categories_key
    "mobile_api/categories/#{category_version}"
  end

  def self.banners_key(location)
    "mobile_api/banners/#{banner_version(location)}/#{location}"
  end

  def self.filters_key
    "mobile_api/filters/#{product_version}/#{category_version}"
  end

  def self.pincode_key(pincode)
    "mobile_api/pincode/#{pincode}"
  end
end

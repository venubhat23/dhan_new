class SystemSetting < ApplicationRecord
  validates :key, presence: true, uniqueness: true
  validates :value, presence: true
  validates :setting_type, presence: true

  # Business details validations
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :upi_id, format: { with: /\A[a-zA-Z0-9.\-_]+@[a-zA-Z0-9.\-_]+\z/, message: "must be a valid UPI ID" }, allow_blank: true

  # Class method to get a setting value by key
  def self.get_value(key)
    setting = find_by(key: key)
    setting&.value
  end

  # Class method to set a setting value by key
  def self.set_value(key, value, description: nil, setting_type: 'string')
    setting = find_or_initialize_by(key: key)
    setting.value = value
    setting.description = description if description
    setting.setting_type = setting_type
    setting.save!
    setting
  end

  # Get company expenses percentage as float
  def self.company_expenses_percentage
    value = get_value('company_expenses_percentage')
    value ? value.to_f : 2.0
  end

  # Set company expenses percentage
  def self.set_company_expenses_percentage(percentage)
    set_value(
      'company_expenses_percentage',
      percentage.to_s,
      description: 'Company expenses percentage that can be configured by admin',
      setting_type: 'percentage'
    )
  end

  # Get default pagination per page as integer
  def self.default_pagination_per_page
    Rails.cache.fetch('system_setting:pagination_per_page', expires_in: 10.minutes) do
      value = get_value('default_pagination_per_page')
      value ? value.to_i : 10
    end
  end

  # Set default pagination per page
  def self.set_default_pagination_per_page(per_page)
    Rails.cache.delete('system_setting:pagination_per_page')
    set_value(
      'default_pagination_per_page',
      per_page.to_s,
      description: 'Default number of records per page for all index pages',
      setting_type: 'integer'
    )
  end

  # Commission methods for new columns

  # Get default main agent commission as float
  def self.default_main_agent_commission
    setting = find_by(key: 'system_config')
    setting&.default_main_agent_commission || 0.0
  end

  # Get default affiliate commission as float
  def self.default_affiliate_commission
    setting = find_by(key: 'system_config')
    setting&.default_affiliate_commission || 0.0
  end

  # Get default ambassador commission as float
  def self.default_ambassador_commission
    setting = find_by(key: 'system_config')
    setting&.default_ambassador_commission || 0.0
  end

  # Get default company expenses as float
  def self.default_company_expenses
    setting = find_by(key: 'system_config')
    setting&.default_company_expenses || 0.0
  end

  # Update commission values
  def self.update_commission_settings(params)
    # Create a default setting if none exists
    setting = find_by(key: 'system_config') || create!(
      key: 'system_config',
      value: 'system configuration',
      setting_type: 'configuration',
      description: 'System configuration settings'
    )

    setting.update!(
      default_main_agent_commission: params[:default_main_agent_commission],
      default_affiliate_commission: params[:default_affiliate_commission],
      default_ambassador_commission: params[:default_ambassador_commission],
      default_company_expenses: params[:default_company_expenses]
    )
  end

  # Business Settings Methods

  # Singleton pattern to get the current business settings
  def self.business_settings
    find_by(key: 'business_config') || new
  end

  # Update business settings
  def self.update_business_settings(params)
    setting = find_or_create_by(key: 'business_config') do |s|
      s.value = 'business configuration'
      s.setting_type = 'configuration'
      s.description = 'Business configuration settings'
    end

    setting.update!(
      business_name: params[:business_name],
      address: params[:address],
      mobile: params[:mobile],
      email: params[:email],
      gstin: params[:gstin],
      pan_number: params[:pan_number],
      account_holder_name: params[:account_holder_name],
      bank_name: params[:bank_name],
      account_number: params[:account_number],
      ifsc_code: params[:ifsc_code],
      upi_id: params[:upi_id],
      terms_and_conditions: params[:terms_and_conditions]
    )

    setting
  end

  def formatted_terms_and_conditions
    return [] if terms_and_conditions.blank?
    terms_and_conditions.split("\n").map(&:strip).reject(&:empty?)
  end

  # Collect From Store Feature Methods

  # Check if collect from store feature is enabled
  def self.collect_from_store_enabled?
    setting = find_by(key: 'system_config')
    setting&.collect_from_store_enabled || false
  end

  # Enable or disable collect from store feature
  def self.set_collect_from_store_enabled(enabled)
    setting = find_or_create_by(key: 'system_config') do |s|
      s.value = 'system configuration'
      s.setting_type = 'configuration'
      s.description = 'System configuration settings'
    end

    setting.update!(collect_from_store_enabled: enabled)
    setting
  end

  # Update collect from store setting along with other settings
  def self.update_collect_from_store_settings(params)
    setting = find_or_create_by(key: 'system_config') do |s|
      s.value = 'system configuration'
      s.setting_type = 'configuration'
      s.description = 'System configuration settings'
    end

    setting.update!(collect_from_store_enabled: params[:collect_from_store_enabled] || false)
    setting
  end

  # Delivery Only At Shop Feature Methods

  # Check if delivery only at shop feature is enabled
  def self.delivery_only_at_shop_enabled?
    setting = find_by(key: 'system_config')
    setting&.delivery_only_at_shop || false
  end

  # Enable or disable delivery only at shop feature
  def self.set_delivery_only_at_shop_enabled(enabled)
    setting = find_or_create_by(key: 'system_config') do |s|
      s.value = 'system configuration'
      s.setting_type = 'configuration'
      s.description = 'System configuration settings'
    end

    setting.update!(delivery_only_at_shop: enabled)
    setting
  end

  # Get shop addresses as array
  def self.get_shop_addresses
    setting = find_by(key: 'system_config')
    addresses = setting&.shop_addresses
    return [] if addresses.blank?

    JSON.parse(addresses) rescue []
  end

  # Set shop addresses from array
  def self.set_shop_addresses(addresses_array)
    setting = find_or_create_by(key: 'system_config') do |s|
      s.value = 'system configuration'
      s.setting_type = 'configuration'
      s.description = 'System configuration settings'
    end

    setting.update!(shop_addresses: addresses_array.to_json)
    setting
  end

  # Update delivery only at shop settings with addresses
  def self.update_delivery_only_at_shop_settings(params)
    setting = find_or_create_by(key: 'system_config') do |s|
      s.value = 'system configuration'
      s.setting_type = 'configuration'
      s.description = 'System configuration settings'
    end

    # Update delivery only at shop setting
    delivery_enabled = params[:delivery_only_at_shop] == "1"

    # Process addresses if feature is enabled
    addresses = []
    if delivery_enabled && params[:shop_addresses].present?
      # Handle addresses submitted from form
      addresses = params[:shop_addresses].split("\n").map(&:strip).reject(&:empty?)
    end

    setting.update!(
      delivery_only_at_shop: delivery_enabled,
      shop_addresses: addresses.to_json
    )

    setting
  end

  # Get formatted shop addresses for display
  def formatted_shop_addresses
    return [] if shop_addresses.blank?
    JSON.parse(shop_addresses) rescue []
  end

  # Low Stock Alert Methods

  def self.low_stock_alert_enabled?
    setting = find_by(key: 'system_config')
    setting&.low_stock_alert_enabled || false
  end

  def self.low_stock_alert_threshold
    setting = find_by(key: 'system_config')
    setting&.low_stock_alert_threshold || 10
  end

  def self.low_stock_alert_email
    setting = find_by(key: 'system_config')
    setting&.low_stock_alert_email.presence || business_settings&.email
  end

  def self.update_low_stock_settings(params)
    setting = find_or_create_by(key: 'system_config') do |s|
      s.value = 'system configuration'
      s.setting_type = 'configuration'
      s.description = 'System configuration settings'
    end
    setting.update!(
      low_stock_alert_enabled:   params[:low_stock_alert_enabled] == '1',
      low_stock_alert_threshold: params[:low_stock_alert_threshold].to_i,
      low_stock_alert_email:     params[:low_stock_alert_email]
    )
    setting
  end
end

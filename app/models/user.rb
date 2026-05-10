class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Override Devise's authentication to support mobile number login
  attr_writer :login

  def login
    @login || self.email
  end

  def self.find_for_database_authentication(warden_conditions)
    conditions = warden_conditions.dup
    if login = conditions.delete(:login)
      # Try email first
      user = where(conditions.to_hash).where(["lower(email) = :value", { :value => login.downcase }]).first

      # If not found by email, try mobile number with flexible formatting
      unless user
        formatted_mobile = format_mobile_number(login)
        if formatted_mobile
          # Try multiple mobile format variations
          user = where(conditions.to_hash).where(mobile: formatted_mobile).first ||
                 where(conditions.to_hash).where(mobile: "+91#{formatted_mobile}").first ||
                 where(conditions.to_hash).where(mobile: "+91 #{formatted_mobile}").first ||
                 where(conditions.to_hash).where(mobile: "#{formatted_mobile[0..4]} #{formatted_mobile[5..9]}").first ||
                 where(conditions.to_hash).where(mobile: "+91 #{formatted_mobile[0..4]} #{formatted_mobile[5..9]}").first ||
                 where(conditions.to_hash).where("REPLACE(REPLACE(mobile, ' ', ''), '+91', '') = ?", formatted_mobile).first
        else
          # If format_mobile_number returns nil, try direct mobile search as fallback
          user = where(conditions.to_hash).where(mobile: login).first
        end
      end

      user
    else
      if conditions.has_key?(:email)
        where(conditions.to_hash).first
      else
        where(conditions.to_hash).first
      end
    end
  end
  include PgSearch::Model

  # Associations
  belongs_to :role, optional: true
  belongs_to :user_role, optional: true
  belongs_to :authenticatable, polymorphic: true, optional: true
  has_one :franchise, dependent: :destroy

  # Store associations
  belongs_to :assigned_store, class_name: 'Store', foreign_key: 'assigned_store_id', optional: true
  has_one :managed_store, class_name: 'Store', foreign_key: 'store_admin_user_id'
  has_many_attached :profile_images
  has_many_attached :documents
  has_many :uploaded_documents, as: :documentable, class_name: 'Document', dependent: :destroy

  # Validations
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :mobile, presence: true, uniqueness: true
  validates :user_type, presence: true, inclusion: { in: ['admin', 'agent', 'sub_agent', 'customer', 'franchise', 'affiliate', 'delivery_person', 'store_admin'] }
  # Note: role validation can be added later when roles are set up

  # Enums
  enum :user_type, { admin: 'admin', agent: 'agent', sub_agent: 'sub_agent', customer: 'customer', franchise: 'franchise', affiliate: 'affiliate', delivery_person: 'delivery_person', store_admin: 'store_admin' }

  # Callbacks
  after_update :role_changed_callback

  # Scopes
  scope :active, -> { where(status: true) }
  scope :inactive, -> { where(status: false) }
  scope :by_type, ->(type) { where(user_type: type) }

  # Search
  pg_search_scope :search_users,
    against: [:first_name, :last_name, :email, :mobile, :pan_number],
    using: {
      tsearch: { prefix: true, any_word: true }
    }

  # Instance methods
  def full_name
    "#{first_name} #{last_name}".strip
  end

  def active?
    status
  end

  # Role-based permission methods
  def role_name
    role&.name
  end

  def role_display_name
    role&.display_name || 'No Role Assigned'
  end

  def has_role?(role_name)
    return false unless role
    role.name == role_name.to_s
  end

  def has_permission?(module_name, action_type)
    return false unless role

    # Get user abilities
    role.permissions.pluck(:module_name, :action_type).include?([module_name.to_s, action_type.to_s])
  end

  def can_access_module?(module_name)
    return false unless role
    role.permissions.exists?(module_name: module_name.to_s)
  end

  def accessible_modules
    return [] unless role
    role.permissions.distinct.pluck(:module_name)
  end

  def module_permissions(module_name)
    return [] unless role
    role.permissions.where(module_name: module_name.to_s).pluck(:action_type)
  end

  # Sidebar permissions methods
  def sidebar_permissions_array
    return [] if sidebar_permissions.blank?

    if sidebar_permissions.is_a?(String)
      JSON.parse(sidebar_permissions)
    elsif sidebar_permissions.is_a?(Array)
      sidebar_permissions
    else
      []
    end
  rescue JSON::ParserError
    []
  end


  # Sidebar permissions methods
  def sidebar_permissions_array
    return [] if sidebar_permissions.blank?
    begin
      parsed = if sidebar_permissions.is_a?(String)
        JSON.parse(sidebar_permissions)
      elsif sidebar_permissions.is_a?(Array)
        sidebar_permissions
      else
        []
      end
      # If it's the new CRUD format (hash), extract the keys
      if parsed.is_a?(Hash)
        parsed.keys
      else
        # Old format (array)
        parsed
      end
    rescue JSON::ParserError
      []
    end
  end

  # Get permissions in CRUD format (for compatibility)
  def sidebar_permissions_hash
    return {} if sidebar_permissions.blank?
    begin
      parsed = if sidebar_permissions.is_a?(String)
        JSON.parse(sidebar_permissions)
      else
        sidebar_permissions
      end
      # If it's already a hash (CRUD format), return it
      if parsed.is_a?(Hash)
        parsed
      else
        # Convert old array format to CRUD format (view-only)
        result = {}
        parsed.each do |permission|
          result[permission] = { 'view' => true, 'create' => false, 'edit' => false, 'delete' => false }
        end
        result
      end
    rescue JSON::ParserError
      {}
    end
  end

  def has_sidebar_permission?(permission_key)
    # Super admin (admin@dhanvantri-naturals.com) has access to everything
    return true if email == 'admin@dhanvantri-naturals.com'

    # Only give full access to users with 'super_admin' role, not all admin user types
    return true if role_name == 'super_admin' || (role.present? && role.name == 'super_admin')

    # Check CRUD permissions - user needs 'view' permission for sidebar access
    permissions = sidebar_permissions_hash
    permission_data = permissions[permission_key.to_s]
    return false if permission_data.nil?

    # Check if user has view permission for this module
    permission_data['view'] == true
  end

  def update_sidebar_permissions(permissions)
    self.update(sidebar_permissions: permissions.to_json)
  end

  # Legacy support for existing code that checks user_type
  def admin?
    user_type == 'admin'
  end

  def agent?
    user_type == 'agent'
  end

  def customer?
    user_type == 'customer'
  end

  def franchise?
    user_type == 'franchise'
  end

  def affiliate?
    user_type == 'affiliate'
  end

  def delivery_person?
    user_type == 'delivery_person'
  end

  def store_admin?
    user_type == 'store_admin'
  end

  def super_admin?
    has_role?('super_admin')
  end

  # Store permission methods
  def store_permissions_hash
    return {} if store_permissions.blank?
    parsed = store_permissions.is_a?(String) ? JSON.parse(store_permissions) : store_permissions
    parsed.is_a?(Hash) ? parsed : {}
  rescue JSON::ParserError
    {}
  end

  def can_manage_inventory?
    store_permissions_hash['can_manage_inventory'] == true
  end

  def can_create_bookings?
    store_permissions_hash.fetch('can_create_bookings', true) != false
  end

  def can_view_reports?
    store_permissions_hash.fetch('can_view_reports', true) != false
  end

  def can_request_transfers?
    store_permissions_hash['can_request_transfers'] == true
  end

  def primary_store
    assigned_store || managed_store
  end

  def update_store_access_log!
    update_column(:last_store_access, Time.current)
  end

  # Clear abilities cache when role changes
  def clear_abilities_cache
    Rails.cache.delete("user_#{id}_abilities")
  end

  private

  # Clear cache when role changes
  def role_changed_callback
    clear_abilities_cache if role_id_changed?
  end

  # Mobile number formatting helper (flexible for various formats)
  def self.format_mobile_number(mobile)
    return nil if mobile.blank?
    # Remove all non-digit characters
    clean_mobile = mobile.to_s.gsub(/\D/, '')

    # Handle different mobile number formats
    if clean_mobile.length == 10
      # Standard 10-digit format, accept all (for testing purposes)
      return clean_mobile
    elsif clean_mobile.length == 12 && clean_mobile.start_with?('91')
      # 12 digits starting with 91
      return clean_mobile[2..-1]
    elsif clean_mobile.length == 13 && clean_mobile.start_with?('+91')
      # +91 prefix with spaces removed
      return clean_mobile[3..-1]
    else
      return nil
    end
  end
end

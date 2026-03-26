class Customer < ApplicationRecord
  include PgSearch::Model

  # Associations
  # Note: family_members, policies, corporate_members, and documents tables don't exist
  # has_many :family_members, dependent: :destroy
  # has_many :policies, dependent: :destroy
  # has_many :corporate_members, dependent: :destroy
  # has_many :documents, class_name: 'CustomerDocument', dependent: :destroy
  # has_many :uploaded_documents, as: :documentable, class_name: 'Document', dependent: :destroy
  has_one_attached :profile_image
  has_one_attached :personal_image
  has_one_attached :house_image
  belongs_to :affiliate, class_name: 'SubAgent', foreign_key: 'sub_agent_id', optional: true

  # Product associations (investment/loan features removed for ecommerce focus)

  # E-commerce associations
  has_many :bookings, dependent: :destroy
  has_many :orders, dependent: :destroy
  has_many :booking_schedules, dependent: :destroy
  has_many :invoices, dependent: :destroy
  has_many :milk_subscriptions, dependent: :destroy
  has_many :milk_delivery_tasks, dependent: :destroy
  has_many :customer_addresses, dependent: :destroy
  has_many :wishlists, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :pending_amounts, dependent: :destroy
  has_many :client_requests, dependent: :destroy

  # Referral associations
  has_many :referrals, foreign_key: 'referring_customer_id', dependent: :destroy
  has_many :received_referrals, class_name: 'Referral', foreign_key: 'customer_id', dependent: :destroy

  # Nested attributes - commented out as tables don't exist
  # accepts_nested_attributes_for :family_members, allow_destroy: true, reject_if: :all_blank
  # accepts_nested_attributes_for :corporate_members, allow_destroy: true, reject_if: :all_blank
  # accepts_nested_attributes_for :documents, allow_destroy: true, reject_if: :all_blank
  # accepts_nested_attributes_for :uploaded_documents, allow_destroy: true, reject_if: :all_blank

  # Password support for customer login
  has_secure_password validations: false

  # Virtual attribute for status if column doesn't exist yet
  attr_accessor :status unless column_names.include?('status')

  # Validate password presence and confirmation only when password is set
  validates :password, presence: true, length: { minimum: 6 }, if: :password_required?
  validates :password_confirmation, presence: true, if: :password_required?
  validates_confirmation_of :password, if: :password_required?

  # Store password in password_digest if column exists, otherwise in auto_generated_password
  before_save :handle_password_storage, if: :password_required?

  def password_required?
    password.present?
  end

  def authenticate(password)
    if respond_to?(:password_digest) && password_digest.present?
      # Use bcrypt if password_digest column exists
      BCrypt::Password.new(password_digest).is_password?(password)
    elsif auto_generated_password.present?
      # Fallback to plain text comparison
      auto_generated_password == password
    else
      false
    end
  end

  # Validations
  validates :first_name, presence: true
  validates :email, uniqueness: { allow_blank: true }, format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }
  validates :mobile, presence: true, uniqueness: true
  validate :valid_mobile_format
  validates :whatsapp_number, format: { with: /\A[+]?[\d\s\-\(\)]{7,15}\z/ }, allow_blank: true
  validates :longitude, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }, allow_blank: true
  validates :latitude, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }, allow_blank: true

  # Set default values
  after_initialize :set_defaults
  # before_create :generate_lead_id_if_missing  # Commented out until lead_id column exists

  def set_defaults
    # No default status field - column doesn't exist in customers table
  end

  # Optional validations - removed validations for non-existent columns

  # Scopes
  scope :active, -> { column_names.include?('status') ? where(status: true) : all }
  scope :inactive, -> { column_names.include?('status') ? where(status: false) : none }

  # Callbacks
  before_validation :normalize_blank_values, :normalize_mobile_numbers
  before_save :calculate_age

  # Search
  pg_search_scope :search_customers,
    against: [:first_name, :last_name, :email, :mobile],
    using: {
      tsearch: { prefix: true, any_word: true }
    }

  # Instance methods
  def full_name
    "#{first_name} #{middle_name} #{last_name}".strip.squeeze(' ')
  end

  def display_name
    full_name
  end

  def active?
    return status if respond_to?(:status) && !status.nil?
    true # Default to active if no status column
  end

  def has_location?
    latitude.present? && longitude.present?
  end

  def whatsapp_same_as_mobile?
    whatsapp_number == mobile
  end


  def self.generate_random_password(length = 10)
    charset = Array('A'..'Z') + Array('a'..'z') + Array('0'..'9') + ['@', '#', '$', '%', '&']
    password = Array.new(length) { charset.sample }.join

    # Ensure it has at least one uppercase, one lowercase, one digit, and one special char
    password[0] = Array('A'..'Z').sample
    password[1] = Array('a'..'z').sample
    password[2] = Array('0'..'9').sample
    password[3] = ['@', '#', '$', '%', '&'].sample

    # Shuffle to randomize position
    password.chars.shuffle.join
  end


  # Cache busting callback
  after_update :bust_cache

  def calculate_age
    # Skip age calculation since birth_date and age columns don't exist
    return
  end

  def formatted_age
    # Return empty string since birth_date column doesn't exist
    ""
  end

  # Simple Password Reset Methods
  def generate_password_reset_token!
    loop do
      token = SecureRandom.hex(32)
      unless Customer.exists?(password_reset_token: token)
        update_columns(
          password_reset_token: token,
          password_reset_sent_at: Time.current
        )
        break
      end
    end
  end

  def password_reset_expired?
    return true unless password_reset_sent_at
    password_reset_sent_at < 24.hours.ago
  end

  def clear_password_reset_token!
    update_columns(
      password_reset_token: nil,
      password_reset_sent_at: nil
    )
  end

  def self.find_by_password_reset_token(token)
    return nil if token.blank?

    # Handle URL encoding from email clients (= becomes %3D)
    decoded_token = CGI.unescape(token)

    # Try original token first
    customer = where(password_reset_token: token)
               .where('password_reset_sent_at > ?', 24.hours.ago)
               .first

    return customer if customer

    # Try decoded token
    where(password_reset_token: decoded_token)
      .where('password_reset_sent_at > ?', 24.hours.ago)
      .first
  end

  # Override password_reset_token getter to return raw database value
  def password_reset_token
    # Get raw value directly from database to bypass Rails signed token mechanism
    result = self.class.connection.execute(
      "SELECT password_reset_token FROM customers WHERE id = #{self.id}"
    ).first
    result ? result['password_reset_token'] : nil
  end

  private

  def handle_password_storage
    if respond_to?(:password_digest)
      # Store encrypted password in password_digest column
      self.password_digest = BCrypt::Password.create(password)
    else
      # Fallback to storing in auto_generated_password field
      self.auto_generated_password = password
    end
  end

  def store_password_in_auto_generated_field
    if password.present?
      self.auto_generated_password = password
    end
  end

  def bust_cache
    Rails.cache.delete("customer_#{id}_full_name")
    Rails.cache.delete("customer_#{id}_display_name")
  end

  def normalize_blank_values
    # Convert empty strings to nil to prevent uniqueness validation issues
    self.mobile = nil if mobile.blank?
    self.email = nil if email.blank?
    # Removed pan_no and gst_no as these columns don't exist
  end

  def normalize_mobile_numbers
    # Normalize mobile number
    if mobile.present?
      self.mobile = normalize_indian_mobile(mobile)
    end

    # Normalize WhatsApp number
    if whatsapp_number.present?
      self.whatsapp_number = normalize_indian_mobile(whatsapp_number)
    end
  end

  def normalize_indian_mobile(number)
    return number if number.blank?

    # Remove all non-digit characters
    clean_number = number.gsub(/\D/, '')

    # Handle different input formats:
    # +91 91909 39390 -> 919190939390 -> 9190939390
    # 91909 39390 -> 919190939390 -> 9190939390
    # 9190939390 -> 9190939390 (already correct)

    if clean_number.length == 12 && clean_number.start_with?('91')
      # Remove country code +91
      clean_number = clean_number[2..-1]
    elsif clean_number.length == 11 && clean_number.start_with?('91')
      # Remove country code 91 without +
      clean_number = clean_number[2..-1]
    end

    clean_number
  end

  def valid_mobile_format
    return if mobile.blank?

    unless mobile.match?(/\A[6-9]\d{9}\z/)
      errors.add(:mobile, "must be exactly 10 digits starting with 6, 7, 8, or 9")
    end
  end

  # Generate lead_id if not already present (for direct customer creation)
  # def generate_lead_id_if_missing
  #   return if lead_id.present?
  #
  #   loop do
  #     self.lead_id = "CUST-#{Date.current.strftime('%Y%m%d')}-#{rand(1000..9999)}"
  #     break unless Customer.exists?(lead_id: self.lead_id) || Lead.exists?(lead_id: self.lead_id)
  #   end
  # end

end

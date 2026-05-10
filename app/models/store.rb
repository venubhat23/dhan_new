class Store < ApplicationRecord
  # Constants
  MAX_STORES_LIMIT = 10

  # Associations
  has_many :bookings, dependent: :restrict_with_error
  belongs_to :store_admin_user, class_name: 'User', foreign_key: 'store_admin_user_id', optional: true
  has_many :store_staff, class_name: 'User', foreign_key: 'assigned_store_id', dependent: :nullify
  has_many :expenses, dependent: :destroy
  has_many :stock_batches, foreign_key: :store_id, dependent: :nullify
  has_many :stock_transfers_received, class_name: 'StockTransfer', foreign_key: :to_store_id, dependent: :destroy
  has_many :stock_transfers_sent, class_name: 'StockTransfer', foreign_key: :from_store_id, dependent: :destroy

  # Virtual attributes for store creation form
  attr_accessor :admin_username, :admin_email, :admin_password, :admin_first_name, :admin_last_name, :admin_mobile
  attr_accessor :create_admin_user

  before_validation :normalize_contact_mobile

  # Validations
  validates :name, presence: true, uniqueness: true, length: { maximum: 100 }
  validates :address, presence: true, length: { maximum: 500 }
  validates :city, presence: true, length: { maximum: 50 }
  validates :state, presence: true, length: { maximum: 50 }
  validates :pincode, presence: true, format: { with: /\A\d{6}\z/, message: "should be 6 digits" }
  validates :contact_mobile, presence: true, format: { with: /\A[7-9]\d{9}\z/, message: "should be a valid 10-digit Indian mobile number starting with 7, 8, or 9" }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :contact_person, presence: true, length: { maximum: 100 }
  validates :description, length: { maximum: 1000 }, allow_blank: true

  # Custom validation for maximum stores limit
  validate :check_maximum_stores_limit, on: :create
  validate :validate_admin_details, if: :create_admin_user

  after_create :create_store_admin_user!, if: :create_admin_user

  # Scopes
  scope :active, -> { where(status: true) }
  scope :inactive, -> { where(status: false) }
  scope :by_display_order, -> { order(:name) }

  # Class methods
  def self.available_for_collection
    active.by_display_order
  end

  def self.can_add_more_stores?
    Store.count < MAX_STORES_LIMIT
  end

  def self.remaining_store_slots
    MAX_STORES_LIMIT - Store.count
  end

  # Instance methods
  def display_name
    "#{name} - #{city}"
  end

  def full_address
    [address, city, state, pincode].compact.join(', ')
  end

  def contact_info
    info = [contact_person, contact_mobile]
    info << email if email.present?
    info.join(' | ')
  end

  def can_be_deleted?
    bookings.count == 0
  end

  def has_store_admin?
    store_admin_user.present?
  end

  def daily_sales_summary(date = Date.current)
    bookings.where(created_at: date.beginning_of_day..date.end_of_day)
            .where.not(status: ['cancelled', 'returned'])
            .sum(:total_amount)
  end

  def store_inventory_summary
    batches = stock_batches.where(status: 'active').where('quantity_remaining > 0')
    products_with_stock = batches.select(:product_id).distinct.count
    total_value = batches.sum('quantity_remaining * selling_price')
    threshold = auto_transfer_threshold || 10
    low_stock = batches.group(:product_id)
                       .having('SUM(quantity_remaining) <= ?', threshold)
                       .count.size
    {
      total_products: products_with_stock,
      total_stock_value: total_value.to_f.round(2),
      low_stock_count: low_stock,
      pending_incoming_transfers: stock_transfers_received.where(status: 'pending').count,
      pending_outgoing_transfers: stock_transfers_sent.where(status: 'pending').count,
      recent_bookings_count: bookings.where(created_at: 1.week.ago..Time.current).count
    }
  end

  def low_stock_products(threshold = nil)
    threshold ||= auto_transfer_threshold || 10
    product_ids = stock_batches.where(status: 'active')
                               .group(:product_id)
                               .having('SUM(quantity_remaining) <= ?', threshold)
                               .pluck(:product_id)
    Product.where(id: product_ids)
  end

  def store_products_with_inventory
    product_ids = stock_batches.where(status: 'active')
                               .where('quantity_remaining > 0')
                               .pluck(:product_id).uniq
    Product.where(id: product_ids).active
  end

  def available_stock_for(product_id)
    stock_batches.where(product_id: product_id, status: 'active')
                 .sum(:quantity_remaining)
  end

  def self.main_inventory
    find_by(is_main_inventory: true)
  end

  def create_store_admin_user!
    sidebar_permissions = {
      'dashboard' => { 'view' => true },
      'bookings' => { 'view' => true, 'create' => true, 'update' => true },
      'expenses' => { 'view' => true, 'create' => true, 'update' => true, 'delete' => true },
      'inventory' => { 'view' => true, 'create' => true, 'update' => true },
      'stock_transfers' => { 'view' => true, 'create' => true }
    }

    user = User.create!(
      first_name: admin_first_name,
      last_name: admin_last_name,
      email: admin_email,
      mobile: admin_mobile,
      password: admin_password,
      password_confirmation: admin_password,
      user_type: 'store_admin',
      assigned_store_id: id,
      sidebar_permissions: sidebar_permissions.to_json,
      store_permissions: {
        'can_manage_inventory' => true,
        'can_create_bookings' => true,
        'can_view_reports' => true,
        'can_request_transfers' => true
      }.to_json,
      status: true,
      is_active: true,
      is_verified: true
    )

    update!(store_admin_user: user, admin_plain_password: admin_password)
    user
  end

  private

  def normalize_contact_mobile
    return if contact_mobile.blank?
    # Strip +91, 0, spaces, dashes, parentheses — keep last 10 digits
    digits = contact_mobile.to_s.gsub(/\D/, '')
    digits = digits.last(10) if digits.length > 10
    self.contact_mobile = digits
  end

  def validate_admin_details
    return unless create_admin_user
    errors.add(:admin_first_name, "can't be blank") if admin_first_name.blank?
    errors.add(:admin_last_name, "can't be blank") if admin_last_name.blank?
    errors.add(:admin_email, "can't be blank") if admin_email.blank?
    errors.add(:admin_mobile, "can't be blank") if admin_mobile.blank?
    errors.add(:admin_password, "can't be blank") if admin_password.blank?
    errors.add(:admin_password, "must be at least 6 characters") if admin_password.present? && admin_password.length < 6
    if admin_email.present? && User.exists?(email: admin_email)
      errors.add(:admin_email, "already exists")
    end
    if admin_mobile.present? && User.exists?(mobile: admin_mobile)
      errors.add(:admin_mobile, "already exists")
    end
  end

  def check_maximum_stores_limit
    if Store.count >= MAX_STORES_LIMIT
      errors.add(:base, "Maximum #{MAX_STORES_LIMIT} stores allowed. Cannot add more stores.")
    end
  end
end

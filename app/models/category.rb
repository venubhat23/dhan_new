class Category < ApplicationRecord
  has_many :products, dependent: :destroy

  has_one_attached :image

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :display_order, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Store image URL as backup when image is attached
  after_commit :backup_image_url, if: :saved_change_to_id?
  after_commit :bust_mobile_api_cache

  def bust_mobile_api_cache
    MobileApiCache.bust_categories!
  end

  scope :active, -> { where(status: true) }
  scope :inactive, -> { where(status: false) }
  scope :ordered, -> { order(:display_order, :name) }

  before_validation :set_default_display_order, if: :new_record?

  def active?
    status?
  end

  def inactive?
    !status?
  end

  def products_count
    products.count
  end

  def self.for_select
    ordered.pluck(:name, :id)
  end

  def display_image_url
    if image.attached?
      Rails.application.routes.url_helpers.rails_blob_url(image, only_path: true)
    else
      # Return a default category image URL
      "/assets/category-placeholder.png"
    end
  end

  def has_image?
    image.attached?
  end

  private

  def set_default_display_order
    max_order = Category.maximum(:display_order) || 0
    self.display_order ||= max_order + 1
  end

  def backup_image_url
    if image.attached?
      update_column(:image_backup_url, display_image_url)
    end
  rescue => e
    Rails.logger.error "Failed to backup image URL for category #{id}: #{e.message}"
  end
end
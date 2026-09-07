class StoreAdmin::ApplicationController < ApplicationController
  include StoreAdmin::SidebarPermissions

  protect_from_forgery with: :exception
  skip_load_and_authorize_resource if respond_to?(:skip_load_and_authorize_resource)
  before_action :authenticate_user!
  before_action :ensure_store_admin_access
  before_action :set_current_store
  layout 'store_admin'

  protected

  def ensure_store_admin_access
    unless current_user&.store_admin? || current_user&.super_admin? || current_user&.admin?
      redirect_to root_path, alert: 'Access denied. Store admin privileges required.'
    end
  end

  def set_current_store
    @current_store = current_user.primary_store
    unless @current_store
      redirect_to root_path, alert: 'No store assigned. Please contact administrator.'
    end
  end

  # before_action helper: require a store permission flag (mirrors the vendors
  # controller's ensure_can_manage_inventory!).
  def require_permission!(flag, redirect: nil, message: 'You do not have permission to do that.')
    return if privileged_store_user?
    return if current_user&.public_send(flag)

    redirect_to(redirect || store_admin_root_path, alert: message)
  end

  # ---- store-scoped finders shared across the store_admin controllers --------

  # All bookings — kept identical to Admin::BookingsController's unscoped
  # Booking.all so /store_admin/bookings matches /admin/bookings exactly.
  def store_bookings
    Booking.all
  end

  # All customers — kept identical to Admin::CustomersController's unscoped
  # Customer.all so /store_admin/customers matches /admin/customers exactly.
  def store_customers
    Customer.all
  end

  # Products this store stocks or has sold: an active stock batch here, a
  # store_inventories row here, or a line on one of this store's bookings.
  def store_products
    @store_products ||= begin
      product_ids  = @current_store.stock_batches.where(status: 'active').pluck(:product_id)
      product_ids |= @current_store.store_inventories.pluck(:product_id)
      product_ids |= BookingItem.where(booking_id: store_bookings.select(:id)).pluck(:product_id)
      Product.where(id: product_ids.compact.uniq)
    end
  end

  # All invoices — kept identical to Admin::InvoicesController's unscoped
  # Invoice.all so /store_admin/invoices matches /admin/invoices exactly.
  def store_invoices
    Invoice.all
  end

end

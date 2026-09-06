class StoreAdmin::ApplicationController < ApplicationController
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

  # Admins / super admins bypass the granular store-role flags.
  def privileged_store_user?
    current_user&.admin? || current_user&.super_admin?
  end

  # before_action helper: require a store permission flag (mirrors the vendors
  # controller's ensure_can_manage_inventory!).
  def require_permission!(flag, redirect: nil, message: 'You do not have permission to do that.')
    return if privileged_store_user?
    return if current_user&.public_send(flag)

    redirect_to(redirect || store_admin_root_path, alert: message)
  end

  # ---- store-scoped finders shared across the store_admin controllers --------

  def store_bookings
    @current_store.bookings
  end

  # Customers who have a booking at this store. `set_customer` in the customers
  # controller additionally tolerates just-created customers with no bookings yet.
  def store_customers
    Customer.where(id: @current_store.bookings.select(:customer_id))
  end

  # Products this store stocks or has sold: an active stock batch here, a
  # store_inventories row here, or a line on one of this store's bookings.
  def store_products
    @store_products ||= begin
      product_ids  = @current_store.stock_batches.where(status: 'active').pluck(:product_id)
      product_ids |= @current_store.store_inventories.pluck(:product_id)
      product_ids |= BookingItem.where(booking_id: @current_store.bookings.select(:id)).pluck(:product_id)
      Product.where(id: product_ids.compact.uniq)
    end
  end

  # Invoices generated from bookings placed at this store (linked by invoice_number).
  def store_invoice_numbers
    @current_store.bookings.where.not(invoice_number: [nil, '']).select(:invoice_number)
  end

  def store_invoices
    Invoice.where(invoice_number: store_invoice_numbers)
  end

  def store_admin_sidebar_permissions
    return @store_admin_permissions if defined?(@store_admin_permissions)
    @store_admin_permissions = {
      'dashboard'       => true,
      'bookings'        => privileged_store_user? || current_user.can_create_bookings?,
      'customers'       => true,
      'products'        => true,
      'product_summary' => privileged_store_user? || current_user.can_manage_inventory?,
      'invoices'        => true,
      'expenses'        => true
    }
  end

  helper_method :store_admin_sidebar_permissions
end

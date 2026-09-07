# The store_admin layout/sidebar (layouts/store_admin.html.erb,
# layouts/_store_admin_sidebar.html.erb) calls the `store_admin_sidebar_permissions`
# helper. Most StoreAdmin::* controllers get it for free via StoreAdmin::ApplicationController,
# but StoreAdmin::VendorsController and StoreAdmin::VendorPurchasesController inherit
# from Admin::VendorsController / Admin::VendorPurchasesController instead (to reuse
# those controllers' actions), which skips that ancestor entirely — rendering the
# store_admin layout there raised NameError. Both include this concern to fill the gap.
module StoreAdmin::SidebarPermissions
  extend ActiveSupport::Concern

  included do
    helper_method :store_admin_sidebar_permissions
  end

  private

  # Admins / super admins bypass the granular store-role flags.
  def privileged_store_user?
    current_user&.admin? || current_user&.super_admin?
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
end

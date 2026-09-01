# Store-login version of the admin Vendor Purchases screen. Reuses
# Admin::VendorPurchasesController's actions and the app/views/admin/vendor_purchases
# templates verbatim; only the access gate, layout and redirect namespace differ.
#
# Stock still lands centrally (StockBatch with store_id nil) exactly like the admin
# flow — the store transfers it in afterwards via Stock Transfers.
class StoreAdmin::VendorPurchasesController < Admin::VendorPurchasesController
  skip_before_action :ensure_admin
  before_action :ensure_store_admin_access
  before_action :ensure_can_manage_inventory!
  before_action :set_current_store
  layout 'store_admin'

  private

  def resource_area = :store_admin

  def ensure_store_admin_access
    unless current_user&.store_admin? || current_user&.super_admin? || current_user&.admin?
      redirect_to root_path, alert: 'Access denied. Store admin privileges required.'
    end
  end

  def ensure_can_manage_inventory!
    return if current_user&.admin? || current_user&.super_admin?

    unless current_user&.can_manage_inventory?
      redirect_to store_admin_root_path, alert: 'You do not have permission to manage vendor purchases.'
    end
  end

  def set_current_store
    @current_store = current_user.primary_store
  end
end

# Namespace-aware path helpers so the admin Vendor / Vendor Purchase views can be
# rendered unchanged under both /admin (Admin::*) and the store login (StoreAdmin::*).
#
# `vendor_area` resolves to :admin or :store_admin from the controller rendering the
# view, and every vn_* helper below builds the matching route.
module VendorAreaHelper
  def vendor_area
    @vendor_area ||=
      controller.class.name.start_with?('StoreAdmin::') ? :store_admin : :admin
  end

  # Used by `form_with model: vendor_area_for(record)` in the shared forms.
  def vendor_area_for(record)
    [vendor_area, record]
  end

  # ---- Vendors ----
  def vn_vendors_path(*args)             = polymorphic_path([vendor_area, :vendors], *args)
  def vn_vendor_path(vendor, *args)      = polymorphic_path([vendor_area, vendor], *args)
  def vn_new_vendor_path(*args)          = new_polymorphic_path([vendor_area, :vendor], *args)
  def vn_edit_vendor_path(vendor, *args) = edit_polymorphic_path([vendor_area, vendor], *args)
  def vn_toggle_status_vendor_path(vendor, *args)
    public_send("toggle_status_#{vendor_area}_vendor_path", vendor, *args)
  end

  # ---- Vendor Purchases ----
  def vn_vendor_purchases_path(*args)         = polymorphic_path([vendor_area, :vendor_purchases], *args)
  def vn_vendor_purchase_path(purchase, *args) = polymorphic_path([vendor_area, purchase], *args)
  def vn_new_vendor_purchase_path(*args)      = new_polymorphic_path([vendor_area, :vendor_purchase], *args)
  def vn_edit_vendor_purchase_path(purchase, *args)
    edit_polymorphic_path([vendor_area, purchase], *args)
  end

  def vn_complete_purchase_vendor_purchase_path(purchase, *args)
    public_send("complete_purchase_#{vendor_area}_vendor_purchase_path", purchase, *args)
  end

  def vn_generate_invoice_vendor_purchase_path(purchase, *args)
    public_send("generate_invoice_#{vendor_area}_vendor_purchase_path", purchase, *args)
  end

  def vn_mark_as_paid_vendor_purchase_path(purchase, *args)
    public_send("mark_as_paid_#{vendor_area}_vendor_purchase_path", purchase, *args)
  end

  def vn_batch_inventory_vendor_purchases_path(*args)
    public_send("batch_inventory_#{vendor_area}_vendor_purchases_path", *args)
  end

  def vn_products_vendor_purchases_path(*args)
    public_send("products_#{vendor_area}_vendor_purchases_path", *args)
  end

  def vn_bulk_mark_as_paid_vendor_purchases_path(*args)
    public_send("bulk_mark_as_paid_#{vendor_area}_vendor_purchases_path", *args)
  end
end

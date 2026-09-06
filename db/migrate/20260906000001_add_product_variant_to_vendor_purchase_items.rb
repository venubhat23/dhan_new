class AddProductVariantToVendorPurchaseItems < ActiveRecord::Migration[8.0]
  def change
    add_reference :vendor_purchase_items, :product_variant, null: true, foreign_key: true
  end
end

module Admin::VendorPurchasesHelper
  # <option> tags for the purchase form's product picker. Multi-quantity products
  # contribute one entry per variant; `selected` is the composite value of the
  # currently chosen product/variant ("<product_id>" or "<product_id>-v<variant_id>").
  def vendor_purchase_product_option_tags(products, selected = nil)
    options = VendorPurchase.product_option_list(products).map do |opt|
      [opt[:name], opt[:value], {
        'data-unit-type' => opt[:unit_type],
        'data-default-price' => opt[:default_selling_price],
        'data-purchase-price' => opt[:default_purchase_price]
      }]
    end
    options_for_select(options, selected)
  end
end

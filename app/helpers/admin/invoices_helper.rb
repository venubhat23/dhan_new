module Admin::InvoicesHelper
  # Builds <option> tags for the invoice line-item "Product" select, expanding
  # multi-quantity products into one option per variant so each variant's own
  # price/description is selectable instead of just the base product price.
  def invoice_product_options(selected_product_id: nil, selected_unit_price: nil)
    options = [content_tag(:option, 'Select Product...', value: '')]

    Product.active.includes(:category, :product_variants).order(:name).each do |product|
      gst_rate = invoice_gst_rate_for(product)

      if product.has_multiple_quantities? && product.product_variants.any?
        variants = product.product_variants.sort_by { |v| [v.display_order || 0, v.weight.to_f] }
        # Best-effort match: pick the variant whose price is closest to what was
        # actually saved on the line item, since invoice_items has no variant_id.
        closest_variant = variants.min_by { |v| (v.effective_price.to_f - selected_unit_price.to_f).abs } if selected_product_id == product.id

        variants.each do |variant|
          options << content_tag(:option, "#{product.name} - #{variant.label} - ₹#{variant.effective_price}",
            value: product.id,
            data: { price: variant.effective_price, description: "#{product.name} - #{variant.label}", gst_rate: gst_rate },
            selected: selected_product_id == product.id && variant == closest_variant)
        end
      else
        options << content_tag(:option, "#{product.name} - ₹#{product.selling_price}/#{product.unit_type}",
          value: product.id,
          data: { price: product.selling_price, description: product.name, gst_rate: gst_rate },
          selected: selected_product_id == product.id)
      end
    end

    safe_join(options)
  end

  # GST rate (%) that applies to a product's line total, matching the tax
  # calculation used on the invoice show page.
  def invoice_gst_rate_for(product)
    return 0 unless product&.gst_enabled

    if product.cgst_percentage.present? || product.sgst_percentage.present?
      (product.cgst_percentage || 0) + (product.sgst_percentage || 0) + (product.igst_percentage || 0)
    else
      product.gst_percentage || 0
    end
  end
end

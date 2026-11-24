# Bulk (loose) sale GST exemption, shared by BookingItem and InvoiceItem.
#
# A GST product sold in a line weighing MORE than THRESHOLD_KG (25 kg) is
# billed without GST: the GST part is dropped from the price instead of being
# charged (₹25 incl. 5% → ₹23.75, tax ₹0), and the invoice shows 0% tax.
#
# Only weight-measured lines qualify (variant / product unit Kg or Gram);
# Pack / Bottle / Liter / Piece lines never do. Nothing is stored — the
# exemption is derived from product, variant and quantity, exactly like the GST
# rate itself (read live from the product), so booking and invoice always agree.
module BulkGstExemption
  THRESHOLD_KG = 25

  KG_PER_UNIT = {
    'kg' => 1.0, 'kgs' => 1.0, 'kilogram' => 1.0, 'kilograms' => 1.0,
    'g' => 0.001, 'gm' => 0.001, 'gms' => 0.001, 'gram' => 0.001, 'grams' => 0.001
  }.freeze

  def self.kg_factor(unit)
    KG_PER_UNIT[unit.to_s.strip.downcase]
  end

  # Kg in one unit of this line, or nil when the line isn't sold by weight.
  def unit_weight_kg
    if product_variant
      factor = BulkGstExemption.kg_factor(product_variant.unit)
      return nil unless factor && product_variant.weight.to_f > 0

      product_variant.weight.to_f * factor
    elsif product
      factor = BulkGstExemption.kg_factor(product.unit_type)
      return nil unless factor

      weight = product.weight.to_f
      # A "Kg" product with no weight set is sold per 1 kg.
      weight = 1.0 if weight <= 0 && factor == 1.0
      weight > 0 ? weight * factor : nil
    end
  end

  # Total kg on this line (quantity × unit weight), or nil if not weight-based.
  def line_weight_kg
    per_unit = unit_weight_kg
    per_unit && (per_unit * quantity.to_f).round(3)
  end

  # True when this GST line is over the bulk threshold and so carries no GST.
  def bulk_gst_exempt?
    return false unless product&.gst_enabled

    kg = line_weight_kg
    kg.present? && kg > THRESHOLD_KG
  end

  # Drop-in for `item.product&.gst_enabled` in tax calculations: GST product
  # AND not bulk-exempt.
  def gst_charged?
    !!product&.gst_enabled && !bulk_gst_exempt?
  end
end

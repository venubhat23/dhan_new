# One-shot stock seeder.
#   bin/rails runner scratch_seed_stock.rb
#
# - Wipes ALL stock_batches, stock_movements, stock_transfers (catalog untouched).
# - Re-inserts central + store stock from the sheet below.
# - Central stock -> product_variant.available_stock (+ a central StockBatch per positive qty)
# - Store stock   -> StoreInventory row (+ a store StockBatch per positive qty)
# - "store low stock" -> StoreInventory#low_stock_threshold (per variant)
# Store = "Gandhi Bazar" if present, else the only store (when there is exactly one).

SHEET = [
  # name,               weight, unit,   store_low, store_qty, central, central_low, category
  ["A2 Cow Ghee",         1,   "Liter",  1,   1,   5,   nil, "Ghee"],
  ["A2 Cow Ghee",         500, "Ml",     3,   3,   5,   nil, "Ghee"],
  ["A2 Cow Ghee",         250, "Gm",     2,   5,   5,   nil, "Ghee"],
  ["Groundnut Oil",       1,   "Liter",  5,   6,   5,   nil, "Oils Cold Pressed"],
  ["Groundnut Oil",       5,   "Liter",  1,   2,   5,   nil, "Oils Cold Pressed"],
  ["Safflower Oil",       1,   "Ltr",    5,   7,   5,   nil, "Oils Cold Pressed"],
  ["Sunflower Oil",       1,   "Ltr",    5,   10,  5,   nil, "Oils Cold Pressed"],
  ["Mustard Oil",         1,   "Ltr",    2,   3,   5,   nil, "Oils Cold Pressed"],
  ["Mustard Oil",         500, "Ml",     2,   4,   5,   nil, "Oils Cold Pressed"],
  ["Sesame Oil",          1,   "Ltr",    2,   3,   5,   nil, "Oils Cold Pressed"],
  ["Sesame Oil",          500, "Ml",     2,   4,   5,   nil, "Oils Cold Pressed"],
  ["Castor Oil",          500, "Ml",     2,   5,   5,   nil, "Oils Cold Pressed"],
  ["Coconut Oil",         1,   "Ltr",    2,   13,  5,   nil, "Oils Cold Pressed"],
  ["Coconut Oil",         500, "Ltr",    2,   12,  5,   nil, "Oils Cold Pressed"], # "Ltr" is a typo -> 500 Ml
  ["Safflower Oil",       5,   "Liter",  1,   1,   5,   nil, "Oils Cold Pressed"],
  ["Sunflower Oil",       5,   "Liter",  1,   2,   5,   nil, "Oils Cold Pressed"],
  ["Virgin Coconut Oil",  1,   "Ltr",    nil, 3,   5,   nil, "Oils Cold Pressed"],
].freeze

NAME_ALIAS = { "virgin coconut oil" => "virgin coconut oil" }
UNIT_ALIAS = { "ltr" => "liter", "l" => "liter", "ltrs" => "liter",
               "gm" => "gram", "g" => "gram", "gms" => "gram",
               "ml" => "ml", "mls" => "ml", "liter" => "liter", "gram" => "gram" }

def norm_unit(u) = UNIT_ALIAS[u.to_s.strip.downcase] || u.to_s.strip.downcase

store  = Store.where("name ILIKE '%Gandhi%Baz%'").first ||
         (Store.count == 1 ? Store.first : nil) or
  abort "Gandhi Bazar store not found and there is not exactly one store"
vendor = Vendor.find_by("name ILIKE 'System Default'") || Vendor.first or abort "no vendor"
puts "Store: ##{store.id} #{store.name}   Vendor: ##{vendor.id} #{vendor.name}"

log = []

ActiveRecord::Base.transaction do
  del_b = StockBatch.count; del_m = StockMovement.count; del_t = StockTransfer.count
  StockTransfer.delete_all
  StockBatch.delete_all
  StockMovement.delete_all
  puts "Deleted: #{del_b} batches, #{del_m} movements, #{del_t} transfers"

  touched_variant_ids = []

  SHEET.each do |name, weight, unit, store_low, store_qty_in, central, central_low, category_name|
    lookup = NAME_ALIAS[name.downcase] || name
    product = Product.where("lower(name) = ?", lookup.downcase).first
    raise "Product not found: #{name}" unless product

    # category
    cat = Category.find_by("lower(name) = ?", category_name.downcase)
    if cat && product.category_id != cat.id
      product.update_columns(category_id: cat.id, updated_at: Time.current)
      log << "#{name}: category -> #{cat.name}"
    end

    # single-variant product -> make it behave like the multi-variant ones
    if product.product_variants.count == 1 && !product.has_multiple_quantities?
      product.update_columns(has_multiple_quantities: true, updated_at: Time.current)
    end

    wanted_u = norm_unit(unit)
    variant = product.product_variants.detect { |v| v.weight.to_f == weight.to_f && norm_unit(v.unit) == wanted_u }
    # No matching variant -> treat this row as the variant-less product itself.
    if variant
      touched_variant_ids << variant.id
    else
      log << "#{name} #{weight} #{unit}: no variant match -> using product ##{product.id} (no variant)"
    end

    sell = (variant&.selling_price).to_f
    sell = product.price.to_f if sell <= 0
    sell = 1 if sell <= 0
    buy = (variant&.buying_price).to_f
    buy = product.buying_price.to_f if buy <= 0
    buy = sell if buy <= 0

    # ---- central (admin app) ----
    central_qty = central.to_i
    if variant
      variant.update_columns(
        available_stock: central_qty,
        low_stock_threshold: (central_low || variant.low_stock_threshold || 10),
        updated_at: Time.current
      )
      central_low_val = variant.low_stock_threshold
    else
      product.update_columns(
        stock: central_qty,
        low_stock_threshold: (central_low || product.low_stock_threshold || 10),
        updated_at: Time.current
      )
      central_low_val = product.low_stock_threshold
    end
    if central_qty > 0
      StockBatch.create!(product: product, product_variant: variant, vendor: vendor, store_id: nil,
                         quantity_purchased: central_qty, quantity_remaining: central_qty,
                         purchase_price: buy, selling_price: sell, batch_date: Date.current, status: "active")
    end

    # ---- store ----
    store_qty = store_qty_in.to_i
    si = StoreInventory.find_or_initialize_by(store_id: store.id, product_id: product.id, product_variant_id: variant&.id)
    si.quantity = store_qty
    si.low_stock_threshold = (store_low || store.auto_transfer_threshold || 10)
    si.save!
    if store_qty > 0
      StockBatch.create!(product: product, product_variant: variant, vendor: vendor, store_id: store.id,
                         quantity_purchased: store_qty, quantity_remaining: store_qty,
                         purchase_price: buy, selling_price: sell, batch_date: Date.current, status: "active")
    end

    log << format("%-20s %4s %-6s | central %-3s (low %s) | %s %-3s (low %s)",
                  name, weight, unit, central_qty, central_low_val,
                  store.name, store_qty, si.low_stock_threshold)
  end
end

puts "\n=== RESULT ==="
puts log.join("\n")
puts "\nStockBatch=#{StockBatch.count} (central #{StockBatch.central.count}, #{store.name} #{StockBatch.where.not(store_id: nil).count})  StoreInventory=#{StoreInventory.count}"

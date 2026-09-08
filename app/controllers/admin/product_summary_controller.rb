class Admin::ProductSummaryController < Admin::ApplicationController
  # Single editable table: every product (with its variants) alongside main-store
  # stock / low-stock threshold and the same figures for each physical store.
  #
  # Stock edits are reconciled the same way the rest of the app does it: an
  # increase creates a new FIFO StockBatch for the delta, a decrease draws the
  # delta down from existing batches (see project memory "Stock batch on edit").
  def index
    load_summary
  end

  def update
    # Save only needs the rows the form actually touched — loading the whole
    # catalog (every product, variant and store-inventory row) plus rebuilding
    # the per-store roll-ups was ~6 queries and a full-catalog Ruby loop wasted
    # on every save. load_for_update fetches just the referenced records.
    load_for_update
    @errors = []
    @new_batches = []   # StockBatch rows for stock increases — one bulk insert
    @movements   = []   # StockMovement audit rows — one bulk insert
    # Column writes are collected as {id => value} and flushed as a single
    # CASE-per-column UPDATE, so a 100-row bulk edit is ~4 UPDATEs, not 100+.
    @col_updates = {
      Product        => { stock: {}, low_stock_threshold: {} },
      ProductVariant => { available_stock: {}, low_stock_threshold: {} }
    }
    @inv_updates = {}  # store_inventories.id => {quantity:, low_stock_threshold:}
    @inv_inserts = []  # new store_inventories rows
    changed = 0

    # Per-row failures (e.g. adding stock with no cost price) are collected in
    # @errors and skipped — the rows that did apply are still committed, so one
    # bad cell no longer discards every other edit on the page.
    ActiveRecord::Base.transaction do
      changed += apply_main_product_changes
      changed += apply_main_variant_changes
      changed += apply_store_changes
      flush_pending_writes
    end

    if @errors.any? && changed.zero?
      redirect_to admin_product_summary_path, alert: "No changes saved. #{@errors.first(5).join(' | ')}"
    elsif @errors.any?
      redirect_to admin_product_summary_path,
                  alert: "#{changed} change(s) saved, #{@errors.size} skipped: #{@errors.first(5).join(' | ')}"
    else
      redirect_to admin_product_summary_path, notice: "#{changed} change(s) saved."
    end
  end

  private

  # ---- loading -------------------------------------------------------------

  def load_summary
    @stores = Store.order(:name).to_a
    @products = Product.includes(:product_variants, :category).order(:name).to_a
    product_ids = @products.map(&:id)

    # Per-store inventory rows (store_inventories).
    @store_qty       = {} # [store_id, product_id, variant_id] => quantity
    @store_threshold = {} # [store_id, product_id, variant_id] => low_stock_threshold
    StoreInventory.where(product_id: product_ids).each do |row|
      key = [row.store_id, row.product_id, row.product_variant_id]
      @store_qty[key] = row.quantity
      @store_threshold[key] = row.low_stock_threshold
    end

    # Main-store on-hand for a simple product is the sum of its central (store_id
    # NULL) active stock batches — the same figure the storefront, POS, dashboard
    # and stock filters use (Product::REAL_STOCK_SQL). The legacy products.stock
    # column has drifted from this on most products, so reading/writing it here
    # made edits land on a number nothing else in the app looks at.
    @central_stock = Hash.new(0.0).merge(
      StockBatch.where(product_id: product_ids, store_id: nil, status: 'active')
                .where('quantity_remaining > 0')
                .group(:product_id).sum(:quantity_remaining)
    )

    # Main-store stock per product (canonical fulfilment fields the app keeps).
    @main_stock = {}
    # Aggregated per-store quantity per product (variant rows + plain row);
    # nil when the store has no inventory row for that product at all.
    @store_prod_qty = {}
    @products.each do |product|
      @main_stock[product.id] =
        if product.has_multiple_quantities?
          product.product_variants.sum { |v| v.available_stock.to_f }
        else
          @central_stock[product.id].to_f
        end

      @stores.each do |store|
        keys = [[store.id, product.id, nil]] +
               product.product_variants.map { |v| [store.id, product.id, v.id] }
        next unless keys.any? { |k| @store_qty.key?(k) }
        @store_prod_qty[[store.id, product.id]] = keys.sum { |k| @store_qty[k].to_f }
      end
    end
  end

  # Lean loader for the save path: only the products / variants / stores named
  # in the submitted params, plus the current central-stock total and existing
  # store-inventory rows for exactly those keys. Everything is keyed by id so
  # the apply_* methods do hash lookups instead of scanning @products.
  def load_for_update
    mp = params[:main_products]  || {}
    mv = params[:main_variants]  || {}
    sp = params[:store_products] || {}
    sv = params[:store_variants] || {}

    store_ids      = (sp.keys + sv.keys).map(&:to_i).uniq
    sp_product_ids = sp.values.flat_map { |rows| rows.keys }.map(&:to_i)
    sv_variant_ids = sv.values.flat_map { |rows| rows.keys }.map(&:to_i)

    variant_ids = (mv.keys.map(&:to_i) + sv_variant_ids).uniq
    @variants_by_id = ProductVariant.where(id: variant_ids).includes(:product).index_by(&:id)

    product_ids = (mp.keys.map(&:to_i) + sp_product_ids +
                   @variants_by_id.values.map(&:product_id)).uniq
    @products_by_id = Product.where(id: product_ids).includes(:product_variants).index_by(&:id)
    @stores_by_id   = Store.where(id: store_ids).index_by(&:id)

    simple_ids = @products_by_id.values.reject(&:has_multiple_quantities?).map(&:id)
    @central_stock = Hash.new(0.0).merge(
      StockBatch.where(product_id: simple_ids, store_id: nil, status: 'active')
                .where('quantity_remaining > 0')
                .group(:product_id).sum(:quantity_remaining)
    )

    # Existing store_inventories rows for the referenced (store, product/variant)
    # keys — one query instead of a find_or_initialize_by per edited cell.
    @store_inv = {}
    if store_ids.any?
      inv_product_ids = (sp_product_ids + @variants_by_id.values.map(&:product_id)).uniq
      StoreInventory.where(store_id: store_ids, product_id: inv_product_ids).each do |row|
        @store_inv[[row.store_id, row.product_id, row.product_variant_id]] = row
      end
    end
  end

  def queue_col(model, id, column, value)
    @col_updates[model][column][id.to_i] = value
  end

  # Flush the batched inserts + column updates collected during the apply_* pass.
  def flush_pending_writes
    now = Time.current
    if @new_batches.any?
      StockBatch.insert_all(@new_batches.map { |h| h.merge(created_at: now, updated_at: now) })
    end
    if @movements.any?
      StockMovement.insert_all(@movements.map { |h| h.merge(created_at: now, updated_at: now) })
    end

    @col_updates.each do |model, columns|
      columns.each do |column, map|
        next if map.empty?
        int = model.columns_hash[column.to_s].type == :integer
        whens = map.map { |id, v| "WHEN #{id.to_i} THEN #{int ? v.to_i : v.to_f}" }.join(' ')
        model.where(id: map.keys)
             .update_all(Arel.sql("#{column} = CASE id #{whens} ELSE #{column} END, updated_at = '#{now.utc.iso8601}'"))
      end
    end

    if @inv_inserts.any?
      StoreInventory.insert_all(@inv_inserts.map { |h| h.merge(created_at: now, updated_at: now) })
    end
    if @inv_updates.any?
      q = @inv_updates.map { |id, v| "WHEN #{id.to_i} THEN #{v[:quantity].to_f}" }.join(' ')
      t = @inv_updates.map { |id, v| "WHEN #{id.to_i} THEN #{v[:low_stock_threshold].to_i}" }.join(' ')
      StoreInventory.where(id: @inv_updates.keys).update_all(Arel.sql(
        "quantity = CASE id #{q} END, low_stock_threshold = CASE id #{t} END, updated_at = '#{now.utc.iso8601}'"))
    end
  end

  # ---- writing ------------------------------------------------------------

  def apply_main_product_changes
    count = 0
    (params[:main_products] || {}).each do |pid, attrs|
      product = @products_by_id[pid.to_i]
      next unless product

      if attrs[:threshold].present? && attrs[:threshold].to_i != product.low_stock_threshold.to_i
        queue_col(Product, product.id, :low_stock_threshold, attrs[:threshold].to_i)
        count += 1
      end

      next if attrs[:stock].blank?
      new_stock = attrs[:stock].to_f

      if product.has_multiple_quantities?
        count += apply_variant_product_main_stock(product, new_stock)
        next
      end

      old_stock = @central_stock[product.id].to_f
      next if new_stock == old_stock

      err = reconcile_stock(product, nil, old_stock, new_stock,
                            cost: product.buying_price || product.purchase_price || product.price,
                            sell: product.price,
                            label: "#{product.name}: main stock #{fmt(old_stock)} → #{fmt(new_stock)}")
      err ? (@errors << err) : (count += 1)
    end
    count
  end

  # Parent row of a variant product shows an aggregate Main Store stock. Editing
  # it reconciles the delta against the default variant so the roll-up still adds
  # up. Returns 1 on a successful change, 0 otherwise (errors go on @errors).
  def apply_variant_product_main_stock(product, new_total)
    target = product.sorted_variants.first
    return 0 unless target

    old_total = product.product_variants.sum { |v| v.available_stock.to_f }
    delta = new_total - old_total
    return 0 if delta.zero?

    target_old = target.available_stock.to_f
    target_new = target_old + delta
    if target_new.negative?
      @errors << "#{product.name}: can't lower Main Store stock below the other variants' total"
      return 0
    end

    err = reconcile_stock(product, target, target_old, target_new,
                          cost: target.buying_price || target.purchase_price || target.selling_price,
                          sell: target.selling_price,
                          label: "#{product.name} #{target.label}: main stock #{fmt(target_old)} → #{fmt(target_new)} (parent total edit)")
    if err
      @errors << err
      0
    else
      queue_col(ProductVariant, target.id, :available_stock, target_new.to_i)
      1
    end
  end

  def apply_main_variant_changes
    count = 0
    (params[:main_variants] || {}).each do |vid, attrs|
      variant = @variants_by_id[vid.to_i]
      next unless variant

      if attrs[:threshold].present? && attrs[:threshold].to_i != variant.low_stock_threshold.to_i
        queue_col(ProductVariant, variant.id, :low_stock_threshold, attrs[:threshold].to_i)
        count += 1
      end

      next if attrs[:stock].blank?
      new_stock = attrs[:stock].to_f
      old_stock = variant.available_stock.to_f
      next if new_stock == old_stock

      err = reconcile_stock(variant.product, variant, old_stock, new_stock,
                            cost: variant.buying_price || variant.purchase_price || variant.selling_price,
                            sell: variant.selling_price,
                            label: "#{variant.product.name} #{variant.label}: main stock #{fmt(old_stock)} → #{fmt(new_stock)}")
      if err
        @errors << err
      else
        queue_col(ProductVariant, variant.id, :available_stock, new_stock.to_i)
        count += 1
      end
    end
    count
  end

  def apply_store_changes
    count = 0
    count += apply_store_scope(params[:store_products], variant_scoped: false)
    count += apply_store_scope(params[:store_variants], variant_scoped: true)
    count
  end

  # store_products: { store_id => { product_id => { qty:, threshold: } } }
  # store_variants: { store_id => { variant_id => { qty:, threshold: } } }
  def apply_store_scope(scope, variant_scoped:)
    count = 0
    (scope || {}).each do |sid, rows|
      store = @stores_by_id[sid.to_i]
      next unless store

      rows.each do |rid, attrs|
        if variant_scoped
          variant = @variants_by_id[rid.to_i]
          next unless variant
          product_id, variant_id = variant.product_id, variant.id
        else
          product = @products_by_id[rid.to_i]
          next unless product
          product_id, variant_id = product.id, nil
        end

        qty_in = attrs[:qty]
        thr_in = attrs[:threshold]
        next if qty_in.blank? && thr_in.blank?

        inv     = @store_inv[[store.id, product_id, variant_id]]
        old_qty = inv&.quantity.to_f
        old_thr = inv&.low_stock_threshold.to_i
        new_qty = qty_in.present? ? qty_in.to_f : old_qty
        new_thr = thr_in.present? ? thr_in.to_i : old_thr
        next if new_qty == old_qty && new_thr == old_thr

        label = @products_by_id[product_id]&.name || variant&.label || "product #{product_id}"
        if new_qty.negative? || new_thr.negative?
          @errors << "#{store.name} / #{label}: quantity and threshold can't be negative"
          next
        end

        if inv
          @inv_updates[inv.id] = { quantity: new_qty, low_stock_threshold: new_thr }
        else
          @inv_inserts << { store_id: store.id, product_id: product_id, product_variant_id: variant_id,
                            quantity: new_qty, low_stock_threshold: new_thr }
        end

        if new_qty != old_qty
          prod = @products_by_id[product_id] || variant&.product
          log_movement(prod, new_qty - old_qty, new_qty,
                       "#{store.name}: stock #{fmt(old_qty)} → #{fmt(new_qty)}") if prod
        end
        count += 1
      end
    end
    count
  end

  # Reconciles central (main-store) stock for a product/variant to new_stock.
  # Returns an error string on failure, nil on success.
  #
  # An increase is queued as a StockBatch row (inserted in one batch by
  # flush_pending_writes); a decrease draws down existing batches FIFO right
  # away. The legacy products.stock column is then resynced arithmetically from
  # the known central total + the amount actually moved, so there is no extra
  # SELECT per edited row.
  def reconcile_stock(product, variant, old_stock, new_stock, cost:, sell:, label:)
    delta = new_stock - old_stock
    return nil if delta.zero?

    applied = delta
    if delta.positive?
      cost_f = cost.to_f
      sell_f = sell.to_f
      sell_f = cost_f if sell_f <= 0
      return "#{label}: set a cost/buying price before adding stock" if cost_f <= 0

      @new_batches << {
        product_id: product.id,
        vendor_id: default_stock_vendor.id,
        store_id: nil,
        product_variant_id: variant&.id,
        quantity_purchased: delta,
        quantity_remaining: delta,
        purchase_price: cost_f,
        selling_price: sell_f,
        batch_date: Date.current,
        status: 'active'
      }
    else
      # reduce_central_batches caps at what actually exists; applied is the real
      # signed change so the resync below lands on the true new on-hand.
      applied = -reduce_central_batches(product, variant, delta.abs)
    end

    unless product.has_multiple_quantities?
      new_total = old_stock + applied
      queue_col(Product, product.id, :stock, new_total)
      @central_stock[product.id] = new_total
    end

    log_movement(product, applied, old_stock + applied, label)
    nil
  rescue ActiveRecord::RecordInvalid => e
    # A validation failure sends no SQL, so the surrounding transaction stays
    # usable: report this row and let the rest of the save commit.
    "#{label}: #{e.message}"
  end

  # Draws `amount` down from the product's central active batches, FIFO.
  # Returns the amount actually removed (may be less than `amount`).
  def reduce_central_batches(product, variant, amount)
    scope = product.stock_batches.central.active.by_fifo
    scope = scope.where(product_variant_id: variant.id) if variant
    remaining = amount
    scope.each do |batch|
      break if remaining <= 0
      take = [batch.quantity_remaining, remaining].min
      batch.reduce_stock!(take)
      remaining -= take
    end
    amount - remaining
  end

  def log_movement(product, delta, new_total, note)
    @movements << {
      product_id: product.id,
      reference_type: 'adjustment',
      reference_id: nil,
      movement_type: delta.positive? ? 'added' : 'adjusted',
      quantity: delta,
      stock_before: new_total - delta,
      stock_after: new_total,
      notes: "Product Summary edit: #{note}"
    }
  end

  def default_stock_vendor
    @default_stock_vendor ||= Vendor.find_or_create_by(name: 'System Default') do |v|
      v.email = 'system@default.com'
      v.phone = '0000000000'
      v.address = 'System Generated'
      v.payment_type = 'Paid'
      v.status = true
    end
  end

  def fmt(n)
    n.to_f == n.to_i ? n.to_i.to_s : n.to_f.round(2).to_s
  end
end

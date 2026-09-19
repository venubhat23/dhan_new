class StoreAdmin::ProductSummaryController < StoreAdmin::ApplicationController
  before_action -> { require_permission!(:can_manage_inventory?, redirect: store_admin_root_path,
                                         message: 'You do not have permission to manage inventory.') }

  # Store-login version of Admin::ProductSummaryController, cut down to a single
  # store: one editable Stock + Low-stock-threshold column pair per product /
  # variant for @current_store, plus Bulk Edit. Values are written straight to
  # store_inventories (no central FIFO reconciliation — that stays admin-only).
  def index
    load_summary
  end

  def update
    # Save only touches the submitted rows — no need to load the whole catalog.
    load_for_update
    @errors = []
    @movements   = []   # one bulk insert
    @inv_updates = {}    # store_inventories.id => {quantity:, low_stock_threshold:}
    @inv_inserts = []    # new store_inventories rows
    changed = 0

    ActiveRecord::Base.transaction do
      changed += apply_store_scope(params[:store_products], variant_scoped: false)
      changed += apply_store_scope(params[:store_variants], variant_scoped: true)
      flush_pending_writes
    end

    if @errors.any? && changed.zero?
      redirect_to store_admin_product_summary_path, alert: "No changes saved. #{@errors.first(5).join(' | ')}"
    elsif @errors.any?
      redirect_to store_admin_product_summary_path,
                  alert: "#{changed} change(s) saved, #{@errors.size} skipped: #{@errors.first(5).join(' | ')}"
    else
      redirect_to store_admin_product_summary_path, notice: "#{changed} change(s) saved."
    end
  end

  private

  # ---- loading -------------------------------------------------------------

  def load_summary
    @products = store_products.includes(:product_variants, :category).order(:name).to_a
    product_ids = @products.map(&:id)

    # This store's inventory rows.
    @store_qty       = {} # [product_id, variant_id] => quantity
    @store_threshold = {} # [product_id, variant_id] => low_stock_threshold
    StoreInventory.where(store_id: @current_store.id, product_id: product_ids).each do |row|
      key = [row.product_id, row.product_variant_id]
      @store_qty[key]       = row.quantity
      @store_threshold[key] = row.low_stock_threshold
    end

    # Per-product roll-up, identical to the store columns on Admin::ProductSummary:
    # a variant product's total is the sum of its variants' rows ONLY (never
    # also a product-level row — that would double-count); a simple product
    # uses its own product-level row. nil when the store has no row at all.
    @store_prod_qty = {}
    @store_prod_thr = {}
    @products.each do |product|
      keys = if product.has_multiple_quantities?
               product.product_variants.map { |v| [product.id, v.id] }
             else
               [[product.id, nil]]
             end
      next unless keys.any? { |k| @store_qty.key?(k) }
      @store_prod_qty[product.id] = keys.sum { |k| @store_qty[k].to_f }
      @store_prod_thr[product.id] = keys.sum { |k| @store_threshold[k].to_i }
    end
  end

  # Lean loader for the save path: only the products / variants named in the
  # submitted params, plus this store's existing inventory rows for those keys.
  def load_for_update
    sp = params[:store_products] || {}
    sv = params[:store_variants] || {}

    @variants_by_id = ProductVariant.where(id: sv.keys.map(&:to_i)).includes(:product).index_by(&:id)
    product_ids = (sp.keys.map(&:to_i) + @variants_by_id.values.map(&:product_id)).uniq
    @products_by_id = Product.where(id: product_ids).includes(:product_variants).index_by(&:id)

    @store_inv = {}
    StoreInventory.where(store_id: @current_store.id, product_id: product_ids).each do |row|
      @store_inv[[row.product_id, row.product_variant_id]] = row
    end
  end

  def flush_pending_writes
    now = Time.current
    if @inv_inserts.any?
      StoreInventory.insert_all(@inv_inserts.map { |h| h.merge(created_at: now, updated_at: now) })
    end
    if @inv_updates.any?
      q = @inv_updates.map { |id, v| "WHEN #{id.to_i} THEN #{v[:quantity].to_f}" }.join(' ')
      t = @inv_updates.map { |id, v| "WHEN #{id.to_i} THEN #{v[:low_stock_threshold].to_i}" }.join(' ')
      StoreInventory.where(id: @inv_updates.keys).update_all(Arel.sql(
        "quantity = CASE id #{q} END, low_stock_threshold = CASE id #{t} END, updated_at = '#{now.utc.iso8601}'"))
    end
    if @movements.any?
      StockMovement.insert_all(@movements.map { |h| h.merge(created_at: now, updated_at: now) })
    end
  end

  # ---- writing ------------------------------------------------------------

  # store_products: { product_id => { qty:, threshold: } }
  # store_variants: { variant_id => { qty:, threshold: } }
  def apply_store_scope(scope, variant_scoped:)
    count = 0
    (scope || {}).each do |rid, attrs|
      if variant_scoped
        variant = @variants_by_id[rid.to_i]
        next unless variant
        product_id, variant_id = variant.product_id, variant.id
      else
        product = @products_by_id[rid.to_i]
        next unless product

        if product.has_multiple_quantities?
          # Parent row of a variant product is a display roll-up — write
          # through to the default variant's row (same as the admin screen)
          # rather than creating a product-level row that double-counts.
          variant = product.sorted_variants.first
          next unless variant
          product_id, variant_id = product.id, variant.id
        else
          variant = nil
          product_id, variant_id = product.id, nil
        end
      end

      qty_in = attrs[:qty]
      thr_in = attrs[:threshold]
      next if qty_in.blank? && thr_in.blank?

      inv     = @store_inv[[product_id, variant_id]]
      old_qty = inv&.quantity.to_f
      old_thr = inv&.low_stock_threshold.to_i
      new_qty = qty_in.present? ? qty_in.to_f : old_qty
      new_thr = thr_in.present? ? thr_in.to_i : old_thr
      next if new_qty == old_qty && new_thr == old_thr

      label = @products_by_id[product_id]&.name || variant&.label || "product #{product_id}"
      if new_qty.negative? || new_thr.negative?
        @errors << "#{@current_store.name} / #{label}: quantity and threshold can't be negative"
        next
      end

      if inv
        @inv_updates[inv.id] = { quantity: new_qty, low_stock_threshold: new_thr }
      else
        @inv_inserts << { store_id: @current_store.id, product_id: product_id, product_variant_id: variant_id,
                          quantity: new_qty, low_stock_threshold: new_thr }
      end

      if new_qty != old_qty
        prod = @products_by_id[product_id] || variant&.product
        log_movement(prod, new_qty - old_qty, new_qty,
                     "#{@current_store.name}: stock #{fmt(old_qty)} → #{fmt(new_qty)}") if prod
      end
      count += 1
    end
    count
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
      notes: "Store Product Summary edit: #{note}"
    }
  end

  def fmt(n)
    n.to_f == n.to_i ? n.to_i.to_s : n.to_f.round(2).to_s
  end
end

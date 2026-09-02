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
    load_summary
    @errors = []
    changed = 0

    # Per-row failures (e.g. adding stock with no cost price) are collected in
    # @errors and skipped — the rows that did apply are still committed, so one
    # bad cell no longer discards every other edit on the page.
    ActiveRecord::Base.transaction do
      changed += apply_main_product_changes
      changed += apply_main_variant_changes
      changed += apply_store_changes
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

  # ---- writing ------------------------------------------------------------

  def apply_main_product_changes
    count = 0
    (params[:main_products] || {}).each do |pid, attrs|
      product = @products.find { |p| p.id.to_s == pid.to_s }
      next unless product

      if attrs[:threshold].present? && attrs[:threshold].to_i != product.low_stock_threshold.to_i
        product.update_column(:low_stock_threshold, attrs[:threshold].to_i)
        count += 1
      end

      next if attrs[:stock].blank?
      new_stock = attrs[:stock].to_f

      if product.has_multiple_quantities?
        count += apply_variant_product_main_stock(product, new_stock)
        next
      end

      old_stock = @main_stock[product.id].to_f
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
      target.update_column(:available_stock, target_new.to_i)
      1
    end
  end

  def apply_main_variant_changes
    count = 0
    (params[:main_variants] || {}).each do |vid, attrs|
      variant = @products.flat_map(&:product_variants).find { |v| v.id.to_s == vid.to_s }
      next unless variant

      if attrs[:threshold].present? && attrs[:threshold].to_i != variant.low_stock_threshold.to_i
        variant.update_column(:low_stock_threshold, attrs[:threshold].to_i)
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
        variant.update_column(:available_stock, new_stock.to_i)
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
      store = @stores.find { |s| s.id.to_s == sid.to_s }
      next unless store

      rows.each do |rid, attrs|
        if variant_scoped
          variant = @products.flat_map(&:product_variants).find { |v| v.id.to_s == rid.to_s }
          next unless variant
          product_id, variant_id = variant.product_id, variant.id
        else
          product = @products.find { |p| p.id.to_s == rid.to_s }
          next unless product
          product_id, variant_id = product.id, nil
        end

        qty_in = attrs[:qty]
        thr_in = attrs[:threshold]
        next if qty_in.blank? && thr_in.blank?

        inv = StoreInventory.find_or_initialize_by(
          store_id: store.id, product_id: product_id, product_variant_id: variant_id
        )
        old_qty = inv.quantity.to_f
        touched = false

        if qty_in.present? && qty_in.to_f != old_qty
          inv.quantity = qty_in.to_f
          touched = true
        end
        if thr_in.present? && thr_in.to_i != inv.low_stock_threshold.to_i
          inv.low_stock_threshold = thr_in.to_i
          touched = true
        end
        next unless touched

        if inv.save
          if inv.quantity.to_f != old_qty
            prod = @products.find { |p| p.id == product_id }
            log_movement(prod, inv.quantity.to_f - old_qty, inv.quantity.to_f,
                         "#{store.name}: stock #{fmt(old_qty)} → #{fmt(inv.quantity)}") if prod
          end
          count += 1
        else
          @errors << "#{store.name} / #{inv.label rescue product_id}: #{inv.errors.full_messages.join(', ')}"
        end
      end
    end
    count
  end

  # Reconciles central (main-store) stock for a product/variant to new_stock.
  # Returns an error string on failure, nil on success.
  def reconcile_stock(product, variant, old_stock, new_stock, cost:, sell:, label:)
    delta = new_stock - old_stock
    return nil if delta.zero?

    if delta.positive?
      cost_f = cost.to_f
      sell_f = sell.to_f
      sell_f = cost_f if sell_f <= 0
      return "#{label}: set a cost/buying price before adding stock" if cost_f <= 0

      product.stock_batches.create!(
        vendor: default_stock_vendor,
        product_variant_id: variant&.id,
        quantity_purchased: delta,
        quantity_remaining: delta,
        purchase_price: cost_f,
        selling_price: sell_f,
        batch_date: Date.current,
        status: 'active'
      )
    else
      reduce_central_batches(product, variant, delta.abs)
    end

    # Keep the legacy products.stock column honest by resyncing it to the actual
    # central batch total after the adjustment (matches Admin::ProductsController
    # #apply_stock_change and BookingItem). A decrease is capped at the central
    # stock that actually exists, so the resynced total is the real new on-hand.
    unless product.has_multiple_quantities?
      synced = product.stock_batches.central.active.sum(:quantity_remaining)
      product.update_column(:stock, synced)
    end

    log_movement(product, delta, new_stock, label)
    nil
  rescue ActiveRecord::RecordInvalid => e
    "#{label}: #{e.message}"
  end

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
  end

  def log_movement(product, delta, new_total, note)
    product.stock_movements.create!(
      reference_type: 'adjustment',
      reference_id: nil,
      movement_type: delta.positive? ? 'added' : 'adjusted',
      quantity: delta,
      stock_before: new_total - delta,
      stock_after: new_total,
      notes: "Product Summary edit: #{note}"
    )
  rescue => e
    Rails.logger.error "Product Summary movement log failed (Product ##{product.id}): #{e.message}"
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

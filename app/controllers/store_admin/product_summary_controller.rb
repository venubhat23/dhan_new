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
    load_summary
    @errors = []
    changed = 0

    ActiveRecord::Base.transaction do
      changed += apply_store_scope(params[:store_products], variant_scoped: false)
      changed += apply_store_scope(params[:store_variants], variant_scoped: true)
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

    # Fall back to this store's active batch stock where there's no inventory row.
    @batch_qty = Hash.new(0.0).merge(
      @current_store.stock_batches.where(product_id: product_ids, status: 'active')
                    .where('quantity_remaining > 0')
                    .group(:product_id).sum(:quantity_remaining)
    )

    # Aggregated store quantity per product (plain row + variant rows), nil when
    # the store carries no inventory row for the product at all.
    @store_prod_qty = {}
    @products.each do |product|
      keys = [[product.id, nil]] + product.product_variants.map { |v| [product.id, v.id] }
      if keys.any? { |k| @store_qty.key?(k) }
        @store_prod_qty[product.id] = keys.sum { |k| @store_qty[k].to_f }
      elsif @batch_qty[product.id].to_f.positive?
        @store_prod_qty[product.id] = @batch_qty[product.id].to_f
      end
    end
  end

  # ---- writing ------------------------------------------------------------

  # store_products: { product_id => { qty:, threshold: } }
  # store_variants: { variant_id => { qty:, threshold: } }
  def apply_store_scope(scope, variant_scoped:)
    count = 0
    (scope || {}).each do |rid, attrs|
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
        store_id: @current_store.id, product_id: product_id, product_variant_id: variant_id
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
                       "#{@current_store.name}: stock #{fmt(old_qty)} → #{fmt(inv.quantity)}") if prod
        end
        count += 1
      else
        @errors << "#{@current_store.name} / #{(inv.label rescue product_id)}: #{inv.errors.full_messages.join(', ')}"
      end
    end
    count
  end

  def log_movement(product, delta, new_total, note)
    product.stock_movements.create!(
      reference_type: 'adjustment',
      reference_id: nil,
      movement_type: delta.positive? ? 'added' : 'adjusted',
      quantity: delta,
      stock_before: new_total - delta,
      stock_after: new_total,
      notes: "Store Product Summary edit: #{note}"
    )
  rescue => e
    Rails.logger.error "Store Product Summary movement log failed (Product ##{product.id}): #{e.message}"
  end

  def fmt(n)
    n.to_f == n.to_i ? n.to_i.to_s : n.to_f.round(2).to_s
  end
end

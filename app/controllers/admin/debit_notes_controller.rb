class Admin::DebitNotesController < Admin::ApplicationController
  def index
    scope = DebitNote.includes(:vendor, :vendor_purchase, debit_note_items: [:product, :product_variant])

    if params[:search].present?
      raw = params[:search].strip
      q = "%#{raw}%"
      purchase_id = raw.sub(/\AVP0*/i, '')
      scope = scope.left_joins(:vendor).where(
        'debit_notes.debit_note_number ILIKE :q OR vendors.name ILIKE :q OR vendors.phone ILIKE :q OR CAST(debit_notes.vendor_purchase_id AS TEXT) = :pid',
        q: q, pid: purchase_id
      )
    end
    scope = scope.where(vendor_id: params[:vendor_id]) if params[:vendor_id].present?
    scope = scope.where('debit_notes.debit_date >= ?', params[:from]) if params[:from].present?
    scope = scope.where('debit_notes.debit_date <= ?', params[:to]) if params[:to].present?

    @total_count  = scope.count
    @total_amount = scope.sum(:total_amount).to_f
    @total_units  = DebitNoteItem.where(debit_note_id: scope.select(:id)).sum(:quantity).to_f
    month_scope   = DebitNote.where(debit_date: Date.current.beginning_of_month..Date.current.end_of_month)
    @month_amount = month_scope.sum(:total_amount).to_f
    @month_count  = month_scope.count
    @vendor_count = DebitNote.distinct.count(:vendor_id)
    @vendors      = Vendor.where(id: DebitNote.select(:vendor_id)).order(:name)

    @per_page = 25
    @page = [params[:page].to_i, 1].max
    @total_pages = [(@total_count.to_f / @per_page).ceil, 1].max
    @debit_notes = scope.recent.offset((@page - 1) * @per_page).limit(@per_page)
  end

  def show
    @debit_note = DebitNote.includes(:vendor, :user, :vendor_purchase,
                                     debit_note_items: [:product, :product_variant]).find(params[:id])
  end

  def new
    @purchase_query = params[:purchase].to_s.strip
  end

  # GET /admin/debit_notes/lookup_purchase?q=VP000012 | 12 | vendor name
  def lookup_purchase
    q = params[:q].to_s.strip
    return render(json: { suggestions: [] }) if q.empty?

    purchase = VendorPurchase.find_by(id: q.sub(/\AVP0*/i, '').to_i) if q.match?(/\A(VP)?\d+\z/i)

    if purchase
      render json: { purchase: purchase_payload(purchase) }
    else
      matches = VendorPurchase.joins(:vendor).includes(:vendor)
                              .where('vendors.name ILIKE :q OR vendors.phone ILIKE :q', q: "%#{q}%")
                              .order(purchase_date: :desc, id: :desc).limit(10)
      render json: {
        suggestions: matches.map do |p|
          { id: p.id, purchase_number: p.purchase_number, vendor: p.vendor&.name,
            date: p.purchase_date&.strftime('%d %b %Y'), total: p.total_amount.to_f }
        end
      }
    end
  end

  def create
    purchase = VendorPurchase.find(params[:vendor_purchase_id])
    lines = Array(params[:items]&.values).filter_map do |row|
      next unless row[:selected] == '1'

      { vendor_purchase_item_id: row[:vendor_purchase_item_id], quantity: row[:quantity], amount: row[:amount] }
    end

    note = DebitNote.issue!(
      purchase: purchase,
      lines: lines,
      user: current_user,
      attrs: params.permit(:debit_date, :settlement_method, :reason, :notes).to_h.symbolize_keys
    )
    redirect_to admin_debit_note_path(note),
                notice: "Debit Note #{note.debit_note_number} saved — #{note.debit_note_items.size} item(s) removed from stock and returned to #{purchase.vendor&.name.to_s.chomp(".")}."
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_to new_admin_debit_note_path(purchase: purchase&.purchase_number), alert: e.message
  end

  private

  def purchase_payload(purchase)
    returned = DebitNote.returned_quantities_for(purchase)
    batches = purchase.stock_batches.to_a
    items = purchase.vendor_purchase_items.includes(:product, :product_variant).order(:id).map do |item|
      batch = batches.find { |b| b.product_id == item.product_id && b.product_variant_id == item.product_variant_id }
      returned_qty = returned.fetch(item.id, 0.0)
      {
        id: item.id,
        name: item.product&.name,
        variant: item.product_variant&.label,
        image: item.product&.main_image_url.presence,
        quantity: item.quantity.to_f,
        returned: returned_qty,
        in_stock: batch&.quantity_remaining.to_f,
        returnable: DebitNote.returnable_for(item, batch, returned_qty),
        unit_price: item.purchase_price.to_f.round(2),
        line_total: item.line_total.to_f
      }
    end

    {
      id: purchase.id,
      purchase_number: purchase.purchase_number,
      date: purchase.purchase_date&.strftime('%d %b %Y'),
      vendor: purchase.vendor&.name,
      vendor_phone: purchase.vendor&.phone,
      vendor_gst: purchase.vendor&.gst_no,
      status: purchase.status.to_s.humanize,
      total_amount: purchase.total_amount.to_f,
      paid_amount: purchase.paid_amount.to_f,
      previous_debit_total: purchase.debit_notes_total,
      items: items
    }
  end
end

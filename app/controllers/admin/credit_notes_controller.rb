class Admin::CreditNotesController < Admin::ApplicationController
  def index
    scope = CreditNote.includes(:booking, :customer, :store, credit_note_items: [:product, :product_variant])

    if params[:search].present?
      q = "%#{params[:search].strip}%"
      scope = scope.left_joins(:booking).where(
        'credit_notes.credit_note_number ILIKE :q OR bookings.booking_number ILIKE :q OR ' \
        'bookings.customer_name ILIKE :q OR bookings.customer_phone ILIKE :q', q: q
      )
    end
    scope = scope.where('credit_notes.credit_date >= ?', params[:from]) if params[:from].present?
    scope = scope.where('credit_notes.credit_date <= ?', params[:to]) if params[:to].present?

    @total_count  = scope.count
    @total_amount = scope.sum(:total_amount).to_f
    @total_units  = CreditNoteItem.where(credit_note_id: scope.select(:id)).sum(:quantity).to_f
    month_scope   = CreditNote.where(credit_date: Date.current.beginning_of_month..Date.current.end_of_month)
    @month_amount = month_scope.sum(:total_amount).to_f
    @month_count  = month_scope.count

    @per_page = 25
    @page = [params[:page].to_i, 1].max
    @total_pages = [(@total_count.to_f / @per_page).ceil, 1].max
    @credit_notes = scope.recent.offset((@page - 1) * @per_page).limit(@per_page)
  end

  def show
    @credit_note = CreditNote.includes(:booking, :customer, :store, :user,
                                       credit_note_items: [:product, :product_variant]).find(params[:id])
  end

  def new
    @booking_query = params[:booking].to_s.strip
  end

  # GET /admin/credit_notes/lookup_booking?q=BK2026...
  # Exact booking number / id → full booking with returnable items.
  # Otherwise → up to 8 suggestions matching the typed text.
  def lookup_booking
    q = params[:q].to_s.strip
    return render(json: { suggestions: [] }) if q.length < 2

    booking = Booking.where('LOWER(booking_number) = ?', q.downcase).first
    booking ||= Booking.find_by(id: q.to_i) if q.match?(/\A\d+\z/)

    if booking
      render json: { booking: booking_payload(booking) }
    else
      like = "%#{q}%"
      matches = Booking.where('booking_number ILIKE :q OR customer_name ILIKE :q OR customer_phone ILIKE :q', q: like)
                       .order(created_at: :desc).limit(8)
      render json: {
        suggestions: matches.map do |b|
          { booking_number: b.booking_number, customer_name: b.customer_name, customer_phone: b.customer_phone,
            date: (b.booking_date || b.created_at)&.strftime('%d %b %Y'), total: b.total_amount.to_f }
        end
      }
    end
  end

  def create
    booking = Booking.find(params[:booking_id])
    lines = Array(params[:items]&.values).filter_map do |row|
      next unless row[:selected] == '1'

      { booking_item_id: row[:booking_item_id], quantity: row[:quantity], amount: row[:amount] }
    end

    note = CreditNote.issue!(
      booking: booking,
      lines: lines,
      user: current_user,
      attrs: params.permit(:credit_date, :refund_method, :reason, :notes).to_h.symbolize_keys
    )
    redirect_to admin_credit_note_path(note),
                notice: "Credit Note #{note.credit_note_number} saved — #{note.credit_note_items.size} item(s) returned to stock."
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_to new_admin_credit_note_path(booking: booking&.booking_number), alert: e.message
  end

  private

  def booking_payload(booking)
    returned = CreditNote.returned_quantities_for(booking)
    items = booking.booking_items.includes(:product, :product_variant).order(:id).map do |item|
      returned_qty = returned.fetch(item.id, 0.0)
      {
        id: item.id,
        name: item.product&.name,
        variant: item.product_variant&.label,
        image: product_image_url(item.product),
        quantity: item.quantity.to_f,
        returned: returned_qty,
        returnable: [item.quantity.to_f - returned_qty, 0].max,
        unit_price: item.discounted_unit_price.round(2),
        line_total: item.total.to_f
      }
    end

    {
      id: booking.id,
      booking_number: booking.booking_number,
      date: (booking.booking_date || booking.created_at)&.strftime('%d %b %Y'),
      customer_name: booking.customer&.display_name.presence || booking.customer_name,
      customer_phone: booking.customer_phone,
      store: booking.store&.name,
      status: booking.status_label,
      total_amount: booking.total_amount.to_f,
      previous_credit_total: booking.credit_notes.sum(:total_amount).to_f,
      items: items
    }
  end

  def product_image_url(product)
    product&.main_image_url.presence
  rescue StandardError
    nil
  end
end

# Admin app — dashboard numbers and dropdown values (statuses, stores, delivery people...).
class Api::V1::App::MetaController < Api::V1::App::BaseController
  before_action :require_admin!

  # GET /meta
  def show
    render_success({
      booking_statuses: Booking::STATUS_LABELS.map { |k, v| { value: k, label: v } },
      payment_statuses: Booking.payment_statuses.keys.map { |k| { value: k, label: k.humanize } },
      paid_via: Booking::PAID_VIA_OPTIONS.map { |k, v| { value: k, label: v } },
      purchase_payment_modes: VendorPurchase::PAYMENT_MODES.map { |k, v| { value: k, label: v } },
      stock_modes: StockAdjustment::MODES,
      stores: Store.where(status: true).order(:name).map { |s| { id: s.id, name: s.name } },
      delivery_persons: DeliveryPerson.where(status: true).order(:first_name).map { |d| { id: d.id, name: d.display_name, mobile: d.mobile } },
      categories: Category.order(:name).map { |c| { id: c.id, name: c.name } },
      invoice_due_days: SystemSetting.invoice_due_days.to_i
    })
  end

  # GET /dashboard
  def dashboard
    today = Date.current
    live = Booking.where.not(status: %w[draft cancelled returned refund])
    today_scope = live.where('COALESCE(booking_date, created_at) BETWEEN ? AND ?', today.beginning_of_day, today.end_of_day)
    month_scope = live.where('COALESCE(booking_date, created_at) >= ?', today.beginning_of_month.beginning_of_day)
    unpaid = live.where(payment_status: %w[unpaid partially_paid])
    paid_on_unpaid = Invoice.where(invoice_number: unpaid.where.not(invoice_number: nil).select(:invoice_number)).sum(:paid_amount).to_f
    low_stock = Product.active.where("(#{Product::REAL_STOCK_SQL}) <= COALESCE(products.low_stock_threshold, 0)")
                       .where('COALESCE(products.low_stock_threshold, 0) > 0').count

    render_success({
      today: { bookings: today_scope.count, amount: money(today_scope.sum(:total_amount)) },
      this_month: { bookings: month_scope.count, amount: money(month_scope.sum(:total_amount)) },
      delivery_pending: live.where(status: %w[ordered_and_delivery_pending packed shipped rescheduled reconfirm_order]).count,
      deliveries_today: live.where(expected_delivery_date: today).where.not(status: 'delivered').count,
      unpaid_bookings: unpaid.count,
      amount_due: money(unpaid.sum(:total_amount).to_f - paid_on_unpaid),
      low_stock_products: low_stock
    })
  end

  # GET /delivery_persons
  def delivery_persons
    rows = DeliveryPerson.order(:first_name).map do |d|
      { id: d.id, name: d.display_name, mobile: d.mobile, status: d.status, vehicle_type: d.vehicle_type,
        open_bookings: d.bookings.where.not(status: %w[delivered cancelled returned refund draft]).count,
        can_login: d.password_digest.present? }
    end
    render_success(rows)
  end
end

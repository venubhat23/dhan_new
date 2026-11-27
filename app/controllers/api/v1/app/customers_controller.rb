# Admin app — customers: search as you type, view, create, edit.
class Api::V1::App::CustomersController < Api::V1::App::BaseController
  before_action :require_admin!
  before_action :set_customer, only: [:show, :update]

  # GET /customers?q=kal&page=&per_page=
  def index
    scope = Customer.all
    if params[:q].present?
      q = "%#{Customer.sanitize_sql_like(params[:q].strip)}%"
      scope = scope.where('full_name ILIKE :q OR mobile ILIKE :q OR email ILIKE :q OR landmark ILIKE :q', q: q)
    end
    scope = scope.where(is_b2b: true) if params[:b2b] == '1'
    rows, meta = paginate(scope.order(:full_name))
    render_success(rows.map { |c| customer_json(c) }, meta: meta)
  end

  # GET /customers/:id — profile + recent bookings + amount due
  def show
    bookings = @customer.bookings.where.not(status: 'draft').includes(:delivery_person, :store)
                        .order(Arel.sql('COALESCE(booking_date, created_at) DESC')).limit(20)
    open = @customer.bookings.where(payment_status: %w[unpaid partially_paid]).where.not(status: %w[draft cancelled returned refund])
    paid_on_open = Invoice.where(invoice_number: open.where.not(invoice_number: nil).select(:invoice_number)).sum(:paid_amount).to_f
    render_success(customer_json(@customer, full: true).merge(
      total_bookings: @customer.bookings.where.not(status: 'draft').count,
      amount_due: money(open.sum(:total_amount).to_f - paid_on_open),
      recent_bookings: bookings.map { |b| booking_json(b) }
    ))
  end

  # POST /customers { "customer": { "full_name": "", "mobile": "", "email": "", "address": "",
  #   "landmark": "Jayanagar", "location_link": "", "is_b2b": false, "gst_no": "" } }
  # An existing mobile returns that customer (200) instead of failing.
  def create
    cp = customer_params
    digits = cp[:mobile].to_s.gsub(/\D/, '').last(10)
    existing = digits.length == 10 && Customer.where("RIGHT(REGEXP_REPLACE(mobile, '\\D', '', 'g'), 10) = ?", digits).first
    if existing
      return render_success(customer_json(existing, full: true), message: "Customer with this mobile already exists (#{existing.display_name})")
    end

    customer = Customer.new(cp)
    pwd = "#{digits.first(4)}@123"
    customer.password = pwd
    customer.password_confirmation = pwd
    customer.save!
    render_success(customer_json(customer, full: true), message: 'Customer created', status: :created)
  end

  # PATCH /customers/:id { "customer": { ... } }
  def update
    @customer.update!(customer_params)
    render_success(customer_json(@customer, full: true), message: 'Customer updated')
  end

  private

  def set_customer
    @customer = Customer.find(params[:id])
  end

  def customer_params
    params.require(:customer).permit(:full_name, :mobile, :email, :address, :shipping_address, :landmark, :location_link,
                                     :latitude, :longitude, :whatsapp_number, :is_b2b, :gst_no, :company_name, :notes)
  end
end

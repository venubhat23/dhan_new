class Admin::MobileUiController < ActionController::Base
  include ActionController::Flash
  include ActionController::RequestForgeryProtection
  include Rails.application.routes.url_helpers
  include ActionView::Helpers::NumberHelper

  layout 'mobile_ui'
  protect_from_forgery with: :exception

  MOBILE_USERNAME = 'admin'.freeze
  MOBILE_PASSWORD = 'admin123'.freeze

  before_action :authenticate_mobile!, except: [:login, :do_login]

  # ── Auth ──────────────────────────────────────────────────────────────────
  def login
    redirect_to admin_mobile_ui_bookings_path if session[:mobile_ui_auth]
  end

  def do_login
    if params[:username].to_s.strip == MOBILE_USERNAME &&
       params[:password].to_s == MOBILE_PASSWORD
      session[:mobile_ui_auth] = true
      redirect_to admin_mobile_ui_bookings_path
    else
      flash.now[:error] = 'Invalid username or password'
      render :login, status: :unprocessable_entity
    end
  end

  def logout
    session.delete(:mobile_ui_auth)
    redirect_to admin_mobile_ui_login_path
  end

  # ── Bookings list ─────────────────────────────────────────────────────────
  def index
    @bookings = Booking.includes(:customer, :booking_items, :booking_invoices)
                       .order(created_at: :desc)

    if params[:search].present?
      q = "%#{params[:search]}%"
      @bookings = @bookings.where(
        'booking_number LIKE ? OR customer_name LIKE ? OR customer_phone LIKE ?',
        q, q, q
      )
    end

    if params[:status].present? && params[:status] != ''
      @bookings = @bookings.where(status: params[:status])
    end

    @total = @bookings.count
    @bookings = @bookings.page(params[:page]).per(15)
  end

  # ── New Booking ───────────────────────────────────────────────────────────
  def new_booking
    @preselected_customer = Customer.find_by(id: params[:customer_id]) if params[:customer_id].present?
    @products = load_mobile_products
    @customers = Customer.select(:id, :first_name, :middle_name, :last_name, :email, :mobile)
                         .order(:first_name, :last_name)
  end

  def create_booking
    @booking = Booking.new(mobile_booking_params)
    @booking.booked_by = 'admin'
    @booking.booking_date = Time.current unless @booking.booking_date.present?
    @booking.status ||= 'completed'

    # Clean discount
    raw_discount = params.dig(:booking, :discount_amount).to_s.gsub(/\s+/, '').strip
    @booking.discount_amount = raw_discount.to_f > 0 ? raw_discount.to_f : 0

    payment_status_param = params.dig(:booking, :payment_status)

    if @booking.save
      # Re-calculate and set payment status
      @booking.calculate_totals
      @booking.payment_status = payment_status_param == 'paid' ? :paid : :unpaid
      @booking.save!

      # Generate invoice if paid
      invoice_notice = ""
      if @booking.payment_status_paid?
        invoice = @booking.generate_quick_invoice!
        if invoice
          invoice_notice = " Invoice ##{invoice.invoice_number} generated."
        else
          Rails.logger.warn "Mobile UI: Invoice generation returned nil for booking #{@booking.id}"
        end
      end

      redirect_to admin_mobile_ui_bookings_path,
                  notice: "Booking ##{@booking.booking_number} created successfully!#{invoice_notice}"
    else
      @products = load_mobile_products
      @customers = Customer.select(:id, :first_name, :middle_name, :last_name, :email, :mobile)
                           .order(:first_name, :last_name)
      @preselected_customer = Customer.find_by(id: mobile_booking_params[:customer_id])
      flash.now[:error] = @booking.errors.full_messages.join(', ')
      render :new_booking, status: :unprocessable_entity
    end
  end

  # ── Booking Show / Edit ───────────────────────────────────────────────────
  def show_booking
    @booking = Booking.includes(:customer, booking_items: :product, booking_invoices: []).find(params[:id])
  end

  def edit_booking
    @booking = Booking.includes(:customer, booking_items: :product).find(params[:id])
  end

  def update_booking
    @booking = Booking.find(params[:id])
    if @booking.update(mobile_update_booking_params)
      redirect_to admin_mobile_ui_show_booking_path(@booking), notice: 'Booking updated successfully.'
    else
      render :edit_booking, status: :unprocessable_entity
    end
  end

  # ── Price List ────────────────────────────────────────────────────────────
  def price_list
    products = Product.joins(:category)
                      .joins("LEFT JOIN stock_batches ON stock_batches.product_id = products.id
                              AND stock_batches.status = 'active'
                              AND stock_batches.quantity_remaining > 0
                              AND stock_batches.store_id IS NULL")
                      .select("products.*, COALESCE(SUM(stock_batches.quantity_remaining), 0) AS cached_stock,
                               categories.name AS cat_name")
                      .group("products.id, categories.id, categories.name")
                      .order("categories.name ASC, products.name ASC")

    if params[:category_id].present?
      products = products.where(products: { category_id: params[:category_id] })
    end

    if params[:search].present?
      q = "%#{params[:search]}%"
      products = products.where("products.name LIKE ? OR products.sku LIKE ?", q, q)
    end

    @categories = Category.order(:name)
    # Group by category_id so products sharing a category are correctly grouped
    @products_by_category = products.group_by { |p| [p.category_id, p.cat_name] }
  end

  # ── Quick Customer ────────────────────────────────────────────────────────
  def new_customer
    @customer = Customer.new
    @back_url = params[:back_url].presence || admin_mobile_ui_bookings_path
  end

  def create_customer
    @customer = Customer.new
    @customer.first_name = params[:customer][:first_name].to_s.strip
    @customer.mobile     = params[:customer][:mobile].to_s.strip
    @customer.email      = params[:customer][:email].to_s.strip.presence

    mobile_digits       = @customer.mobile.gsub(/\D/, '')
    generated_password  = "#{mobile_digits[0..3]}@123"
    @customer.password              = generated_password
    @customer.password_confirmation = generated_password

    if @customer.save
      redirect_to admin_mobile_ui_new_booking_path(customer_id: @customer.id),
                  notice: "Customer created! Now add products and complete the booking."
    else
      @back_url = params[:back_url].presence || admin_mobile_ui_bookings_path
      render :new_customer, status: :unprocessable_entity
    end
  end

  private

  def authenticate_mobile!
    redirect_to admin_mobile_ui_login_path unless session[:mobile_ui_auth]
  end

  def mobile_update_booking_params
    params.require(:booking).permit(:status, :payment_status, :payment_method, :notes, :discount_amount)
  end

  def mobile_booking_params
    params.require(:booking).permit(
      :customer_id, :customer_name, :customer_email, :customer_phone,
      :payment_method, :payment_status, :discount_amount, :notes,
      :delivery_address, :cash_received, :change_amount, :status, :booking_date,
      booking_items_attributes: [:product_id, :product_variant_id, :quantity, :price]
    )
  end

  def load_mobile_products
    Product.active
           .includes(:category, :product_variants, image_attachment: :blob)
           .joins("LEFT JOIN stock_batches ON stock_batches.product_id = products.id
                   AND stock_batches.status = 'active'
                   AND stock_batches.quantity_remaining > 0
                   AND stock_batches.store_id IS NULL")
           .select("products.*, COALESCE(SUM(stock_batches.quantity_remaining), 0) AS cached_stock")
           .group("products.id")
           .order(Arel.sql(
             "CASE WHEN COALESCE(SUM(stock_batches.quantity_remaining), 0) > 0 THEN 0 ELSE 1 END ASC,
              products.name ASC"
           ))
  end
end

class Admin::MobileUiController < ActionController::Base
  include ActionController::Flash
  include ActionController::RequestForgeryProtection
  include Rails.application.routes.url_helpers

  layout 'mobile_ui'
  protect_from_forgery with: :exception

  MOBILE_USERNAME = 'admin'.freeze
  MOBILE_PASSWORD = 'admin123'.freeze

  before_action :authenticate_mobile!, except: [:login, :do_login]

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

  def logout
    session.delete(:mobile_ui_auth)
    redirect_to admin_mobile_ui_login_path
  end

  private

  def authenticate_mobile!
    redirect_to admin_mobile_ui_login_path unless session[:mobile_ui_auth]
  end
end

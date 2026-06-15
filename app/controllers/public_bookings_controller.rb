class PublicBookingsController < ActionController::Base
  layout 'invoice'
  protect_from_forgery with: :exception

  def show
    @booking = Booking.includes(:customer, booking_items: [:product, :product_variant])
                      .find_by!(share_token: params[:token])
    @business = SystemSetting.business_settings
  rescue ActiveRecord::RecordNotFound
    render :not_found, status: :not_found
  end
end

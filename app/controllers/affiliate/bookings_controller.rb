class Affiliate::BookingsController < Affiliate::BaseController
  before_action :set_booking, only: [:show, :update]

  def index
    @bookings = Booking.joins(:customer)
                      .where(customers: { sub_agent_id: current_affiliate.id })
                      .includes(:customer, :booking_items)
                      .order(created_at: :desc)

    # Filter by status if provided
    if params[:status].present?
      @bookings = @bookings.where(status: params[:status])
    end

    # Search functionality
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @bookings = @bookings.where(
        "booking_number ILIKE ? OR customers.full_name ILIKE ? OR customers.email ILIKE ?",
        search_term, search_term, search_term
      )
    end

    @bookings = @bookings.page(params[:page]).per(20)

    # Stats for the page
    @total_count = Booking.joins(:customer).where(customers: { sub_agent_id: current_affiliate.id }).count
    @pending_count = Booking.joins(:customer).where(customers: { sub_agent_id: current_affiliate.id }, status: 'pending').count
    @processing_count = Booking.joins(:customer).where(customers: { sub_agent_id: current_affiliate.id }, status: 'processing').count
    @delivered_count = Booking.joins(:customer).where(customers: { sub_agent_id: current_affiliate.id }, status: 'delivered').count
  end

  def show
    @customer = @booking.customer
    @booking_items = @booking.booking_items.includes(:product)
  end

  def update
    if @booking.update(booking_params)
      redirect_to affiliate_booking_path(@booking), notice: 'Booking updated successfully'
    else
      redirect_to affiliate_booking_path(@booking), alert: 'Failed to update booking'
    end
  end

  private

  def set_booking
    @booking = Booking.joins(:customer)
                     .where(customers: { sub_agent_id: current_affiliate.id })
                     .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to affiliate_bookings_path, alert: 'Booking not found'
  end

  def booking_params
    params.require(:booking).permit(:status, :notes)
  end
end
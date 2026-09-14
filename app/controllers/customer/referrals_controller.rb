class Customer::ReferralsController < Customer::BaseController
  before_action :set_referral, only: [:show, :destroy]
  before_action :authenticate_customer!

  # GET /customer/referrals
  def index
    @referrals = current_customer.referrals
                                .includes(:customer)
                                .order(created_at: :desc)
                                .page(params[:page])
                                .per(10)

    # Calculate statistics — one GROUP BY instead of 4 separate COUNTs
    status_counts = current_customer.referrals.reorder('').group(:status).count
    @total_referrals = status_counts.values.sum
    @pending_referrals = status_counts['pending'].to_i
    @registered_referrals = status_counts['registered'].to_i
    @converted_referrals = status_counts['converted'].to_i
    @conversion_rate = calculate_conversion_rate
  end

  # GET /customer/referrals/1
  def show
  end

  # GET /customer/referrals/new
  def new
    @referral = current_customer.referrals.build
  end

  # POST /customer/referrals
  def create
    @referral = current_customer.referrals.build(referral_params)

    if @referral.save
      redirect_to success_customer_referrals_path, notice: 'Referral was successfully created! Your friend will be contacted soon.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  # DELETE /customer/referrals/1
  def destroy
    @referral.destroy
    redirect_to customer_referrals_path, notice: 'Referral was successfully deleted.'
  end

  # GET /customer/referrals/success
  def success
    @latest_referral = current_customer.referrals.order(:created_at).last
  end

  private

  def set_referral
    @referral = current_customer.referrals.find(params[:id])
  end

  def referral_params
    params.require(:referral).permit(:referred_name, :referred_email, :referred_mobile, :notes)
  end

  def calculate_conversion_rate
    return 0 if @total_referrals == 0
    ((@converted_referrals.to_f / @total_referrals) * 100).round(1)
  end
end
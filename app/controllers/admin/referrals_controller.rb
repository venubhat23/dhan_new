class Admin::ReferralsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_referral, only: [:show, :update, :destroy, :mark_registered, :mark_converted]

  # GET /admin/referrals
  def index
    @referrals = Referral.includes(:affiliate, :referring_customer, :customer)
                        .order(created_at: :desc)

    # Filter by referral source (affiliate or customer)
    if params[:source].present?
      case params[:source]
      when 'customer'
        @referrals = @referrals.customer_referrals
      when 'affiliate'
        @referrals = @referrals.affiliate_referrals
      end
    end

    # Filter by status if specified
    if params[:status].present?
      @referrals = @referrals.where(status: params[:status])
    end

    # Add basic search functionality
    if params[:search].present?
      search_term = "%#{params[:search].downcase}%"
      @referrals = @referrals.where(
        "LOWER(referred_name) LIKE ? OR LOWER(referred_email) LIKE ? OR LOWER(referred_mobile) LIKE ?",
        search_term, search_term, search_term
      )
    end

    # Add pagination manually (25 per page)
    @referrals = @referrals.limit(25).offset((params[:page]&.to_i || 0) * 25)

    # Calculate statistics
    @stats = {
      total: Referral.count,
      customer_referrals: Referral.customer_referrals.count,
      affiliate_referrals: Referral.affiliate_referrals.count,
      pending: Referral.pending.count,
      registered: Referral.registered.count,
      converted: Referral.converted.count,
      conversion_rate: calculate_conversion_rate
    }
  end

  # GET /admin/referrals/1
  def show
  end

  # PATCH/PUT /admin/referrals/1
  def update
    if @referral.update(referral_params)
      redirect_to admin_referral_path(@referral), notice: 'Referral was successfully updated.'
    else
      render :show, status: :unprocessable_entity
    end
  end

  # DELETE /admin/referrals/1
  def destroy
    @referral.destroy
    redirect_to admin_referrals_path, notice: 'Referral was successfully deleted.'
  end

  # PATCH /admin/referrals/1/mark_registered
  def mark_registered
    if params[:customer_id].present?
      customer = Customer.find(params[:customer_id])
      @referral.mark_as_registered!(customer)
      redirect_to admin_referral_path(@referral), notice: 'Referral marked as registered successfully.'
    else
      redirect_to admin_referral_path(@referral), alert: 'Customer must be selected to mark as registered.'
    end
  end

  # PATCH /admin/referrals/1/mark_converted
  def mark_converted
    @referral.mark_as_converted!
    redirect_to admin_referral_path(@referral), notice: 'Referral marked as converted successfully.'
  end

  # GET /admin/referrals/affiliate_referrals
  def affiliate_referrals
    @referrals = Referral.affiliate_referrals
                        .includes(:affiliate, :referring_customer, :customer)
                        .order(created_at: :desc)

    # Filter by status if specified
    if params[:status].present?
      @referrals = @referrals.where(status: params[:status])
    end

    # Add basic search functionality
    if params[:search].present?
      search_term = "%#{params[:search].downcase}%"
      @referrals = @referrals.where(
        "LOWER(referred_name) LIKE ? OR LOWER(referred_email) LIKE ? OR LOWER(referred_mobile) LIKE ?",
        search_term, search_term, search_term
      )
    end

    # Add pagination manually (25 per page)
    @referrals = @referrals.limit(25).offset((params[:page]&.to_i || 0) * 25)

    # Calculate statistics for affiliate referrals only
    @stats = {
      total: Referral.affiliate_referrals.count,
      affiliate_referrals: Referral.affiliate_referrals.count,
      pending: Referral.affiliate_referrals.pending.count,
      registered: Referral.affiliate_referrals.respond_to?(:registered) ? Referral.affiliate_referrals.registered.count : 0,
      converted: Referral.affiliate_referrals.respond_to?(:converted) ? Referral.affiliate_referrals.converted.count : 0,
      conversion_rate: calculate_affiliate_conversion_rate
    }

    render :index
  end

  # GET /admin/referrals/analytics
  def analytics
    @date_range = params[:date_range] || '30_days'

    case @date_range
    when '7_days'
      start_date = 7.days.ago
    when '30_days'
      start_date = 30.days.ago
    when '90_days'
      start_date = 90.days.ago
    when '1_year'
      start_date = 1.year.ago
    else
      start_date = 30.days.ago
    end

    @referrals_data = {
      total_in_period: Referral.where(created_at: start_date..).count,
      customer_referrals_in_period: Referral.customer_referrals.where(created_at: start_date..).count,
      affiliate_referrals_in_period: Referral.affiliate_referrals.where(created_at: start_date..).count,
      conversions_in_period: Referral.converted.where(created_at: start_date..).count,
      conversion_rate_in_period: calculate_conversion_rate(start_date)
    }

    # Daily breakdown for charts
    @daily_referrals = Referral.where(created_at: start_date..)
                               .group_by_day(:created_at, range: start_date..Date.current)
                               .count

    @daily_conversions = Referral.converted
                                .where(created_at: start_date..)
                                .group_by_day(:created_at, range: start_date..Date.current)
                                .count

    # Top referrers
    @top_customer_referrers = Customer.joins(:referrals)
                                    .group('customers.id', 'customers.first_name', 'customers.last_name')
                                    .order('COUNT(referrals.id) DESC')
                                    .limit(10)
                                    .count

    @top_affiliate_referrers = Affiliate.joins(:referrals)
                                      .group('affiliates.id', 'affiliates.first_name', 'affiliates.last_name')
                                      .order('COUNT(referrals.id) DESC')
                                      .limit(10)
                                      .count
  end

  private

  def set_referral
    @referral = Referral.find(params[:id])
  end

  def referral_params
    params.require(:referral).permit(:status, :notes)
  end

  def calculate_conversion_rate(start_date = nil)
    if start_date
      total = Referral.where(created_at: start_date..).count
      converted = Referral.converted.where(created_at: start_date..).count
    else
      total = Referral.count
      converted = Referral.converted.count
    end

    return 0 if total == 0
    ((converted.to_f / total) * 100).round(2)
  end

  def calculate_affiliate_conversion_rate
    total = Referral.affiliate_referrals.count
    converted = Referral.affiliate_referrals.respond_to?(:converted) ? Referral.affiliate_referrals.converted.count : 0

    return 0 if total == 0
    ((converted.to_f / total) * 100).round(2)
  end
end
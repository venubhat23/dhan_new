class Affiliate::ApplicationController < ApplicationController
  layout 'affiliate'
  skip_load_and_authorize_resource
  before_action :authenticate_affiliate!
  before_action :set_current_affiliate

  private

  def authenticate_affiliate!
    unless user_signed_in? && current_user.user_type == 'affiliate'
      redirect_to affiliate_login_path, alert: 'Please log in to access your affiliate account.'
    end
  end

  def set_current_affiliate
    if current_user&.user_type == 'affiliate'
      @current_affiliate = current_user.authenticatable || Affiliate.find_by(email: current_user.email)

      # Repair missing polymorphic link for legacy records
      if @current_affiliate && current_user.authenticatable.nil?
        current_user.update_columns(authenticatable_type: 'Affiliate', authenticatable_id: @current_affiliate.id)
      end
    end
  end

  def current_affiliate
    @current_affiliate
  end
  helper_method :current_affiliate
end
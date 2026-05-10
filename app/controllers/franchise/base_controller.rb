class Franchise::BaseController < ApplicationController
  layout 'franchise'

  # Skip ApplicationController filters for franchise authentication
  skip_before_action :authenticate_user!
  skip_before_action :ensure_session_security

  # Override CanCan methods to prevent resource loading issues
  def load_and_authorize_resource
    # Do nothing for franchise controllers
  end

  def should_authorize?
    false
  end

  before_action :authenticate_franchise

  private

  def authenticate_franchise
    unless current_franchise
      redirect_to franchise_login_path, alert: 'Please log in to continue'
    end
  end

  def current_franchise
    if session[:franchise_id] && session[:user_id]
      @current_user ||= User.find_by(id: session[:user_id])
      @current_franchise ||= @current_user&.franchise if @current_user&.franchise?
    end
  end

  helper_method :current_franchise
end
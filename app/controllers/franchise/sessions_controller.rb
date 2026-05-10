class Franchise::SessionsController < ApplicationController
  layout 'affiliate_auth', except: [:new]
  layout false, only: [:new]

  # Skip all ApplicationController filters for franchise authentication
  skip_before_action :authenticate_user!
  skip_before_action :ensure_session_security
  skip_before_action :verify_authenticity_token, only: [:create]

  # Override the load_and_authorize_resource method to prevent CanCan from interfering
  def load_and_authorize_resource
    # Do nothing for franchise sessions
  end

  # Override should_authorize? to prevent CanCan authorization
  def should_authorize?
    false
  end

  before_action :redirect_if_authenticated, only: [:new, :create]
  before_action :authenticate_franchise, only: [:destroy]

  def new
    # Clear any existing Devise sessions to prevent interference
    sign_out(current_user) if current_user
    reset_session
    @franchise = Franchise.new
  end

  def create
    # Find user by email (supports email and mobile login)
    user = User.find_for_database_authentication(login: franchise_params[:email])

    if user&.valid_password?(franchise_params[:password])
      if user.franchise? && user.active?
        # Check if franchise record exists and is active
        franchise = user.franchise
        if franchise&.active?
          session[:franchise_id] = franchise.id
          session[:franchise_type] = 'franchise'
          session[:user_id] = user.id
          redirect_to franchise_dashboard_path, notice: 'Successfully logged in!'
        else
          @franchise = Franchise.new
          flash.now[:alert] = 'Your franchise account is inactive. Please contact administrator.'
          render :new
        end
      else
        @franchise = Franchise.new
        flash.now[:alert] = 'Access denied. This login is for franchise users only.'
        render :new
      end
    else
      @franchise = Franchise.new
      flash.now[:alert] = 'Invalid email or password'
      render :new
    end
  end

  def destroy
    session[:franchise_id] = nil
    session[:franchise_type] = nil
    session[:user_id] = nil
    redirect_to franchise_login_path, notice: 'Successfully logged out!'
  end

  private

  def franchise_params
    params.require(:franchise).permit(:email, :password)
  end

  def redirect_if_authenticated
    if current_franchise
      redirect_to franchise_dashboard_path
    end
  end

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
end
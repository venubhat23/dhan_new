class ApplicationController < ActionController::Base
  # Browser compatibility check disabled - allow all browsers
  # allow_browser versions: :modern

  # Include exception handler for API
  include ExceptionHandler

  # Security headers and cache control
  before_action :set_cache_control_headers
  before_action :ensure_session_security

  # Devise authentication (skip for mobile API)
  before_action :authenticate_user!, unless: :mobile_api?
  before_action :configure_permitted_parameters, if: :devise_controller?

  # Authorization
  load_and_authorize_resource unless: :devise_controller?, if: :should_authorize?

  rescue_from CanCan::AccessDenied do |exception|
    redirect_to root_path, alert: exception.message
  end

  protected

  def after_sign_in_path_for(resource)
    # Special handling for franchise users - redirect directly to bookings
    if resource.franchise?
      franchise_dashboard_path
    elsif resource.has_sidebar_permission?('dashboard')
      root_path  # Dashboard
    else
      # Find first available sidebar page for the user
      redirect_to_first_available_page(resource)
    end
  end

  def redirect_to_first_available_page(user)
    # Define available routes in order of preference
    available_routes = [
      { permission: 'bookings', path: -> { admin_bookings_path } },
      { permission: 'customers', path: -> { admin_customers_path } },
      { permission: 'products', path: -> { admin_products_path } },
      { permission: 'categories', path: -> { admin_categories_path } },
      { permission: 'vendors', path: -> { admin_vendors_path } },
      { permission: 'vendor_purchases', path: -> { admin_vendor_purchases_path } },
      { permission: 'invoices', path: -> { admin_invoices_path } },
      { permission: 'subscriptions', path: -> { admin_subscriptions_path } },
      { permission: 'reports', path: -> { admin_reports_enhanced_sales_path } },
      { permission: 'stores', path: -> { admin_stores_path } },
      { permission: 'delivery_people', path: -> { admin_delivery_people_path } },
      { permission: 'franchises', path: -> { admin_franchises_path } },
      { permission: 'affiliates', path: -> { admin_affiliates_path } },
      { permission: 'system_settings', path: -> { admin_settings_system_path } },
      { permission: 'user_roles', path: -> { admin_settings_user_roles_path } },
      { permission: 'banners', path: -> { admin_banners_path } }
    ]

    # Find first available route
    available_routes.each do |route|
      if user.has_sidebar_permission?(route[:permission])
        return route[:path].call
      end
    end

    # Fallback - if user has no permissions, redirect to a safe page
    root_path
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_in, keys: [:login])
    devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name, :last_name, :mobile, :user_type, :role, :status])
    devise_parameter_sanitizer.permit(:account_update, keys: [:first_name, :last_name, :mobile, :user_type, :role, :pan_number, :gst_number, :date_of_birth, :gender, :height, :weight, :education, :marital_status, :occupation, :job_name, :type_of_duty, :annual_income, :birth_place, :address, :state, :city])
  end

  def current_ability
    @current_ability ||= Ability.new(current_user)
  end

  def should_authorize?
    # Skip authorization for admin controllers if user is admin
    if self.class.name.start_with?('Admin::') && (current_user&.admin? || current_user&.user_type == 'admin')
      return false
    end
    # Skip authorization for vendor invoices public view
    if controller_name == 'vendor_invoices' && action_name == 'public_view'
      return false
    end
    true
  end

  private

  def set_cache_control_headers
    # Strong cache prevention for all authenticated pages
    # Skip for franchise controllers to avoid session interference
    unless controller_name == 'sessions' && params[:controller]&.include?('franchise')
      if user_signed_in?
        response.headers['Cache-Control'] = 'no-cache, no-store, must-revalidate, private, max-age=0'
        response.headers['Pragma'] = 'no-cache'
        response.headers['Expires'] = 'Thu, 01 Jan 1970 00:00:00 GMT'

        # Additional headers to prevent browser caching
        response.headers['Last-Modified'] = Time.current.httpdate
        response.headers['ETag'] = SecureRandom.hex(16)
      end
    end
  end

  def ensure_session_security
    # Enhanced session security with multiple validation layers
    if user_signed_in? && current_user
      # Validate session integrity
      current_session_id = session.id.to_s
      stored_session_id = session[:session_id]

      # Check for session hijacking or replay attacks
      if stored_session_id && stored_session_id != current_session_id
        handle_session_security_breach
        return
      end

      # Set or verify session markers
      session[:session_id] = current_session_id
      session[:user_authenticated] = current_user.id
      session[:last_activity] = Time.current.to_i

      # Validate session age (prevent old session reuse)
      login_time = session[:login_time]
      if login_time && (Time.current.to_i - login_time) > 24.hours
        handle_session_expiry
        return
      end

      # Check for suspicious activity patterns
      if detect_suspicious_navigation?
        handle_suspicious_activity
        return
      end

    elsif !devise_controller? && !is_public_action?
      # Clear any stale session data for unauthenticated access
      clear_session_data
    end
  end

  def is_public_action?
    # Define actions that don't require authentication
    public_controllers = [
      'sessions', 'devise/sessions', 'registrations', 'devise/registrations',
      'public_pages', 'api/cities', 'booking_invoices', 'public_invoices', 'home'
    ]
    public_controllers.any? { |controller| self.class.name.downcase.include?(controller) }
  end

  def handle_session_security_breach
    Rails.logger.warn "Session security breach detected for user #{current_user&.id}: Session ID mismatch"
    clear_session_data
    sign_out(current_user) if current_user
    redirect_to new_sessions_path, alert: 'Security breach detected. Please login again.'
  end

  def handle_session_expiry
    Rails.logger.info "Session expired for user #{current_user&.id}"
    clear_session_data
    sign_out(current_user) if current_user
    redirect_to new_sessions_path, alert: 'Your session has expired. Please login again.'
  end

  def handle_suspicious_activity
    Rails.logger.warn "Suspicious navigation detected for user #{current_user&.id}"
    clear_session_data
    sign_out(current_user) if current_user
    redirect_to new_sessions_path, alert: 'Suspicious activity detected. Please login again.'
  end

  def detect_suspicious_navigation?
    # Check if user came from browser back/forward navigation after logout
    return false unless session[:last_activity]

    # Check for rapid navigation patterns (back button abuse)
    last_activity_time = session[:last_activity]
    current_time = Time.current.to_i

    # If more than 30 seconds of inactivity, require fresh validation
    if (current_time - last_activity_time) > 30
      # Check if this looks like a cached page access
      user_agent = request.headers['User-Agent']
      referer = request.headers['Referer']

      # Detect browser navigation patterns
      if referer.blank? || referer.include?('sign_in') || referer.include?('login')
        return true
      end
    end

    false
  end

  def clear_session_data
    session.delete(:user_authenticated)
    session.delete(:login_time)
    session.delete(:last_activity)
    session.delete(:session_id)
  end

  # Mobile API helper methods
  def mobile_api?
    request.path.start_with?('/api/v1/mobile') || params[:controller]&.include?('mobile')
  end

  def authenticate_mobile_token!
    token = extract_token_from_header

    return render_unauthorized('Token not provided') unless token

    begin
      decoded_token = JWT.decode(token, Rails.application.secret_key_base, true, algorithm: 'HS256')
      @current_mobile_user_id = decoded_token[0]['account_id']
      @current_mobile_user_type = decoded_token[0]['account_type']

      case @current_mobile_user_type
      when 'customer'
        @current_customer = Customer.find_by(id: @current_mobile_user_id)
        return render_unauthorized('Customer not found') unless @current_customer
      when 'delivery_person'
        @current_delivery_person = DeliveryPerson.find_by(id: @current_mobile_user_id)
        return render_unauthorized('Delivery person not found') unless @current_delivery_person
      else
        return render_unauthorized('Invalid account type')
      end

    rescue JWT::ExpiredSignature
      render_unauthorized('Token has expired')
    rescue JWT::DecodeError
      render_unauthorized('Invalid token')
    rescue => e
      Rails.logger.error "Mobile token authentication error: #{e.message}"
      render_unauthorized('Authentication failed')
    end
  end

  def extract_token_from_header
    header = request.headers['Authorization']
    header&.split(' ')&.last
  end

  def render_unauthorized(message = 'Unauthorized access')
    render json: {
      success: false,
      message: message
    }, status: :unauthorized
  end

  def generate_mobile_jwt_token(account, account_type)
    payload = {
      account_id: account.id,
      account_type: account_type,
      exp: 30.days.from_now.to_i,
      iat: Time.current.to_i
    }

    JWT.encode(payload, Rails.application.secret_key_base, 'HS256')
  end

  def format_mobile_number(mobile)
    return nil if mobile.blank?
    # Remove all non-digit characters
    clean_mobile = mobile.to_s.gsub(/\D/, '')

    # Handle different mobile number formats
    if clean_mobile.length == 10 && clean_mobile.match?(/\A[6-9]\d{9}\z/)
      return clean_mobile
    elsif clean_mobile.length == 12 && clean_mobile.start_with?('91') && clean_mobile[2..-1].match?(/\A[6-9]\d{9}\z/)
      return clean_mobile[2..-1]
    elsif clean_mobile.length == 13 && clean_mobile.start_with?('+91')
      return clean_mobile[3..-1]
    else
      return nil
    end
  end
end

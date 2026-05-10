# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  # GET /resource/sign_in
  def new
    super
  end

  # POST /resource/sign_in
  def create
    # Check credentials before calling super
    email = params[resource_name]&.dig(:login) || params[resource_name]&.dig(:email)
    password = params[resource_name]&.dig(:password)

    Rails.logger.info "Login attempt for email: #{email}"

    # Validate inputs first
    if email.blank? || password.blank?
      flash.now[:alert] = 'Please enter both email and password'
      self.resource = resource_class.new
      render :new and return
    end

    # Check if user exists
    user = User.find_by(email: email)
    if user.nil?
      flash.now[:alert] = 'No account found with this email address'
      self.resource = resource_class.new(sign_in_params)
      render :new and return
    end

    # Check password
    if !user.valid_password?(password)
      flash.now[:alert] = 'Incorrect password. Please try again.'
      self.resource = resource_class.new(sign_in_params)
      render :new and return
    end

    # Check if user is active/enabled
    unless user.status?
      flash.now[:alert] = 'Your account has been deactivated. Please contact support.'
      self.resource = resource_class.new(sign_in_params)
      render :new and return
    end

    # If we get here, credentials are valid - proceed with Devise
    super do |resource|
      if resource.persisted?
        Rails.logger.info "User #{resource.id} signed in successfully"
      end
    end
  end

  # DELETE /resource/sign_out
  def destroy
    super
  end

  protected

  # Override to add custom flash messages
  def auth_options
    { scope: resource_name, recall: "#{controller_path}#new" }
  end

  # If you have extra params to permit, append them to the sanitizer.
  def configure_sign_in_params
    devise_parameter_sanitizer.permit(:sign_in, keys: [:attribute])
  end

  # Custom failure handling
  def after_sign_in_path_for(resource)
    if resource.store_admin?
      store_admin_root_path
    else
      stored_location_for(resource) || dashboard_path
    end
  end

  def after_sign_out_path_for(resource_or_scope)
    new_user_session_path
  end
end
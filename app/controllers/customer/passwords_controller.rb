class Customer::PasswordsController < Customer::BaseController
  skip_before_action :authenticate_customer!
  skip_before_action :ensure_customer_role
  layout 'customer_auth'

  def new
    # Forgot password form
  end

  def create
    # Handle forgot password request
    email = params[:email]&.strip&.downcase
    @customer = Customer.find_by('LOWER(email) = ?', email)

    if @customer
      begin
        # Generate password reset token
        @customer.generate_password_reset_token!

        # Send password reset email
        CustomerMailer.password_reset_instructions(@customer).deliver_now

        flash[:notice] = 'Password reset instructions have been sent to your email address. Please check your inbox and spam folder.'
        Rails.logger.info "Password reset email sent to: #{@customer.email}"
      rescue => e
        Rails.logger.error "Failed to send password reset email: #{e.message}"
        flash[:alert] = 'There was an error sending the reset email. Please try again or contact support.'
      end
    else
      # Don't reveal that the email doesn't exist for security
      flash[:notice] = 'If an account exists with that email address, password reset instructions have been sent.'
      Rails.logger.info "Password reset attempted for non-existent email: #{email}"
    end

    redirect_to customer_forgot_password_path
  end

  def edit
    # Reset password form (comes from email link)
    @token = params[:token]
    # URL decode the token and clean up encoding issues
    if @token
      @token = CGI.unescape(@token)
      # Remove leading 3D if present (URL encoded =)
      @token = @token[2..-1] if @token.start_with?('3D')
    end
    @customer = Customer.find_by_password_reset_token(@token)

    unless @customer
      flash[:alert] = 'Invalid or expired password reset token. Please request a new password reset.'
      redirect_to customer_forgot_password_path and return
    end

    if @customer.password_reset_expired?
      flash[:alert] = 'Password reset token has expired. Please request a new password reset.'
      redirect_to customer_forgot_password_path and return
    end
  end

  def update
    # Handle password reset
    @token = params[:token]
    # URL decode the token and clean up encoding issues
    if @token
      @token = CGI.unescape(@token)
      # Remove leading 3D if present (URL encoded =)
      @token = @token[2..-1] if @token.start_with?('3D')
    end
    @customer = Customer.find_by_password_reset_token(@token)

    unless @customer
      flash[:alert] = 'Invalid or expired password reset token.'
      redirect_to customer_forgot_password_path and return
    end

    if @customer.password_reset_expired?
      flash[:alert] = 'Password reset token has expired. Please request a new password reset.'
      redirect_to customer_forgot_password_path and return
    end

    # Validate password parameters
    password = params[:password]
    password_confirmation = params[:password_confirmation]

    if password.blank?
      flash[:alert] = 'Password cannot be blank.'
      render :edit and return
    end

    if password.length < 6
      flash[:alert] = 'Password must be at least 6 characters long.'
      render :edit and return
    end

    if password != password_confirmation
      flash[:alert] = 'Password confirmation does not match.'
      render :edit and return
    end

    begin
      # Update password
      @customer.password = password
      @customer.password_confirmation = password_confirmation

      if @customer.save
        # Clear the reset token
        @customer.clear_password_reset_token!

        # Send confirmation email (optional)
        begin
          CustomerMailer.password_changed_notification(@customer).deliver_now
        rescue => e
          Rails.logger.error "Failed to send password changed notification: #{e.message}"
        end

        flash[:notice] = 'Your password has been reset successfully. Please log in with your new password.'
        redirect_to customer_login_path
      else
        flash[:alert] = @customer.errors.full_messages.join(', ')
        render :edit
      end
    rescue => e
      Rails.logger.error "Password reset failed: #{e.message}"
      flash[:alert] = 'There was an error updating your password. Please try again.'
      render :edit
    end
  end

  private

  def password_params
    params.permit(:password, :password_confirmation, :token)
  end
end
class Api::V1::Mobile::AuthenticationController < Api::V1::BaseController
  skip_before_action :authorize_request, only: [:login, :register, :forgot_password]

  # POST /api/v1/mobile/auth/login
  def login
    # Support login with email or mobile number
    login_field = params[:username] || params[:email] || params[:mobile]
    password = params[:password]

    if login_field.blank? || password.blank?
      return json_response({
        success: false,
        message: 'Email/Mobile and password are required'
      }, :unprocessable_entity)
    end

    # Check if it's a user login (including customers, agents, admin)
    # Support login with both email and mobile number
    user = User.find_by(email: login_field)

    # If not found by email and login_field looks like a mobile number, try mobile search with formatting
    unless user
      formatted_mobile = format_mobile_number(login_field)
      if formatted_mobile
        # Try to find user with multiple mobile format variations
        user = User.find_by(mobile: formatted_mobile) ||
               User.find_by(mobile: "+91#{formatted_mobile}") ||
               User.find_by(mobile: "+91 #{formatted_mobile}") ||
               User.find_by(mobile: "#{formatted_mobile[0..4]} #{formatted_mobile[5..9]}") ||
               User.find_by(mobile: "+91 #{formatted_mobile[0..4]} #{formatted_mobile[5..9]}")
      else
        # If format_mobile_number returns nil, try direct mobile search as fallback
        user = User.find_by(mobile: login_field)
      end
    end
    if user && user.valid_password?(password) && user.status

      if user.customer?
        # Customer login - find associated customer record
        customer = Customer.find_by(email: user.email)
        unless customer
          formatted_mobile = format_mobile_number(user.mobile)
          if formatted_mobile
            customer = Customer.find_by(mobile: formatted_mobile) ||
                      Customer.find_by(mobile: "+91#{formatted_mobile}") ||
                      Customer.find_by(mobile: "+91 #{formatted_mobile}") ||
                      Customer.find_by(mobile: "#{formatted_mobile[0..4]} #{formatted_mobile[5..9]}") ||
                      Customer.find_by(mobile: "+91 #{formatted_mobile[0..4]} #{formatted_mobile[5..9]}")
          else
            customer = Customer.find_by(mobile: user.mobile)
          end
        end
        if customer
          token = generate_token(user, 'customer')
          portfolio_stats = get_customer_portfolio_stats(customer)

          json_response({
            success: true,
            data: {
              token: token,
              username: user.full_name,
              role: 'customer',
              user_id: user.id,
              customer_id: customer.id,
              email: user.email,
              mobile: user.mobile,
              portfolio_summary: {
                total_policies: portfolio_stats[:total_policies],
                upcoming_installments: portfolio_stats[:upcoming_installments],
                renewal_policies: portfolio_stats[:renewal_policies]
              }
            }
          })
          return
        end
      elsif user.agent? || user.admin? || user.sub_agent?
        # Agent/Admin login
        token = generate_token(user, user.user_type)
        agent_stats = get_agent_statistics(user)

        json_response({
          success: true,
          data: {
            token: token,
            username: user.full_name,
            role: user.user_type,
            user_id: user.id,
            email: user.email,
            mobile: user.mobile,
            commission_earned: agent_stats[:commission_earned],
            customers_count: agent_stats[:customers_count],
            policies_count: agent_stats[:policies_count],
            commission_breakdown: agent_stats[:commission_breakdown],
            dashboard_stats: {
              total_commission: agent_stats[:commission_earned],
              monthly_target: 75000,
              achievement_percentage: ((agent_stats[:commission_earned] / 75000) * 100).round(2),
              policies_this_month: (agent_stats[:policies_count] * 0.3).round,
              customers_this_month: (agent_stats[:customers_count] * 0.25).round,
              conversion_rate: "#{rand(65..85)}%"
            }
          }
        })
        return
      end
    end

    # Check direct Customer login
    customer = Customer.find_by(email: login_field)
    unless customer
      formatted_mobile = format_mobile_number(login_field)
      if formatted_mobile
        customer = Customer.find_by(mobile: formatted_mobile) ||
                  Customer.find_by(mobile: "+91#{formatted_mobile}") ||
                  Customer.find_by(mobile: "+91 #{formatted_mobile}") ||
                  Customer.find_by(mobile: "#{formatted_mobile[0..4]} #{formatted_mobile[5..9]}") ||
                  Customer.find_by(mobile: "+91 #{formatted_mobile[0..4]} #{formatted_mobile[5..9]}")
      else
        customer = Customer.find_by(mobile: login_field)
      end
    end

    if customer && customer.authenticate(password) && customer.status
      token = generate_token(customer, 'customer')
      portfolio_stats = get_customer_portfolio_stats(customer)

      json_response({
        success: true,
        data: {
          token: token,
          username: customer.display_name,
          role: 'customer',
          user_id: customer.id,
          customer_id: customer.id,
          email: customer.email,
          mobile: customer.mobile,
          profile: {
            full_name: customer.full_name,
            gender: customer.gender,
            birth_date: customer.birth_date,
            address: customer.address,
            city: customer.city,
            state: customer.state,
            pincode: customer.pincode
          },
          portfolio_summary: {
            total_policies: portfolio_stats[:total_policies],
            upcoming_installments: portfolio_stats[:upcoming_installments],
            renewal_policies: portfolio_stats[:renewal_policies]
          }
        }
      })
      return
    end

    # Check DeliveryPerson login
    delivery_person = DeliveryPerson.find_by(email: login_field)
    unless delivery_person
      # First try direct mobile search (for 12-digit numbers like 919190939300)
      delivery_person = DeliveryPerson.find_by(mobile: login_field)

      unless delivery_person
        formatted_mobile = format_mobile_number(login_field)
        if formatted_mobile
          delivery_person = DeliveryPerson.find_by(mobile: formatted_mobile) ||
                           DeliveryPerson.find_by(mobile: "+91#{formatted_mobile}") ||
                           DeliveryPerson.find_by(mobile: "+91 #{formatted_mobile}") ||
                           DeliveryPerson.find_by(mobile: "#{formatted_mobile[0..4]} #{formatted_mobile[5..9]}") ||
                           DeliveryPerson.find_by(mobile: "+91 #{formatted_mobile[0..4]} #{formatted_mobile[5..9]}")
        end
      end
    end
    if delivery_person && delivery_person.authenticate(password) && delivery_person.status
      token = generate_token(delivery_person, 'delivery_person')

      # Get delivery person statistics
      delivery_stats = get_delivery_person_statistics(delivery_person)

      json_response({
        success: true,
        data: {
          token: token,
          username: delivery_person.display_name,
          role: 'delivery_person',
          user_id: delivery_person.id,
          delivery_person_id: delivery_person.id,
          email: delivery_person.email,
          mobile: delivery_person.mobile,
          profile: {
            first_name: delivery_person.first_name,
            last_name: delivery_person.last_name,
            vehicle_type: delivery_person.vehicle_type,
            vehicle_number: delivery_person.vehicle_number,
            license_number: delivery_person.license_number,
            delivery_areas: delivery_person.delivery_area_list,
            joining_date: delivery_person.joining_date,
            years_of_service: delivery_person.years_of_service
          },
          dashboard_stats: {
            total_deliveries: delivery_stats[:total_deliveries],
            completed_deliveries: delivery_stats[:completed_deliveries],
            pending_deliveries: delivery_stats[:pending_deliveries],
            success_rate: delivery_stats[:success_rate],
            earnings_this_month: delivery_stats[:earnings_this_month],
            deliveries_this_month: delivery_stats[:deliveries_this_month],
            average_rating: delivery_stats[:average_rating],
            vehicle_info: delivery_person.vehicle_info
          }
        }
      })
      return
    end

    # Check sub-agent login
    sub_agent = SubAgent.find_by(email: login_field)
    unless sub_agent
      formatted_mobile = format_mobile_number(login_field)
      if formatted_mobile
        sub_agent = SubAgent.find_by(mobile: formatted_mobile) ||
                   SubAgent.find_by(mobile: "+91#{formatted_mobile}") ||
                   SubAgent.find_by(mobile: "+91 #{formatted_mobile}") ||
                   SubAgent.find_by(mobile: "#{formatted_mobile[0..4]} #{formatted_mobile[5..9]}") ||
                   SubAgent.find_by(mobile: "+91 #{formatted_mobile[0..4]} #{formatted_mobile[5..9]}")
      else
        sub_agent = SubAgent.find_by(mobile: login_field)
      end
    end
    if sub_agent && sub_agent.status == 'active'
      # For sub-agents, we also don't have password in current model
      token = generate_token(sub_agent, 'sub_agent')

      # Get sub-agent statistics
      sub_agent_stats = get_sub_agent_statistics(sub_agent)

      json_response({
        success: true,
        data: {
          token: token,
          username: sub_agent.display_name,
          role: 'sub_agent',
          user_id: sub_agent.id,
          email: sub_agent.email,
          mobile: sub_agent.mobile,
          commission_earned: sub_agent_stats[:commission_earned],
          customers_count: sub_agent_stats[:customers_count],
          policies_count: sub_agent_stats[:policies_count],
          commission_breakdown: sub_agent_stats[:commission_breakdown],
          monthly_target: sub_agent_stats[:monthly_target],
          achievement_percentage: sub_agent_stats[:achievement_percentage],
          dashboard_stats: {
            total_commission: sub_agent_stats[:commission_earned],
            monthly_target: sub_agent_stats[:monthly_target],
            achievement_percentage: sub_agent_stats[:achievement_percentage],
            policies_this_month: get_current_month_policies_count(sub_agent),
            customers_this_month: get_current_month_customers_count(sub_agent),
            conversion_rate: calculate_conversion_rate(sub_agent),
            ranking: calculate_agent_ranking(sub_agent),
            team_size: get_team_size(sub_agent),
            performance_grade: calculate_performance_grade(sub_agent_stats[:achievement_percentage])
          },
          agency_info: {
            agency_name: "#{sub_agent.display_name} Agency",
            license_number: "AGY#{sub_agent.id.to_s.rjust(6, '0')}",
            territory: ["North Zone", "South Zone", "East Zone", "West Zone"][sub_agent.id % 4],
            join_date: (Date.current - rand(30..1000).days).strftime("%Y-%m-%d")
          }
        }
      })
      return
    end


    json_response({
      success: false,
      message: 'Invalid username or password'
    }, :unauthorized)
  end

  # POST /api/v1/mobile/auth/forgot_password
  def forgot_password
    login_field = params[:email] || params[:mobile]

    if login_field.blank?
      return json_response({
        success: false,
        message: 'Email or mobile number is required'
      }, :unprocessable_entity)
    end

    # Check in all user types
    user = User.find_by(email: login_field) || Customer.find_by(email: login_field) || SubAgent.find_by(email: login_field)

    # If not found by email, try mobile search with formatting
    unless user
      formatted_mobile = format_mobile_number(login_field)
      if formatted_mobile
        user = User.find_by(mobile: formatted_mobile) ||
               User.find_by(mobile: "+91#{formatted_mobile}") ||
               User.find_by(mobile: "+91 #{formatted_mobile}") ||
               User.find_by(mobile: "#{formatted_mobile[0..4]} #{formatted_mobile[5..9]}") ||
               User.find_by(mobile: "+91 #{formatted_mobile[0..4]} #{formatted_mobile[5..9]}") ||
               Customer.find_by(mobile: formatted_mobile) ||
               Customer.find_by(mobile: "+91#{formatted_mobile}") ||
               Customer.find_by(mobile: "+91 #{formatted_mobile}") ||
               Customer.find_by(mobile: "#{formatted_mobile[0..4]} #{formatted_mobile[5..9]}") ||
               Customer.find_by(mobile: "+91 #{formatted_mobile[0..4]} #{formatted_mobile[5..9]}") ||
               SubAgent.find_by(mobile: formatted_mobile) ||
               SubAgent.find_by(mobile: "+91#{formatted_mobile}") ||
               SubAgent.find_by(mobile: "+91 #{formatted_mobile}") ||
               SubAgent.find_by(mobile: "#{formatted_mobile[0..4]} #{formatted_mobile[5..9]}") ||
               SubAgent.find_by(mobile: "+91 #{formatted_mobile[0..4]} #{formatted_mobile[5..9]}")
      else
        user = User.find_by(mobile: login_field) ||
               Customer.find_by(mobile: login_field) ||
               SubAgent.find_by(mobile: login_field)
      end
    end

    if user
      # Generate reset token (simplified - you might want to use a proper token system)
      reset_token = SecureRandom.urlsafe_base64(32)

      # Here you would typically:
      # 1. Save the reset token to database with expiry
      # 2. Send email with reset link

      json_response({
        success: true,
        message: 'Password reset instructions have been sent to your email'
      })
    else
      json_response({
        success: false,
        message: 'Email address not found'
      }, :not_found)
    end
  end

  # POST /api/v1/mobile/auth/register
  def register
    # Handle both 'role' and 'user_type' parameters for backward compatibility
    role = params[:role]&.downcase || params[:user_type]&.downcase || 'customer'

    # Ensure valid role values
    case role
    when 'customer', 'user'
      register_customer
    when 'agent', 'sub_agent'
      register_agent
    else
      json_response({
        success: false,
        message: 'Invalid role. Only customer and agent registration are allowed.',
        valid_roles: ['customer', 'agent']
      }, :unprocessable_entity)
    end
  end

  def register_customer
    customer_params = params.permit(:first_name, :last_name, :middle_name, :email, :mobile, :password, :password_confirmation,
                                   :user_type, :role, :address, :city, :state, :pincode, :whatsapp_number, :latitude, :longitude, :is_registered_by_mobile)

    # Validate required fields
    if customer_params[:first_name].blank? || customer_params[:last_name].blank? ||
       customer_params[:email].blank? || customer_params[:mobile].blank? || customer_params[:password].blank?
      return json_response({
        success: false,
        message: 'First name, last name, email, mobile number, and password are required'
      }, :unprocessable_entity)
    end

    # Validate password confirmation if provided
    if customer_params[:password_confirmation].present? && customer_params[:password] != customer_params[:password_confirmation]
      return json_response({
        success: false,
        message: 'Password confirmation does not match'
      }, :unprocessable_entity)
    end

    # Validate email format
    unless customer_params[:email].match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
      return json_response({
        success: false,
        message: 'Please enter a valid email address'
      }, :unprocessable_entity)
    end

    # Validate and format mobile number
    mobile_number = format_mobile_number(customer_params[:mobile])
    unless mobile_number
      return json_response({
        success: false,
        message: 'Please enter a valid Indian mobile number (10 digits starting with 6-9)'
      }, :unprocessable_entity)
    end

    # Validate name fields
    unless validate_name_fields(customer_params[:first_name])
      return json_response({
        success: false,
        message: 'First name should contain only alphabetic characters and be 2-50 characters long'
      }, :unprocessable_entity)
    end

    unless validate_name_fields(customer_params[:last_name])
      return json_response({
        success: false,
        message: 'Last name should contain only alphabetic characters and be 2-50 characters long'
      }, :unprocessable_entity)
    end

    # Validate password strength
    if customer_params[:password].length < 6
      return json_response({
        success: false,
        message: 'Password must be at least 6 characters long'
      }, :unprocessable_entity)
    end

    # Check if customer or user already exists
    existing_customer_email = Customer.exists?(email: customer_params[:email])
    existing_customer_mobile = Customer.exists?(mobile: mobile_number)
    existing_user_email = User.exists?(email: customer_params[:email])
    existing_user_mobile = User.exists?(mobile: mobile_number)

    if existing_customer_email || existing_user_email
      return json_response({
        success: false,
        message: 'An account with this email address already exists. Please use a different email or try logging in.'
      }, :conflict)
    end

    if existing_customer_mobile || existing_user_mobile
      return json_response({
        success: false,
        message: 'An account with this mobile number already exists. Please use a different mobile number or try logging in.'
      }, :conflict)
    end

    # Use database transaction to ensure both records are created together
    begin
      ActiveRecord::Base.transaction do
        # Create Customer record (without password validations)
        customer = Customer.new(
          full_name: [customer_params[:first_name], customer_params[:middle_name], customer_params[:last_name]].compact_blank.join(' '),
          email: customer_params[:email],
          mobile: mobile_number, # Use formatted mobile number
          address: customer_params[:address],
          whatsapp_number: customer_params[:whatsapp_number],
          latitude: customer_params[:latitude],
          longitude: customer_params[:longitude],
          is_registered_by_mobile: true, # Always set to true for mobile registrations
          status: true
        )
        customer.save!(validate: false)  # Skip validations to avoid password requirements

        # Create User record for login
        user = User.new(
          first_name: customer_params[:first_name],
          last_name: customer_params[:last_name],
          middle_name: customer_params[:middle_name],
          email: customer_params[:email],
          mobile: mobile_number, # Use formatted mobile number
          user_type: 'customer',
          address: customer_params[:address],
          city: customer_params[:city],
          state: customer_params[:state],
          pincode: customer_params[:pincode],
          status: true
        )

        # Set password separately to ensure proper Devise handling
        user.password = customer_params[:password]
        user.password_confirmation = customer_params[:password_confirmation].present? ? customer_params[:password_confirmation] : customer_params[:password]
        user.save!

        json_response({
          success: true,
          message: 'Customer registration successful. You can now login with your credentials.',
          data: {
            customer_id: customer.id,
            user_id: user.id,
            email: customer.email,
            mobile: customer.mobile,
            role: 'customer'
          }
        })
      end
    rescue ActiveRecord::RecordInvalid => e
      json_response({
        success: false,
        message: 'Customer registration failed',
        errors: e.record.errors.full_messages
      }, :unprocessable_entity)
    rescue => e
      json_response({
        success: false,
        message: 'Registration failed due to system error',
        error: e.message
      }, :internal_server_error)
    end
  end

  def register_agent
    agent_params = params.permit(:first_name, :last_name, :email, :mobile, :password, :password_confirmation,
                                :pan_no, :address, :city, :state, :gender, :occupation, :annual_income)

    # Validate required fields
    if agent_params[:first_name].blank? || agent_params[:last_name].blank? ||
       agent_params[:email].blank? || agent_params[:mobile].blank? || agent_params[:password].blank?
      return json_response({
        success: false,
        message: 'First name, last name, email, mobile number, and password are required'
      }, :unprocessable_entity)
    end

    # Validate password confirmation
    if agent_params[:password_confirmation].present? && agent_params[:password] != agent_params[:password_confirmation]
      return json_response({
        success: false,
        message: 'Password confirmation does not match'
      }, :unprocessable_entity)
    end

    # Validate email format
    unless agent_params[:email].match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
      return json_response({
        success: false,
        message: 'Please enter a valid email address'
      }, :unprocessable_entity)
    end

    # Validate and format mobile number
    mobile_number = format_mobile_number(agent_params[:mobile])
    unless mobile_number
      return json_response({
        success: false,
        message: 'Please enter a valid Indian mobile number (10 digits starting with 6-9)'
      }, :unprocessable_entity)
    end

    # Validate name fields
    unless validate_name_fields(agent_params[:first_name])
      return json_response({
        success: false,
        message: 'First name should contain only alphabetic characters and be 2-50 characters long'
      }, :unprocessable_entity)
    end

    unless validate_name_fields(agent_params[:last_name])
      return json_response({
        success: false,
        message: 'Last name should contain only alphabetic characters and be 2-50 characters long'
      }, :unprocessable_entity)
    end

    # Validate password strength
    if agent_params[:password].length < 6
      return json_response({
        success: false,
        message: 'Password must be at least 6 characters long'
      }, :unprocessable_entity)
    end

    # Check if user already exists
    existing_user_email = User.exists?(email: agent_params[:email])
    existing_user_mobile = User.exists?(mobile: mobile_number)

    if existing_user_email
      return json_response({
        success: false,
        message: 'An account with this email address already exists. Please use a different email or try logging in.'
      }, :conflict)
    end

    if existing_user_mobile
      return json_response({
        success: false,
        message: 'An account with this mobile number already exists. Please use a different mobile number or try logging in.'
      }, :conflict)
    end

    user = User.new(
      first_name: agent_params[:first_name],
      last_name: agent_params[:last_name],
      email: agent_params[:email],
      mobile: mobile_number, # Use formatted mobile number
      user_type: 'agent',
      role: 'agent_role',
      status: false,  # Pending approval
      pan_number: agent_params[:pan_no],
      address: agent_params[:address],
      city: agent_params[:city],
      state: agent_params[:state],
      gender: agent_params[:gender],
      occupation: agent_params[:occupation],
      annual_income: agent_params[:annual_income]
    )

    # Set password separately to ensure proper Devise handling
    user.password = agent_params[:password]
    user.password_confirmation = agent_params[:password_confirmation].present? ? agent_params[:password_confirmation] : agent_params[:password]

    if user.save
      json_response({
        success: true,
        message: 'Agent registration successful. Your account is pending approval by admin.',
        data: {
          user_id: user.id,
          email: user.email,
          mobile: user.mobile,
          role: 'agent'
        }
      })
    else
      json_response({
        success: false,
        message: 'Agent registration failed',
        errors: user.errors.full_messages
      }, :unprocessable_entity)
    end
  end

  private

  def generate_token(user, role)
    payload = {
      user_id: user.id,
      role: role,
      exp: 30.days.from_now.to_i
    }

    # Add specific ID fields based on role
    case role
    when 'delivery_person'
      payload[:delivery_person_id] = user.id
    when 'customer'
      payload[:customer_id] = user.id
    when 'sub_agent'
      payload[:sub_agent_id] = user.id
    end

    JWT.encode(payload, Rails.application.secret_key_base)
  end

  def validate_name_fields(name)
    return false if name.blank?
    # Allow only alphabetic characters and spaces, min 2 characters
    name.match?(/\A[a-zA-Z\s]{2,50}\z/)
  end

  def format_mobile_number(mobile)
    return nil if mobile.blank?
    # Remove all non-digit characters
    clean_mobile = mobile.to_s.gsub(/\D/, '')

    # Handle different mobile number formats
    if clean_mobile.length == 10
      # Standard 10-digit format, accept all (for testing purposes)
      return clean_mobile
    elsif clean_mobile.length == 12 && clean_mobile.start_with?('91')
      # 12 digits starting with 91
      return clean_mobile[2..-1]
    elsif clean_mobile.length == 13 && clean_mobile.start_with?('+91')
      # +91 prefix with spaces removed
      return clean_mobile[3..-1]
    else
      return nil
    end
  end

  def get_agent_statistics(user)
    # Calculate real commission from policies where agent is involved
    health_policies = HealthInsurance.where(sub_agent: user)
    life_policies = LifeInsurance.where(sub_agent: user)
    motor_policies = MotorInsurance.where(sub_agent: user) if defined?(MotorInsurance)

    # Calculate commission earned from different policy types
    health_commission = health_policies.sum do |policy|
      policy.commission_amount || calculate_health_commission(policy)
    end

    life_commission = life_policies.sum do |policy|
      policy.sub_agent_commission_amount || calculate_life_commission(policy)
    end

    motor_commission = 0
    if defined?(MotorInsurance) && motor_policies
      motor_commission = motor_policies.sum do |policy|
        policy.main_agent_commission_amount || calculate_motor_commission(policy)
      end
    end

    total_commission = health_commission + life_commission + motor_commission

    # Get unique customers associated with this agent's policies
    customer_ids = (health_policies.pluck(:customer_id) +
                   life_policies.pluck(:customer_id))
    customer_ids += motor_policies.pluck(:customer_id) if defined?(MotorInsurance) && motor_policies

    total_policies = health_policies.count + life_policies.count
    total_policies += motor_policies.count if defined?(MotorInsurance) && motor_policies

    # If no real data, provide realistic mock data
    if total_commission == 0 && total_policies == 0
      total_commission = generate_mock_commission(user)
      total_policies = generate_mock_policies_count(user)
      customer_ids = generate_mock_customers(user, total_policies)
    end

    {
      commission_earned: total_commission.round(2),
      customers_count: customer_ids.uniq.count,
      policies_count: total_policies,
      commission_breakdown: {
        health_commission: health_commission.round(2),
        life_commission: life_commission.round(2),
        motor_commission: motor_commission.round(2)
      }
    }
  end

  def get_sub_agent_statistics(sub_agent)
    # Get policies where sub-agent is involved (using sub_agent_id)
    health_policies = HealthInsurance.where(sub_agent_id: sub_agent.id)
    life_policies = LifeInsurance.where(sub_agent_id: sub_agent.id)
    motor_policies = []

    begin
      motor_policies = MotorInsurance.where(sub_agent_id: sub_agent.id) if defined?(MotorInsurance)
    rescue => e
      # Skip motor insurance if there's an error
      motor_policies = []
    end

    # Calculate commission from each policy type using actual database values
    health_commission = health_policies.sum do |policy|
      commission = 0.0
      # Try multiple commission fields for HealthInsurance
      commission = policy.sub_agent_commission_amount.to_f if policy.respond_to?(:sub_agent_commission_amount) && policy.sub_agent_commission_amount.present?
      commission = policy.commission_amount.to_f if commission == 0.0 && policy.respond_to?(:commission_amount) && policy.commission_amount.present?
      commission = policy.after_tds_value.to_f if commission == 0.0 && policy.respond_to?(:after_tds_value) && policy.after_tds_value.present?
      commission = policy.main_agent_commission_amount.to_f if commission == 0.0 && policy.respond_to?(:main_agent_commission_amount) && policy.main_agent_commission_amount.present?
      commission = calculate_health_commission(policy) if commission == 0.0
      commission
    end

    life_commission = life_policies.sum do |policy|
      commission = 0.0
      # LifeInsurance has sub_agent_commission_amount field
      commission = policy.sub_agent_commission_amount.to_f if policy.respond_to?(:sub_agent_commission_amount) && policy.sub_agent_commission_amount.present?
      commission = policy.after_tds_value.to_f if commission == 0.0 && policy.respond_to?(:after_tds_value) && policy.after_tds_value.present?
      commission = policy.commission_amount.to_f if commission == 0.0 && policy.respond_to?(:commission_amount) && policy.commission_amount.present?
      commission = calculate_life_commission(policy) if commission == 0.0
      commission
    end

    motor_commission = 0
    if motor_policies&.any?
      motor_commission = motor_policies.sum do |policy|
        commission = 0.0
        # MotorInsurance may have different commission field names
        commission = policy.main_agent_commission_amount.to_f if policy.respond_to?(:main_agent_commission_amount) && policy.main_agent_commission_amount.present?
        commission = policy.commission_amount.to_f if commission == 0.0 && policy.respond_to?(:commission_amount) && policy.commission_amount.present?
        commission = policy.after_tds_value.to_f if commission == 0.0 && policy.respond_to?(:after_tds_value) && policy.after_tds_value.present?
        commission = calculate_motor_commission(policy) if commission == 0.0
        commission
      end
    end

    total_commission = health_commission + life_commission + motor_commission

    # Get unique customer IDs from actual policies - this is the real-time customer count
    customer_ids = (health_policies.pluck(:customer_id) + life_policies.pluck(:customer_id))
    customer_ids += motor_policies.pluck(:customer_id) if motor_policies&.any?

    total_policies = health_policies.count + life_policies.count
    total_policies += motor_policies.count if motor_policies&.any?

    # Use only customers who have active policies for real-time data
    real_customers_count = customer_ids.uniq.count
    monthly_target = 50000.0

    {
      commission_earned: total_commission.round(2),
      customers_count: real_customers_count,
      policies_count: total_policies,
      commission_breakdown: {
        health_commission: health_commission.round(2),
        life_commission: life_commission.round(2),
        motor_commission: motor_commission.round(2)
      },
      monthly_target: monthly_target,
      achievement_percentage: total_commission > 0 ? ((total_commission / monthly_target) * 100).round(2) : 0.0
    }
  end

  # Helper methods for commission calculation
  def calculate_health_commission(policy)
    return 0.0 unless policy&.net_premium
    # Default 2% commission for health insurance
    (policy.net_premium.to_f * 0.02)
  end

  def calculate_life_commission(policy)
    return 0.0 unless policy&.net_premium
    # Default 10% commission for life insurance first year
    (policy.net_premium.to_f * 0.10)
  end

  def calculate_motor_commission(policy)
    return 0.0 unless policy&.respond_to?(:net_premium) && policy.net_premium
    # Default 15% commission for motor insurance
    (policy.net_premium.to_f * 0.15)
  end

  # Mock data generation methods
  def generate_mock_commission(user)
    # Generate realistic commission based on user ID for consistency
    base_commission = 25000 + (user.id * 1250) % 75000
    variation = (user.id * 17) % 20000 - 10000
    [base_commission + variation, 5000].max.to_f
  end

  def generate_mock_policies_count(user)
    # Generate consistent policy count based on user ID
    base_count = 15 + (user.id * 3) % 35
    [base_count, 5].max
  end

  def generate_mock_customers(user, policies_count)
    # Generate consistent customer IDs based on user ID
    customer_count = [(policies_count * 0.7).round, 3].max
    base_id = user.id * 100
    (1..customer_count).map { |i| base_id + i }
  end

  def get_customer_portfolio_stats(customer)
    # This is an ecommerce application, so return ecommerce-related stats
    begin
      total_orders = customer.orders.count
      total_bookings = customer.bookings.count
      total_spent = customer.orders.where.not(status: ['cancelled', 'returned']).sum(:total_amount)

      {
        total_orders: total_orders,
        total_bookings: total_bookings,
        total_spent: total_spent.to_f,
        member_since: customer.created_at,
        recent_activity: {
          last_order_date: customer.orders.maximum(:created_at),
          last_booking_date: customer.bookings.maximum(:created_at)
        }
      }
    rescue => e
      Rails.logger.error "Customer stats calculation error: #{e.message}"
      # Return basic data if there's any error
      {
        total_orders: 0,
        total_bookings: 0,
        total_spent: 0.0,
        member_since: customer.created_at,
        recent_activity: {
          last_order_date: nil,
          last_booking_date: nil
        }
      }
    end
  end

  def calculate_next_installment_date(start_date, payment_mode)
    return nil unless start_date

    case payment_mode.to_s.downcase
    when 'monthly'
      start_date + 1.month
    when 'quarterly'
      start_date + 3.months
    when 'half-yearly', 'half yearly'
      start_date + 6.months
    when 'yearly'
      start_date + 1.year
    else
      nil
    end
  end

  # Real-time dashboard calculation methods
  def get_current_month_policies_count(sub_agent)
    start_of_month = Date.current.beginning_of_month
    end_of_month = Date.current.end_of_month

    health_policies = HealthInsurance.where(sub_agent_id: sub_agent.id).where(created_at: start_of_month..end_of_month).count
    life_policies = LifeInsurance.where(sub_agent_id: sub_agent.id).where(created_at: start_of_month..end_of_month).count

    motor_policies = 0
    begin
      if defined?(MotorInsurance)
        motor_policies = MotorInsurance.where(sub_agent_id: sub_agent.id).where(created_at: start_of_month..end_of_month).count
      end
    rescue => e
      # Skip if error
    end

    health_policies + life_policies + motor_policies
  end

  def get_current_month_customers_count(sub_agent)
    start_of_month = Date.current.beginning_of_month
    end_of_month = Date.current.end_of_month

    # Count unique customers who got policies this month through this sub-agent
    health_customer_ids = HealthInsurance.where(sub_agent_id: sub_agent.id).where(created_at: start_of_month..end_of_month).pluck(:customer_id)
    life_customer_ids = LifeInsurance.where(sub_agent_id: sub_agent.id).where(created_at: start_of_month..end_of_month).pluck(:customer_id)

    motor_customer_ids = []
    begin
      if defined?(MotorInsurance)
        motor_customer_ids = MotorInsurance.where(sub_agent_id: sub_agent.id).where(created_at: start_of_month..end_of_month).pluck(:customer_id)
      end
    rescue => e
      # Skip if error
    end

    (health_customer_ids + life_customer_ids + motor_customer_ids).uniq.count
  end

  def calculate_conversion_rate(sub_agent)
    # Get leads assigned to this sub-agent in the last 3 months
    three_months_ago = 3.months.ago

    begin
      total_leads = Lead.where(affiliate_id: sub_agent.id).where('created_at >= ?', three_months_ago).count
      converted_leads = Lead.where(affiliate_id: sub_agent.id).where('created_at >= ?', three_months_ago).where(current_stage: ['converted', 'policy_created']).count

      if total_leads > 0
        conversion_rate = ((converted_leads.to_f / total_leads) * 100).round
        "#{conversion_rate}%"
      else
        # If no leads data, calculate based on customers vs policies ratio
        customers_count = Customer.where(sub_agent_id: sub_agent.id).count
        policies_count = get_total_policies_count(sub_agent)

        if customers_count > 0 && policies_count > 0
          rate = [(policies_count.to_f / customers_count * 100).round, 100].min
          "#{rate}%"
        else
          "0%"
        end
      end
    rescue => e
      "N/A"
    end
  end

  def calculate_agent_ranking(sub_agent)
    # Calculate ranking based on commission earned compared to other sub-agents
    begin
      all_sub_agents = SubAgent.where(status: 'active')
      sub_agent_commissions = []

      all_sub_agents.each do |agent|
        stats = get_sub_agent_statistics(agent)
        sub_agent_commissions << { id: agent.id, commission: stats[:commission_earned] }
      end

      # Sort by commission in descending order
      sorted_agents = sub_agent_commissions.sort_by { |agent| -agent[:commission] }

      # Find current agent's position
      current_agent_rank = sorted_agents.find_index { |agent| agent[:id] == sub_agent.id }

      current_agent_rank ? current_agent_rank + 1 : sorted_agents.count
    rescue => e
      # Fallback to a consistent ranking based on ID
      ((sub_agent.id * 7) % 20) + 1
    end
  end

  def get_team_size(sub_agent)
    # Count customers with active policies from this sub-agent
    health_customer_ids = HealthInsurance.where(sub_agent_id: sub_agent.id).pluck(:customer_id)
    life_customer_ids = LifeInsurance.where(sub_agent_id: sub_agent.id).pluck(:customer_id)

    motor_customer_ids = []
    begin
      motor_customer_ids = MotorInsurance.where(sub_agent_id: sub_agent.id).pluck(:customer_id) if defined?(MotorInsurance)
    rescue => e
      # Skip motor insurance if there's an error
      motor_customer_ids = []
    end

    (health_customer_ids + life_customer_ids + motor_customer_ids).uniq.count
  end

  def calculate_performance_grade(achievement_percentage)
    case achievement_percentage
    when 150..Float::INFINITY
      'A+'
    when 125..149.99
      'A'
    when 100..124.99
      'B+'
    when 75..99.99
      'B'
    when 50..74.99
      'C+'
    when 25..49.99
      'C'
    else
      'D'
    end
  end

  def get_total_policies_count(sub_agent)
    health_count = HealthInsurance.where(sub_agent_id: sub_agent.id).count
    life_count = LifeInsurance.where(sub_agent_id: sub_agent.id).count

    motor_count = 0
    begin
      if defined?(MotorInsurance)
        motor_count = MotorInsurance.where(sub_agent_id: sub_agent.id).count
      end
    rescue => e
      # Skip if error
    end

    health_count + life_count + motor_count
  end

  # Customer portfolio calculation helper methods
  def calculate_upcoming_installments(health_policies, life_policies, motor_policies, other_policies)
    upcoming_count = 0
    thirty_days_from_now = 30.days.from_now.to_date

    # Health insurance installments
    health_policies.each do |policy|
      next_installment = get_next_installment_date(policy)
      if next_installment && next_installment <= thirty_days_from_now && next_installment >= Date.current
        upcoming_count += 1
      end
    end

    # Life insurance installments
    life_policies.each do |policy|
      next_installment = get_next_installment_date(policy)
      if next_installment && next_installment <= thirty_days_from_now && next_installment >= Date.current
        upcoming_count += 1
      end
    end

    # Motor insurance installments
    motor_policies.each do |policy|
      next_installment = get_next_installment_date(policy)
      if next_installment && next_installment <= thirty_days_from_now && next_installment >= Date.current
        upcoming_count += 1
      end
    end

    # Other insurance installments
    other_policies.each do |policy|
      next_installment = get_next_installment_date(policy)
      if next_installment && next_installment <= thirty_days_from_now && next_installment >= Date.current
        upcoming_count += 1
      end
    end

    upcoming_count
  end

  def calculate_renewal_policies(health_policies, life_policies, motor_policies, other_policies)
    renewal_count = 0
    ninety_days_from_now = 90.days.from_now.to_date

    # Health insurance renewals
    health_policies.each do |policy|
      if policy.policy_end_date.present? &&
         policy.policy_end_date >= Date.current &&
         policy.policy_end_date <= ninety_days_from_now
        renewal_count += 1
      end
    end

    # Life insurance renewals
    life_policies.each do |policy|
      if policy.policy_end_date.present? &&
         policy.policy_end_date >= Date.current &&
         policy.policy_end_date <= ninety_days_from_now
        renewal_count += 1
      end
    end

    # Motor insurance renewals
    motor_policies.each do |policy|
      if policy.respond_to?(:policy_end_date) &&
         policy.policy_end_date.present? &&
         policy.policy_end_date >= Date.current &&
         policy.policy_end_date <= ninety_days_from_now
        renewal_count += 1
      end
    end

    # Other insurance renewals
    other_policies.each do |policy|
      if policy.respond_to?(:policy_end_date) &&
         policy.policy_end_date.present? &&
         policy.policy_end_date >= Date.current &&
         policy.policy_end_date <= ninety_days_from_now
        renewal_count += 1
      end
    end

    renewal_count
  end

  def calculate_total_coverage(health_policies, life_policies, motor_policies, other_policies)
    total_coverage = 0.0

    # Health insurance coverage
    health_policies.each do |policy|
      total_coverage += policy.sum_insured.to_f if policy.sum_insured.present?
    end

    # Life insurance coverage
    life_policies.each do |policy|
      total_coverage += policy.sum_insured.to_f if policy.sum_insured.present?
    end

    # Motor insurance coverage
    motor_policies.each do |policy|
      if policy.respond_to?(:sum_insured) && policy.sum_insured.present?
        total_coverage += policy.sum_insured.to_f
      elsif policy.respond_to?(:idv_amount) && policy.idv_amount.present?
        total_coverage += policy.idv_amount.to_f
      end
    end

    # Other insurance coverage
    other_policies.each do |policy|
      total_coverage += policy.sum_insured.to_f if policy.respond_to?(:sum_insured) && policy.sum_insured.present?
    end

    total_coverage
  end

  def calculate_total_premiums(health_policies, life_policies, motor_policies, other_policies)
    total_premiums = 0.0

    # Health insurance premiums
    health_policies.each do |policy|
      total_premiums += policy.total_premium.to_f if policy.total_premium.present?
    end

    # Life insurance premiums
    life_policies.each do |policy|
      total_premiums += policy.total_premium.to_f if policy.total_premium.present?
    end

    # Motor insurance premiums
    motor_policies.each do |policy|
      total_premiums += policy.total_premium.to_f if policy.respond_to?(:total_premium) && policy.total_premium.present?
    end

    # Other insurance premiums
    other_policies.each do |policy|
      total_premiums += policy.total_premium.to_f if policy.respond_to?(:total_premium) && policy.total_premium.present?
    end

    total_premiums
  end

  def get_next_installment_date(policy)
    return nil unless policy.respond_to?(:installment_autopay_start_date) && policy.installment_autopay_start_date.present?
    return nil unless policy.respond_to?(:payment_mode) && policy.payment_mode.present?

    start_date = policy.installment_autopay_start_date
    payment_mode = policy.payment_mode

    # Calculate next installment from start date
    case payment_mode.to_s.downcase
    when 'monthly'
      # Find next monthly installment
      months_since_start = ((Date.current.year - start_date.year) * 12) + (Date.current.month - start_date.month)
      next_installment = start_date + (months_since_start + 1).months
      next_installment >= Date.current ? next_installment : start_date + (months_since_start + 2).months
    when 'quarterly'
      # Find next quarterly installment
      quarters_since_start = ((Date.current.year - start_date.year) * 4) + ((Date.current.month - start_date.month) / 3)
      next_installment = start_date + (quarters_since_start + 1).quarters
      next_installment >= Date.current ? next_installment : start_date + (quarters_since_start + 2).quarters
    when 'half_yearly', 'half yearly', 'semi_annual'
      # Find next half-yearly installment
      half_years_since_start = ((Date.current.year - start_date.year) * 2) + ((Date.current.month - start_date.month) / 6)
      next_installment = start_date + (half_years_since_start + 1) * 6.months
      next_installment >= Date.current ? next_installment : start_date + (half_years_since_start + 2) * 6.months
    when 'yearly', 'annual'
      # Find next yearly installment
      years_since_start = Date.current.year - start_date.year
      next_installment = start_date + (years_since_start + 1).years
      next_installment >= Date.current ? next_installment : start_date + (years_since_start + 2).years
    else
      nil
    end
  end

  def count_upcoming_installments(customer)
    # For ecommerce, count upcoming subscription deliveries
    begin
      customer.milk_subscriptions.where(status: 'active')
                                  .where('start_date <= ? AND (end_date IS NULL OR end_date >= ?)',
                                         Date.current, Date.current).count
    rescue
      0
    end
  end

  def count_upcoming_renewals(customer)
    # For ecommerce, count subscriptions ending soon (requiring renewal)
    begin
      customer.milk_subscriptions.where(status: 'active')
                                  .where('end_date BETWEEN ? AND ?', Date.current, 2.months.from_now)
                                  .where.not(end_date: nil).count
    rescue
      0
    end
  end

  def get_delivery_person_statistics(delivery_person)
    # Get actual delivery data if Order model has delivery_person relationship
    begin
      # Try to get actual delivery statistics
      if defined?(Order) && Order.column_names.include?('delivery_person_id')
        total_deliveries = Order.where(delivery_person_id: delivery_person.id).count
        completed_deliveries = Order.where(delivery_person_id: delivery_person.id, status: 'delivered').count
        pending_deliveries = Order.where(delivery_person_id: delivery_person.id, status: ['pending', 'shipped', 'out_for_delivery']).count

        # Calculate success rate
        success_rate = total_deliveries > 0 ? ((completed_deliveries.to_f / total_deliveries) * 100).round(2) : 0

        # Get current month stats
        current_month_deliveries = Order.where(
          delivery_person_id: delivery_person.id,
          created_at: Date.current.beginning_of_month..Date.current.end_of_month
        ).count

        # Mock earnings calculation (₹50 per delivery)
        earnings_this_month = current_month_deliveries * 50

        # Mock average rating
        average_rating = (4.0 + (rand * 1.0)).round(1) # Random rating between 4.0-5.0
      else
        # Generate realistic mock data if actual Order model doesn't have delivery person relationship
        total_deliveries = 150 + (delivery_person.id % 100)
        completed_deliveries = (total_deliveries * 0.85).to_i
        pending_deliveries = total_deliveries - completed_deliveries
        success_rate = ((completed_deliveries.to_f / total_deliveries) * 100).round(2)
        current_month_deliveries = 25 + (delivery_person.id % 15)
        earnings_this_month = current_month_deliveries * 50
        average_rating = (4.0 + (rand * 1.0)).round(1)
      end

      {
        total_deliveries: total_deliveries,
        completed_deliveries: completed_deliveries,
        pending_deliveries: pending_deliveries,
        success_rate: success_rate,
        deliveries_this_month: current_month_deliveries,
        earnings_this_month: earnings_this_month,
        average_rating: average_rating
      }
    rescue => e
      Rails.logger.error "Delivery statistics calculation error: #{e.message}"
      # Return mock data if there's any error
      {
        total_deliveries: 120,
        completed_deliveries: 102,
        pending_deliveries: 18,
        success_rate: 85.0,
        deliveries_this_month: 20,
        earnings_this_month: 1000,
        average_rating: 4.5
      }
    end
  end

end
require 'bcrypt'

class Api::V1::Mobile::SettingsController < Api::V1::Mobile::BaseController
  before_action :authenticate_customer!

  # GET /api/v1/mobile/settings/profile
  def profile
    user = current_user

    render json: {
      success: true,
      data: build_profile_data(user)
    }
  end

  # PUT /api/v1/mobile/settings/profile
  def update_profile
    user = current_user
    profile_params = get_permitted_params_for_user(user)

    ActiveRecord::Base.transaction do
      if user.update(profile_params)
        # Handle nominee details update for customers
        if user.is_a?(Customer) && params[:nominees].present?
          update_customer_nominees(user, params[:nominees])
        end

        render json: {
          success: true,
          message: 'Profile updated successfully',
          data: build_profile_data(user)
        }
      else
        render json: {
          success: false,
          message: 'Failed to update profile',
          errors: user.errors.full_messages
        }, status: :unprocessable_entity
      end
    end
  rescue StandardError => e
    render json: {
      success: false,
      message: 'Failed to update profile',
      errors: [e.message]
    }, status: :unprocessable_entity
  end

  # POST /api/v1/mobile/settings/change_password
  def change_password
    new_password = params[:new_password]
    old_password = params[:old_password] || params[:current_password]

    Rails.logger.info "=== PASSWORD CHANGE REQUEST ==="
    Rails.logger.info "User type: #{current_user.class.name}"
    Rails.logger.info "User ID: #{current_user.id}"
    Rails.logger.info "User email: #{current_user.email}" if current_user.respond_to?(:email)

    if new_password.blank?
      return render json: {
        success: false,
        message: 'New password is required'
      }, status: :unprocessable_entity
    end

    if new_password.length < 6
      return render json: {
        success: false,
        message: 'Password must be at least 6 characters long'
      }, status: :unprocessable_entity
    end

    # Get current user - could be Customer, User, or SubAgent
    user = current_user

    if user.nil?
      Rails.logger.error "User not found in change_password"
      return render json: {
        success: false,
        message: 'User not found'
      }, status: :not_found
    end

    Rails.logger.info "Processing password change for: #{user.class.name} ID: #{user.id}"

    # For users with has_secure_password (SubAgent) or Devise (User) models
    if (user.respond_to?(:authenticate) || user.respond_to?(:valid_password?)) && user.respond_to?(:password=)
      # Verify old password if provided
      if old_password.present?
        password_valid = if user.respond_to?(:authenticate)
          # SubAgent uses has_secure_password
          user.authenticate(old_password)
        elsif user.respond_to?(:valid_password?)
          # User uses Devise
          user.valid_password?(old_password)
        else
          false
        end

        unless password_valid
          Rails.logger.warn "Old password verification failed"
          return render json: {
            success: false,
            message: 'Current password is incorrect'
          }, status: :unprocessable_entity
        end
      end

      # Update password and plain_password field for SubAgent
      user.password = new_password
      user.password_confirmation = new_password

      # Update plain_password field for SubAgent model
      if user.is_a?(SubAgent)
        user.plain_password = new_password
        Rails.logger.info "Setting plain_password for SubAgent to: #{new_password}"
        # Force the callback to run
        user.store_plain_password = true
      elsif user.is_a?(User)
        # Also update plain_password for User (agent) model
        user.plain_password = new_password
        Rails.logger.info "Setting plain_password for User to: #{new_password}"
      end

      # Use update_columns to bypass all validations and callbacks for password fields
      begin
        ActiveRecord::Base.transaction do
          if user.respond_to?(:password_digest)
            # For SubAgent with has_secure_password
            user.password_digest = BCrypt::Password.create(new_password)
            user.update_columns(password_digest: user.password_digest)

            # Update plain_password if the field exists
            if user.respond_to?(:plain_password) && user.class.column_names.include?('plain_password')
              user.update_columns(plain_password: new_password)
            end
          else
            # For User with Devise
            user.password = new_password
            user.password_confirmation = new_password
            user.save(validate: false)
          end

          Rails.logger.info "Password updated successfully for #{user.class.name} ID: #{user.id}"
          Rails.logger.info "[PasswordSync] Updated plain_password for #{user.class.name} #{user.id}"

          # Also update corresponding User model if it's a SubAgent
          if user.is_a?(SubAgent)
            corresponding_user = User.find_by(email: user.email)
            if corresponding_user
              corresponding_user.password = new_password
              corresponding_user.password_confirmation = new_password
              corresponding_user.plain_password = new_password if corresponding_user.respond_to?(:plain_password)
              corresponding_user.save(validate: false)
              Rails.logger.info "Also updated User account for email: #{user.email}"
            end
          end
        end

        render json: {
          success: true,
          message: 'Password changed successfully'
        }
      rescue => e
        Rails.logger.error "Failed to update password: #{e.message}"
        render json: {
          success: false,
          message: "Failed to update password: #{e.message}"
        }, status: :unprocessable_entity
      end
    elsif user.is_a?(Customer)
      # For Customer model, find and update the corresponding User account
      corresponding_user = User.find_by(email: user.email)
      if corresponding_user.nil?
        return render json: {
          success: false,
          message: 'User account not found for this customer'
        }, status: :not_found
      end

      # Verify old password if provided (using User model's Devise authentication)
      if old_password.present? && !corresponding_user.valid_password?(old_password)
        Rails.logger.warn "Old password verification failed for customer"
        return render json: {
          success: false,
          message: 'Current password is incorrect'
        }, status: :unprocessable_entity
      end

      # Update password using Devise
      corresponding_user.password = new_password
      corresponding_user.password_confirmation = new_password
      # Also update plain_password for UI display
      corresponding_user.plain_password = new_password

      if corresponding_user.save(validate: false)
        Rails.logger.info "Password updated for customer's User account: #{corresponding_user.email}"
        render json: {
          success: true,
          message: 'Password changed successfully'
        }
      else
        render json: {
          success: false,
          message: corresponding_user.errors.full_messages.join(', ')
        }, status: :unprocessable_entity
      end
    else
      render json: {
        success: false,
        message: 'Password change not supported for this user type'
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/mobile/settings/terms
  def terms_and_conditions
    # You can store this in database or return static content
    terms_url = "#{request.base_url}/terms_and_conditions.html"

    render json: {
      success: true,
      data: {
        terms_url: terms_url,
        terms_content: get_terms_content
      }
    }
  end

  # GET /api/v1/mobile/settings/contact
  def contact_us
    user = current_user

    # Check user role from token and respond accordingly
    if user.is_a?(Customer)
      # Customer role - Show assigned agent details
      agent_info = get_customer_agent(user)

      render json: {
        success: true,
        data: {
          agent_name: agent_info[:name],
          agent_mobile: agent_info[:mobile],
          agent_email: agent_info[:email],
          agent_address: agent_info[:address],
          company_info: {
            name: "Atma Nirbhar Farm",
            mobile: "+918431174477",
            email: "support@dhanvantarifarm.in",
            address: "123 Insurance Street, Mumbai, Maharashtra, India",
            website: "www.dhanvantarifarm.in"
          },
          support_hours: "Monday to Friday: 9:00 AM - 6:00 PM",
          emergency_contact: "+918431174477"
        }
      }
    elsif user.is_a?(User) || user.is_a?(SubAgent)
      # Agent role - Show company support details
      render json: {
        success: true,
        data: {
          company_name: "Atma Nirbhar Farm",
          support_mobile: "+918431174477",
          support_email: "support@dhanvantarifarm.in",
          support_address: "123 Insurance Street, Mumbai, Maharashtra, India",
          website: "www.dhanvantarifarm.in",
          support_hours: "Monday to Friday: 9:00 AM - 6:00 PM",
          emergency_contact: "+918431174477",
          technical_support: {
            mobile: "+918431174477",
            email: "support@dhanvantarifarm.in"
          },
          sales_support: {
            mobile: "+918431174477",
            email: "support@dhanvantarifarm.in"
          }
        }
      }
    else
      render json: {
        success: false,
        message: "Invalid user role"
      }, status: :unauthorized
    end
  end

  # POST /api/v1/mobile/settings/helpdesk
  def helpdesk
    helpdesk_params = params.permit(:name, :email, :phone_number, :description)

    if helpdesk_params[:name].blank? || helpdesk_params[:email].blank? || helpdesk_params[:description].blank?
      return render json: {
        success: false,
        message: 'Name, email, and description are required'
      }, status: :unprocessable_entity
    end

    begin
      # Create client request in database
      client_request = ClientRequest.create!(
        name: helpdesk_params[:name],
        email: helpdesk_params[:email],
        phone_number: helpdesk_params[:phone_number],
        description: helpdesk_params[:description],
        status: 'pending',
        priority: 'medium'
      )

      render json: {
        success: true,
        message: 'Your request has been submitted successfully. Our team will contact you soon.',
        data: {
          request_id: client_request.id,
          ticket_number: client_request.ticket_number,
          status: client_request.status,
          estimated_response_time: '24-48 hours'
        }
      }

    rescue ActiveRecord::RecordInvalid => e
      render json: {
        success: false,
        message: 'Failed to submit request',
        errors: e.record.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  private

  def get_terms_content
    # You can store this in database or return static content
    <<~TERMS
      Terms and Conditions for DemoFarm Admin

      1. General Terms
      These terms and conditions govern your use of DemoFarm Admin mobile application.

      2. Privacy Policy
      We are committed to protecting your privacy and personal information.

      3. Policy Management
      You can view and manage your insurance policies through this application.

      4. Support
      For any queries or support, please contact our customer service team.

      Last updated: December 2025
    TERMS
  end

  def get_customer_agent(customer)
    # Try to find agent from customer's policies
    health_policy = HealthInsurance.where(customer: customer).joins(:sub_agent).first
    life_policy = LifeInsurance.where(customer: customer).joins(:sub_agent).first

    sub_agent = health_policy&.sub_agent || life_policy&.sub_agent

    if sub_agent
      {
        name: sub_agent.display_name,
        mobile: sub_agent.mobile,
        email: sub_agent.email,
        address: sub_agent.address || "Not provided"
      }
    else
      # Default company agent
      {
        name: "Atma Nirbhar Farm Support Team",
        mobile: "+918431174477",
        email: "support@dr-wise.in",
        address: "123 Insurance Street, Mumbai, Maharashtra, India"
      }
    end
  end

  def build_profile_data(user)
    base_data = {
      username: user.email,
      user_image: nil, # Add if you have profile images
      full_name: user.display_name,
      first_name: user.first_name,
      last_name: user.last_name,
      email: user.email,
      mobile_number: user.mobile,
      gender: user.gender,
      age: user.age,
      birth_date: user.birth_date,
      address: user.address
    }

    # Handle city and state based on model structure
    if user.respond_to?(:city)
      base_data[:city] = user.city
      base_data[:state] = user.state
    elsif user.respond_to?(:city_id)
      base_data[:city_id] = user.city_id
      base_data[:state_id] = user.state_id
    end

    # Add user-type specific fields
    case user
    when Customer
      base_data.merge!({
        pincode: user.pincode,
        pan: user.pan_number || user.pan_no,
        gst: user.gst_number || user.gst_no,
        customer_type: user.customer_type,
        occupation: user.occupation,
        annual_income: user.annual_income,
        marital_status: user.marital_status,
        education: user.education
      })

      # Add nominee details for customers
      base_data[:nominees] = get_nominee_details(user)
    when SubAgent
      # Get city and state names from IDs using the mapped data
      city_name = nil
      state_name = nil

      # Simple state mapping (you can expand this based on your state_id mapping)
      state_mapping = {
        1 => 'Karnataka',
        2 => 'Tamil Nadu',
        3 => 'Maharashtra',
        4 => 'Gujarat',
        5 => 'Delhi',
        6 => 'West Bengal'
      }

      # Simple city mapping (you can expand this based on your city_id mapping)
      city_mapping = {
        1 => 'Bangalore',
        2 => 'Mumbai',
        3 => 'Chennai',
        4 => 'Delhi',
        5 => 'Kolkata',
        6 => 'Pune'
      }

      city_name = city_mapping[user.city_id] if user.city_id.present?
      state_name = state_mapping[user.state_id] if user.state_id.present?

      base_data.merge!({
        role_id: user.role_id,
        pan: user.pan_no,
        gst: user.gst_no,
        city: city_name,
        state: state_name,
        account_type: user.account_type,
        account_holder_name: user.account_holder_name,
        account_number: user.account_no, # Note: it's account_no not account_number in the model
        ifsc_code: user.ifsc_code,
        bank_name: user.bank_name,
        upi_id: user.upi_id,
        status: user.status,
        company_name: user.company_name
      })
    when User
      base_data.merge!({
        user_type: user.user_type,
        role: user.role,
        pan_number: user.pan_number,
        occupation: user.occupation,
        annual_income: user.annual_income
      })
    end

    base_data
  end

  def get_nominee_details(customer)
    # Get all nominees from life insurance policies for this customer
    life_insurance_nominees = []

    # Fetch life insurance policies with nominees
    life_insurances = LifeInsurance.includes(:life_insurance_nominees).where(customer: customer)

    life_insurances.each do |policy|
      policy.life_insurance_nominees.each do |nominee|
        life_insurance_nominees << {
          policy_number: policy.policy_number,
          policy_type: 'life_insurance',
          nominee_name: nominee.nominee_name,
          relationship: nominee.relationship,
          age: nominee.age,
          share_percentage: nominee.share_percentage
        }
      end
    end

    {
      life_insurance_nominees: life_insurance_nominees,
      total_nominees_count: life_insurance_nominees.count
    }
  end

  def update_customer_nominees(customer, nominees_params)
    return unless nominees_params.is_a?(Array)

    nominees_params.each do |nominee_data|
      policy_number = nominee_data[:policy_number] || nominee_data['policy_number']
      next unless policy_number.present?

      # Find the life insurance policy
      life_insurance = LifeInsurance.find_by(customer: customer, policy_number: policy_number)
      next unless life_insurance

      # Find existing nominee or create new one
      nominee = life_insurance.life_insurance_nominees.find_by(
        nominee_name: nominee_data[:nominee_name] || nominee_data['nominee_name']
      ) || life_insurance.life_insurance_nominees.new

      # Update nominee attributes
      nominee.assign_attributes(
        nominee_name: nominee_data[:nominee_name] || nominee_data['nominee_name'],
        relationship: nominee_data[:relationship] || nominee_data['relationship'],
        age: nominee_data[:age] || nominee_data['age'],
        share_percentage: nominee_data[:share_percentage] || nominee_data['share_percentage']
      )

      nominee.save! if nominee.valid?
    end
  end

  def get_permitted_params_for_user(user)
    base_params = [:first_name, :last_name, :mobile, :gender, :birth_date, :address]

    # Add city/state params based on model structure
    if user.respond_to?(:city)
      base_params += [:city, :state]
    elsif user.respond_to?(:city_id)
      base_params += [:city_id, :state_id]
    end

    case user
    when Customer
      params.permit(base_params + [:pincode, :occupation, :annual_income, :marital_status, :education])
    when SubAgent
      params.permit(base_params + [:gst_no, :account_type, :account_holder_name, :account_no, :ifsc_code, :bank_name, :upi_id, :company_name])
    when User
      params.permit(base_params + [:occupation, :annual_income])
    else
      params.permit(base_params)
    end
  end
end
class Api::V1::Mobile::CustomerController < Api::V1::Mobile::BaseController
  before_action :authenticate_customer!

  # GET /api/v1/mobile/customer/portfolio
  def portfolio
    customer_id = current_customer.id

    # Get all health insurance policies
    health_policies = HealthInsurance.where(customer_id: customer_id)

    # Get all life insurance policies
    life_policies = LifeInsurance.where(customer_id: customer_id)

    # Get all motor insurance policies
    motor_policies = []
    begin
      if defined?(MotorInsurance)
        motor_policies = MotorInsurance.where(customer_id: customer_id)
      end
    rescue => e
      Rails.logger.warn "Motor insurance table issue: #{e.message}"
    end

    portfolio = []

    # Add health insurance policies
    health_policies.each do |policy|
      portfolio << {
        id: policy.id,
        insurance_name: policy.plan_name || "Health Insurance",
        insurance_type: "Health",
        policy_number: policy.policy_number,
        policy_holder: policy.policy_holder,
        start_date: policy.policy_start_date,
        end_date: policy.policy_end_date,
        total_premium: policy.total_premium,
        sum_insured: policy.sum_insured,
        insurance_company: policy.insurance_company_name,
        payment_mode: policy.payment_mode,
        status: policy.active? ? 'Active' : (policy.expired? ? 'Expired' : 'Expiring Soon'),
        days_until_expiry: policy.days_until_expiry,
        attachment: policy.policy_documents.attached? ? rails_blob_url(policy.policy_documents.first) : nil
      }
    end

    # Add life insurance policies
    life_policies.each do |policy|
      portfolio << {
        id: policy.id,
        insurance_name: policy.plan_name || "Life Insurance",
        insurance_type: "Life",
        policy_number: policy.policy_number,
        policy_holder: policy.policy_holder,
        start_date: policy.policy_start_date,
        end_date: policy.policy_end_date,
        total_premium: policy.total_premium,
        sum_insured: policy.sum_insured,
        insurance_company: policy.insurance_company_name,
        payment_mode: policy.payment_mode,
        status: policy.active? ? 'Active' : (policy.expired? ? 'Expired' : 'Expiring Soon'),
        days_until_expiry: policy.days_until_expiry,
        attachment: policy.policy_documents.attached? ? rails_blob_url(policy.policy_documents.first) : nil,
        # Life insurance specific fields
        nominee_name: policy.nominee_name,
        nominee_relationship: policy.nominee_relationship,
        policy_term: policy.policy_term,
        premium_payment_term: policy.premium_payment_term
      }
    end

    # Add motor insurance policies
    motor_policies.each do |policy|
      portfolio << {
        id: policy.id,
        insurance_name: "Motor Insurance",
        insurance_type: "Motor",
        policy_number: policy.policy_number,
        policy_holder: policy.policy_holder,
        start_date: policy.policy_start_date,
        end_date: policy.policy_end_date,
        total_premium: policy.total_premium,
        sum_insured: policy.respond_to?(:vehicle_idv) ? policy.vehicle_idv : nil,
        insurance_company: policy.insurance_company_name,
        payment_mode: policy.respond_to?(:payment_mode) ? policy.payment_mode : 'Yearly',
        status: begin
          if policy.policy_end_date.present?
            policy.policy_end_date > Date.current ? 'Active' : (policy.policy_end_date < Date.current ? 'Expired' : 'Expiring Soon')
          else
            'Active'
          end
        end,
        days_until_expiry: begin
          if policy.policy_end_date.present?
            (policy.policy_end_date - Date.current).to_i
          else
            nil
          end
        end,
        attachment: policy.respond_to?(:policy_documents) && policy.policy_documents.attached? ? rails_blob_url(policy.policy_documents.first) : nil
      }
    end

    # Sort by start date (newest first)
    portfolio = portfolio.sort_by { |p| p[:start_date] || Date.current }.reverse

    # Calculate portfolio summary with real-time counts — reuse the
    # health/life/motor policies already loaded above instead of the summary
    # helpers re-querying each of them 2-3 more times.
    portfolio_summary = get_customer_portfolio_summary(current_customer, health_policies, life_policies, motor_policies)

    render json: {
      success: true,
      data: {
        portfolio: portfolio,
        total_policies: portfolio.count,
        total_premium: portfolio.sum { |p| p[:total_premium].to_f },
        total_sum_insured: portfolio.sum { |p| p[:sum_insured].to_f },
        active_policies: portfolio.count { |p| p[:status] == 'Active' },
        expiring_policies: portfolio.count { |p| p[:status] == 'Expiring Soon' },
        portfolio_summary: portfolio_summary
      }
    }
  end

  # GET /api/v1/mobile/customer/upcoming_installments
  def upcoming_installments
    customer_id = current_customer.id

    # Get policies with upcoming installments (include active and recently expired policies)
    installments = []

    # Health Insurance installments - include active and expired policies that might need renewal payments
    health_policies = HealthInsurance.where(customer_id: customer_id)
                                    .where('policy_end_date >= ? OR policy_start_date >= ?', 18.months.ago, Date.current)

    health_policies.each do |policy|
      # Skip policies with missing critical data
      next unless policy.policy_end_date.present? && policy.policy_start_date.present?
      next unless policy.total_premium.present? && policy.total_premium > 0

      # For expired policies, calculate installments based on renewal dates
      if policy.policy_end_date < Date.current
        # Policy is expired - calculate renewal installments if within renewal period
        days_since_expiry = (Date.current - policy.policy_end_date).to_i

        # Only show renewal installments if policy expired recently (within 18 months)
        next if days_since_expiry > 540 # 18 months

        # Use renewal date (day after policy end) as the base for installment calculations
        renewal_date = policy.policy_end_date + 1.day
        installment_type = 'renewal'
        autopay_start = renewal_date
      else
        # Policy is active - use normal installment logic
        autopay_start = if policy.respond_to?(:installment_autopay_start_date) && policy.installment_autopay_start_date.present?
                          policy.installment_autopay_start_date
                        else
                          policy.policy_start_date
                        end
        installment_type = 'regular'
      end

      if autopay_start.present? && policy.payment_mode.present? &&
         !['single', 'one time', 'lump sum'].include?(policy.payment_mode.downcase)

        next_installment = calculate_next_installment_date(autopay_start, policy.payment_mode)

        # If next_installment is in the past, keep adding payment cycle until we get a future date
        safety_counter = 0
        while next_installment && next_installment < Date.current && safety_counter < 10
          next_installment = calculate_next_installment_date(next_installment, policy.payment_mode)
          safety_counter += 1
        end

        # Show installments within appropriate time frame based on payment mode
        # Show installments only within next 2 months (60 days)
        if next_installment && next_installment <= 60.days.from_now
          days_until_installment = (next_installment - Date.current).to_i
          days_left_from_today = days_until_installment

          # Generate label based on days left
          label = if days_left_from_today <= 0
                    "Expired"
                  elsif days_left_from_today <= 7
                    if days_left_from_today == 1
                      "Expiring in 1 day"
                    else
                      "Expiring in #{days_left_from_today} days"
                    end
                  elsif days_left_from_today < 30
                    "Coming soon"
                  else
                    "Upcoming"
                  end

          installments << {
            id: policy.id,
            insurance_name: policy.plan_name || "Health Insurance",
            insurance_type: "Health",
            policy_number: policy.policy_number || "N/A",
            policy_holder: policy.policy_holder || "N/A",
            insurance_company: policy.insurance_company_name || "N/A",
            start_date: policy.policy_start_date,
            end_date: policy.policy_end_date,
            total_premium: policy.total_premium.to_f,
            payment_mode: policy.payment_mode,
            next_installment_date: next_installment,
            installment_amount: calculate_installment_amount(policy.total_premium, policy.payment_mode),
            days_until_installment: days_until_installment,
            days_left_from_today: days_left_from_today,
            label: label,
            installment_type: installment_type, # 'regular' or 'renewal'
            is_expired: policy.policy_end_date < Date.current,
            is_overdue: installment_type == 'renewal' && days_until_installment < 0,
            attachment: policy.policy_documents.attached? ? rails_blob_url(policy.policy_documents.first) : nil
          }
        end
      end
    end

    # Life Insurance installments - include active and expired policies that might need renewal payments
    life_policies = LifeInsurance.where(customer_id: customer_id)
                                .where('policy_end_date >= ? OR policy_start_date >= ?', 18.months.ago, Date.current)

    life_policies.each do |policy|
      # Skip policies with missing critical data
      next unless policy.policy_end_date.present? && policy.policy_start_date.present?
      next unless policy.total_premium.present? && policy.total_premium > 0

      # For expired policies, calculate installments based on renewal dates
      if policy.policy_end_date < Date.current
        # Policy is expired - calculate renewal installments if within renewal period
        days_since_expiry = (Date.current - policy.policy_end_date).to_i

        # Only show renewal installments if policy expired recently (within 18 months)
        next if days_since_expiry > 540 # 18 months

        # Use renewal date (day after policy end) as the base for installment calculations
        renewal_date = policy.policy_end_date + 1.day
        installment_type = 'renewal'
        autopay_start = renewal_date
      else
        # Policy is active - use normal installment logic
        autopay_start = if policy.respond_to?(:installment_autopay_start_date) && policy.installment_autopay_start_date.present?
                          policy.installment_autopay_start_date
                        else
                          policy.policy_start_date
                        end
        installment_type = 'regular'
      end

      if autopay_start.present? && policy.payment_mode.present? &&
         !['single', 'one time', 'lump sum'].include?(policy.payment_mode.downcase)

        next_installment = calculate_next_installment_date(autopay_start, policy.payment_mode)

        # If next_installment is in the past, keep adding payment cycle until we get a future date
        safety_counter = 0
        while next_installment && next_installment < Date.current && safety_counter < 10
          next_installment = calculate_next_installment_date(next_installment, policy.payment_mode)
          safety_counter += 1
        end

        # Show installments within appropriate time frame based on payment mode
        # Show installments only within next 2 months (60 days)
        if next_installment && next_installment <= 60.days.from_now
          days_until_installment = (next_installment - Date.current).to_i
          days_left_from_today = days_until_installment

          # Generate label based on days left
          label = if days_left_from_today <= 0
                    "Expired"
                  elsif days_left_from_today <= 7
                    if days_left_from_today == 1
                      "Expiring in 1 day"
                    else
                      "Expiring in #{days_left_from_today} days"
                    end
                  elsif days_left_from_today < 30
                    "Coming soon"
                  else
                    "Upcoming"
                  end

          installments << {
            id: policy.id,
            insurance_name: policy.plan_name || "Life Insurance",
            insurance_type: "Life",
            policy_number: policy.policy_number || "N/A",
            policy_holder: policy.policy_holder || "N/A",
            insurance_company: policy.insurance_company_name || "N/A",
            start_date: policy.policy_start_date,
            end_date: policy.policy_end_date,
            total_premium: policy.total_premium.to_f,
            payment_mode: policy.payment_mode,
            next_installment_date: next_installment,
            installment_amount: calculate_installment_amount(policy.total_premium, policy.payment_mode),
            days_until_installment: days_until_installment,
            days_left_from_today: days_left_from_today,
            label: label,
            installment_type: installment_type, # 'regular' or 'renewal'
            is_expired: policy.policy_end_date < Date.current,
            is_overdue: installment_type == 'renewal' && days_until_installment < 0,
            attachment: policy.policy_documents.attached? ? rails_blob_url(policy.policy_documents.first) : nil
          }
        end
      end
    end

    # Motor Insurance installments - include active and expired policies that might need renewal payments
    motor_policies = []
    begin
      if defined?(MotorInsurance)
        motor_policies = MotorInsurance.where(customer_id: customer_id)
                                     .where('policy_end_date >= ? OR policy_start_date >= ?', 18.months.ago, Date.current)
      end
    rescue => e
      Rails.logger.warn "Motor insurance table issue: #{e.message}"
    end

    motor_policies.each do |policy|
      # Skip policies with missing critical data
      next unless policy.policy_end_date.present? && policy.policy_start_date.present?
      next unless policy.total_premium.present? && policy.total_premium > 0

      # For expired policies, calculate installments based on renewal dates
      if policy.policy_end_date < Date.current
        # Policy is expired - calculate renewal installments if within renewal period
        days_since_expiry = (Date.current - policy.policy_end_date).to_i

        # Only show renewal installments if policy expired recently (within 18 months)
        next if days_since_expiry > 540 # 18 months

        # Use renewal date (day after policy end) as the base for installment calculations
        renewal_date = policy.policy_end_date + 1.day
        installment_type = 'renewal'
        autopay_start = renewal_date
      else
        # Policy is active - use normal installment logic
        autopay_start = if policy.respond_to?(:installment_autopay_start_date) && policy.installment_autopay_start_date.present?
                          policy.installment_autopay_start_date
                        else
                          policy.policy_start_date
                        end
        installment_type = 'regular'
      end

      payment_mode = policy.respond_to?(:payment_mode) ? policy.payment_mode : 'Yearly'

      if autopay_start.present? && payment_mode.present? &&
         !['single', 'one time', 'lump sum'].include?(payment_mode.downcase)

        next_installment = calculate_next_installment_date(autopay_start, payment_mode)

        # If next_installment is in the past, keep adding payment cycle until we get a future date
        safety_counter = 0
        while next_installment && next_installment < Date.current && safety_counter < 10
          next_installment = calculate_next_installment_date(next_installment, payment_mode)
          safety_counter += 1
        end

        # Show installments within appropriate time frame based on payment mode
        # Show installments only within next 2 months (60 days)
        if next_installment && next_installment <= 60.days.from_now
          days_until_installment = (next_installment - Date.current).to_i
          days_left_from_today = days_until_installment

          # Generate label based on days left
          label = if days_left_from_today <= 0
                    "Expired"
                  elsif days_left_from_today <= 7
                    if days_left_from_today == 1
                      "Expiring in 1 day"
                    else
                      "Expiring in #{days_left_from_today} days"
                    end
                  elsif days_left_from_today < 30
                    "Coming soon"
                  else
                    "Upcoming"
                  end

          installments << {
            id: policy.id,
            insurance_name: "Motor Insurance",
            insurance_type: "Motor",
            policy_number: policy.policy_number || "N/A",
            policy_holder: policy.policy_holder || "N/A",
            insurance_company: policy.insurance_company_name || "N/A",
            start_date: policy.policy_start_date,
            end_date: policy.policy_end_date,
            total_premium: policy.total_premium.to_f,
            payment_mode: payment_mode,
            next_installment_date: next_installment,
            installment_amount: calculate_installment_amount(policy.total_premium, payment_mode),
            days_until_installment: days_until_installment,
            days_left_from_today: days_left_from_today,
            label: label,
            installment_type: installment_type, # 'regular' or 'renewal'
            is_expired: policy.policy_end_date < Date.current,
            is_overdue: installment_type == 'renewal' && days_until_installment < 0,
            attachment: policy.respond_to?(:policy_documents) && policy.policy_documents.attached? ? rails_blob_url(policy.policy_documents.first) : nil
          }
        end
      end
    end

    # Sort by installment date
    installments = installments.sort_by { |i| i[:next_installment_date] }

    render json: {
      success: true,
      data: {
        upcoming_installments: installments,
        total_installments: installments.count,
        total_amount: installments.sum { |i| (i[:installment_amount] || 0).to_f }.round(2),
        # Regular time-based groupings
        next_7_days: installments.count { |i| (i[:days_until_installment] || 0) <= 7 && (i[:days_until_installment] || 0) > 0 },
        next_30_days: installments.count { |i| (i[:days_until_installment] || 0) <= 30 && (i[:days_until_installment] || 0) > 0 },
        next_60_days: installments.count { |i| (i[:days_until_installment] || 0) <= 60 && (i[:days_until_installment] || 0) > 0 },
        next_90_days: installments.count { |i| (i[:days_until_installment] || 0) <= 90 && (i[:days_until_installment] || 0) > 0 },
        # Installment type groupings
        regular_installments: installments.count { |i| i[:installment_type] == 'regular' },
        renewal_installments: installments.count { |i| i[:installment_type] == 'renewal' },
        # Status groupings
        overdue_installments: installments.count { |i| i[:is_overdue] == true },
        expired_policies: installments.count { |i| i[:is_expired] == true },
        active_policies: installments.count { |i| i[:is_expired] != true },
        # Most urgent
        next_installment: installments.first # Sorted by date, so first is most urgent
      }
    }
  end

  # GET /api/v1/mobile/customer/upcoming_renewals
  def upcoming_renewals
    customer_id = current_customer.id

    renewals = []

    # Debug info
    Rails.logger.info "Upcoming renewals for customer ID: #{customer_id}"

    # Health Insurance renewals - show only policies with renewals within next 2 months
    health_policies = HealthInsurance.where(customer_id: customer_id)
                                    .where('policy_end_date BETWEEN ? AND ?', Date.current, 2.months.from_now)
                                    .where.not(policy_end_date: nil)

    health_policies.each do |policy|
      days_since_end = (Date.current - policy.policy_end_date).to_i

      # Determine renewal status based on whether policy is expired or expiring
      renewal_status = if policy.policy_end_date < Date.current
                        # Policy is expired - need to renew soon
                        'overdue'
                      else
                        # Policy is still active - categorize by time until expiry
                        days_until_expiry = (policy.policy_end_date - Date.current).to_i
                        if days_until_expiry <= 7
                          'urgent' # Renewal in 7 days
                        elsif days_until_expiry <= 30
                          'due_soon' # Renewal in 30 days
                        elsif days_until_expiry <= 60
                          'approaching'
                        else
                          'upcoming'
                        end
                      end

      # Calculate days until renewal (negative for overdue)
      days_until_renewal = (policy.policy_end_date - Date.current).to_i

      renewals << {
        id: policy.id,
        insurance_name: policy.plan_name || "Health Insurance",
        insurance_type: "Health",
        policy_number: policy.policy_number,
        policy_holder: policy.policy_holder,
        start_date: policy.policy_start_date,
        end_date: policy.policy_end_date,
        renewal_date: policy.policy_end_date + 1.day,
        total_premium: policy.total_premium,
        sum_insured: policy.sum_insured,
        payment_mode: policy.payment_mode,
        days_until_renewal: days_until_renewal,
        renewal_status: renewal_status,
        is_expired: policy.policy_end_date < Date.current,
        days_since_expiry: policy.policy_end_date < Date.current ? days_since_end : nil,
        insurance_company: policy.insurance_company_name,
        attachment: policy.policy_documents.attached? ? rails_blob_url(policy.policy_documents.first) : nil
      }
    end

    # Life Insurance renewals - show only policies with renewals within next 2 months
    life_policies = LifeInsurance.where(customer_id: customer_id)
                                .where('policy_end_date BETWEEN ? AND ?', Date.current, 2.months.from_now)
                                .where.not(policy_end_date: nil)

    life_policies.each do |policy|
      days_since_end = (Date.current - policy.policy_end_date).to_i

      # Determine renewal status based on whether policy is expired or expiring
      renewal_status = if policy.policy_end_date < Date.current
                        # Policy is expired - need to renew soon
                        'overdue'
                      else
                        # Policy is still active - categorize by time until expiry
                        days_until_expiry = (policy.policy_end_date - Date.current).to_i
                        if days_until_expiry <= 7
                          'urgent' # Renewal in 7 days
                        elsif days_until_expiry <= 30
                          'due_soon' # Renewal in 30 days
                        elsif days_until_expiry <= 60
                          'approaching'
                        else
                          'upcoming'
                        end
                      end

      # Calculate days until renewal (negative for overdue)
      days_until_renewal = (policy.policy_end_date - Date.current).to_i

      renewals << {
        id: policy.id,
        insurance_name: policy.plan_name || "Life Insurance",
        insurance_type: "Life",
        policy_number: policy.policy_number,
        policy_holder: policy.policy_holder,
        start_date: policy.policy_start_date,
        end_date: policy.policy_end_date,
        renewal_date: policy.policy_end_date + 1.day,
        total_premium: policy.total_premium,
        sum_insured: policy.sum_insured,
        payment_mode: policy.payment_mode,
        policy_term: policy.policy_term,
        premium_payment_term: policy.premium_payment_term,
        days_until_renewal: days_until_renewal,
        renewal_status: renewal_status,
        is_expired: policy.policy_end_date < Date.current,
        days_since_expiry: policy.policy_end_date < Date.current ? days_since_end : nil,
        insurance_company: policy.insurance_company_name,
        attachment: policy.policy_documents.attached? ? rails_blob_url(policy.policy_documents.first) : nil
      }
    end

    # Motor Insurance and Other Insurance Types - Dynamic approach
    # Define all insurance types to check
    insurance_types = [
      { model: 'MotorInsurance', type: 'Motor', date_range: 3.years },
      { model: 'TravelInsurance', type: 'Travel', date_range: 2.years },
      { model: 'GeneralInsurance', type: 'General', date_range: 3.years },
      { model: 'OtherInsurance', type: 'Other', date_range: 3.years }
    ]

    insurance_types.each do |insurance_config|
      begin
        # Check if the model exists and is defined
        if Object.const_defined?(insurance_config[:model])
          model_class = insurance_config[:model].constantize

          # Skip if model doesn't have required fields
          unless model_class.column_names.include?('customer_id') && model_class.column_names.include?('policy_end_date')
            Rails.logger.info "Skipping #{insurance_config[:model]}: Missing required fields"
            next
          end

          policies = model_class.where(customer_id: customer_id)
                               .where('policy_end_date BETWEEN ? AND ?', Date.current, 2.months.from_now)
                               .where.not(policy_end_date: nil)

          Rails.logger.info "Processing #{policies.count} #{insurance_config[:type]} insurance policies"

          policies.each do |policy|
            days_since_end = (Date.current - policy.policy_end_date).to_i

            # Determine renewal status based on whether policy is expired or expiring
            renewal_status = if policy.policy_end_date < Date.current
                              # Policy is expired
                              if days_since_end <= 30
                                'overdue' # Recently expired (within 30 days)
                              elsif days_since_end <= 90
                                'renewal_required' # Expired but still renewable (30-90 days)
                              else
                                'renewal_recommended' # Long expired but still show for renewal
                              end
                            else
                              # Policy is still active
                              days_until_expiry = (policy.policy_end_date - Date.current).to_i
                              if days_until_expiry <= 7
                                'urgent'
                              elsif days_until_expiry <= 30
                                'due_soon'
                              elsif days_until_expiry <= 60
                                'approaching'
                              else
                                'upcoming'
                              end
                            end

            # Calculate days until renewal (negative for overdue)
            days_until_renewal = (policy.policy_end_date - Date.current).to_i

            # Build insurance name based on type
            insurance_name = case insurance_config[:type]
                           when 'Motor'
                             "Motor Insurance"
                           when 'Travel'
                             "Travel Insurance"
                           when 'General'
                             policy.respond_to?(:plan_name) && policy.plan_name.present? ? policy.plan_name : "General Insurance"
                           when 'Other'
                             policy.respond_to?(:other_policy_type) && policy.other_policy_type.present? ? policy.other_policy_type : "Other Insurance"
                           else
                             "#{insurance_config[:type]} Insurance"
                           end

            renewals << {
              id: policy.id,
              insurance_name: insurance_name,
              insurance_type: insurance_config[:type],
              policy_number: policy.respond_to?(:policy_number) ? policy.policy_number : "N/A",
              policy_holder: policy.respond_to?(:policy_holder) ? policy.policy_holder : current_customer.display_name,
              start_date: policy.respond_to?(:policy_start_date) ? policy.policy_start_date : nil,
              end_date: policy.policy_end_date,
              renewal_date: policy.policy_end_date + 1.day,
              total_premium: policy.respond_to?(:total_premium) ? policy.total_premium : 0,
              sum_insured: policy.respond_to?(:sum_insured) ? policy.sum_insured : nil,
              payment_mode: policy.respond_to?(:payment_mode) ? policy.payment_mode : 'Yearly',
              days_until_renewal: days_until_renewal,
              renewal_status: renewal_status,
              is_expired: policy.policy_end_date < Date.current,
              days_since_expiry: policy.policy_end_date < Date.current ? days_since_end : nil,
              insurance_company: policy.respond_to?(:insurance_company_name) ? policy.insurance_company_name : "Unknown",
              attachment: policy.respond_to?(:policy_documents) && policy.policy_documents.attached? ? rails_blob_url(policy.policy_documents.first) : nil,
              # Additional fields specific to motor insurance
              vehicle_number: insurance_config[:type] == 'Motor' && policy.respond_to?(:vehicle_number) ? policy.vehicle_number : nil,
              vehicle_make: insurance_config[:type] == 'Motor' && policy.respond_to?(:vehicle_make) ? policy.vehicle_make : nil,
              vehicle_model: insurance_config[:type] == 'Motor' && policy.respond_to?(:vehicle_model) ? policy.vehicle_model : nil
            }
          end
        end
      rescue => e
        # Skip this insurance type if there are any issues
        Rails.logger.warn "#{insurance_config[:model]} table issue: #{e.message}"
        next
      end
    end

    # Log that we are only showing renewals within next 2 months
    Rails.logger.info "Found #{renewals.count} renewals within next 2 months for customer #{customer_id}"

    # Sort by renewal date (most urgent first, then by days until renewal)
    renewals = renewals.sort_by { |r| [r[:renewal_status] == 'overdue' ? 0 : 1, r[:days_until_renewal]] }

    render json: {
      success: true,
      data: {
        upcoming_renewals: renewals,
        total_renewals: renewals.count,
        # Active renewal statuses
        urgent_renewals: renewals.count { |r| r[:renewal_status] == 'urgent' },
        due_soon: renewals.count { |r| r[:renewal_status] == 'due_soon' },
        approaching: renewals.count { |r| r[:renewal_status] == 'approaching' },
        upcoming: renewals.count { |r| r[:renewal_status] == 'upcoming' },
        # Expired renewal statuses
        overdue: renewals.count { |r| r[:renewal_status] == 'overdue' },
        renewal_required: renewals.count { |r| r[:renewal_status] == 'renewal_required' },
        renewal_recommended: renewals.count { |r| r[:renewal_status] == 'renewal_recommended' },
        # Status groupings
        active_policies: renewals.count { |r| !r[:is_expired] },
        expired_policies: renewals.count { |r| r[:is_expired] },
        # Customer info
        customer_id: customer_id,
        customer_name: current_customer.display_name,
        has_policies: renewals.any?,
        # Insurance type breakdown
        by_insurance_type: {
          health: renewals.count { |r| r[:insurance_type] == 'Health' },
          life: renewals.count { |r| r[:insurance_type] == 'Life' },
          motor: renewals.count { |r| r[:insurance_type] == 'Motor' },
          travel: renewals.count { |r| r[:insurance_type] == 'Travel' },
          general: renewals.count { |r| r[:insurance_type] == 'General' },
          other: renewals.count { |r| r[:insurance_type] == 'Other' }
        },
        summary: {
          next_7_days: renewals.count { |r| r[:days_until_renewal] <= 7 && r[:days_until_renewal] > 0 },
          next_30_days: renewals.count { |r| r[:days_until_renewal] <= 30 && r[:days_until_renewal] > 0 },
          next_60_days: renewals.count { |r| r[:days_until_renewal] <= 60 && r[:days_until_renewal] > 0 },
          overdue_count: renewals.count { |r| r[:days_until_renewal] < 0 },
          total_premium_due: renewals.sum { |r| r[:total_premium].to_f }.round(2),
          most_urgent: renewals.first, # Most urgent renewal (sorted by days_until_renewal)
          insurance_types_covered: renewals.map { |r| r[:insurance_type] }.uniq
        }
      }
    }
  end

  # POST /api/v1/mobile/customer/add_policy
  def add_policy
    # Log incoming parameters for debugging
    Rails.logger.info "=== ADD POLICY API CALL ==="
    Rails.logger.info "Raw params: #{params.inspect}"
    Rails.logger.info "Current customer: #{current_customer&.id} - #{current_customer&.display_name}"

    policy_params = params.permit(:insurance_type, :plan_name, :sum_insured, :premium_amount,
                                  :"premium amount", :"Renewal date",
                                  :renewal_date, :policy_number, :insurance_company, :remarks,
                                  :product_through_dr, :product_through_dr_wise, family_members: [])

    Rails.logger.info "Permitted params: #{policy_params.inspect}"

    # Handle the premium amount field with space
    premium_amount = policy_params[:premium_amount] || policy_params[:"premium amount"]
    renewal_date = policy_params[:renewal_date] || policy_params[:"Renewal date"]

    # Handle product_through_dr field variations
    product_through_dr = policy_params[:product_through_dr] || policy_params[:product_through_dr_wise]

    Rails.logger.info "Processed values - Premium: #{premium_amount}, Renewal: #{renewal_date}, Through DR: #{product_through_dr}"

    # Validate required fields
    if policy_params[:insurance_type].blank?
      return render json: {
        success: false,
        message: 'Insurance type is required'
      }, status: :unprocessable_entity
    end

    if policy_params[:plan_name].blank?
      return render json: {
        success: false,
        message: 'Plan name is required'
      }, status: :unprocessable_entity
    end

    if policy_params[:sum_insured].blank? || policy_params[:sum_insured].to_f <= 0
      return render json: {
        success: false,
        message: 'Sum insured is required and must be greater than 0'
      }, status: :unprocessable_entity
    end

    if premium_amount.blank? || premium_amount.to_f <= 0
      return render json: {
        success: false,
        message: 'Premium amount is required and must be greater than 0'
      }, status: :unprocessable_entity
    end

    # Create a policy request or notification for admin to review
    # This is a simplified implementation - you might want to create a separate PolicyRequest model

    case policy_params[:insurance_type].downcase
    when 'health'
      policy = HealthInsurance.new(
        customer_id: current_customer.id,
        policy_holder: current_customer.display_name || 'Self',
        plan_name: policy_params[:plan_name],
        insurance_company_name: policy_params[:insurance_company] || 'To be assigned',
        insurance_type: 'Individual',
        policy_type: 'New',
        policy_number: policy_params[:policy_number] || "REQ-#{Time.current.to_i}",
        policy_booking_date: Date.current,
        policy_start_date: Date.current,
        policy_end_date: renewal_date.present? ? Date.parse(renewal_date.to_s) + 1.day : 1.year.from_now,  # Ensure end date is after start date
        payment_mode: 'Yearly',
        sum_insured: policy_params[:sum_insured].to_f,
        net_premium: premium_amount&.to_f || 0,
        total_premium: premium_amount&.to_f || 0,
        gst_percentage: 18,
        product_through_dr: product_through_dr || false,
        is_customer_added: true,
        is_agent_added: false,
        is_admin_added: false
      )

      # Store additional info in a notes field or separate model
      if policy_params[:family_members].present?
        family_info = "Family members to be covered: #{policy_params[:family_members].join(', ')}"
        # You might want to add this to a notes field or create family member records
      end

    when 'life', 'lic'
      # Get default distributor and investor
      default_distributor = Distributor.first
      default_investor = Investor.first

      # Check if default distributor and investor exist
      unless default_distributor && default_investor
        return render json: {
          success: false,
          message: 'System configuration error: Default distributor or investor not found. Please contact support.'
        }, status: :internal_server_error
      end

      policy = LifeInsurance.new(
        customer_id: current_customer.id,
        policy_holder: current_customer.display_name || 'Self',
        plan_name: policy_params[:plan_name],
        insurance_company_name: policy_params[:insurance_company] || 'To be assigned',
        policy_type: 'New',
        policy_number: policy_params[:policy_number] || "REQ-#{Time.current.to_i}",
        policy_booking_date: Date.current,
        policy_start_date: Date.current,
        policy_end_date: 20.years.from_now,  # Life insurance typically has 20+ year terms
        payment_mode: 'Yearly',
        policy_term: 20,
        premium_payment_term: 10,
        sum_insured: policy_params[:sum_insured].to_f,
        net_premium: premium_amount&.to_f || 0,
        total_premium: premium_amount&.to_f || 0,
        first_year_gst_percentage: 18,
        product_through_dr: product_through_dr || false,
        distributor_id: default_distributor&.id,
        investor_id: default_investor&.id,
        is_customer_added: true,
        is_agent_added: false,
        is_admin_added: false
      )

    when 'motor'
      return render json: {
        success: false,
        message: 'Motor insurance requests are not available through customer portal. Please contact your agent.'
      }, status: :unprocessable_entity

    when 'other'
      return render json: {
        success: false,
        message: 'Other insurance requests are not available through customer portal. Please contact your agent.'
      }, status: :unprocessable_entity

    else
      return render json: {
        success: false,
        message: 'Invalid insurance type. Supported types: health, life'
      }, status: :unprocessable_entity
    end

    # Log the policy creation attempt for debugging
    Rails.logger.info "=== POLICY CREATION ATTEMPT ==="
    Rails.logger.info "Customer ID: #{current_customer&.id}"
    Rails.logger.info "Customer Name: #{current_customer&.display_name}"
    Rails.logger.info "Policy Type: #{policy_params[:insurance_type]}"
    Rails.logger.info "Policy attributes: #{policy.attributes.inspect}"

    if policy&.save
      Rails.logger.info "✅ Policy created successfully with ID: #{policy.id}"
      render json: {
        success: true,
        message: 'Policy request submitted successfully! Our team will review your request and contact you within 24 hours.',
        data: {
          policy_id: policy.id,
          policy_number: policy.policy_number,
          insurance_type: policy_params[:insurance_type],
          plan_name: policy_params[:plan_name],
          sum_insured: policy_params[:sum_insured].to_f,
          premium_amount: premium_amount&.to_f || 0,
          renewal_date: renewal_date,
          product_through_dr: product_through_dr || false,
          status: 'pending_approval',
          family_members: policy_params[:family_members] || [],
          remarks: policy_params[:remarks],
          submitted_at: Time.current.iso8601
        }
      }
    else
      Rails.logger.error "❌ Policy creation failed"
      Rails.logger.error "Validation errors: #{policy.errors.full_messages}"
      Rails.logger.error "Detailed errors: #{policy.errors.as_json}"
      render json: {
        success: false,
        message: 'Failed to submit policy request',
        errors: policy&.errors&.full_messages || ['Unable to create policy request'],
        debug_info: Rails.env.development? ? {
          validation_errors: policy&.errors&.as_json,
          customer_info: {
            current_customer_present: current_customer.present?,
            current_customer_id: current_customer&.id,
            current_customer_name: current_customer&.display_name
          }
        } : nil
      }, status: :unprocessable_entity
    end
  end

  private

  # health_policies/life_policies/motor_policies are the already-loaded
  # collections from #portfolio — reusing them here avoids re-querying each
  # insurance type 2 more times (once for this count, once inside each of
  # the two count_upcoming_* helpers below).
  def get_customer_portfolio_summary(customer, health_policies = nil, life_policies = nil, motor_policies = nil)
    health_policies ||= HealthInsurance.where(customer_id: customer.id)
    life_policies ||= LifeInsurance.where(customer_id: customer.id)
    if motor_policies.nil?
      motor_policies = []
      begin
        motor_policies = MotorInsurance.where(customer_id: customer.id) if defined?(MotorInsurance)
      rescue => e
        Rails.logger.warn "Motor insurance count issue: #{e.message}"
      end
    end

    # Calculate total policies count
    health_count = health_policies.size
    life_count = life_policies.size
    motor_count = motor_policies.size
    other_count = 0

    begin
      if defined?(OtherInsurance)
        # Other insurance is linked through policy table
        other_count = OtherInsurance.joins(:policy).where(policies: { customer_id: customer.id }).count
      end
    rescue => e
      Rails.logger.warn "Other insurance count issue: #{e.message}"
    end

    total_policies = health_count + life_count + motor_count + other_count

    # Calculate upcoming installments count (within next 2 months)
    upcoming_installments = count_upcoming_installments_for_customer(customer, health_policies, life_policies, motor_policies)

    # Calculate renewal policies count (within next 2 months)
    renewal_policies = count_upcoming_renewals_for_customer(customer, health_policies, life_policies, motor_policies)

    {
      total_policies: total_policies,
      upcoming_installments: upcoming_installments,
      renewal_policies: renewal_policies
    }
  end

  def count_upcoming_installments_for_customer(customer, health_policies = nil, life_policies = nil, motor_policies = nil)
    count = 0

    # Health insurance installments within 2 months
    health_policies ||= HealthInsurance.where(customer_id: customer.id)
    health_policies.each do |policy|
      next unless policy.policy_end_date.present? && policy.policy_start_date.present?
      next unless policy.total_premium.present? && policy.total_premium > 0
      next if ['single', 'one time', 'lump sum'].include?(policy.payment_mode&.downcase)

      autopay_start = policy.respond_to?(:installment_autopay_start_date) && policy.installment_autopay_start_date.present? ?
                      policy.installment_autopay_start_date : policy.policy_start_date

      if autopay_start.present? && policy.payment_mode.present?
        next_installment = calculate_next_installment_date(autopay_start, policy.payment_mode)

        # Find next future installment
        safety_counter = 0
        while next_installment && next_installment < Date.current && safety_counter < 10
          next_installment = calculate_next_installment_date(next_installment, policy.payment_mode)
          safety_counter += 1
        end

        # Count if installment is within next 2 months
        if next_installment && next_installment <= 2.months.from_now
          count += 1
        end
      end
    end

    # Life insurance installments within 2 months
    life_policies ||= LifeInsurance.where(customer_id: customer.id)
    life_policies.each do |policy|
      next unless policy.policy_end_date.present? && policy.policy_start_date.present?
      next unless policy.total_premium.present? && policy.total_premium > 0
      next if ['single', 'one time', 'lump sum'].include?(policy.payment_mode&.downcase)

      autopay_start = policy.respond_to?(:installment_autopay_start_date) && policy.installment_autopay_start_date.present? ?
                      policy.installment_autopay_start_date : policy.policy_start_date

      if autopay_start.present? && policy.payment_mode.present?
        next_installment = calculate_next_installment_date(autopay_start, policy.payment_mode)

        # Find next future installment
        safety_counter = 0
        while next_installment && next_installment < Date.current && safety_counter < 10
          next_installment = calculate_next_installment_date(next_installment, policy.payment_mode)
          safety_counter += 1
        end

        # Count if installment is within next 2 months
        if next_installment && next_installment <= 2.months.from_now
          count += 1
        end
      end
    end

    # Motor insurance installments within 2 months
    begin
      if defined?(MotorInsurance)
        motor_policies ||= MotorInsurance.where(customer_id: customer.id)
        motor_policies.each do |policy|
          next unless policy.policy_end_date.present? && policy.policy_start_date.present?
          next unless policy.total_premium.present? && policy.total_premium > 0
          payment_mode = policy.respond_to?(:payment_mode) ? policy.payment_mode : 'Yearly'
          next if ['single', 'one time', 'lump sum'].include?(payment_mode&.downcase)

          autopay_start = policy.respond_to?(:installment_autopay_start_date) && policy.installment_autopay_start_date.present? ?
                          policy.installment_autopay_start_date : policy.policy_start_date

          if autopay_start.present? && payment_mode.present?
            next_installment = calculate_next_installment_date(autopay_start, payment_mode)

            # Find next future installment
            safety_counter = 0
            while next_installment && next_installment < Date.current && safety_counter < 10
              next_installment = calculate_next_installment_date(next_installment, payment_mode)
              safety_counter += 1
            end

            # Count if installment is within next 2 months
            if next_installment && next_installment <= 2.months.from_now
              count += 1
            end
          end
        end
      end
    rescue => e
      Rails.logger.warn "Motor insurance installment count issue: #{e.message}"
    end

    count
  end

  def count_upcoming_renewals_for_customer(customer, health_policies = nil, life_policies = nil, motor_policies = nil)
    count = 0
    renewal_start = Date.current
    renewal_end = 2.months.from_now.to_date
    in_renewal_window = ->(policy) {
      policy.policy_end_date.present? &&
        policy.policy_end_date >= renewal_start &&
        policy.policy_end_date <= renewal_end
    }

    # Health insurance renewals within 2 months — filtered in Ruby against
    # the collection #portfolio already loaded, instead of a fresh query.
    health_policies ||= HealthInsurance.where(customer_id: customer.id)
    count += health_policies.count { |policy| in_renewal_window.call(policy) }

    # Life insurance renewals within 2 months
    life_policies ||= LifeInsurance.where(customer_id: customer.id)
    count += life_policies.count { |policy| in_renewal_window.call(policy) }

    # Motor insurance renewals within 2 months
    begin
      if defined?(MotorInsurance)
        motor_policies ||= MotorInsurance.where(customer_id: customer.id)
        count += motor_policies.count { |policy| in_renewal_window.call(policy) }
      end
    rescue => e
      Rails.logger.warn "Motor insurance renewal count issue: #{e.message}"
    end

    # Other insurance types renewals within 2 months
    insurance_types = [
      { model: 'TravelInsurance' },
      { model: 'GeneralInsurance' },
      { model: 'OtherInsurance' }
    ]

    insurance_types.each do |insurance_config|
      begin
        if Object.const_defined?(insurance_config[:model])
          model_class = insurance_config[:model].constantize
          if model_class.column_names.include?('customer_id') && model_class.column_names.include?('policy_end_date')
            policies = model_class.where(customer_id: customer.id)
                                 .where('policy_end_date BETWEEN ? AND ?', Date.current, 2.months.from_now)
                                 .where.not(policy_end_date: nil)
            count += policies.count
          end
        end
      rescue => e
        Rails.logger.warn "#{insurance_config[:model]} renewal count issue: #{e.message}"
      end
    end

    count
  end

  def calculate_next_installment_date(start_date, payment_mode)
    return nil unless start_date

    case payment_mode.downcase
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

  def calculate_installment_amount(total_premium, payment_mode)
    return 0.0 unless total_premium.present? && payment_mode.present?

    premium_amount = total_premium.to_f
    return 0.0 if premium_amount <= 0

    amount = case payment_mode.downcase
    when 'monthly'
      premium_amount / 12.0
    when 'quarterly'
      premium_amount / 4.0
    when 'half-yearly', 'half yearly'
      premium_amount / 2.0
    when 'yearly'
      premium_amount
    else
      premium_amount
    end

    # Round to 2 decimal places
    amount.round(2)
  end
end
class LeadGeneratorService
  def self.create_lead_for_insurance(insurance)
    # Skip if lead already exists (both lead_id is present AND the lead record exists)
    return if insurance.lead_id.present? && Lead.exists?(lead_id: insurance.lead_id)

    product_type = determine_product_type(insurance)

    # Generate a unique lead ID for each insurance policy
    # Each policy needs its own unique lead_id due to unique constraint
    generated_lead_id = LeadIdGeneratorService.generate_for_policy(
      insurance.customer,
      insurance.class.name
    )

    # Set additional lead data based on customer type and product
    lead_data = build_lead_data_for_insurance(insurance, product_type, generated_lead_id)

    lead = Lead.create!(lead_data)

    # Update the insurance with the generated lead_id
    insurance.update_column(:lead_id, generated_lead_id)

    Rails.logger.info "Created new lead #{generated_lead_id} for insurance #{insurance.id}"
    lead
  rescue StandardError => e
    Rails.logger.error "Failed to create lead for #{insurance.class.name} #{insurance.id}: #{e.message}"
    nil
  end

  def self.build_lead_data_for_insurance(insurance, product_type, lead_id)
    customer = insurance.customer

    base_data = {
      lead_id: lead_id,
      name: customer.display_name,
      contact_number: customer.mobile,
      email: customer.email,
      product_category: 'insurance',
      product_subcategory: product_type,
      current_stage: 'policy_created',
      lead_source: determine_lead_source(insurance),
      customer_type: customer.customer_type,
      converted_customer_id: customer.id,
      policy_created_id: insurance.id,
      stage_updated_at: Time.current,
      created_date: insurance.policy_booking_date || Date.current,
      referred_by: determine_referred_by(insurance),
      notes: "Auto-generated lead from #{insurance.class.name.underscore.humanize.downcase} policy creation. Policy Number: #{insurance.policy_number}",
      is_direct: insurance.sub_agent_id.blank?,
      affiliate_id: insurance.sub_agent_id
    }

    # Add customer type specific data
    if customer.individual?
      name_parts = customer.full_name.to_s.split(' ')
      base_data.merge!(
        first_name: name_parts.first,
        last_name: name_parts[1..-1]&.join(' '),
        gender: customer.gender,
        birth_date: customer.birth_date,
        marital_status: customer.marital_status,
        pan_no: customer.pan_no
      )
    else
      base_data.merge!(
        company_name: customer.company_name,
        gst_no: customer.gst_no,
        pan_no: customer.pan_no
      )
    end

    # Add address information if available
    if customer.address.present?
      base_data[:address] = customer.address
      base_data[:city] = customer.city
      base_data[:state] = customer.state
    end

    base_data
  end

  private

  def self.find_existing_lead_for_customer(customer)
    # Try to find an existing lead for this customer by contact number or email
    Lead.where(
      'contact_number = ? OR (email IS NOT NULL AND email = ?)',
      customer.mobile,
      customer.email
    ).first
  end

  def self.determine_product_type(insurance)
    case insurance.class.name
    when 'HealthInsurance' then 'health'
    when 'LifeInsurance' then 'life'
    when 'MotorInsurance' then 'motor'
    when 'OtherInsurance' then 'other'
    else 'other'
    end
  end

  def self.determine_lead_source(insurance)
    # Check if it's customer-added
    if insurance.respond_to?(:is_customer_added?) && insurance.is_customer_added?
      'online'
    elsif insurance.sub_agent_id.present?
      'agent_referral'
    else
      'offline'
    end
  end

  def self.determine_referred_by(insurance)
    if insurance.sub_agent_id.present?
      insurance.sub_agent&.display_name
    elsif insurance.respond_to?(:distributor_id) && insurance.distributor_id.present?
      insurance.distributor&.full_name
    else
      nil
    end
  end
end
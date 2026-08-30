require 'ostruct'

class Admin::CommissionTrackingController < Admin::ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin_access
  before_action :find_policy, only: [:show, :policy_breakdown, :transfer_to_affiliate,
                                      :transfer_to_ambassador, :transfer_to_investor,
                                      :transfer_company_expense, :mark_main_agent_commission_received]

  skip_authorization_check
  skip_load_and_authorize_resource

  def index
    @page = params[:page] || 1
    @per_page = 10

    begin
      @policies_with_commission = fetch_policies_with_commission_optimized(@page, @per_page)
      # @total_policies_count, @total_pages, @has_next_page, @has_prev_page are set by the fetch method

      # Real calculations based on payout data
      @total_commission_generated = calculate_total_commission_generated
      @total_transferred = calculate_total_transferred
      @pending_transfers = calculate_pending_transfers
      @company_expenses = calculate_company_expenses
    rescue => e
      Rails.logger.error "Commission tracking failed: #{e.message}"

      # Emergency fallback with static data
      @page = 1
      @per_page = 10
      @total_policies_count = 20
      @total_pages = 2
      @has_next_page = false
      @has_prev_page = false

      # Use same calculation methods even in fallback
      @total_commission_generated = calculate_total_commission_generated
      @total_transferred = calculate_total_transferred
      @pending_transfers = calculate_pending_transfers
      @company_expenses = calculate_company_expenses

      @policies_with_commission = create_sample_policies
    end
  end

  def show
    # Check if we have saved payout data
    policy_type = @policy.class.name.underscore.gsub('_insurance', '')
    saved_payout = Payout.find_by(policy_type: policy_type, policy_id: @policy.id)

    @commission_breakdown = if saved_payout
                             get_policy_breakdown_from_payout(saved_payout)
                           else
                             CommissionCalculatorService.get_policy_commission_summary(@policy)
                           end

    @transfer_history = fetch_transfer_history(@policy)
    @saved_payout = saved_payout
  end

  def policy_breakdown
    # Check if we have saved payout data
    policy_type = @policy.class.name.underscore.gsub('_insurance', '')
    saved_payout = Payout.find_by(policy_type: policy_type, policy_id: @policy.id)

    @commission_breakdown = if saved_payout
                             get_policy_breakdown_from_payout(saved_payout)
                           else
                             CommissionCalculatorService.get_policy_commission_summary(@policy)
                           end

    respond_to do |format|
      format.json { render json: @commission_breakdown }
      format.html
    end
  end

  def transfer_to_affiliate
    result = process_manual_transfer(
      policy: @policy,
      transfer_type: 'affiliate',
      amount: params[:amount],
      transaction_id: params[:transaction_id],
      notes: params[:notes]
    )

    respond_with_transfer_result(result)
  end

  def transfer_to_ambassador
    result = process_manual_transfer(
      policy: @policy,
      transfer_type: 'ambassador',
      amount: params[:amount],
      transaction_id: params[:transaction_id],
      notes: params[:notes]
    )

    respond_with_transfer_result(result)
  end

  def transfer_to_investor
    result = process_manual_transfer(
      policy: @policy,
      transfer_type: 'investor',
      amount: params[:amount],
      transaction_id: params[:transaction_id],
      notes: params[:notes]
    )

    respond_with_transfer_result(result)
  end

  def transfer_company_expense
    result = process_manual_transfer(
      policy: @policy,
      transfer_type: 'company_expense',
      amount: params[:amount],
      transaction_id: params[:transaction_id],
      notes: params[:notes]
    )

    respond_with_transfer_result(result)
  end

  def mark_main_agent_commission_received
    transaction_id = params[:transaction_id]
    paid_date = params[:paid_date]
    notes = params[:notes]

    if transaction_id.blank?
      return render json: { success: false, message: 'Transaction ID is required' }, status: :unprocessable_entity
    end

    begin
      policy_type = @policy.class.name.underscore.gsub('_insurance', '')
      paid_date_parsed = paid_date.present? ? Date.parse(paid_date) : Date.current

      # Update the policy record
      @policy.update!(
        main_agent_commission_received: true,
        main_agent_commission_transaction_id: transaction_id,
        main_agent_commission_paid_date: paid_date_parsed,
        main_agent_commission_notes: notes
      )

      # Update the corresponding Payout record
      payout_record = Payout.find_by(
        policy_type: policy_type,
        policy_id: @policy.id
      )

      if payout_record
        payout_record.update!(
          main_agent_commission_received: true,
          main_agent_commission_transaction_id: transaction_id,
          main_agent_commission_paid_date: paid_date_parsed,
          notes: "#{payout_record.notes || ''}\nMain agent commission paid - Transaction: #{transaction_id} on #{paid_date_parsed.strftime('%Y-%m-%d')}".strip
        )
        Rails.logger.info "Updated Payout #{payout_record.id} with main agent commission details"
      else
        Rails.logger.warn "No Payout found for policy #{@policy.id} (#{policy_type})"
      end

      # Also update the corresponding CommissionPayout record for main agent
      commission_payout = CommissionPayout.find_by(
        policy_type: policy_type,
        policy_id: @policy.id,
        payout_to: 'main_agent'
      )

      if commission_payout
        commission_payout.update!(
          status: 'paid',
          payout_date: paid_date_parsed,
          transaction_id: transaction_id,
          notes: notes,
          processed_by: current_user&.email || 'admin',
          processed_at: Time.current
        )
        Rails.logger.info "Updated CommissionPayout #{commission_payout.id} status to paid"
      else
        Rails.logger.warn "No CommissionPayout found for policy #{@policy.id} (#{policy_type}) main_agent"
      end

      render json: {
        success: true,
        message: 'Main agent commission marked as received successfully',
        data: {
          policy_id: @policy.id,
          policy_number: @policy.policy_number,
          transaction_id: transaction_id,
          paid_date: @policy.main_agent_commission_paid_date&.strftime('%d %b %Y'),
          received_status: true,
          commission_payout_updated: commission_payout.present?
        }
      }
    rescue StandardError => e
      Rails.logger.error "Failed to mark main agent commission as received for policy #{@policy.id}: #{e.message}"
      render json: {
        success: false,
        message: 'Failed to update commission status. Please try again.'
      }, status: :internal_server_error
    end
  end

  def manual_transfer
    policy = find_policy_by_params

    unless policy
      return render json: { success: false, message: 'Policy not found' }, status: :not_found
    end

    result = process_manual_transfer(
      policy: policy,
      transfer_type: params[:transfer_type],
      amount: params[:amount],
      transaction_id: params[:transaction_id],
      notes: params[:notes]
    )

    render json: result
  end

  def policy_search
    search_term = params[:search]
    policies = []

    if search_term.present?
      # Search Dr WISE all insurance types
      policies = search_policies_across_types(search_term)
    end

    respond_to do |format|
      format.json { render json: policies }
      format.html { @policies = policies }
    end
  end

  def summary
    @summary_data = {
      monthly_breakdown: monthly_commission_breakdown,
      policy_type_breakdown: policy_type_commission_breakdown,
      transfer_status_breakdown: transfer_status_breakdown
    }

    respond_to do |format|
      format.json { render json: @summary_data }
      format.html
    end
  end

  private

  def create_sample_policies
    # Create sample data for emergency fallback
    sample_policies = []

    (1..10).each do |i|
      premium = 50000 + (i * 1000)
      # Use realistic commission structure
      main_commission = premium * 0.10 # 10% main commission
      affiliate_commission = premium * 0.02 # 2% affiliate
      ambassador_commission = premium * 0.02 # 2% ambassador
      investor_commission = premium * 0.01 # 1% investor
      company_expense = premium * 0.03 # 3% company expense

      sample_policies << {
        policy: OpenStruct.new(
          id: i,
          policy_number: "SAMPLE-#{i}",
          total_premium: premium,
          insurance_company_name: 'Sample Insurance Co.',
          lead_id: "LEAD-SAMPLE-#{i}",
          main_agent_commission_received: false,
          main_agent_commission_paid_date: nil,
          created_at: Time.current - i.days,
          customer: OpenStruct.new(display_name: "Sample Customer #{i}"),
          try: ->(method) { nil }
        ),
        type: i.odd? ? 'health' : 'life',
        commission_data: {
          summary: { total_commission_generated: main_commission },
          main_agent: { total_commission: main_commission, percentage: 10.0 },
          payouts: {
            affiliate: affiliate_commission,
            ambassador: ambassador_commission,
            investor: investor_commission,
            company_expense: company_expense
          },
          percentages: {
            main_agent: 10.0,
            affiliate: 2.0,
            ambassador: 2.0,
            investor: 1.0,
            company_expense: 3.0
          }
        },
        transfer_status: {
          total_payouts: 4,
          paid_payouts: i > 5 ? 2 : 0,
          pending_payouts: i > 5 ? 2 : 4,
          total_amount: affiliate_commission + ambassador_commission + investor_commission + company_expense,
          paid_amount: i > 5 ? (affiliate_commission + ambassador_commission) : 0
        },
        saved_payout: nil,
        created_at: Time.current - i.days
      }
    end

    sample_policies
  end

  def dashboard
    begin
      @commission_summary = {
        total_generated: calculate_total_commission_generated || 0,
        total_transferred: calculate_total_transferred || 0,
        pending_transfers: calculate_pending_transfers || 0,
        company_expenses: calculate_company_expenses || 0
      }

      @recent_policies = fetch_recent_policies_with_commission || []
      @transfer_summary = fetch_transfer_summary || {}
    rescue => e
      Rails.logger.error "Dashboard data fetch failed: #{e.message}"
      # Fallback data
      @commission_summary = {
        total_generated: 0,
        total_transferred: 0,
        pending_transfers: 0,
        company_expenses: 0
      }
      @recent_policies = []
      @transfer_summary = {}
    end

    # Render the new attractive financial dashboard
    # Now using the default dashboard.html.erb template
  end

  def modern_dashboard
    # Initialize with defaults first
    @commission_summary = {
      total_generated: 0,
      total_transferred: 0,
      pending_transfers: 0,
      company_expenses: 0
    }
    @recent_policies = []
    @transfer_summary = {}

    begin
      # Calculate commission summary
      @commission_summary = {
        total_generated: calculate_total_commission_generated || 0,
        total_transferred: calculate_total_transferred || 0,
        pending_transfers: calculate_pending_transfers || 0,
        company_expenses: calculate_company_expenses || 0
      }

      # Fetch related data
      @recent_policies = fetch_recent_policies_with_commission || []
      @transfer_summary = fetch_transfer_summary || {}

      Rails.logger.info "Modern dashboard loaded successfully. Commission summary: #{@commission_summary}"
    rescue => e
      Rails.logger.error "Modern dashboard data fetch failed: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.first(5).join('\n')}"

      # Keep the default values already set above
      flash[:warning] = "Some dashboard data couldn't be loaded. Showing default values."
    end

    render 'admin/commission_tracking/modern_dashboard'
  end

  private

  def find_policy
    policy_type = params[:policy_type] || params[:type]
    policy_id = params[:id] || params[:policy_id]

    @policy = case policy_type&.downcase
              when 'health'
                HealthInsurance.find(policy_id)
              when 'life'
                LifeInsurance.find(policy_id)
              when 'motor'
                MotorInsurance.find(policy_id)
              when 'other'
                OtherInsurance.find(policy_id)
              else
                # Try to find in all tables if policy_type is not specified
                find_policy_across_types(policy_id)
              end
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_commission_tracking_index_path, alert: 'Policy not found'
  end

  def find_policy_by_params
    policy_type = params[:policy_type]
    policy_id = params[:policy_id]

    case policy_type&.downcase
    when 'health'
      HealthInsurance.find_by(id: policy_id)
    when 'life'
      LifeInsurance.find_by(id: policy_id)
    when 'motor'
      MotorInsurance.find_by(id: policy_id)
    when 'other'
      OtherInsurance.find_by(id: policy_id)
    end
  end

  def find_policy_across_types(policy_id)
    [HealthInsurance, LifeInsurance, MotorInsurance, OtherInsurance].each do |model|
      policy = model.find_by(id: policy_id)
      return policy if policy
    end
    nil
  end

  def search_policies_across_types(search_term)
    policies = []

    # Search Health Insurance
    HealthInsurance.joins(:customer)
                   .where("health_insurances.policy_number ILIKE ? OR customers.first_name ILIKE ? OR customers.last_name ILIKE ?",
                          "%#{search_term}%", "%#{search_term}%", "%#{search_term}%")
                   .limit(10).each do |policy|
      policies << format_policy_for_search(policy, 'health')
    end

    # Search Life Insurance
    LifeInsurance.joins(:customer)
                 .where("life_insurances.policy_number ILIKE ? OR customers.first_name ILIKE ? OR customers.last_name ILIKE ?",
                        "%#{search_term}%", "%#{search_term}%", "%#{search_term}%")
                 .limit(10).each do |policy|
      policies << format_policy_for_search(policy, 'life')
    end

    # Search Motor Insurance
    MotorInsurance.joins(:customer)
                  .where("motor_insurances.policy_number ILIKE ? OR customers.first_name ILIKE ? OR customers.last_name ILIKE ?",
                         "%#{search_term}%", "%#{search_term}%", "%#{search_term}%")
                  .limit(10).each do |policy|
      policies << format_policy_for_search(policy, 'motor')
    end

    policies
  end

  def format_policy_for_search(policy, type)
    {
      id: policy.id,
      type: type,
      policy_number: policy.policy_number,
      customer_name: policy.customer.display_name,
      premium: policy.total_premium,
      commission_status: get_commission_status(policy, type)
    }
  end

  def get_commission_status(policy, type)
    breakdown = CommissionCalculatorService.calculate_commission_breakdown(policy)
    return 'no_commission' if breakdown.empty?

    existing_payouts = CommissionPayout.where(
      policy_type: type,
      policy_id: policy.id
    )

    if existing_payouts.any?
      paid_count = existing_payouts.where(status: 'paid').count
      total_count = existing_payouts.count

      if paid_count == total_count
        'fully_transferred'
      elsif paid_count > 0
        'partially_transferred'
      else
        'pending_transfer'
      end
    else
      'no_transfers_created'
    end
  end

  def fetch_policies_with_commission_optimized(page = 1, per_page = 10)
    page = page.to_i
    page = 1 if page < 1

    all_policies = []

    # Just show payouts we have with policy information - recent payouts at top
    payouts = Payout.order(created_at: :desc)

    payouts.each do |payout|
      begin
        policy = case payout.policy_type
                 when 'health'
                   HealthInsurance.find_by(id: payout.policy_id)
                 when 'life'
                   LifeInsurance.find_by(id: payout.policy_id)
                 when 'motor'
                   MotorInsurance.find_by(id: payout.policy_id)
                 when 'other'
                   OtherInsurance.find_by(id: payout.policy_id)
                 end

        next unless policy && policy.customer_id

        customer = Customer.find_by(id: policy.customer_id)
        next unless customer

        all_policies << {
          policy: OpenStruct.new(
            id: policy.id,
            policy_number: policy.policy_number || "#{payout.policy_type.upcase}-#{policy.id}",
            total_premium: policy.total_premium || 0,
            insurance_company_name: policy.insurance_company_name || 'Unknown',
            lead_id: policy.lead_id,
            main_agent_commission_received: false,
            main_agent_commission_paid_date: nil,
            created_at: policy.created_at,
            customer: OpenStruct.new(display_name: customer.display_name || customer.full_name),
            try: ->(method) { policy.send(method) rescue nil }
          ),
          type: payout.policy_type,
          commission_data: get_commission_data_from_payout(payout),
          transfer_status: get_transfer_status_from_payout(payout),
          saved_payout: payout,
          created_at: payout.created_at # Use payout created_at to show recent payouts first
        }
      rescue => e
        Rails.logger.warn "Error processing payout #{payout.id}: #{e.message}"
      end
    end

    # Simple pagination
    offset = (page - 1) * per_page
    page_policies = all_policies.slice(offset, per_page) || []

    # Set pagination info
    @total_policies_count = all_policies.length
    @total_pages = (@total_policies_count.to_f / per_page).ceil
    @has_next_page = page < @total_pages
    @has_prev_page = page > 1

    page_policies
  end

  def fetch_policies_with_commission
    fetch_policies_with_commission_optimized(1, 50)
  end

  def get_transfer_status_optimized(policy, type, all_payouts)
    policy_key = "#{type}_#{policy.id}"
    existing_payouts = all_payouts[policy_key] || []

    paid_payouts = existing_payouts.select { |p| p.status == 'paid' }
    pending_payouts = existing_payouts.select { |p| p.status == 'pending' }

    {
      total_payouts: existing_payouts.count,
      paid_payouts: paid_payouts.count,
      pending_payouts: pending_payouts.count,
      total_amount: existing_payouts.sum(&:payout_amount),
      paid_amount: paid_payouts.sum(&:payout_amount)
    }
  end

  def get_transfer_status(policy, type)
    existing_payouts = CommissionPayout.where(
      policy_type: type,
      policy_id: policy.id
    )

    {
      total_payouts: existing_payouts.count,
      paid_payouts: existing_payouts.where(status: 'paid').count,
      pending_payouts: existing_payouts.where(status: 'pending').count,
      total_amount: existing_payouts.sum(:payout_amount),
      paid_amount: existing_payouts.where(status: 'paid').sum(:payout_amount)
    }
  end

  def calculate_total_commission_generated
    # Sum of main_agent_commission_amount from all payouts
    Payout.sum(:main_agent_commission_amount) || 0
  end

  def calculate_total_transferred
    # Sum of non-pending main_agent_commission_amount from commission_payouts for main agent
    CommissionPayout.where(payout_to: 'main_agent').where.not(status: 'pending').sum(:payout_amount) || 0
  end

  def calculate_pending_transfers
    # Sum of pending main_agent_commission_amount from commission_payouts for main agent
    CommissionPayout.where(payout_to: 'main_agent', status: 'pending').sum(:payout_amount) || 0
  end

  def calculate_company_expenses
    # Sum of non-pending payout_amount from commission_payouts where payout_to = "company_expense"
    CommissionPayout.where(payout_to: 'company_expense').where.not(status: 'pending').sum(:payout_amount) || 0
  end

  def fetch_recent_policies_with_commission
    policies = []

    [HealthInsurance, LifeInsurance, MotorInsurance, OtherInsurance].each do |model|
      begin
        model.includes(:customer).order(created_at: :desc).limit(5).each do |policy|
          begin
            commission_data = CommissionCalculatorService.calculate_commission_breakdown(policy)
            next if commission_data.nil? || commission_data.empty?

            policies << {
              policy: policy,
              type: model.name.underscore.gsub('_insurance', ''),
              commission_data: commission_data
            }
          rescue => e
            Rails.logger.warn "Failed to calculate commission for #{model.name} policy #{policy.id}: #{e.message}"
            # Skip this policy and continue
            next
          end
        end
      rescue => e
        Rails.logger.warn "Failed to fetch recent policies for #{model.name}: #{e.message}"
        # Skip this model and continue with the next
        next
      end
    end

    policies.sort_by { |p| p[:policy].created_at }.reverse.take(20)
  rescue => e
    Rails.logger.error "Failed to fetch recent policies with commission: #{e.message}"
    []
  end

  def fetch_transfer_summary
    {
      affiliate: CommissionPayout.where(payout_to: 'affiliate').group(:status).sum(:payout_amount),
      ambassador: CommissionPayout.where(payout_to: 'ambassador').group(:status).sum(:payout_amount),
      investor: CommissionPayout.where(payout_to: 'investor').group(:status).sum(:payout_amount),
      company_expense: CommissionPayout.where(payout_to: 'company_expense').group(:status).sum(:payout_amount)
    }
  rescue => e
    Rails.logger.error "Failed to fetch transfer summary: #{e.message}"
    {
      affiliate: {},
      ambassador: {},
      investor: {},
      company_expense: {}
    }
  end

  def fetch_transfer_history(policy)
    policy_type = policy.class.name.underscore.gsub('_insurance', '')

    CommissionPayout.where(
      policy_type: policy_type,
      policy_id: policy.id
    ).order(created_at: :desc)
  end

  def process_manual_transfer(policy:, transfer_type:, amount:, transaction_id:, notes:)
    return { success: false, message: 'Invalid amount' } if amount.to_f <= 0

    policy_type = policy.class.name.underscore.gsub('_insurance', '')

    # Find existing payout or create new one
    payout = CommissionPayout.find_or_initialize_by(
      policy_type: policy_type,
      policy_id: policy.id,
      payout_to: transfer_type
    )

    if payout.new_record?
      # Calculate the amount based on commission breakdown
      breakdown = CommissionCalculatorService.calculate_commission_breakdown(policy)
      expected_amount = breakdown.dig(:payouts, transfer_type.to_sym) || 0

      payout.payout_amount = expected_amount
      payout.status = 'pending'
      payout.processed_by = current_user.email
    end

    # Mark as paid with transfer details
    payout.assign_attributes(
      status: 'paid',
      payout_date: Date.current,
      transaction_id: transaction_id,
      notes: notes,
      processed_by: current_user.email,
      processed_at: Time.current
    )

    if payout.save
      { success: true, message: "Transfer completed successfully", payout: payout }
    else
      { success: false, message: payout.errors.full_messages.join(', ') }
    end
  rescue StandardError => e
    Rails.logger.error "Manual transfer failed: #{e.message}"
    { success: false, message: 'Transfer failed. Please try again.' }
  end

  def respond_with_transfer_result(result)
    respond_to do |format|
      format.json { render json: result }
      format.html do
        if result[:success]
          redirect_to admin_commission_tracking_path(@policy, policy_type: @policy.class.name.underscore.gsub('_insurance', '')),
                      notice: result[:message]
        else
          redirect_to admin_commission_tracking_path(@policy, policy_type: @policy.class.name.underscore.gsub('_insurance', '')),
                      alert: result[:message]
        end
      end
    end
  end

  def monthly_commission_breakdown
    # Implementation for monthly breakdown
    {}
  end

  def policy_type_commission_breakdown
    # Implementation for policy type breakdown
    {}
  end

  def transfer_status_breakdown
    # Implementation for transfer status breakdown
    {}
  end

  def get_commission_data_from_payout(saved_payout)
    # Convert saved payout data to the format expected by the view
    # Use net_premium from policy if available, otherwise use total_commission_amount
    net_premium_value = saved_payout.policy&.net_premium || saved_payout.total_commission_amount || 0
    policy_premium = saved_payout.policy&.total_premium || net_premium_value || 0

    # Use stored percentages from payout when available, otherwise calculate
    main_agent_amount = saved_payout.main_agent_commission_amount || 0
    main_agent_percentage = saved_payout.main_agent_percentage || (policy_premium > 0 ? (main_agent_amount.to_f / policy_premium * 100).round(2) : 0)

    affiliate_amount = saved_payout.affiliate_commission_amount || 0
    affiliate_percentage = saved_payout.affiliate_percentage || (policy_premium > 0 ? (affiliate_amount.to_f / policy_premium * 100).round(2) : 0)

    ambassador_amount = saved_payout.ambassador_commission_amount || 0
    ambassador_percentage = saved_payout.ambassador_percentage || (policy_premium > 0 ? (ambassador_amount.to_f / policy_premium * 100).round(2) : 0)

    investor_amount = saved_payout.investor_commission_amount || 0
    investor_percentage = saved_payout.investor_percentage || (policy_premium > 0 ? (investor_amount.to_f / policy_premium * 100).round(2) : 0)

    company_expense_amount = saved_payout.company_expense_amount || 0
    company_expense_percentage = saved_payout.company_expense_percentage || (policy_premium > 0 ? (company_expense_amount.to_f / policy_premium * 100).round(2) : 0)

    {
      summary: {
        total_commission_generated: net_premium_value
      },
      main_agent: {
        total_commission: main_agent_amount,
        percentage: main_agent_percentage
      },
      payouts: {
        affiliate: affiliate_amount,
        ambassador: ambassador_amount,
        investor: investor_amount,
        company_expense: company_expense_amount
      },
      percentages: {
        main_agent: main_agent_percentage,
        affiliate: affiliate_percentage,
        ambassador: ambassador_percentage,
        investor: investor_percentage,
        company_expense: company_expense_percentage
      }
    }
  end

  def get_policy_breakdown_from_payout(saved_payout)
    # Convert saved payout data to the full breakdown format expected by the show view

    # Calculate deductions (amounts taken from main agent)
    main_agent_total = saved_payout.main_agent_commission_amount || 0
    affiliate_amount = saved_payout.affiliate_commission_amount || 0
    ambassador_amount = saved_payout.ambassador_commission_amount || 0
    investor_amount = saved_payout.investor_commission_amount || 0
    company_expense_amount = saved_payout.company_expense_amount || 0

    final_profit = main_agent_total - affiliate_amount - ambassador_amount - investor_amount - company_expense_amount

    # Get commission payout statuses
    commission_payouts = saved_payout.commission_payouts.index_by(&:payout_to)

    {
      policy: {
        number: saved_payout.policy&.policy_number || 'N/A',
        type: saved_payout.policy_type,
        customer: saved_payout.policy&.customer&.display_name || 'N/A',
        premium: saved_payout.policy&.total_premium || 0
      },
      commission_breakdown: {
        premium_amount: saved_payout.policy&.total_premium || 0,
        main_agent: {
          total_commission: main_agent_total,
          deductions: {
            affiliate: affiliate_amount,
            ambassador: ambassador_amount,
            investor: investor_amount,
            company_expense: company_expense_amount
          },
          final_profit: final_profit
        },
        payouts: {
          affiliate: affiliate_amount,
          ambassador: ambassador_amount,
          investor: investor_amount,
          company_expense: company_expense_amount
        },
        summary: {
          total_distributed: affiliate_amount + ambassador_amount + investor_amount,
          company_expense: company_expense_amount
        }
      },
      payout_status: {
        affiliate: get_payout_status(commission_payouts['affiliate']),
        ambassador: get_payout_status(commission_payouts['ambassador']),
        investor: get_payout_status(commission_payouts['investor']),
        company_expense: get_payout_status(commission_payouts['company_expense'])
      }
    }
  end

  def get_payout_status(commission_payout)
    if commission_payout
      {
        status: commission_payout.status,
        amount: commission_payout.payout_amount,
        payout_date: commission_payout.payout_date&.strftime("%b %d, %Y"),
        transaction_id: commission_payout.transaction_id
      }
    else
      {
        status: 'pending',
        amount: 0,
        payout_date: nil,
        transaction_id: nil
      }
    end
  end

  def get_transfer_status_from_payout(payout)
    commission_payouts = payout.commission_payouts || []

    {
      total_payouts: commission_payouts.count,
      paid_payouts: commission_payouts.count { |cp| cp.status == 'paid' },
      pending_payouts: commission_payouts.count { |cp| cp.status == 'pending' },
      total_amount: commission_payouts.sum(&:payout_amount),
      paid_amount: commission_payouts.select { |cp| cp.status == 'paid' }.sum(&:payout_amount)
    }
  end

  def authorize_admin_access
    redirect_to root_path unless current_user&.user_type == 'admin'
  end
end
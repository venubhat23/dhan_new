class Admin::Settings::SystemController < Admin::Settings::BaseController

  def index
    # Placeholder for system settings
    @system_settings = {
      app_name: 'DemoFarm Admin',
      version: '1.0.0',
      maintenance_mode: false,
      email_notifications: true,
      backup_frequency: 'Daily',
      session_timeout: 30,
      max_file_upload_size: 10
    }

    # Get company expenses percentage from database
    @company_expenses_percentage = SystemSetting.company_expenses_percentage

    # Get default pagination per page from database
    @default_pagination_per_page = SystemSetting.default_pagination_per_page

    # Get commission settings from database
    @default_main_agent_commission = SystemSetting.default_main_agent_commission
    @default_affiliate_commission = SystemSetting.default_affiliate_commission
    @default_ambassador_commission = SystemSetting.default_ambassador_commission
    @default_company_expenses = SystemSetting.default_company_expenses

    # Get business settings
    @business_setting = SystemSetting.business_settings

    # Get collect from store settings
    @collect_from_store_enabled = SystemSetting.collect_from_store_enabled?
    @stores_count = Store.count

    # Get delivery only at shop settings
    @delivery_only_at_shop_enabled = SystemSetting.delivery_only_at_shop_enabled?
    @shop_addresses = SystemSetting.get_shop_addresses

    # Get low stock alert settings
    @low_stock_alert_enabled   = SystemSetting.low_stock_alert_enabled?
    @low_stock_alert_threshold = SystemSetting.low_stock_alert_threshold
    @low_stock_alert_email     = SystemSetting.low_stock_alert_email
  end

  def update
    success_messages = []

    # Handle company expenses percentage
    if params[:company_expenses_percentage].present?
      percentage = params[:company_expenses_percentage].to_f

      # Validate percentage (should be between 0 and 100)
      if percentage >= 0 && percentage <= 100
        SystemSetting.set_company_expenses_percentage(percentage)
        success_messages << 'Company expenses percentage updated successfully!'
      else
        redirect_to admin_settings_system_path, alert: 'Invalid percentage. Please enter a value between 0 and 100.'
        return
      end
    end

    # Handle default pagination per page
    if params[:default_pagination_per_page].present?
      per_page = params[:default_pagination_per_page].to_i

      # Validate per_page (should be between 5 and 100)
      if per_page >= 5 && per_page <= 100
        SystemSetting.set_default_pagination_per_page(per_page)
        success_messages << 'Default pagination per page updated successfully!'
      else
        redirect_to admin_settings_system_path, alert: 'Invalid pagination value. Please enter a value between 5 and 100.'
        return
      end
    end

    # Handle commission settings update
    if params[:commission_settings_update] == "true"
      commission_params = {
        default_main_agent_commission: params[:default_main_agent_commission]&.to_f,
        default_affiliate_commission: params[:default_affiliate_commission]&.to_f,
        default_ambassador_commission: params[:default_ambassador_commission]&.to_f,
        default_company_expenses: params[:default_company_expenses]&.to_f
      }

      # Validate all commission values
      valid_commissions = commission_params.values.all? do |value|
        value && value >= 0 && value <= 100
      end

      if valid_commissions
        begin
          SystemSetting.update_commission_settings(commission_params)
          success_messages << 'Commission settings updated successfully!'
        rescue => e
          redirect_to admin_settings_system_path, alert: "Error updating commission settings: #{e.message}"
          return
        end
      else
        redirect_to admin_settings_system_path, alert: 'Invalid commission values. Please enter percentages between 0 and 100.'
        return
      end
    end

    # Handle business settings update
    if params[:business_settings_update] == "true"
      begin
        business_params = {
          business_name: params[:business_name],
          address: params[:address],
          mobile: params[:mobile],
          email: params[:email],
          gstin: params[:gstin],
          pan_number: params[:pan_number],
          account_holder_name: params[:account_holder_name],
          bank_name: params[:bank_name],
          account_number: params[:account_number],
          ifsc_code: params[:ifsc_code],
          upi_id: params[:upi_id],
          terms_and_conditions: params[:terms_and_conditions],
          website: params[:website],
          logo_url: params[:logo_url]
        }

        @business_setting = SystemSetting.update_business_settings(business_params)

        # Generate QR code if UPI ID is present
        write_upi_qr_code(@business_setting.upi_id) if @business_setting.upi_id.present?

        # Handle store settings if present
        if params[:collect_from_store_enabled].present?
          SystemSetting.set_collect_from_store_enabled(params[:collect_from_store_enabled] == "1")
          success_messages << 'Store collection settings updated!'
        end

        # Handle delivery only at shop settings if present
        if params[:delivery_only_at_shop].present?
          delivery_params = {
            delivery_only_at_shop: params[:delivery_only_at_shop],
            shop_addresses: params[:shop_addresses]
          }
          SystemSetting.update_delivery_only_at_shop_settings(delivery_params)
          success_messages << 'Delivery settings updated!'
        end

        success_messages << 'Business settings updated successfully!'
      rescue => e
        redirect_to admin_settings_system_path, alert: "Error updating business settings: #{e.message}"
        return
      end
    end

    # Handle collect from store settings update
    if params[:collect_from_store_update] == "true"
      begin
        collect_from_store_enabled = params[:collect_from_store_enabled] == "1"

        SystemSetting.set_collect_from_store_enabled(collect_from_store_enabled)

        if collect_from_store_enabled
          success_messages << 'Collect From Store feature enabled successfully! You can now manage stores.'
        else
          success_messages << 'Collect From Store feature disabled successfully!'
        end
      rescue => e
        redirect_to admin_settings_system_path, alert: "Error updating Collect From Store settings: #{e.message}"
        return
      end
    end

    # Handle low stock alert settings update
    if params[:low_stock_alert_update] == "true"
      begin
        SystemSetting.update_low_stock_settings(
          low_stock_alert_enabled:   params[:low_stock_alert_enabled],
          low_stock_alert_threshold: params[:low_stock_alert_threshold],
          low_stock_alert_email:     params[:low_stock_alert_email]
        )
        success_messages << 'Low stock alert settings updated successfully!'
      rescue => e
        redirect_to admin_settings_system_path, alert: "Error updating low stock settings: #{e.message}"
        return
      end
    end

    # Handle delivery only at shop settings update
    if params[:delivery_only_at_shop_update] == "true"
      begin
        delivery_params = {
          delivery_only_at_shop: params[:delivery_only_at_shop],
          shop_addresses: params[:shop_addresses]
        }

        SystemSetting.update_delivery_only_at_shop_settings(delivery_params)

        if params[:delivery_only_at_shop] == "1"
          success_messages << 'Delivery Only at Shop feature enabled successfully with addresses!'
        else
          success_messages << 'Delivery Only at Shop feature disabled successfully!'
        end
      rescue => e
        redirect_to admin_settings_system_path, alert: "Error updating Delivery Only at Shop settings: #{e.message}"
        return
      end
    end

    if success_messages.any?
      redirect_to admin_settings_system_path, notice: success_messages.join(' ')
    else
      redirect_to admin_settings_system_path, alert: 'Please enter valid values to update.'
    end
  end

  # POST /admin/settings/system/upload_logo
  def upload_logo
    respond_to do |format|
      if params[:logo].present?
        begin
          result = R2Service.upload(params[:logo], folder: 'business_logo')

          if result[:error]
            format.json { render json: { error: result[:error] }, status: :unprocessable_entity }
          else
            format.json { render json: {
              key: result[:key],
              filename: result[:filename],
              public_url: result[:public_url],
              size: result[:size]
            } }
          end
        rescue => e
          Rails.logger.error "Logo R2 upload exception: #{e.message}"
          format.json { render json: { error: "Upload failed: #{e.message}" }, status: :internal_server_error }
        end
      else
        format.json { render json: { error: "No logo file provided" }, status: :bad_request }
      end
    end
  end

  # Generate (and persist) the UPI QR code for the given UPI ID via AJAX,
  # without requiring a full Business Settings form submit.
  def generate_qr_code
    @business_setting = SystemSetting.business_settings
    upi_id = params[:upi_id].to_s.strip

    unless upi_id.match?(/\A[a-zA-Z0-9.\-_]+@[a-zA-Z0-9.\-_]+\z/)
      render json: { success: false, error: 'Please enter a valid UPI ID.' }, status: :unprocessable_entity
      return
    end

    @business_setting.update!(upi_id: upi_id)
    write_upi_qr_code(upi_id)

    render json: { success: true, qr_code_path: @business_setting.qr_code_path }
  rescue => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  private

  def system_setting_params
    params.require(:system_setting).permit(
      :maintenance_mode, :email_notifications, :backup_frequency, :session_timeout,
      :max_file_upload_size, :company_expenses_percentage, :default_pagination_per_page,
      :default_main_agent_commission, :default_affiliate_commission,
      :default_ambassador_commission, :default_company_expenses
    )
  end

  def write_upi_qr_code(upi_id)
    require 'rqrcode'

    # Encode a proper UPI payment deep link so scanning it opens a UPI app
    # with the payee pre-filled, instead of just the raw UPI ID as text.
    payee_name = @business_setting.business_name.presence || 'Merchant'
    upi_uri = "upi://pay?pa=#{ERB::Util.url_encode(upi_id)}&pn=#{ERB::Util.url_encode(payee_name)}&cu=INR"

    qr = RQRCode::QRCode.new(upi_uri)

    svg = qr.as_svg(
      color: "000",
      shape_rendering: "crispEdges",
      module_size: 6,
      standalone: true
    )

    # Upload to R2 rather than local disk — Render's filesystem is ephemeral
    # and wipes public/qr_codes on every deploy/restart.
    result = R2Service.upload_content(
      svg,
      filename: "upi_qr_#{@business_setting.id}.svg",
      content_type: 'image/svg+xml',
      folder: 'qr_codes'
    )

    if result[:error]
      Rails.logger.error "UPI QR R2 upload failed: #{result[:error]}"
      return
    end

    @business_setting.update!(qr_code_path: result[:public_url])
  end
end
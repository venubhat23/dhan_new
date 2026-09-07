class StoreAdmin::CustomersController < StoreAdmin::ApplicationController
  before_action :set_customer, only: [:show, :edit, :update, :destroy, :toggle_status, :generate_password]

  # All customers, matching Admin::CustomersController#index.
  def index
    scope = store_customers

    if params[:search].present?
      term = "%#{params[:search].strip}%"
      scope = scope.where('customers.full_name ILIKE ? OR customers.mobile ILIKE ? OR customers.email ILIKE ? OR customers.company_name ILIKE ?',
                          term, term, term, term)
    end
    scope = scope.where(status: params[:status]) if params[:status].present? && Customer.column_names.include?('status')

    @total_filtered_count = scope.count
    @customers = scope.order(created_at: :desc)
    @customers = @customers.page(params[:page]).per(20) if @customers.respond_to?(:page)

    base = store_customers
    @total_customers = base.count
    @active_customers = Customer.column_names.include?('status') ? base.where(status: [true, nil]).count : @total_customers
    @new_this_month = base.where(created_at: Time.current.all_month).count
  end

  def show
    @store_bookings = store_bookings.where(customer_id: @customer.id)
                                    .order(created_at: :desc).includes(booking_items: :product)
    @store_spend = @store_bookings.where.not(status: ['cancelled', 'returned']).sum(:total_amount)
  end

  def new
    @customer = Customer.new
  end

  def quick_new
    @customer = Customer.new
  end

  def edit; end

  def create
    @customer = Customer.new(customer_params)
    if @customer.save
      redirect_to store_admin_customer_path(@customer), notice: 'Customer created successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @customer.update(customer_params)
      redirect_to store_admin_customer_path(@customer), notice: 'Customer was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    name = @customer.display_name
    ActiveRecord::Base.transaction { purge_customer!(@customer) }
    redirect_to store_admin_customers_path, notice: "Customer '#{name}' has been permanently deleted."
  rescue => e
    redirect_to store_admin_customer_path(@customer), alert: "Failed to delete customer '#{name}': #{e.message}"
  end

  def bulk_delete
    ids = Array(params[:customer_ids]) & store_customers.pluck(:id).map(&:to_s)
    return redirect_to(store_admin_customers_path, alert: 'No customers selected for deletion.') if ids.blank?

    deleted = 0
    errors = []
    Customer.where(id: ids).find_each do |customer|
      begin
        ActiveRecord::Base.transaction { purge_customer!(customer) }
        deleted += 1
      rescue => e
        errors << "#{customer.display_name}: #{e.message}"
      end
    end

    if errors.any?
      redirect_to store_admin_customers_path, alert: "Deleted #{deleted} customer(s). Errors: #{errors.join('; ')}"
    else
      redirect_to store_admin_customers_path, notice: "#{deleted} customer(s) deleted successfully."
    end
  end

  def toggle_status
    if @customer.respond_to?(:status)
      current = @customer.status.nil? ? true : @customer.status
      @customer.update(status: !current)
      text = @customer.status ? 'enabled' : 'disabled'
      respond_to do |format|
        format.html { redirect_back(fallback_location: store_admin_customer_path(@customer), notice: "Customer has been #{text}.") }
        format.json { render json: { status: @customer.status, message: "Customer #{text}" } }
      end
    else
      redirect_to store_admin_customers_path, alert: 'Status functionality requires database migration.'
    end
  end

  def export
    scope = store_customers
    scope = scope.where('customers.full_name ILIKE :q OR customers.mobile ILIKE :q OR customers.email ILIKE :q', q: "%#{params[:search].strip}%") if params[:search].present?
    send_data generate_customers_csv(scope.order(:created_at)), filename: "customers_#{@current_store.name.parameterize}_#{Date.current}.csv"
  end

  # Booking-flow helpers — any customer is reachable here (a counter sale can be
  # for a first-time walk-in).
  def check_mobile
    mobile = normalize_mobile_for_lookup(params[:mobile])
    customer = mobile.present? ? Customer.find_by(mobile: mobile) : nil
    if customer
      render json: { exists: true, customer: { id: customer.id, name: customer.display_name, mobile: customer.mobile, email: customer.email } }
    else
      render json: { exists: false }
    end
  end

  def search_by_name
    query = params[:name].to_s.strip
    if query.length >= 2
      customers = Customer.where('full_name ILIKE :q', q: "%#{query}%").limit(5)
      render json: { customers: customers.map { |c| { id: c.id, name: c.display_name, mobile: c.mobile, email: c.email } } }
    else
      render json: { customers: [] }
    end
  end

  def quick_create
    existing = Customer.find_by(mobile: normalize_mobile_for_lookup(params[:customer][:mobile]))
    if existing
      return redirect_to(new_store_admin_booking_path(customer_id: existing.id),
                         notice: "A customer with this phone number already exists (#{existing.display_name}). Proceeding with the existing customer.")
    end

    @customer = Customer.new(
      full_name: params[:customer][:full_name].to_s.strip,
      mobile:    params[:customer][:mobile].to_s.strip,
      email:     params[:customer][:email].to_s.strip.presence
    )
    mobile_digits = @customer.mobile.gsub(/\D/, '')
    generated_password = "#{mobile_digits[0..3]}@123"
    @customer.password = generated_password
    @customer.password_confirmation = generated_password
    @customer.auto_generated_password = generated_password if @customer.respond_to?(:auto_generated_password)

    if @customer.save
      begin
        login_email = @customer.respond_to?(:real_email?) && @customer.real_email? ? @customer.email : @customer.try(:placeholder_email)
        if login_email.present?
          User.create!(
            first_name: extract_first_name(@customer.full_name), last_name: extract_last_name(@customer.full_name),
            email: login_email, mobile: @customer.mobile,
            password: generated_password, password_confirmation: generated_password,
            user_type: 'customer', city: 'Unknown', state: 'Unknown', pincode: '000000',
            country: 'India', status: true, is_active: true, is_verified: false
          )
        end
      rescue => e
        Rails.logger.warn "Could not create user account for quick customer: #{e.message}"
      end
      redirect_to new_store_admin_booking_path(customer_id: @customer.id),
                  notice: "Customer created! Mobile login password: #{generated_password}. Now complete the booking."
    else
      render :quick_new, status: :unprocessable_entity
    end
  end

  def generate_password
    if params[:password_mode] == 'custom'
      new_password = params[:custom_password].to_s
      return redirect_to(store_admin_customer_path(@customer), alert: 'Password must be at least 6 characters long.') if new_password.length < 6
      return redirect_to(store_admin_customer_path(@customer), alert: 'Password and confirmation do not match.') if new_password != params[:custom_password_confirmation].to_s
    else
      new_password = Customer.respond_to?(:generate_random_password) ? Customer.generate_random_password : SecureRandom.alphanumeric(10)
    end

    ActiveRecord::Base.transaction do
      @customer.password = new_password
      @customer.password_confirmation = new_password
      @customer.auto_generated_password = new_password if @customer.respond_to?(:auto_generated_password)
      @customer.save!

      user = @customer.try(:linked_user)
      if user
        user.update!(password: new_password, password_confirmation: new_password)
        message = 'Password reset for existing user account.'
      else
        login_email = @customer.respond_to?(:real_email?) && @customer.real_email? ? @customer.email : @customer.try(:placeholder_email)
        if login_email.present?
          User.create!(
            first_name: extract_first_name(@customer.full_name), last_name: extract_last_name(@customer.full_name),
            email: login_email, mobile: @customer.mobile,
            password: new_password, password_confirmation: new_password, user_type: 'customer',
            address: @customer.address, city: 'Unknown', state: 'Unknown', pincode: '000000',
            country: 'India', status: true, is_active: true, is_verified: false
          )
          message = @customer.try(:real_email?) ? 'User account created with new password.' :
                    "User account created. The customer logs in with their mobile number (#{@customer.mobile})."
        else
          message = 'Customer password reset. No mobile or email on file, so no separate login account was created.'
        end
      end

      respond_to do |format|
        format.html { redirect_to store_admin_customer_path(@customer), notice: "#{message} Password: #{new_password}" }
        format.json { render json: { success: true, message: message, password: new_password } }
      end
    end
  rescue => e
    respond_to do |format|
      format.html { redirect_to store_admin_customer_path(@customer), alert: "Failed to reset password: #{e.message}" }
      format.json { render json: { success: false, message: "Failed to reset password: #{e.message}" } }
    end
  end

  private

  def set_customer
    @customer = Customer.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to store_admin_customers_path, alert: 'Customer not found.'
  end

  # Hard-delete a customer and every row that references it (raw SQL, bypassing
  # callbacks) — mirrors Admin::CustomersController#bulk_delete.
  def purge_customer!(customer)
    conn = ActiveRecord::Base.connection
    id = customer.id.to_i
    %w[milk_delivery_tasks booking_schedules booking_invoices bookings orders
       subscription_templates customer_formats milk_subscriptions product_reviews
       invoices customer_addresses wishlists carts pending_amounts referrals
       client_requests].each do |table|
      conn.execute("DELETE FROM #{table} WHERE customer_id = #{id}") if conn.table_exists?(table)
    end
    if customer.email.present? && (user = User.find_by(email: customer.email, user_type: 'customer'))
      conn.execute("DELETE FROM users WHERE id = #{user.id.to_i}")
    end
    customer.profile_image_attachment.purge if customer.respond_to?(:profile_image_attachment) && customer.profile_image_attachment.present?
    conn.execute("DELETE FROM customers WHERE id = #{id}")
  end

  def normalize_mobile_for_lookup(mobile)
    Customer.new.send(:normalize_indian_mobile, mobile.to_s)
  rescue
    mobile.to_s.gsub(/\D/, '').last(10)
  end

  def extract_first_name(full_name) = full_name.to_s.split(' ').first || 'Unknown'

  def extract_last_name(full_name)
    names = full_name.to_s.split(' ')
    names.length > 1 ? names[1..-1].join(' ') : 'Unknown'
  end

  def generate_customers_csv(customers)
    require 'csv'
    CSV.generate(headers: true) do |csv|
      csv << %w[ID FullName Email Mobile WhatsappNumber Company Address CreatedAt]
      customers.find_each do |c|
        csv << [c.id, c.full_name, c.email, c.mobile, c.try(:whatsapp_number),
                c.try(:company_name), c.try(:address), c.created_at.strftime('%Y-%m-%d %H:%M:%S')]
      end
    end
  end

  def customer_params
    params.require(:customer).permit(
      :full_name, :email, :mobile, :whatsapp_number, :auto_generated_password,
      :password, :password_confirmation, :birth_date, :gender, :marital_status,
      :pan_no, :gst_no, :company_name, :occupation, :annual_income,
      :emergency_contact_name, :emergency_contact_number, :blood_group,
      :nationality, :preferred_language, :notes, :address, :landmark,
      :shipping_address, :location_link, :location_obtained_at, :location_accuracy,
      :longitude, :latitude, :status
    )
  end
end

class Admin::Settings::UserRolesController < Admin::Settings::BaseController
  include ConfigurablePagination
  before_action :set_user, only: [:show, :edit, :update, :destroy, :toggle_status]

  def index
    @users = User.where(user_type: ['admin', 'agent']).order(:created_at)
    @users = @users.where("first_name ILIKE ? OR last_name ILIKE ? OR email ILIKE ?", "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%") if params[:search].present?
    @users = paginate_records(@users)
  end

  def show
  end

  def new
    @user = User.new
    @sidebar_options = get_sidebar_options
  end

  def edit
    @sidebar_options = get_sidebar_options
  end

  def create
    # Remove role_name from user_params since it's not a User attribute
    user_attributes = user_params.except(:role_name)
    @user = User.new(user_attributes)

    @user.user_type = 'admin'
    @user.status = true

    # Map role_name to role field
    if params[:user][:role_name].present?
      role = find_role_by_display_name(params[:user][:role_name])
      if role
        @user.role = role.name
        @user.role_id = role.id
      else
        @user.errors.add(:role, "Role '#{params[:user][:role_name]}' not found")
      end
    end

    # Store the plain password temporarily for display (before it gets encrypted)
    plain_password = @user.password

    if @user.save
      # Store the original password for showing on the user details page
      @user.update_column(:original_password, plain_password) if plain_password.present?

      # Set special flash to indicate user was just created
      flash[:user_created] = true
      redirect_to admin_settings_user_role_path(@user), notice: 'User was successfully created.'
    else
      @sidebar_options = get_sidebar_options
      render :new, status: :unprocessable_entity
    end
  end

  def update
    # For edit form, only allow updating basic info and permissions, not role or password
    user_attributes = user_params.except(:role_name, :password, :password_confirmation)

    if @user.update(user_attributes)
      redirect_to admin_settings_user_role_path(@user), notice: 'User was successfully updated.'
    else
      @sidebar_options = get_sidebar_options
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @user.destroy
    redirect_to admin_settings_user_roles_path, notice: 'User was successfully deleted.'
  end

  def toggle_status
    @user.update(status: !@user.status)
    redirect_to admin_settings_user_roles_path, notice: "User #{@user.status? ? 'activated' : 'deactivated'} successfully."
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def find_role_by_display_name(display_name)
    # Map display names to database role names
    role_mapping = {
      'Data entry' => 'data_entry',
      'Tele calling' => 'tele_calling',
      'Accounts' => 'accounts',
      'Super admin' => 'super_admin',
      'Franchise' => 'franchise',
      'Affiliate' => 'affiliate',
      'Delivery' => 'delivery'
    }

    # Try to find the role by mapped name first
    database_name = role_mapping[display_name]
    if database_name
      Role.find_by(name: database_name)
    else
      # Fallback: try to find by exact display name or convert to underscore format
      Role.find_by(name: display_name) ||
      Role.find_by(name: display_name.downcase.gsub(' ', '_'))
    end
  end

  def user_params
    permitted_params = params.require(:user).permit(:first_name, :last_name, :email, :mobile, :password, :password_confirmation, :original_password, :role_name, sidebar_permissions: [], crud_permissions: {})

    # Handle CRUD permissions - store as JSON in sidebar_permissions field
    if params[:user][:crud_permissions].present?
      # Process CRUD permissions into a structured format
      crud_data = {}
      params[:user][:crud_permissions].each do |module_key, permissions|
        if permissions['all_access'] == '1'
          # For modules with "All Access" checked, grant all permissions
          crud_data[module_key] = {
            'view' => true,
            'create' => true,
            'edit' => true,
            'delete' => true
          }
        else
          # For modules with individual CRUD permissions (handle both "1" and "on" values)
          crud_data[module_key] = {
            'view' => ['1', 'on'].include?(permissions['view']),
            'create' => ['1', 'on'].include?(permissions['create']),
            'edit' => ['1', 'on'].include?(permissions['edit']),
            'delete' => ['1', 'on'].include?(permissions['delete'])
          }
        end
      end

      # Store CRUD permissions as JSON in sidebar_permissions field
      permitted_params[:sidebar_permissions] = crud_data.to_json
      # Clear the crud_permissions field to avoid confusion
      permitted_params[:crud_permissions] = nil
    elsif permitted_params[:sidebar_permissions].present?
      # Convert array to CRUD permissions format for proper sidebar access
      permissions_array = permitted_params[:sidebar_permissions].compact_blank
      crud_data = {}

      permissions_array.each do |permission_key|
        crud_data[permission_key] = {
          'view' => true,
          'create' => true,
          'edit' => true,
          'delete' => true
        }
      end

      permitted_params[:sidebar_permissions] = crud_data.to_json
    end

    permitted_params
  end

  def get_sidebar_options
    {
      'Main Menu' => [
        { key: 'dashboard', name: 'Dashboard' }
      ],
      'Sales' => [
        { key: 'bookings', name: 'Bookings' },
        { key: 'stores', name: 'Stores' }
      ],
      'HR' => [
        { key: 'staff_payout', name: 'Staff Payout' }
      ],
      'Subscription' => [
        { key: 'customer_formats', name: 'Customer Format' },
        { key: 'subscriptions', name: 'Subscriptions' },
        { key: 'invoices', name: 'Invoices' },
        { key: 'notes', name: 'Notes' },
        { key: 'pending_amounts', name: 'Last Month Pending' },
        { key: 'invoice_check', name: 'Invoice Check' }
      ],
      'Inventory' => [
        { key: 'vendors', name: 'Vendors' },
        { key: 'vendor_purchases', name: 'Vendor Purchase' }
      ],
      'Master Data' => [
        { key: 'customers', name: 'Customers' },
        { key: 'categories', name: 'Categories' },
        { key: 'products', name: 'Products' },
        { key: 'coupons', name: 'Coupons' },
        { key: 'customer_wallets', name: 'Customer Wallets' },
        { key: 'franchises', name: 'Franchise' },
        { key: 'affiliates', name: 'Affiliate' }
      ],
      'Delivery Management' => [
        { key: 'delivery_people', name: 'Delivery People' }
      ],
      'Import & Export' => [
        { key: 'imports', name: 'Import Data' }
      ],
      'Reports' => [
        { key: 'reports', name: 'Enhanced Sales Report' }
      ],
      'Settings & Configuration' => [
        { key: 'system_settings', name: 'System Settings' },
        { key: 'user_roles', name: 'User Roles' },
        { key: 'banners', name: 'Banners' },
        { key: 'client_requests', name: 'Client Requests' }
      ]
    }
  end
end
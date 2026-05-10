class Admin::StoresController < Admin::ApplicationController
  before_action :authenticate_user!
  before_action :set_store, only: [:show, :edit, :update, :destroy, :toggle_status, :assign_admin, :update_admin, :view_as_store_admin]
  before_action :check_collect_from_store_enabled, only: [:index, :new, :create]

  def index
    @stores = Store.all.order(:name)
    @can_add_more = Store.can_add_more_stores?
    @remaining_slots = Store.remaining_store_slots
    @collect_from_store_enabled = SystemSetting.collect_from_store_enabled?

    respond_to do |format|
      format.html
      format.json { render json: @stores }
    end
  end

  def show
    @bookings_count = @store.bookings.count
  end

  def new
    unless Store.can_add_more_stores?
      redirect_to admin_stores_path, alert: "Maximum #{Store::MAX_STORES_LIMIT} stores allowed. Cannot add more stores."
      return
    end

    @store = Store.new
    @store.status = true # Default to active
  end

  def create
    unless Store.can_add_more_stores?
      redirect_to admin_stores_path, alert: "Maximum #{Store::MAX_STORES_LIMIT} stores allowed. Cannot add more stores."
      return
    end

    @store = Store.new(store_params)

    if params[:store][:create_admin_user] == '1'
      @store.create_admin_user = true
      @store.admin_first_name = params[:store][:admin_first_name]
      @store.admin_last_name = params[:store][:admin_last_name]
      @store.admin_email = params[:store][:admin_email]
      @store.admin_mobile = params[:store][:admin_mobile]
      @store.admin_password = params[:store][:admin_password]
    end

    if @store.save
      if @store.create_admin_user && @store.has_store_admin?
        redirect_to admin_store_path(@store), notice: "Store created with admin login. Email: #{@store.store_admin_user.email}, Password: #{@store.admin_plain_password}"
      else
        redirect_to admin_stores_path, notice: 'Store was successfully created.'
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def assign_admin
  end

  def update_admin
    first_name = params[:admin_first_name]
    last_name = params[:admin_last_name]
    email = params[:admin_email]
    mobile = params[:admin_mobile]
    password = params[:admin_password]

    if @store.has_store_admin?
      user = @store.store_admin_user
      attrs = { first_name: first_name, last_name: last_name, email: email, mobile: mobile }
      attrs[:password] = attrs[:password_confirmation] = password if password.present?
      if user.update(attrs)
        redirect_to admin_store_path(@store), notice: 'Store admin updated successfully.'
      else
        redirect_to admin_store_path(@store), alert: "Failed: #{user.errors.full_messages.join(', ')}"
      end
    else
      @store.admin_first_name = first_name
      @store.admin_last_name = last_name
      @store.admin_email = email
      @store.admin_mobile = mobile
      @store.admin_password = password
      @store.create_admin_user = true
      if @store.valid? && @store.create_store_admin_user!
        redirect_to admin_store_path(@store), notice: "Store admin created. Email: #{email}, Password: #{password}"
      else
        redirect_to admin_store_path(@store), alert: "Failed to create admin: #{@store.errors.full_messages.join(', ')}"
      end
    end
  end

  def view_as_store_admin
    redirect_to store_admin_root_path
  end

  def edit
  end

  def update
    if @store.update(store_params)
      redirect_to admin_stores_path, notice: 'Store was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @store.can_be_deleted?
      @store.destroy
      redirect_to admin_stores_path, notice: 'Store was successfully deleted.'
    else
      redirect_to admin_stores_path, alert: 'Cannot delete store. It has associated bookings.'
    end
  end

  def toggle_status
    @store.update(status: !@store.status)

    respond_to do |format|
      format.html { redirect_to admin_stores_path, notice: "Store status updated." }
      format.json { render json: { status: 'success', new_status: @store.status } }
    end
  end

  private

  def set_store
    @store = Store.find(params[:id])
  end

  def check_collect_from_store_enabled
    unless SystemSetting.collect_from_store_enabled?
      redirect_to admin_settings_system_path, alert: 'Enable "Collect From Store" feature first in System Settings.'
    end
  end

  def store_params
    params.require(:store).permit(:name, :description, :address, :city, :state,
                                   :pincode, :contact_person, :contact_mobile,
                                   :email, :gst_no, :status)
  end
end
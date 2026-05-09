class Admin::StoresController < Admin::ApplicationController
  before_action :authenticate_user!
  before_action :set_store, only: [:show, :edit, :update, :destroy, :toggle_status]
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

    if @store.save
      redirect_to admin_stores_path, notice: 'Store was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
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
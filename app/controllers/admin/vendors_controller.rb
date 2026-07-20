class Admin::VendorsController < Admin::ApplicationController
  before_action :authenticate_user!
  before_action :set_vendor, only: [:show, :edit, :update, :destroy, :toggle_status]
  layout 'application'

  def index
    @vendors = Vendor.includes(:vendor_purchases, :stock_batches)
                    .order(created_at: :desc)
    @vendors = @vendors.where('name ILIKE ?', "%#{params[:search]}%") if params[:search].present?
    @vendors = @vendors.where(status: params[:status]) if params[:status].present?
    @vendors = @vendors.page(params[:page]).per(20)

    respond_to do |format|
      format.html
      format.json { render json: @vendors }
    end
  end

  def show
    @purchases = @vendor.vendor_purchases.includes(:vendor_purchase_items).recent.limit(10)
    @stock_summary = InventoryService.new.vendor_stock_summary(@vendor.id)
  end

  def new
    @vendor = Vendor.new
  end

  def edit
  end

  def create
    @vendor = Vendor.new(vendor_params)

    if @vendor.save
      respond_to do |format|
        format.html { redirect_to admin_vendor_path(@vendor), notice: 'Vendor was successfully created.' }
        format.json { render json: { success: true, vendor: { id: @vendor.id, name: @vendor.name } } }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { success: false, errors: @vendor.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def update
    if @vendor.update(vendor_params)
      redirect_to admin_vendor_path(@vendor),
                  notice: 'Vendor was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @vendor.can_be_deleted?
      @vendor.destroy
      redirect_to admin_vendors_path, notice: 'Vendor was successfully deleted.'
    else
      redirect_to admin_vendor_path(@vendor),
                  alert: 'Cannot delete vendor with existing purchases.'
    end
  end

  def toggle_status
    @vendor.update(status: !@vendor.status)
    status_text = @vendor.status? ? 'activated' : 'deactivated'

    respond_to do |format|
      format.html {
        redirect_to admin_vendors_path,
        notice: "Vendor was successfully #{status_text}."
      }
      format.json {
        render json: {
          status: 'success',
          message: "Vendor #{status_text} successfully",
          new_status: @vendor.status
        }
      }
    end
  end

  private

  def set_vendor
    @vendor = Vendor.find(params[:id])
  end

  def vendor_params
    params.require(:vendor).permit(:name, :phone, :email, :address,
                                   :payment_type, :opening_balance, :status)
  end
end

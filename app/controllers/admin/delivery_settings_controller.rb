class Admin::DeliverySettingsController < ApplicationController
  before_action :authenticate_admin
  before_action :set_delivery_charge, only: [:edit, :update]

  def index
    @bangalore_pincodes = DeliveryCharge.bangalore_pincodes.order(:pincode)
  end

  def new
    @delivery_charge = DeliveryCharge.new
  end

  def create
    @delivery_charge = DeliveryCharge.new(delivery_charge_params)

    respond_to do |format|
      if @delivery_charge.save
        format.html { redirect_to admin_delivery_settings_path, notice: 'Delivery charge created successfully.' }
        format.json { render json: { success: true, message: 'Delivery charge created successfully' } }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { success: false, message: 'Failed to create delivery charge', errors: @delivery_charge.errors.full_messages } }
      end
    end
  end

  def update
    if @delivery_charge.update(delivery_charge_params)
      respond_to do |format|
        format.html { redirect_to admin_delivery_settings_path, notice: 'Delivery charge updated successfully.' }
        format.json { render json: { success: true, message: 'Delivery charge updated successfully' } }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: { success: false, message: 'Failed to update delivery charge', errors: @delivery_charge.errors.full_messages } }
      end
    end
  end

  def edit
    # @delivery_charge set by before_action
  end

  def edit_pincode_charges
    @bangalore_pincodes = DeliveryCharge.bangalore_pincodes.order(:pincode)
    render :index
  end

  def update_pincode_charges
    success_count = 0
    error_messages = []

    params[:delivery_charges]&.each do |pincode, charge_params|
      delivery_charge = DeliveryCharge.find_or_initialize_by(pincode: pincode)
      delivery_charge.assign_attributes(charge_params.permit(:charge_amount, :is_active))

      if delivery_charge.save
        success_count += 1
      else
        error_messages << "Failed to update #{pincode}: #{delivery_charge.errors.full_messages.join(', ')}"
      end
    end

    if error_messages.empty?
      render json: {
        success: true,
        message: "Successfully updated #{success_count} delivery charges"
      }
    else
      render json: {
        success: false,
        message: "Updated #{success_count} charges with #{error_messages.count} errors",
        errors: error_messages
      }
    end
  end

  private

  def authenticate_admin
    unless current_user&.admin? || current_user&.super_admin?
      redirect_to root_path, alert: 'Access denied'
    end
  end

  def set_delivery_charge
    @delivery_charge = DeliveryCharge.find(params[:id])
  end

  def delivery_charge_params
    params.require(:delivery_charge).permit(:pincode, :area, :charge_amount, :is_active)
  end
end
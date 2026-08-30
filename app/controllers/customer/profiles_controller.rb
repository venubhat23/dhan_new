class Customer::ProfilesController < Customer::BaseController
  before_action :set_customer, only: [:show, :edit, :update]

  def show
    # Profile view with customer information
  end

  def edit
    # Edit profile form
  end

  def update
    if @customer.update(customer_params)
      redirect_to customer_profile_path, notice: 'Profile updated successfully!'
    else
      render :edit
    end
  end

  private

  def set_customer
    @customer = current_customer
  end

  def customer_params
    params.require(:customer).permit(
      :full_name, :email, :mobile, :whatsapp_number,
      :birth_date, :gender, :marital_status, :pan_no, :aadhar_no, :gst_no,
      :company_name, :address, :city, :state, :pincode, :country,
      :emergency_contact_name, :emergency_contact_mobile, :business_job,
      :annual_income, :height, :weight
    )
  end
end
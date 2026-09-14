class Admin::InsuranceCompaniesController < Admin::ApplicationController
  before_action :set_insurance_company, only: [:show, :edit, :update, :destroy]

  def index
    @insurance_companies = InsuranceCompany.all.order(:name)
    @total_companies_count = @insurance_companies.count
    @active_companies_count = @insurance_companies.where(status: true).count
    @insurance_companies = @insurance_companies.page(params[:page])
  rescue NameError
    # Handle case where InsuranceCompany model doesn't exist yet
    redirect_to admin_customers_path, alert: 'Insurance Companies functionality not yet implemented.'
  end

  def show
  end

  def new
    @insurance_company = InsuranceCompany.new
  rescue NameError
    redirect_to admin_customers_path, alert: 'Insurance Companies functionality not yet implemented.'
  end

  def edit
  end

  def create
    @insurance_company = InsuranceCompany.new(insurance_company_params)

    if @insurance_company.save
      redirect_to admin_insurance_company_path(@insurance_company), notice: 'Insurance company was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  rescue NameError
    redirect_to admin_customers_path, alert: 'Insurance Companies functionality not yet implemented.'
  end

  def update
    if @insurance_company.update(insurance_company_params)
      redirect_to admin_insurance_company_path(@insurance_company), notice: 'Insurance company was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @insurance_company.destroy
    redirect_to admin_insurance_companies_path, notice: 'Insurance company was successfully deleted.'
  end

  private

  def set_insurance_company
    @insurance_company = InsuranceCompany.find(params[:id])
  rescue NameError
    redirect_to admin_customers_path, alert: 'Insurance Companies functionality not yet implemented.'
  end

  def insurance_company_params
    params.require(:insurance_company).permit(:name, :code, :contact_person, :email, :mobile, :address, :status)
  end
end
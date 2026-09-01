class StoreAdmin::CustomersController < StoreAdmin::ApplicationController
  before_action :set_customer, only: [:show, :edit, :update, :destroy]

  # Customers who have at least one booking at the current store.
  def index
    scope = store_customers

    if params[:search].present?
      term = "%#{params[:search].strip}%"
      scope = scope.where('customers.full_name ILIKE ? OR customers.mobile ILIKE ? OR customers.email ILIKE ?',
                          term, term, term)
    end

    @customers = scope.order(:full_name)
    @customers = @customers.page(params[:page]).per(20) if @customers.respond_to?(:page)

    @total_customers = store_customers.count
  end

  def show
    @store_bookings = @current_store.bookings.where(customer_id: @customer.id)
                                    .order(created_at: :desc)
                                    .includes(booking_items: :product)
    @store_spend = @store_bookings.where.not(status: ['cancelled', 'returned']).sum(:total_amount)
  end

  def new
    @customer = Customer.new
  end

  def create
    @customer = Customer.new(customer_params)

    if @customer.save
      redirect_to store_admin_customer_path(@customer), notice: 'Customer created successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @customer.update(customer_params)
      redirect_to store_admin_customer_path(@customer), notice: 'Customer updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @customer.destroy
      redirect_to store_admin_customers_path, notice: 'Customer deleted successfully.'
    else
      redirect_to store_admin_customer_path(@customer),
                  alert: @customer.errors.full_messages.to_sentence.presence || 'Unable to delete customer.'
    end
  end

  private

  def store_customers
    Customer.where(id: @current_store.bookings.select(:customer_id))
  end

  # Only let the store admin open customers that belong to this store
  # (have a booking here) or ones they just created that have no bookings yet.
  def set_customer
    @customer = Customer.find(params[:id])
    return if @current_store.bookings.exists?(customer_id: @customer.id)
    return if @customer.bookings.none?

    redirect_to store_admin_customers_path, alert: 'Customer not found for this store.'
  end

  def customer_params
    params.require(:customer).permit(
      :full_name, :email, :mobile, :whatsapp_number,
      :gender, :birth_date, :company_name, :gst_no, :occupation,
      :address, :landmark, :shipping_address, :location_link, :notes, :status
    )
  end
end

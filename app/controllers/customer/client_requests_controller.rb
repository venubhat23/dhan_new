class Customer::ClientRequestsController < Customer::BaseController

  def index
    @client_requests = current_customer.client_requests.order(created_at: :desc)
  end

  def show
    @client_request = current_customer.client_requests.find(params[:id])
  end

  def new
    if current_customer.present?
      @client_request = current_customer.client_requests.build
    else
      @client_request = ClientRequest.new
    end
  end

  def create
    if current_customer.present?
      @client_request = current_customer.client_requests.build(client_request_params)
      # Set customer information fields from current customer
      @client_request.name = current_customer.display_name
      @client_request.email = current_customer.email
      @client_request.phone_number = current_customer.mobile
    else
      @client_request = ClientRequest.new(client_request_params)
      # For guest users, get the contact info from the form
      @client_request.name = client_request_params[:name]
      @client_request.email = client_request_params[:email]
      @client_request.phone_number = client_request_params[:phone_number]
    end

    @client_request.status = 'pending'
    @client_request.priority = client_request_params[:priority] || 'medium'
    @client_request.stage = 'new'

    if @client_request.save
      if current_customer.present?
        redirect_to customer_client_request_path(@client_request), notice: 'Your request has been submitted successfully. We will get back to you soon.'
      else
        redirect_to customer_support_path, notice: "Your support request (#{@client_request.ticket_number}) has been submitted successfully. We will get back to you via email soon."
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def client_request_params
    params.require(:client_request).permit(:title, :description, :priority, :department, :name, :email, :phone_number)
  end
end
class StoreAdmin::StockTransfersController < StoreAdmin::ApplicationController
  def index
    @transfers = StockTransfer.for_store(@current_store.id)
                              .includes(:product, :from_store, :to_store, :requested_by)
                              .order(created_at: :desc)
  end

  def new
    @products = Product.active.by_stock_availability
    @stores = Store.where.not(id: @current_store.id).active.order(:name)
  end

  def create
    product = Product.find(params[:product_id])
    quantity = params[:quantity].to_f
    from_store_id = params[:from_store_id].presence
    notes = params[:notes].to_s.strip

    if quantity <= 0
      flash[:alert] = 'Quantity must be greater than 0.'
      redirect_to new_store_admin_stock_transfer_path and return
    end

    transfer = StockTransfer.new(
      product: product,
      from_store_id: from_store_id,
      to_store: @current_store,
      requested_by: current_user,
      quantity: quantity,
      notes: notes,
      status: 'pending'
    )

    if transfer.save
      flash[:notice] = "Transfer request submitted. Awaiting admin approval."
      redirect_to store_admin_stock_transfers_path
    else
      flash[:alert] = transfer.errors.full_messages.join(', ')
      redirect_to new_store_admin_stock_transfer_path
    end
  end
end

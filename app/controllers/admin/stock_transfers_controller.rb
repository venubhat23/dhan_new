class Admin::StockTransfersController < Admin::ApplicationController
  before_action :set_transfer, only: [:show, :approve, :reject]

  def index
    @transfers = StockTransfer.includes(:product, :from_store, :to_store, :requested_by, :approved_by)
                              .order(created_at: :desc)

    @transfers = @transfers.where(status: params[:status]) if params[:status].present?
    @pending_count = StockTransfer.pending.count
  end

  def show
  end

  def approve
    source_available = StockBatch.available_for_product(@transfer.product_id, store_id: @transfer.from_store_id)
                                 .sum(:quantity_remaining)
    if source_available < @transfer.quantity
      flash[:alert] = "Insufficient stock in #{@transfer.from_store_name}. Available: #{source_available}, Requested: #{@transfer.quantity}"
      redirect_to admin_stock_transfer_path(@transfer) and return
    end

    @transfer.approve!(current_user)
    flash[:notice] = "Transfer approved. #{@transfer.quantity} units of #{@transfer.product.name} moved to #{@transfer.to_store.name}."
    redirect_to admin_stock_transfers_path
  rescue => e
    flash[:alert] = "Approval failed: #{e.message}"
    redirect_to admin_stock_transfer_path(@transfer)
  end

  def reject
    reason = params[:rejection_reason].to_s.strip
    @transfer.reject!(current_user, reason)
    flash[:notice] = 'Transfer request rejected.'
    redirect_to admin_stock_transfers_path
  end

  private

  def set_transfer
    @transfer = StockTransfer.find(params[:id])
  end
end

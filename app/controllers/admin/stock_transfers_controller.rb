class Admin::StockTransfersController < Admin::ApplicationController
  before_action :set_transfer, only: [:show, :approve, :reject]

  def index
    scope = StockTransfer.includes(:product, :from_store, :to_store, :requested_by, :approved_by)
    scope = scope.where(status: params[:status]) if params[:status].present?
    all_transfers = scope.order(created_at: :desc)

    # Group by transfer_group_id; ungrouped transfers get their own single-item group
    @groups = all_transfers.group_by { |t| t.transfer_group_id.presence || "single_#{t.id}" }
                           .map do |group_id, transfers|
      {
        group_id:     group_id,
        transfers:    transfers,
        status:       group_status(transfers),
        from_store:   transfers.first.from_store_name,
        to_store:     transfers.first.to_store&.name,
        requested_by: transfers.first.requested_by,
        created_at:   transfers.first.created_at,
        notes:        transfers.first.notes
      }
    end
    @pending_count = StockTransfer.pending.count
  end

  def show
  end

  def approve
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

  # Approve all pending transfers in a group
  def approve_group
    group_id = params[:group_id]
    transfers = StockTransfer.pending.where(transfer_group_id: group_id)

    if transfers.empty?
      flash[:alert] = 'No pending transfers found for this request.'
      redirect_to admin_stock_transfers_path and return
    end

    approved = 0
    errors   = []
    transfers.each do |t|
      t.approve!(current_user)
      approved += 1
    rescue => e
      errors << "#{t.product&.name}: #{e.message}"
    end

    if errors.any?
      flash[:alert] = "#{approved} approved, #{errors.size} failed — #{errors.join(' | ')}"
    else
      flash[:notice] = "#{approved} transfer(s) approved successfully."
    end
    redirect_to admin_stock_transfers_path
  end

  # Reject all pending transfers in a group
  def reject_group
    group_id = params[:group_id]
    reason   = params[:rejection_reason].to_s.strip
    transfers = StockTransfer.pending.where(transfer_group_id: group_id)

    if transfers.empty?
      flash[:alert] = 'No pending transfers found for this request.'
      redirect_to admin_stock_transfers_path and return
    end

    transfers.each { |t| t.reject!(current_user, reason) }
    flash[:notice] = "#{transfers.size} transfer(s) rejected."
    redirect_to admin_stock_transfers_path
  end

  # Bulk approve multiple groups at once
  def bulk_approve
    group_ids = Array(params[:group_ids])
    if group_ids.empty?
      flash[:alert] = 'No requests selected.'
      redirect_to admin_stock_transfers_path and return
    end

    approved = 0
    errors   = []
    StockTransfer.pending.where(transfer_group_id: group_ids).each do |t|
      t.approve!(current_user)
      approved += 1
    rescue => e
      errors << "#{t.product&.name}: #{e.message}"
    end

    if errors.any?
      flash[:alert] = "#{approved} approved, #{errors.size} failed — #{errors.join(' | ')}"
    else
      flash[:notice] = "#{approved} transfer(s) approved across #{group_ids.size} request(s)."
    end
    redirect_to admin_stock_transfers_path
  end

  private

  def set_transfer
    @transfer = StockTransfer.find(params[:id])
  end

  def group_status(transfers)
    statuses = transfers.map(&:status).uniq
    return 'pending'   if statuses.include?('pending')
    return 'completed' if statuses.all? { |s| s == 'completed' }
    return 'rejected'  if statuses.all? { |s| s == 'rejected' }
    'partial'
  end
end

class Admin::StockTransfersController < Admin::ApplicationController
  before_action :set_transfer, only: [:show, :approve, :reject]

  # A single "request" (transfer_group_id) can contain hundreds of product
  # line-items — rendering them all inline is what actually breaks the page.
  # Cap what's shown per group on the index; "View full request" links to
  # show_group for the rest.
  GROUP_ITEM_INLINE_LIMIT = 20

  def index
    base_scope = StockTransfer.all
    base_scope = base_scope.where(status: params[:status]) if params[:status].present?

    # Paginate by request-group, not raw row, so a multi-product request never
    # gets split across pages. Determine group order with a light column-only
    # query first (no associations, no full row hydration).
    group_keys_ordered = []
    seen = {}
    base_scope.select(:id, :transfer_group_id, :created_at).order(created_at: :desc).each do |r|
      key = r.transfer_group_id.presence || "single_#{r.id}"
      unless seen[key]
        seen[key] = true
        group_keys_ordered << key
      end
    end

    per_page = SystemSetting.default_pagination_per_page || 20
    paged_keys = Kaminari.paginate_array(group_keys_ordered).page(params[:page]).per(per_page)

    assoc_scope = StockTransfer.includes(:product, :product_variant, :from_store, :to_store, :requested_by, :approved_by)
    assoc_scope = assoc_scope.where(status: params[:status]) if params[:status].present?

    stock_cache = {}

    @groups = paged_keys.filter_map do |key|
      if key.start_with?('single_')
        transfers   = assoc_scope.where(id: key.delete_prefix('single_').to_i).to_a
        total_count = transfers.size
      else
        total_count = StockTransfer.where(transfer_group_id: key).count
        transfers   = assoc_scope.where(transfer_group_id: key)
                                  .order(created_at: :desc)
                                  .limit(GROUP_ITEM_INLINE_LIMIT)
                                  .to_a
      end
      next if transfers.empty?

      # Pre-compute available stock per (product_id, from_store_id) to avoid N+1 — only for what's shown
      transfers.each do |t|
        ck = [t.product_id, t.from_store_id]
        stock_cache[ck] ||= StockBatch.available_for_product(t.product_id, store_id: t.from_store_id)
                                       .sum(:quantity_remaining)
      end

      {
        group_id:     key,
        transfers:    transfers,
        total_count:  total_count,
        truncated:    total_count > transfers.size,
        status:       group_status(transfers),
        from_store:   transfers.first.from_store_name,
        to_store:     transfers.first.to_store&.name,
        requested_by: transfers.first.requested_by,
        created_at:   transfers.first.created_at,
        notes:        transfers.first.notes,
        stock_cache:  stock_cache
      }
    end

    @page_data = paged_keys
    @pending_count = StockTransfer.pending.count
  end

  # Full, paginated item list for a single request (transfer_group_id) —
  # linked from the index when a group has more items than fit inline.
  def show_group
    @group_id = params[:group_id]
    per_page = SystemSetting.default_pagination_per_page || 20

    scope = StockTransfer.includes(:product, :product_variant, :from_store, :to_store, :requested_by, :approved_by)
                          .where(transfer_group_id: @group_id)
                          .order(created_at: :desc)
    @transfers = scope.page(params[:page]).per(per_page)

    if @transfers.empty?
      redirect_to admin_stock_transfers_path, alert: 'Transfer request not found.' and return
    end

    stock_cache = {}
    @transfers.each do |t|
      key = [t.product_id, t.from_store_id]
      stock_cache[key] ||= StockBatch.available_for_product(t.product_id, store_id: t.from_store_id)
                                     .sum(:quantity_remaining)
    end
    @stock_cache  = stock_cache
    first         = @transfers.first
    @status       = group_status(StockTransfer.where(transfer_group_id: @group_id).select(:status))
    @from_store   = first.from_store_name
    @to_store     = first.to_store&.name
    @requested_by = first.requested_by
    @created_at   = first.created_at
    @notes        = first.notes
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

  # Approve all pending transfers in a group. Queued as a background job so a
  # request with many line-items can't hang the web request past the
  # platform timeout. The index page polls bulk_progress with the returned
  # token to show a live percentage while it runs.
  def approve_group
    enqueue_bulk_action([params[:group_id]], 'approve')
  end

  # Reject all pending transfers in a group
  def reject_group
    enqueue_bulk_action([params[:group_id]], 'reject', params[:rejection_reason].to_s.strip)
  end

  # Bulk approve multiple groups at once
  def bulk_approve
    enqueue_bulk_action(Array(params[:group_ids]), 'approve')
  end

  # Bulk reject multiple groups at once
  def bulk_reject
    enqueue_bulk_action(Array(params[:group_ids]), 'reject', params[:rejection_reason].to_s.strip)
  end

  # Polled by the index page's progress bar while a bulk approve/reject job runs.
  def bulk_progress
    progress = Rails.cache.read("stock_transfer_bulk_progress:#{params[:token]}")
    if progress.nil?
      render json: { done: true, missing: true, total: 0, processed: 0, failed: 0, percent: 100 }
      return
    end

    percent = progress[:total].zero? ? 100 : ((progress[:processed].to_f / progress[:total]) * 100).round
    render json: progress.merge(percent: percent)
  end

  private

  def enqueue_bulk_action(group_ids, action, reason = nil)
    group_ids = Array(group_ids).reject(&:blank?)
    return respond_bulk_error('No requests selected.') if group_ids.empty?

    count = StockTransfer.pending.where(transfer_group_id: group_ids).count
    return respond_bulk_error('No pending transfers found for this request.') if count.zero?

    token = SecureRandom.hex(10)
    StockTransferBulkActionJob.perform_later(group_ids, action, current_user.id, reason, token)

    respond_to do |format|
      format.json { render json: { token: token, total: count } }
      format.html do
        verb = action == 'approve' ? 'Approving' : 'Rejecting'
        scope_msg = group_ids.size > 1 ? " across #{group_ids.size} request(s)" : ''
        flash[:notice] = "#{verb} #{count} transfer(s)#{scope_msg} in the background — refresh in a few moments to see the result."
        redirect_to admin_stock_transfers_path
      end
    end
  end

  def respond_bulk_error(message)
    respond_to do |format|
      format.json { render json: { error: message }, status: :unprocessable_entity }
      format.html do
        flash[:alert] = message
        redirect_to admin_stock_transfers_path
      end
    end
  end

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

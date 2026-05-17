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
    transfers_params = params[:transfers].to_unsafe_h rescue {}
    from_store_id    = params[:from_store_id].presence
    notes            = params[:notes].to_s.strip

    if transfers_params.blank?
      flash[:alert] = 'Please select at least one product.'
      redirect_to new_store_admin_stock_transfer_path and return
    end

    errors        = []
    created       = 0
    transfer_group_id = SecureRandom.uuid

    transfers_params.each_value do |item|
      product_id = item[:product_id].to_i
      quantity   = item[:quantity].to_f

      next if product_id.zero? || quantity <= 0

      product = Product.find_by(id: product_id)
      next unless product

      variant_id = item[:variant_id].to_i
      variant    = variant_id > 0 ? ProductVariant.find_by(id: variant_id, product_id: product_id) : nil

      transfer = StockTransfer.new(
        product:            product,
        product_variant:    variant,
        from_store_id:      from_store_id,
        to_store:           @current_store,
        requested_by:       current_user,
        quantity:           quantity,
        notes:              notes,
        status:             'pending',
        transfer_group_id:  transfer_group_id
      )

      if transfer.save
        created += 1
      else
        errors << "#{product.name}: #{transfer.errors.full_messages.join(', ')}"
      end
    end

    if errors.any?
      flash[:alert] = "Some requests failed — #{errors.join(' | ')}"
    end

    if created > 0
      flash[:notice] = "#{created} transfer request(s) submitted. Awaiting admin approval."
      redirect_to store_admin_stock_transfers_path
    else
      redirect_to new_store_admin_stock_transfer_path
    end
  end
end

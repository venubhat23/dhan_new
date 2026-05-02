class Admin::OrdersController < Admin::ApplicationController
  before_action :authenticate_user!
  before_action :set_order, only: [:show, :update_status, :ship, :deliver, :cancel, :invoice, :tracking]

  def index
    @orders = Order.includes(:customer, :user, :booking, :order_items)
                   .recent
                   .page(params[:page])
                   .per(20)

    if params[:search].present?
      @orders = @orders.where(
        "order_number LIKE ? OR customer_name LIKE ? OR customer_email LIKE ? OR tracking_number LIKE ?",
        "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%"
      )
    end

    if params[:status].present?
      @orders = @orders.where(status: params[:status])
    end

    if params[:date_from].present? && params[:date_to].present?
      @orders = @orders.where(created_at: params[:date_from]..params[:date_to])
    end

    @status_counts = {
      all: Order.count,
      draft: Order.draft.count,
      ordered_and_delivery_pending: Order.ordered_and_delivery_pending.count,
      confirmed: Order.confirmed.count,
      processing: Order.processing.count,
      packed: Order.packed.count,
      shipped: Order.shipped.count,
      out_for_delivery: Order.out_for_delivery.count,
      delivered: Order.delivered.count,
      completed: Order.completed.count,
      cancelled: Order.cancelled.count,
      returned: Order.returned.count
    }
  end

  def show
    @order_items = @order.order_items.includes(product: [:category, image_attachment: :blob, additional_images_attachments: :blob])
  end

  def update_status
    # Prepare update attributes based on status and additional parameters
    update_attributes = { status: params[:status] }

    case params[:status]
    when 'processing'
      # Store processing information
      update_attributes[:processing_notes] = params[:processing_notes] if params[:processing_notes].present?
      update_attributes[:estimated_processing_time] = params[:estimated_processing_time] if params[:estimated_processing_time].present?
      update_attributes[:processing_started_at] = Time.current

    when 'packed'
      # Store packing information
      update_attributes[:packed_by] = params[:packed_by] if params[:packed_by].present?
      update_attributes[:package_weight] = params[:package_weight] if params[:package_weight].present?
      update_attributes[:package_dimensions] = params[:package_dimensions] if params[:package_dimensions].present?
      update_attributes[:packing_notes] = params[:packing_notes] if params[:packing_notes].present?
      update_attributes[:packed_at] = Time.current

    when 'shipped'
      # Generate tracking number if not provided
      tracking_number = params[:tracking_number].presence || generate_tracking_number
      update_attributes[:tracking_number] = tracking_number
      update_attributes[:shipping_carrier] = params[:shipping_carrier] if params[:shipping_carrier].present?
      update_attributes[:estimated_delivery_date] = params[:estimated_delivery] if params[:estimated_delivery].present?
      update_attributes[:shipping_cost] = params[:shipping_cost] if params[:shipping_cost].present?
      update_attributes[:shipping_notes] = params[:shipping_notes] if params[:shipping_notes].present?
      update_attributes[:shipped_at] = Time.current

    when 'delivered'
      update_attributes[:delivered_at] = params[:delivery_date].present? ? Time.parse(params[:delivery_date]) : Time.current
      update_attributes[:delivered_to] = params[:delivered_to] if params[:delivered_to].present?
      update_attributes[:delivery_location] = params[:delivery_location] if params[:delivery_location].present?
      update_attributes[:delivery_notes] = params[:delivery_notes] if params[:delivery_notes].present?
      # Handle delivery proof file upload if needed

    when 'cancelled'
      update_attributes[:cancelled_at] = Time.current
      update_attributes[:cancellation_reason] = params[:cancellation_reason] if params[:cancellation_reason].present?
      update_attributes[:refund_method] = params[:refund_method] if params[:refund_method].present?
      update_attributes[:refund_amount] = params[:refund_amount] if params[:refund_amount].present?
      update_attributes[:cancellation_notes] = params[:cancellation_notes] if params[:cancellation_notes].present?
    end

    if @order.update(update_attributes)
      respond_to do |format|
        format.html { redirect_to admin_orders_path, notice: "Order #{@order.order_number} has been moved to #{params[:status].humanize} stage." }
        format.json { render json: { success: true, message: "Order status updated to #{params[:status].humanize}" } }
      end
    else
      respond_to do |format|
        format.html { redirect_to admin_orders_path, alert: 'Failed to update order status.' }
        format.json { render json: { success: false, message: 'Failed to update order status', errors: @order.errors.full_messages } }
      end
    end
  end

  def ship
    if @order.ordered_and_delivery_pending? || @order.confirmed? || @order.processing? || @order.packed?
      @order.update(
        status: :shipped,
        tracking_number: generate_tracking_number
      )
      redirect_to admin_order_path(@order), notice: 'Order marked as shipped!'
    else
      redirect_to admin_order_path(@order), alert: 'Order cannot be shipped in current status.'
    end
  end

  def deliver
    if @order.shipped? || @order.out_for_delivery?
      @order.mark_as_delivered!
      redirect_to admin_order_path(@order), notice: 'Order marked as delivered!'
    else
      redirect_to admin_order_path(@order), alert: 'Order must be shipped before marking as delivered.'
    end
  end

  def cancel
    if @order.can_cancel?
      @order.cancel!
      redirect_to admin_order_path(@order), notice: 'Order cancelled successfully!'
    else
      redirect_to admin_order_path(@order), alert: 'Order cannot be cancelled in current status.'
    end
  end

  def invoice
    render layout: 'invoice'
  end

  def tracking
    render json: {
      order_number: @order.order_number,
      status: @order.status,
      tracking_number: @order.tracking_number,
      shipped_at: @order.updated_at,
      delivered_at: @order.delivered_at,
      timeline: order_timeline(@order)
    }
  end

  # Status-specific collection methods
  def ordered_and_delivery_pending
    @orders = Order.ordered_and_delivery_pending.includes(:customer).page(params[:page])
    render :index
  end

  def processing
    @orders = Order.processing.includes(:customer).page(params[:page])
    render :index
  end

  def shipped
    @orders = Order.shipped.includes(:customer).page(params[:page])
    render :index
  end

  def delivered
    @orders = Order.delivered.includes(:customer).page(params[:page])
    render :index
  end

  def cancelled
    @orders = Order.cancelled.includes(:customer).page(params[:page])
    render :index
  end

  private

  def set_order
    @order = Order.find(params[:id])
  end

  def generate_tracking_number
    "TRK#{Date.current.strftime('%Y%m%d')}#{SecureRandom.hex(4).upcase}"
  end

  def order_timeline(order)
    timeline = [
      { status: 'Order Placed', timestamp: order.created_at, completed: true }
    ]

    if order.processing? || order.packed? || order.shipped? || order.delivered?
      timeline << { status: 'Processing', timestamp: order.updated_at, completed: true }
    end

    if order.packed? || order.shipped? || order.delivered?
      timeline << { status: 'Packed', timestamp: order.updated_at, completed: true }
    end

    if order.shipped? || order.delivered?
      timeline << { status: 'Shipped', timestamp: order.updated_at, completed: true }
    end

    if order.delivered?
      timeline << { status: 'Delivered', timestamp: order.delivered_at, completed: true }
    end

    timeline
  end

end
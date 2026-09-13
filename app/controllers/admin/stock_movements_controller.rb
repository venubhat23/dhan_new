class Admin::StockMovementsController < Admin::ApplicationController
  before_action :authenticate_user!
  before_action :set_stock_movement, only: [:show]

  def index
    @stock_movements = StockMovement.includes(product: [:image_attachment, :additional_images_attachments])

    # Apply filters
    if params[:product_id].present?
      @stock_movements = @stock_movements.where(product_id: params[:product_id])
      @selected_product = Product.find(params[:product_id])
    end

    if params[:reference_type].present?
      @stock_movements = @stock_movements.where(reference_type: params[:reference_type])
    end

    if params[:movement_type].present?
      @stock_movements = @stock_movements.where(movement_type: params[:movement_type])
    end

    if params[:date_from].present? && params[:date_to].present?
      @stock_movements = @stock_movements.where(created_at: params[:date_from]..params[:date_to])
    end

    if params[:search].present?
      @stock_movements = @stock_movements.joins(:product)
                                        .where("products.name ILIKE ? OR products.sku ILIKE ? OR stock_movements.notes ILIKE ?",
                                               "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%")
    end

    # Order by most recent
    @stock_movements = @stock_movements.recent.page(params[:page]).per(50)

    # For filter options
    @products = Product.joins(:stock_movements).distinct.order(:name)
    @reference_types = StockMovement.distinct.pluck(:reference_type).compact.sort
    @movement_types = StockMovement.distinct.pluck(:movement_type).compact.sort
  end

  def show
    @product = @stock_movement.product
    @related_movements = @product.stock_movements.recent.limit(20)
  end

  # API endpoint for product stock movements
  def product_movements
    @product = Product.find(params[:product_id])
    @movements = @product.stock_movements.includes(:product).recent.limit(50)

    render json: @movements.map do |movement|
      {
        id: movement.id,
        movement_type: movement.movement_type,
        movement_type_badge_class: movement.movement_type_badge_class,
        movement_type_icon: movement.movement_type_icon,
        quantity: movement.formatted_quantity,
        stock_before: movement.stock_before,
        stock_after: movement.stock_after,
        reference_description: movement.reference_description,
        notes: movement.notes,
        created_at: movement.created_at.strftime('%d %b %Y %I:%M %p')
      }
    end
  end

  # Stock summary by products
  def summary
    @products_with_movements = Product.joins(:stock_movements)
                                     .includes(:stock_movements, :category)
                                     .group('products.id')
                                     .order(:name)
                                     .page(params[:page])
                                     .per(20)

    if params[:search].present?
      @products_with_movements = @products_with_movements.where(
        "products.name ILIKE ? OR products.sku ILIKE ?",
        "%#{params[:search]}%", "%#{params[:search]}%"
      )
    end

    if params[:stock_status].present?
      case params[:stock_status]
      when 'out_of_stock'
        @products_with_movements = @products_with_movements.select { |p| p.out_of_stock? }
      when 'low_stock'
        @products_with_movements = @products_with_movements.select { |p| p.low_stock? }
      when 'in_stock'
        @products_with_movements = @products_with_movements.select { |p| !p.out_of_stock? && !p.low_stock? }
      end
    end
  end

  private

  def set_stock_movement
    @stock_movement = StockMovement.find(params[:id])
  end
end

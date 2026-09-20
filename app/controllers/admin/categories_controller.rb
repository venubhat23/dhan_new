class Admin::CategoriesController < Admin::ApplicationController
  before_action :set_category, only: [:show, :edit, :update, :destroy, :toggle_status]
  before_action :authenticate_user!

  def index
    @categories = Category.with_attached_image
                         .order(:display_order, :name)

    if params[:search].present?
      @categories = @categories.where('name ILIKE ?', "%#{params[:search]}%")
    end

    if params[:status].present?
      @categories = @categories.where(status: params[:status] == 'active')
    end

    @categories = @categories.page(params[:page]).per(20)

    # One grouped COUNT instead of loading every product of every category just
    # to call .size on it (and 3 more per-page stat queries in the view).
    category_ids = @categories.map(&:id)
    product_counts = Product.where(category_id: category_ids).group(:category_id).count
    @categories.each { |category| category.preloaded_products_count = product_counts[category.id].to_i }
    @categories_with_products = category_ids.count { |id| product_counts[id].to_i > 0 }
    @categories_without_products = category_ids.size - @categories_with_products
  end

  def show
    @products = @category.products.includes(:category, image_attachment: :blob, additional_images_attachments: :blob).recent.limit(10)
    Product.preload_list_aggregates(@products) # stock status/rating for these rows in 2 queries, not per product
  end

  def new
    @category = Category.new
  end

  def create
    @category = Category.new(category_params)

    if @category.save
      redirect_to admin_category_path(@category), notice: 'Category was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @category.update(category_params)
      redirect_to admin_category_path(@category), notice: 'Category was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    products_count = @category.products.count

    if products_count > 0
      # Delete all products in this category first
      @category.products.destroy_all
      flash_message = "Category '#{@category.name}' and #{products_count} product(s) have been deleted successfully."
    else
      flash_message = "Category '#{@category.name}' was successfully deleted."
    end

    # Safely remove the category and its image
    @category.image.purge_later if @category.image.attached?
    @category.destroy

    redirect_to admin_categories_path, notice: flash_message
  end

  def toggle_status
    @category.update(status: !@category.status)
    respond_to do |format|
      format.json { render json: { status: @category.status, message: "Category #{@category.status? ? 'activated' : 'deactivated'} successfully" } }
      format.html { redirect_to admin_categories_path, notice: "Category #{@category.status? ? 'activated' : 'deactivated'} successfully" }
    end
  end

  private

  def set_category
    @category = Category.find(params[:id])
  end

  def category_params
    params.require(:category).permit(:name, :description, :image, :status, :display_order)
  end
end
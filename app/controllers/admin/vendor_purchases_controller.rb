class Admin::VendorPurchasesController < Admin::ApplicationController
  before_action :authenticate_user!
  before_action :set_vendor_purchase, only: [:show, :edit, :update, :destroy, :complete_purchase, :generate_invoice, :mark_as_paid]
  before_action :set_vendors_and_products, only: [:new, :edit, :create, :update]
  layout 'application'

  def index
    @vendor_purchases = VendorPurchase.includes(:vendor, :vendor_purchase_items, :products)
                                     .recent
    @vendor_purchases = @vendor_purchases.joins(:vendor).where('vendors.name ILIKE ?', "%#{params[:search]}%") if params[:search].present?
    @vendor_purchases = @vendor_purchases.where(vendor_id: params[:vendor_id]) if params[:vendor_id].present?
    @vendor_purchases = @vendor_purchases.where(status: params[:status]) if params[:status].present?
    @vendor_purchases = @vendor_purchases.page(params[:page]).per(20)

    @vendors = Vendor.active.order(:name)
  end

  def show
    @stock_batches = @vendor_purchase.stock_batches.includes(:product)
  end

  def new
    @vendor_purchase = VendorPurchase.new
    @vendor_purchase.vendor_purchase_items.build
  end

  def edit
    @vendor_purchase.vendor_purchase_items.build if @vendor_purchase.vendor_purchase_items.empty?
  end

  def create
    @vendor_purchase = VendorPurchase.new(vendor_purchase_params)
    @vendor_purchase.status = 'pending'

    if @vendor_purchase.save
      redirect_to admin_vendor_purchase_path(@vendor_purchase),
                  notice: 'Purchase was successfully created and stock batches have been generated.'
    else
      Rails.logger.error "VendorPurchase creation failed: #{@vendor_purchase.errors.full_messages.join(', ')}"
      flash.now[:alert] = "Error creating purchase: #{@vendor_purchase.errors.full_messages.join(', ')}"
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @vendor_purchase.can_be_edited?
      if @vendor_purchase.update(vendor_purchase_params)
        redirect_to admin_vendor_purchase_path(@vendor_purchase),
                    notice: 'Purchase was successfully updated.'
      else
        render :edit, status: :unprocessable_entity
      end
    else
      redirect_to admin_vendor_purchase_path(@vendor_purchase),
                  alert: 'Cannot edit completed or cancelled purchases.'
    end
  end

  def destroy
    if @vendor_purchase.can_be_cancelled?
      # Mark associated stock batches as cancelled before deletion
      @vendor_purchase.stock_batches.update_all(status: 'cancelled')
      @vendor_purchase.destroy
      redirect_to admin_vendor_purchases_path, notice: 'Purchase was successfully deleted.'
    else
      redirect_to admin_vendor_purchase_path(@vendor_purchase),
                  alert: 'Cannot delete completed purchases with stock movements.'
    end
  end

  def complete_purchase
    # Check if purchase can be completed
    unless @vendor_purchase.status == 'pending'
      respond_to do |format|
        format.html { redirect_to admin_vendor_purchase_path(@vendor_purchase), alert: 'Purchase cannot be completed.' }
        format.json { render json: { success: false, message: 'Purchase cannot be completed.' } }
      end
      return
    end

    # Complete the purchase - update status to 'completed'
    if @vendor_purchase.update(status: 'completed')
      respond_to do |format|
        format.html { redirect_to admin_vendor_purchase_path(@vendor_purchase), notice: 'Purchase marked as completed successfully.' }
        format.json { render json: { success: true, message: 'Purchase marked as completed successfully.' } }
      end
    else
      respond_to do |format|
        format.html { redirect_to admin_vendor_purchase_path(@vendor_purchase), alert: 'Failed to complete purchase.' }
        format.json { render json: { success: false, message: 'Failed to complete purchase.' } }
      end
    end
  end

  def mark_as_paid
    # Check if purchase can be marked as paid
    if @vendor_purchase.payment_status == 'paid'
      respond_to do |format|
        format.html { redirect_to admin_vendor_purchases_path, alert: 'Purchase is already fully paid.' }
        format.json { render json: { success: false, message: 'Purchase is already fully paid.' } }
      end
      return
    end

    # Mark as paid by setting paid_amount to total_amount
    if @vendor_purchase.update(paid_amount: @vendor_purchase.total_amount)
      respond_to do |format|
        format.html { redirect_to admin_vendor_purchases_path, notice: 'Purchase marked as fully paid successfully.' }
        format.json { render json: { success: true, message: 'Purchase marked as fully paid successfully.' } }
      end
    else
      respond_to do |format|
        format.html { redirect_to admin_vendor_purchases_path, alert: 'Failed to mark purchase as paid.' }
        format.json { render json: { success: false, message: 'Failed to mark purchase as paid.' } }
      end
    end
  end

  def bulk_mark_as_paid
    purchase_ids = params[:purchase_ids]

    if purchase_ids.blank? || !purchase_ids.is_a?(Array)
      render json: { success: false, error: 'No purchase IDs provided' }, status: :bad_request
      return
    end

    # Find purchases that are not already paid
    purchases_to_update = VendorPurchase.where(id: purchase_ids)
                                       .where.not(payment_status: 'paid')

    if purchases_to_update.empty?
      render json: { success: false, error: 'No unpaid purchases found to update' }, status: :bad_request
      return
    end

    updated_count = 0

    VendorPurchase.transaction do
      purchases_to_update.find_each do |purchase|
        if purchase.update(paid_amount: purchase.total_amount)
          updated_count += 1
        end
      end
    end

    render json: {
      success: true,
      updated_count: updated_count,
      message: "Successfully marked #{updated_count} purchase(s) as paid"
    }
  rescue => e
    Rails.logger.error "Bulk mark as paid error: #{e.message}"
    render json: {
      success: false,
      error: "Error marking purchases as paid: #{e.message}"
    }, status: :internal_server_error
  end

  def generate_invoice
    # Check if invoice already exists
    vendor_invoice = @vendor_purchase.vendor_invoice

    if vendor_invoice.nil?
      # Create new invoice
      vendor_invoice = @vendor_purchase.create_vendor_invoice!(
        status: :sent,
        notes: "Invoice generated for vendor purchase ##{@vendor_purchase.purchase_number}"
      )
    end

    # Generate the public URL
    invoice_url = vendor_invoice.public_url

    respond_to do |format|
      format.json {
        render json: {
          success: true,
          message: 'Invoice generated successfully',
          invoice_url: invoice_url,
          invoice_number: vendor_invoice.invoice_number,
          purchase_number: @vendor_purchase.purchase_number,
          vendor_name: vendor_invoice.vendor_name
        }
      }
      format.html {
        redirect_to invoice_url
      }
    end
  rescue => e
    Rails.logger.error "Error generating vendor invoice: #{e.message}"

    respond_to do |format|
      format.json {
        render json: {
          success: false,
          error: e.message
        }
      }
      format.html {
        redirect_to admin_vendor_purchase_path(@vendor_purchase),
                    alert: "Error generating invoice: #{e.message}"
      }
    end
  end

  def batch_inventory
    # Get all stock batches with filters
    stock_batches_query = StockBatch.includes(:product, :vendor, :vendor_purchase)
                                   .order(:batch_date, :created_at)

    stock_batches_query = stock_batches_query.joins(:product).where('products.name ILIKE ?', "%#{params[:search]}%") if params[:search].present?
    stock_batches_query = stock_batches_query.where(vendor_id: params[:vendor_id]) if params[:vendor_id].present?
    # Apply in_stock filter only if explicitly requested
    if params[:in_stock] == 'true'
      stock_batches_query = stock_batches_query.where('quantity_remaining > 0')
    elsif params[:in_stock] == 'false'
      stock_batches_query = stock_batches_query.where('quantity_remaining <= 0')
    end
    # If no in_stock filter, show all batches

    @stock_batches = stock_batches_query.to_a

    # Group batches by product for better organization
    @products_with_batches = @stock_batches.group_by(&:product)

    # Statistics
    @vendors = Vendor.active.order(:name)
    @total_batches = @stock_batches.count
    @total_products = @products_with_batches.keys.count
    @total_stock_value = @stock_batches.sum { |batch| batch.quantity_remaining * batch.purchase_price }
    @total_quantity = @stock_batches.sum(&:quantity_remaining)

    # Product-level statistics (sorted by newest batches first to show latest products at top)
    @product_stats = @products_with_batches.sort_by { |product, batches|
      -batches.max_by(&:created_at)&.created_at&.to_i.to_i
    }.map do |product, batches|
      total_quantity = batches.sum(&:quantity_remaining)
      total_value = batches.sum { |batch| batch.quantity_remaining * batch.purchase_price }
      avg_purchase_price = total_quantity > 0 ? (total_value / total_quantity.to_f) : 0

      {
        product: product,
        batch_count: batches.count,
        total_quantity: total_quantity,
        total_value: total_value,
        avg_purchase_price: avg_purchase_price,
        oldest_batch_date: batches.min_by(&:batch_date)&.batch_date,
        newest_batch_date: batches.max_by(&:batch_date)&.batch_date,
        vendor_count: batches.map(&:vendor).uniq.count,
        batches: batches.sort_by(&:batch_date)
      }
    end
  end

  private

  def set_vendor_purchase
    @vendor_purchase = VendorPurchase.find(params[:id])
  end

  def set_vendors_and_products
    @vendors = Vendor.active.order(:name)
    @products = Product.active.order(:name)
    @categories = Category.active.ordered
  end

  def vendor_purchase_params
    params.require(:vendor_purchase).permit(:vendor_id, :purchase_date, :notes, :status, :paid_amount,
      vendor_purchase_items_attributes: [
        :id, :product_id, :quantity, :purchase_price, :selling_price, :_destroy
      ]
    )
  end
end

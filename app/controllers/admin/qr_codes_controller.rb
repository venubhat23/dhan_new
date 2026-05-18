class Admin::QrCodesController < Admin::ApplicationController
  before_action :authenticate_user!

  def index
    @products = Product.where.not(barcode: nil).includes(:category).order(:name)
    if params[:search].present?
      @products = @products.where("name LIKE ? OR barcode LIKE ?", "%#{params[:search]}%", "%#{params[:search]}%")
    end
  end

  def lookup
    product = Product.find_by(barcode: params[:barcode].to_s.strip)
    unless product
      render json: { found: false, message: "No product found for barcode: #{params[:barcode]}" }
      return
    end

    gst_rate = (product.gst_enabled? && product.gst_percentage.present?) ? product.gst_percentage.to_f : 0.0

    response = {
      found: true,
      id: product.id,
      name: product.name,
      sku: product.sku,
      barcode: product.barcode,
      unit_type: product.unit_type,
      has_multiple_quantities: product.has_multiple_quantities?,
      gst_enabled: product.gst_enabled?,
      gst_rate: gst_rate
    }

    if product.has_multiple_quantities? && product.product_variants.any?
      default_v = product.default_variant || product.product_variants.ordered.first
      response[:variants] = product.product_variants.default_first.map do |v|
        {
          id: v.id,
          label: v.label,
          price: v.effective_price.to_f,
          stock: v.available_stock.to_i,
          is_default: v.is_default
        }
      end
      response[:default_variant_id] = default_v.id
      response[:price] = default_v.effective_price.to_f
    else
      avail = product.total_batch_stock.to_i
      response[:price] = product.price.to_f
      response[:available_stock] = avail
    end

    render json: response
  end
end

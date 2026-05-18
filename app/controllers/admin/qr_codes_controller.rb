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
    if product
      render json: {
        found: true,
        id: product.id,
        name: product.name,
        price: product.price,
        sku: product.sku,
        barcode: product.barcode,
        stock: product.stock,
        unit_type: product.unit_type
      }
    else
      render json: { found: false, message: "No product found for barcode: #{params[:barcode]}" }
    end
  end
end

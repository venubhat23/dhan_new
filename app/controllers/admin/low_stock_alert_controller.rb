class Admin::LowStockAlertController < Admin::ApplicationController
  def index
    @products = Product
      .joins(:category)
      .joins("LEFT JOIN stock_batches ON stock_batches.product_id = products.id
              AND stock_batches.status = 'active'
              AND stock_batches.store_id IS NULL")
      .select("products.*,
               categories.name AS cat_name,
               COALESCE(SUM(stock_batches.quantity_remaining), 0) AS current_stock")
      .group("products.id, categories.id, categories.name")
      .having("COALESCE(SUM(stock_batches.quantity_remaining), 0) <= COALESCE(products.low_stock_threshold, 5)")
      .order(Arel.sql("COALESCE(SUM(stock_batches.quantity_remaining), 0) ASC, products.name ASC"))

    @total_count = @products.size
  end
end

class Admin::LowStockAlertController < Admin::ApplicationController
  def index
    # Same "real" stock definition as the dashboard cards (Product::REAL_STOCK_SQL):
    # variant stock for multi-qty products, active central batch stock otherwise.
    @products = Product
      .with_real_stock_amount
      .real_at_or_below_threshold
      .left_joins(:category)
      .select("categories.name AS cat_name")
      .order(Arel.sql("(#{Product::REAL_STOCK_SQL}) ASC, products.name ASC"))

    @total_count = @products.length
  end
end

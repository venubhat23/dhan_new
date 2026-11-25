class AddPaymentModeToVendorPurchases < ActiveRecord::Migration[8.0]
  def change
    # How the vendor was / will be paid for this purchase: cash / upi / bank.
    add_column :vendor_purchases, :payment_mode, :string
  end
end

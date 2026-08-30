class AddBillingAndShippingLandmarkToCustomers < ActiveRecord::Migration[8.0]
  def change
    add_column :customers, :landmark, :string
    add_column :customers, :shipping_address, :text
  end
end

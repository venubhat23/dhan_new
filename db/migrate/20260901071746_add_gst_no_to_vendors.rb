class AddGstNoToVendors < ActiveRecord::Migration[8.0]
  def change
    add_column :vendors, :gst_no, :string
  end
end

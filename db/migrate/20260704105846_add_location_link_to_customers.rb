class AddLocationLinkToCustomers < ActiveRecord::Migration[8.0]
  def change
    add_column :customers, :location_link, :string
  end
end

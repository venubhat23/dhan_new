class AddStoreAdminSupport < ActiveRecord::Migration[8.0]
  def change
    add_column :stores, :store_admin_user_id, :integer
    add_column :stores, :admin_plain_password, :string
    add_column :stores, :auto_transfer_threshold, :integer, default: 10
    add_column :stores, :is_main_inventory, :boolean, default: false

    add_column :users, :assigned_store_id, :integer
    add_column :users, :store_permissions, :text
    add_column :users, :last_store_access, :datetime

    add_index :stores, :store_admin_user_id
    add_index :users, :assigned_store_id
  end
end

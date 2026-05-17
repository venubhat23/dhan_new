class AddTransferGroupIdToStockTransfers < ActiveRecord::Migration[8.0]
  def change
    add_column :stock_transfers, :transfer_group_id, :string
    add_index :stock_transfers, :transfer_group_id
  end
end

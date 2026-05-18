class AddLowStockSettingsToSystemSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :system_settings, :low_stock_alert_enabled, :boolean, default: false
    add_column :system_settings, :low_stock_alert_threshold, :integer, default: 10
    add_column :system_settings, :low_stock_alert_email, :string
  end
end

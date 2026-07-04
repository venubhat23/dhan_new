class AddLogoAndWebsiteToSystemSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :system_settings, :logo_url, :string
    add_column :system_settings, :website, :string
  end
end

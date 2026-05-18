class AddBarcodeToProducts < ActiveRecord::Migration[7.1]
  def change
    add_column :products, :barcode, :string
    add_index :products, :barcode, unique: true
  end
end

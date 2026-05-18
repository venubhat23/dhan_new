class RemoveIsActiveFromProductVariants < ActiveRecord::Migration[8.0]
  def change
    remove_index :product_variants, :is_active, if_exists: true
    remove_column :product_variants, :is_active
  end
end

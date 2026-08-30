class RemoveIsActiveFromProductVariants < ActiveRecord::Migration[8.0]
  def change
    return unless column_exists?(:product_variants, :is_active)

    remove_index :product_variants, :is_active, if_exists: true
    remove_column :product_variants, :is_active
  end
end

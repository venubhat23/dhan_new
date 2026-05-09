class CreateProductVariants < ActiveRecord::Migration[8.0]
  def change
    create_table :product_variants do |t|
      t.references :product, null: false, foreign_key: true
      t.decimal    :weight,           precision: 8,  scale: 3, null: false
      t.string     :unit,             null: false, default: 'Kg'
      t.decimal    :buying_price,     precision: 10, scale: 2, default: 0
      t.decimal    :selling_price,    precision: 10, scale: 2, null: false
      t.boolean    :discount_enabled, default: false
      t.string     :discount_type
      t.decimal    :discount_value,   precision: 10, scale: 2
      t.decimal    :discount_amount,  precision: 10, scale: 2
      t.integer    :available_stock,  default: 0, null: false
      t.boolean    :is_default,       default: false
      t.integer    :display_order,    default: 0
      t.timestamps
    end

    add_index :product_variants, [:product_id, :weight, :unit], unique: true, name: 'index_product_variants_uniqueness'
    add_index :product_variants, :is_default

    add_column :products, :has_multiple_quantities, :boolean, default: false, null: false

    add_column :booking_items, :product_variant_id, :bigint
    add_index  :booking_items, :product_variant_id

    add_column :order_items, :product_variant_id, :bigint
    add_index  :order_items, :product_variant_id
  end
end

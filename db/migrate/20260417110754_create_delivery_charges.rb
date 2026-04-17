class CreateDeliveryCharges < ActiveRecord::Migration[8.0]
  def change
    create_table :delivery_charges do |t|
      t.string :pincode, null: false
      t.string :area
      t.decimal :charge_amount, precision: 10, scale: 2, default: 0.0
      t.boolean :is_active, default: true

      t.timestamps
    end

    add_index :delivery_charges, :pincode, unique: true
    add_index :delivery_charges, :is_active
  end
end

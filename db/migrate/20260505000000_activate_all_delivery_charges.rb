class ActivateAllDeliveryCharges < ActiveRecord::Migration[8.0]
  def up
    DeliveryCharge.update_all(is_active: true)
  end

  def down; end
end

class AddProductVariantToInvoiceItems < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_reference :invoice_items, :product_variant, foreign_key: true, index: { algorithm: :concurrently }
  end
end

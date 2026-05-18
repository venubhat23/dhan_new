class LowStockMailer < ApplicationMailer
  def alert(product:, store:, quantity_remaining:, threshold:, recipient_email:)
    @product            = product
    @store              = store
    @quantity_remaining = quantity_remaining
    @threshold          = threshold

    mail(
      to:      recipient_email,
      subject: "[Low Stock Alert] #{product.name} is running low at #{store&.name || 'Main Inventory'}"
    )
  end
end

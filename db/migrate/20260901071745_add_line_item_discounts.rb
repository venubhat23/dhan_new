class AddLineItemDiscounts < ActiveRecord::Migration[8.0]
  def change
    # Per-product (line-item) discount on a booking line. Sits alongside the
    # order-level bulk discount stored on bookings.discount_amount.
    add_column :booking_items, :discount_type, :string
    add_column :booking_items, :discount_value, :decimal, precision: 10, scale: 2
    add_column :booking_items, :discount_amount, :decimal, precision: 10, scale: 2, default: 0

    # Mirrored onto invoice lines for display. invoice_items.unit_price stays the
    # NET (discounted) base price so existing totals math is untouched;
    # original_unit_price is the pre-discount base price used to render "was ₹X".
    add_column :invoice_items, :discount_type, :string
    add_column :invoice_items, :discount_value, :decimal, precision: 10, scale: 2
    add_column :invoice_items, :discount_amount, :decimal, precision: 10, scale: 2, default: 0
    add_column :invoice_items, :original_unit_price, :decimal, precision: 10, scale: 2
  end
end

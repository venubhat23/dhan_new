# A credit note records goods a customer returned against a booking. Creating
# one puts the returned quantity back into stock (via BookingItem#restock_return!)
# and stores the amount credited back to the customer. The original booking and
# its invoice are left untouched — the credit note is the record of the return.
class CreditNote < ApplicationRecord
  include DashboardCacheBust

  REFUND_METHODS = [
    ['cash', 'Cash'],
    ['upi', 'UPI'],
    ['bank_transfer', 'Bank Transfer'],
    ['wallet', 'Customer Wallet / Store Credit'],
    ['adjust_next_order', 'Adjust in Next Order']
  ].freeze

  belongs_to :booking
  belongs_to :customer, optional: true
  belongs_to :store, optional: true
  belongs_to :user, optional: true
  has_many :credit_note_items, dependent: :destroy

  validates :credit_note_number, presence: true, uniqueness: true
  validates :credit_date, presence: true
  validates :total_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :refund_method, inclusion: { in: REFUND_METHODS.map(&:first) }, allow_blank: true

  before_validation :generate_credit_note_number, on: :create

  scope :recent, -> { order(credit_date: :desc, created_at: :desc) }

  def refund_method_label
    REFUND_METHODS.to_h[refund_method] || refund_method.to_s.humanize
  end

  def total_quantity
    credit_note_items.sum(&:quantity)
  end

  def customer_display_name
    customer&.respond_to?(:display_name) ? customer.display_name : (booking&.customer_name.presence || customer&.try(:name) || 'Walk-in')
  end

  # Quantity of each booking line already returned through earlier credit
  # notes, keyed by booking_item_id.
  def self.returned_quantities_for(booking)
    CreditNoteItem.joins(:credit_note)
                  .where(credit_notes: { booking_id: booking.id })
                  .group(:booking_item_id)
                  .sum(:quantity)
                  .transform_values(&:to_f)
  end

  # Builds and saves a credit note from the admin's selection, restocking
  # every returned line, all in one transaction.
  #   lines: [{ booking_item_id:, quantity:, amount: }]
  def self.issue!(booking:, lines:, user:, attrs: {})
    raise ArgumentError, 'Select at least one item to return' if lines.blank?

    transaction do
      booking.lock!
      already = returned_quantities_for(booking)
      items_by_id = booking.booking_items.includes(:product, :product_variant).index_by(&:id)

      note = new(
        booking: booking,
        customer_id: booking.customer_id,
        store_id: booking.store_id,
        user: user,
        credit_date: attrs[:credit_date].presence || Date.current,
        refund_method: attrs[:refund_method].presence,
        reason: attrs[:reason].presence,
        notes: attrs[:notes].presence
      )

      lines.each do |line|
        item = items_by_id[line[:booking_item_id].to_i]
        raise ArgumentError, 'Item does not belong to this booking' unless item

        qty = line[:quantity].to_f
        returnable = item.quantity.to_f - already.fetch(item.id, 0.0)
        label = item.product_variant ? "#{item.product.name} (#{item.product_variant.label})" : item.product.name
        raise ArgumentError, "Return quantity for #{label} must be more than 0" if qty <= 0
        raise ArgumentError, "Only #{returnable.to_s.sub(/\.0$/, '')} of #{label} can be returned" if qty > returnable + 0.0001

        unit = item.discounted_unit_price.round(2)
        amount = line[:amount].present? ? line[:amount].to_f.round(2) : (unit * qty).round(2)
        raise ArgumentError, "Credit amount for #{label} can't be negative" if amount.negative?

        note.credit_note_items.build(
          booking_item: item,
          product_id: item.product_id,
          product_variant_id: item.product_variant_id,
          quantity: qty,
          unit_price: unit,
          amount: amount
        )
      end

      note.total_amount = note.credit_note_items.sum(&:amount).round(2)
      note.save!

      note.credit_note_items.each do |cni|
        cni.booking_item.restock_return!(
          cni.quantity,
          note: "Stock returned via Credit Note #{note.credit_note_number} (Booking ##{booking.booking_number}): " \
                "#{cni.booking_item.product.name} (Qty: #{cni.quantity.to_f})"
        )
      end

      note
    end
  end

  private

  def generate_credit_note_number
    return if credit_note_number.present?

    prefix = "CN#{Date.current.strftime('%Y%m%d')}"
    last = CreditNote.where('credit_note_number LIKE ?', "#{prefix}-%").maximum(:credit_note_number)
    seq = last ? last.split('-').last.to_i + 1 : 1
    self.credit_note_number = format('%s-%03d', prefix, seq)
  end
end

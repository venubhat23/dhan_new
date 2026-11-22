# A debit note records goods returned to a vendor against a vendor purchase.
# Creating one takes the returned quantity out of that purchase's stock batch
# (VendorPurchase#return_to_vendor!) and stores the amount the vendor owes back
# / that is deducted from what we owe. The purchase itself is left untouched.
class DebitNote < ApplicationRecord
  include DashboardCacheBust

  SETTLEMENT_METHODS = [
    ['adjust_outstanding', 'Adjust Against Vendor Outstanding'],
    ['cash', 'Cash Refund'],
    ['upi', 'UPI Refund'],
    ['bank_transfer', 'Bank Transfer Refund'],
    ['replacement', 'Replacement Goods']
  ].freeze

  belongs_to :vendor_purchase
  belongs_to :vendor
  belongs_to :user, optional: true
  has_many :debit_note_items, dependent: :destroy

  validates :debit_note_number, presence: true, uniqueness: true
  validates :debit_date, presence: true
  validates :total_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :settlement_method, inclusion: { in: SETTLEMENT_METHODS.map(&:first) }, allow_blank: true

  before_validation :generate_debit_note_number, on: :create

  scope :recent, -> { order(debit_date: :desc, created_at: :desc) }

  def settlement_method_label
    SETTLEMENT_METHODS.to_h[settlement_method] || settlement_method.to_s.humanize
  end

  # Quantity of each purchase line already returned through earlier debit
  # notes, keyed by vendor_purchase_item_id.
  def self.returned_quantities_for(purchase)
    DebitNoteItem.joins(:debit_note)
                 .where(debit_notes: { vendor_purchase_id: purchase.id })
                 .group(:vendor_purchase_item_id)
                 .sum(:quantity)
                 .transform_values(&:to_f)
  end

  # How much of a purchase line can still go back to the vendor: what was
  # bought minus earlier returns, capped by what is still unsold in its batch.
  def self.returnable_for(item, batch, already_returned)
    left_on_purchase = item.quantity.to_f - already_returned.to_f
    in_stock = batch ? batch.quantity_remaining.to_f : 0.0
    [[left_on_purchase, in_stock].min, 0].max
  end

  #   lines: [{ vendor_purchase_item_id:, quantity:, amount: }]
  def self.issue!(purchase:, lines:, user:, attrs: {})
    raise ArgumentError, 'Select at least one item to return' if lines.blank?

    transaction do
      purchase.lock!
      already = returned_quantities_for(purchase)
      items_by_id = purchase.vendor_purchase_items.includes(:product, :product_variant).index_by(&:id)

      note = new(
        vendor_purchase: purchase,
        vendor_id: purchase.vendor_id,
        user: user,
        debit_date: attrs[:debit_date].presence || Date.current,
        settlement_method: attrs[:settlement_method].presence,
        reason: attrs[:reason].presence,
        notes: attrs[:notes].presence
      )

      lines.each do |line|
        item = items_by_id[line[:vendor_purchase_item_id].to_i]
        raise ArgumentError, 'Item does not belong to this purchase' unless item

        qty = line[:quantity].to_f
        batch = purchase.batch_for_item(item)
        returnable = returnable_for(item, batch, already.fetch(item.id, 0.0))
        label = item.display_name
        raise ArgumentError, "Return quantity for #{label} must be more than 0" if qty <= 0
        if qty > returnable + 0.0001
          raise ArgumentError, "Only #{returnable.to_s.sub(/\.0$/, '')} of #{label} can be returned (rest is already sold or returned)"
        end

        unit = item.purchase_price.to_f.round(2)
        amount = line[:amount].present? ? line[:amount].to_f.round(2) : (unit * qty).round(2)
        raise ArgumentError, "Debit amount for #{label} can't be negative" if amount.negative?

        note.debit_note_items.build(
          vendor_purchase_item: item,
          stock_batch: batch,
          product_id: item.product_id,
          product_variant_id: item.product_variant_id,
          quantity: qty,
          unit_price: unit,
          amount: amount
        )
      end

      note.total_amount = note.debit_note_items.sum(&:amount).round(2)
      note.save!

      note.debit_note_items.each do |dni|
        purchase.return_to_vendor!(
          dni.vendor_purchase_item, dni.quantity,
          note: "Returned to vendor via Debit Note #{note.debit_note_number} (#{purchase.purchase_number}): " \
                "#{dni.vendor_purchase_item.display_name} (Qty: #{dni.quantity.to_f})"
        )
      end

      note
    end
  end

  private

  def generate_debit_note_number
    return if debit_note_number.present?

    prefix = "DN#{Date.current.strftime('%Y%m%d')}"
    last = DebitNote.where('debit_note_number LIKE ?', "#{prefix}-%").maximum(:debit_note_number)
    seq = last ? last.split('-').last.to_i + 1 : 1
    self.debit_note_number = format('%s-%03d', prefix, seq)
  end
end

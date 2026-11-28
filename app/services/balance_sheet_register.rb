# Zoho-style bank register for /admin/balance_sheet. Not stored anywhere: built
# on the fly from
#   Sales Receipts             → Deposits
#   Purchase Receipts          → Withdrawals
#   Manual Journals (published, user-entered only; auto journals would double
#   count invoices/purchases)  → Withdrawals
# Starting balance is 0, so a row's running balance is the sum of everything
# up to and including it. The opening balance of a filtered date range is the
# balance just before its first day; closing = opening + deposits - withdrawals.
class BalanceSheetRegister
  INITIAL_BALANCE = 0.0
  TYPES = { 'sales_receipt' => 'Sales Receipt', 'purchase_receipt' => 'Purchase Receipt', 'manual_journal' => 'Manual Journal' }.freeze

  Row = Struct.new(:date, :type, :reference, :description, :party, :payment_mode, :deposit, :withdrawal,
                   :balance, :record, :sort_time,
                   # Source documents the row links to: booking + invoice for
                   # sales, vendor purchase + its purchase invoice for purchases.
                   :booking, :invoice, :vendor_purchase, :vendor_invoice, keyword_init: true) do
    def type_label = TYPES[type]
  end

  attr_reader :from, :to, :type, :payment_mode

  def initialize(from: nil, to: nil, type: nil, payment_mode: nil)
    @from = from.presence && Date.parse(from.to_s) rescue nil
    @to   = to.presence && Date.parse(to.to_s) rescue nil
    @type = TYPES.key?(type.to_s) ? type.to_s : nil
    @payment_mode = %w[cash upi bank].include?(payment_mode.to_s) ? payment_mode.to_s : nil
  end

  # Rows inside the filter, oldest first, each with its running balance.
  def rows
    @rows ||= begin
      balance = opening_balance
      in_range(all_rows).map { |r| balance = (balance + r.deposit - r.withdrawal).round(2); r.balance = balance; r }
    end
  end

  def opening_balance
    @opening_balance ||= (INITIAL_BALANCE + before_range(all_rows).sum { |r| r.deposit - r.withdrawal }).round(2)
  end

  def total_deposits    = rows.sum(&:deposit).round(2)
  def total_withdrawals = rows.sum(&:withdrawal).round(2)
  def closing_balance   = (opening_balance + total_deposits - total_withdrawals).round(2)

  private

  # Type / mode filters narrow the whole ledger (so the opening balance is for
  # that slice too); the date filter splits it into "before" and "in range".
  def all_rows
    @all_rows ||= (sales_rows + purchase_rows + journal_rows)
                  .select { |r| type.nil? || r.type == type }
                  .select { |r| payment_mode.nil? || r.payment_mode == payment_mode }
                  .sort_by { |r| [r.date, r.sort_time, r.type, r.reference.to_s] }
  end

  def before_range(list) = from ? list.select { |r| r.date < from } : []

  def in_range(list)
    list.select { |r| (from.nil? || r.date >= from) && (to.nil? || r.date <= to) }
  end

  def sales_rows
    receipts = SalesReceipt.includes(:booking).to_a
    invoice_numbers = receipts.map { |sr| sr.invoice_number.presence || sr.booking&.invoice_number.presence }.compact.uniq
    invoices = Invoice.where(invoice_number: invoice_numbers).index_by(&:invoice_number)
    receipts.map do |sr|
      Row.new(date: sr.receipt_date, type: 'sales_receipt', reference: sr.receipt_number,
              description: ["Customer Payment", sr.booking_number.presence && "Booking ##{sr.booking_number}", sr.invoice_number].compact.join(' · '),
              party: sr.customer_name, payment_mode: sr.payment_mode, deposit: sr.amount.to_f, withdrawal: 0.0,
              record: sr, sort_time: sr.created_at, booking: sr.booking,
              invoice: invoices[sr.invoice_number.presence || sr.booking&.invoice_number.presence])
    end
  end

  def purchase_rows
    PurchaseReceipt.includes(vendor_purchase: :vendor_invoice).map do |pr|
      Row.new(date: pr.receipt_date, type: 'purchase_receipt', reference: pr.receipt_number,
              description: ["Vendor Payment", pr.purchase_number.presence && "Purchase #{pr.purchase_number}"].compact.join(' · '),
              party: pr.vendor_name, payment_mode: pr.payment_mode, deposit: 0.0, withdrawal: pr.amount.to_f,
              record: pr, sort_time: pr.created_at, vendor_purchase: pr.vendor_purchase,
              vendor_invoice: pr.vendor_purchase&.vendor_invoice)
    end
  end

  def journal_rows
    ManualJournal.manual_only.published.map do |j|
      Row.new(date: j.journal_date, type: 'manual_journal', reference: j.journal_number,
              description: j.notes.to_s.truncate(80).presence || 'Manual Journal',
              party: j.reference_number, payment_mode: j.payment_mode, deposit: 0.0, withdrawal: j.total_amount.to_f,
              record: j, sort_time: j.created_at)
    end
  end
end

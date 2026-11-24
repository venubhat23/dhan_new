# Posts system journals (Zoho Books style) for everyday transactions, so the
# Chart of Accounts shows real balances for Receivables, Payables, Cash, Bank,
# GST and Inventory:
#
#   Sales invoice      Dr Accounts Receivable   Cr Sales / GST Payable / Shipping Charge
#   Payment received   Dr Cash in Hand | Bank   Cr Accounts Receivable
#   Vendor purchase    Dr Inventory Asset       Cr Accounts Payable
#   Payment made       Dr Accounts Payable      Cr Cash in Hand | Bank
#
# Each journal is keyed by (source_type, source_id, entry_kind) and rebuilt
# whenever its source changes, removed when the source is cancelled/deleted.
# These journals are read-only in the UI and excluded from Profit & Loss,
# which already reads invoices/purchases directly.
#
# Sync failures are logged, never raised: an accounting hiccup must not block
# saving an invoice or purchase. `rake journals:sync_auto` rebuilds everything.
class AutoJournal
  KINDS = {
    'sales_invoice'    => 'Sales Invoice',
    'payment_received' => 'Payment Received',
    'purchase'         => 'Vendor Purchase',
    'payment_made'     => 'Payment Made'
  }.freeze

  ACCOUNT_TYPES = {
    'Accounts Receivable' => 'asset', 'Accounts Payable' => 'liability', 'GST Payable' => 'liability',
    'Sales' => 'income', 'Shipping Charge' => 'income', 'Inventory Asset' => 'asset',
    'Cash in Hand' => 'cash', 'Bank Account' => 'bank'
  }.freeze

  class << self
    def sync_invoice(invoice)
      guard("invoice ##{invoice.id}") do
        invoice = Invoice.includes(invoice_items: :product).find_by(id: invoice.id)
        return remove_for('Invoice', invoice&.id || 0) if invoice.nil?

        if invoice.cancelled? || invoice.draft?
          remove_for('Invoice', invoice.id)
        else
          post('Invoice', invoice.id, 'sales_invoice', **sales_entry(invoice))
          post('Invoice', invoice.id, 'payment_received', **receipt_entry(invoice))
        end
      end
    end

    def sync_vendor_purchase(purchase)
      guard("vendor purchase ##{purchase.id}") do
        purchase = VendorPurchase.includes(:vendor).find_by(id: purchase.id)
        return if purchase.nil?
        return remove_for('VendorPurchase', purchase.id) if purchase.status == 'cancelled'

        amount = purchase.total_amount.to_f.round(2)
        vendor = purchase.vendor&.name
        post('VendorPurchase', purchase.id, 'purchase',
             date: purchase.purchase_date || purchase.created_at.to_date,
             reference: purchase.purchase_number,
             notes: "Auto: purchase #{purchase.purchase_number} from #{vendor || 'vendor'}",
             lines: [
               { account: 'Inventory Asset', debit: amount, contact: vendor, description: 'Stock purchased' },
               { account: 'Accounts Payable', credit: amount, contact: vendor, description: 'Owed to vendor' }
             ])
      end
    end

    def sync_vendor_payment(payment)
      guard("vendor payment ##{payment.id}") do
        payment = VendorPayment.includes(:vendor, :vendor_purchase).find_by(id: payment.id)
        return if payment.nil?

        amount = payment.amount_paid.to_f.round(2)
        vendor = payment.vendor&.name
        purchase_no = payment.vendor_purchase&.purchase_number
        post('VendorPayment', payment.id, 'payment_made',
             date: payment.payment_date || payment.created_at.to_date,
             reference: payment.payment_number,
             notes: "Auto: #{payment.payment_mode} payment to #{vendor || 'vendor'}#{" for #{purchase_no}" if purchase_no}",
             lines: [
               { account: 'Accounts Payable', debit: amount, contact: vendor, description: "Paid against #{purchase_no}" },
               { account: payment.payment_mode == 'Cash' ? 'Cash in Hand' : 'Bank Account', credit: amount, contact: vendor,
                 description: "#{payment.payment_mode} payment" }
             ])
      end
    end

    def remove_for(source_type, source_id)
      ManualJournal.where(source_type: source_type, source_id: source_id).find_each(&:destroy!)
    end

    # Rebuilds every auto journal from scratch-safe, idempotent syncs.
    def sync_all!
      Invoice.find_each { |i| sync_invoice(i) }
      VendorPurchase.find_each { |p| sync_vendor_purchase(p) }
      VendorPayment.find_each { |p| sync_vendor_payment(p) }
      ManualJournal.automatic.where(source_type: 'Invoice').where.not(source_id: Invoice.select(:id)).find_each(&:destroy!)
      ManualJournal.automatic.where(source_type: 'VendorPurchase').where.not(source_id: VendorPurchase.select(:id)).find_each(&:destroy!)
      ManualJournal.automatic.where(source_type: 'VendorPayment').where.not(source_id: VendorPayment.select(:id)).find_each(&:destroy!)
    end

    private

    def sales_entry(invoice)
      total    = invoice.total_amount.to_f.round(2)
      tax      = invoice.invoice_items.sum { |i| item_tax(i) }.round(2)
      shipping = invoice.delivery_charge.to_f.round(2)
      sales    = (total - tax - shipping).round(2) # net of discounts
      # A discount larger than the goods value eats into shipping, then tax.
      if sales.negative?
        shipping = [shipping + sales, 0].max.round(2)
        sales = 0
        tax = (total - shipping).round(2)
      end
      customer = invoice.customer_display_name.presence rescue nil

      lines = [{ account: 'Accounts Receivable', debit: total, contact: customer, description: "Invoice #{invoice.invoice_number}" }]
      lines << { account: 'Sales', credit: sales, contact: customer, description: 'Goods sold (net of discount)' }
      lines << { account: 'GST Payable', credit: tax, contact: customer, description: 'Output GST' }
      lines << { account: 'Shipping Charge', credit: shipping, contact: customer, description: 'Delivery charge' }

      { date: invoice.invoice_date || invoice.created_at.to_date, reference: invoice.invoice_number,
        notes: "Auto: sales invoice #{invoice.invoice_number}#{" — #{customer}" if customer}", lines: lines }
    end

    def receipt_entry(invoice)
      paid = invoice.fully_paid? ? invoice.total_amount.to_f : invoice.paid_amount.to_f
      paid = paid.round(2)
      customer = invoice.customer_display_name.presence rescue nil
      booking = invoice.related_booking rescue nil
      cash = booking.nil? || booking.payment_gateway.to_s == 'cash' || booking.payment_method.to_s.casecmp?('cash')
      account = cash ? 'Cash in Hand' : 'Bank Account'

      { date: invoice.paid_at&.to_date || invoice.invoice_date || invoice.created_at.to_date,
        reference: invoice.invoice_number,
        notes: "Auto: payment received for #{invoice.invoice_number}#{" — #{customer}" if customer}",
        lines: [
          { account: account, debit: paid, contact: customer, description: cash ? 'Cash received' : 'Received in bank' },
          { account: 'Accounts Receivable', credit: paid, contact: customer, description: "Against #{invoice.invoice_number}" }
        ] }
    end

    # GST on a line, matching Invoice#line_amount_with_tax (tax added on top of the net unit price).
    def item_tax(item)
      product = item.product
      return 0.0 unless product&.gst_enabled

      rate = if product.cgst_percentage.present? || product.sgst_percentage.present?
               product.cgst_percentage.to_f + product.sgst_percentage.to_f + product.igst_percentage.to_f
             else
               product.gst_percentage.to_f
             end
      item.quantity.to_f * item.unit_price.to_f * rate / 100.0
    end

    # Creates/updates/removes one journal so it matches `lines`; zero lines are dropped.
    def post(source_type, source_id, kind, date:, reference:, notes:, lines:)
      lines = lines.map { |l| l.merge(debit: l[:debit].to_f.round(2), credit: l[:credit].to_f.round(2)) }
                   .reject { |l| l[:debit].zero? && l[:credit].zero? }
      journal = ManualJournal.find_by(source_type: source_type, source_id: source_id, entry_kind: kind)
      if lines.size < 2
        journal&.destroy!
        return
      end

      wanted = lines.each_with_index.map { |l, i| [account(l[:account]).id, l[:debit], l[:credit], l[:contact].to_s, l[:description].to_s, i] }
      if journal
        current = journal.manual_journal_lines.map { |l| [l.ledger_account_id, l.debit.to_f, l.credit.to_f, l.contact_name.to_s, l.description.to_s, l.position] }
        return if current == wanted && journal.journal_date == date && journal.reference_number == reference && journal.notes == notes

        journal.manual_journal_lines.each(&:mark_for_destruction)
      else
        journal = ManualJournal.new(source_type: source_type, source_id: source_id, entry_kind: kind,
                                    status: 'published', published_at: Time.current, reporting_method: 'accrual_and_cash')
      end

      journal.assign_attributes(journal_date: date, reference_number: reference, notes: notes.truncate(500))
      wanted.each do |acct_id, dr, cr, contact, desc, pos|
        journal.manual_journal_lines.build(ledger_account_id: acct_id, debit: dr, credit: cr,
                                           contact_name: contact.presence, description: desc.presence, position: pos)
      end
      journal.save!
    end

    def account(name)
      LedgerAccount.where('LOWER(name) = ?', name.downcase).first ||
        LedgerAccount.create!(name: name, account_type: ACCOUNT_TYPES.fetch(name), system: true)
    end

    def guard(label)
      yield
    rescue => e
      Rails.logger.error "[AutoJournal] failed for #{label}: #{e.class}: #{e.message}"
      nil
    end
  end
end

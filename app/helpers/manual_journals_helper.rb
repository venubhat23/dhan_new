module ManualJournalsHelper
  # Admin link to the invoice / purchase an auto journal was posted from (payments link to their purchase).
  def journal_source_path(journal)
    src = journal.source_record
    case src
    when Invoice then admin_invoice_path(src)
    when VendorPurchase then admin_vendor_purchase_path(src)
    when VendorPayment then src.vendor_purchase_id && admin_vendor_purchase_path(src.vendor_purchase_id)
    end
  end

  def journal_kind_badge(journal)
    return unless journal.automatic?

    content_tag(:span, class: 'badge rounded-pill bg-info-subtle text-info-emphasis border border-info-subtle ms-1') do
      safe_join([content_tag(:i, '', class: 'bi bi-lightning-charge-fill me-1'), journal.entry_kind_label])
    end
  end
end

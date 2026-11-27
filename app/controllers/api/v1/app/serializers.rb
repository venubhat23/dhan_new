# JSON shapes shared by the mobile app API controllers.
module Api::V1::App::Serializers
  include ActionView::Helpers::NumberHelper
  include Admin::BookingsHelper

  private

  def money(v) = v.to_f.round(2)

  def wa_digits(phone)
    d = phone.to_s.gsub(/\D/, '').sub(/^0+/, '')
    d = d.delete_prefix('91') if d.length == 12
    d.length == 10 ? d : nil
  end

  def wa_link(phone, text)
    d = wa_digits(phone)
    d ? "https://wa.me/91#{d}?text=#{ERB::Util.url_encode(text)}" : nil
  end

  # ---- customers -----------------------------------------------------------

  def customer_json(c, full: false)
    return nil unless c

    h = { id: c.id, name: c.display_name, mobile: c.mobile, email: c.email.to_s.end_with?('.invalid') ? nil : c.email,
          area: c.try(:landmark), is_b2b: c.try(:is_b2b) || false }
    if full
      h.merge!(address: c.address, shipping_address: c.try(:shipping_address), whatsapp_number: c.try(:whatsapp_number),
               gst_no: c.try(:gst_no), location_link: c.try(:location_link), latitude: c.latitude&.to_f,
               longitude: c.longitude&.to_f, notes: c.try(:notes))
    end
    h
  end

  # ---- products ------------------------------------------------------------

  def product_stock(p)
    if p.has_multiple_quantities?
      p.product_variants.sum { |v| v.available_stock.to_f }
    else
      p.total_batch_stock.to_f
    end
  end

  def variant_json(v)
    { id: v.id, label: v.label, weight: v.weight&.to_f, unit: v.unit, selling_price: money(v.selling_price),
      buying_price: money(v.buying_price || v.purchase_price), b2b_price: v.b2b_price&.to_f,
      stock: v.available_stock.to_f, low_stock_threshold: v.low_stock_threshold.to_i, is_default: v.is_default }
  end

  def product_json(p, full: false)
    h = { id: p.id, name: p.name, category_id: p.category_id, category: p.category&.name, sku: p.sku,
          unit: p.unit_type, price: money(p.price), buying_price: money(p.buying_price || p.purchase_price),
          b2b_price: p.b2b_price&.to_f, gst_percentage: p.gst_percentage.to_f, status: p.status,
          stock: product_stock(p), low_stock_threshold: p.low_stock_threshold.to_i,
          has_variants: p.has_multiple_quantities? || false, image_url: absolute_url(p.main_image_url) }
    h[:variants] = p.sorted_variants.map { |v| variant_json(v) } if p.has_multiple_quantities?
    h.merge!(description: p.description, hsn_code: p.hsn_code) if full
    h
  end

  def absolute_url(url)
    return nil if url.blank?

    url.start_with?('/') ? "#{base_url}#{url}" : url
  end

  # ---- bookings ------------------------------------------------------------

  def booking_invoice(b)
    return @booking_invoice_cache[b.id] if @booking_invoice_cache&.key?(b.id)

    (@booking_invoice_cache ||= {})[b.id] =
      b.invoice_number.present? ? Invoice.find_by(invoice_number: b.invoice_number) : nil
  end

  def booking_paid_amount(b)
    return b.total_amount.to_f if b.payment_status_paid?

    booking_invoice(b)&.paid_amount.to_f
  end

  def booking_item_json(i)
    { id: i.id, product_id: i.product_id, product_variant_id: i.product_variant_id,
      name: i.product_variant ? "#{i.product&.name} (#{i.product_variant.label})" : i.product&.name,
      quantity: i.quantity.to_f, unit: i.product_variant&.unit.presence || i.product&.unit_type,
      price: money(i.price), discount_type: i.discount_type, discount_value: i.discount_value&.to_f,
      discount_amount: money(i.discount_amount), total: money(i.total) }
  end

  def booking_json(b, full: false)
    paid = booking_paid_amount(b)
    c = b.customer
    h = {
      id: b.id, booking_number: b.booking_number,
      booking_date: (b.booking_date || b.created_at)&.iso8601,
      status: b.status, status_label: Booking.status_label(b.status),
      payment_status: b.payment_status, paid_via: b.paid_via, paid_via_label: b.paid_via_label,
      total_amount: money(b.total_amount), paid_amount: money(paid), due_amount: money(b.total_amount.to_f - paid),
      customer_id: b.customer_id,
      customer_name: b.customer_name.presence || c&.display_name,
      customer_phone: b.customer_phone.presence || c&.mobile,
      delivery_address: b.delivery_address.presence || c&.try(:shipping_address).presence || c&.address,
      area: c&.try(:landmark),
      expected_delivery_date: b.expected_delivery_date&.iso8601,
      expected_delivery_time: b.expected_delivery_time,
      delivery_person: b.delivery_person && { id: b.delivery_person.id, name: b.delivery_person.display_name, mobile: b.delivery_person.mobile },
      store: b.store && { id: b.store.id, name: b.store.name },
      items_count: b.booking_items_count || b.booking_items.size,
      invoice_number: b.invoice_number
    }
    return h unless full

    inv = booking_invoice(b)
    bi = b.booking_invoices.first
    b.ensure_share_token!
    public_url = "#{base_url}/booking/#{b.share_token}"
    h.merge(
      subtotal: money(b.subtotal), tax_amount: money(b.tax_amount), discount_amount: money(b.discount_amount),
      shipping_charges: money(b.shipping_charges), notes: b.notes, is_b2b: b.is_b2b, gstin: b.gstin,
      booked_by: b.booked_by,
      customer: customer_json(c, full: true),
      location: location_json(b),
      items: b.booking_items.map { |i| booking_item_json(i) },
      invoice: inv && { id: inv.id, invoice_number: inv.invoice_number, total_amount: money(inv.total_amount),
                        paid_amount: money(inv.paid_amount), payment_status: inv.payment_status },
      public_url: public_url,
      invoice_view_url: bi&.share_token.present? ? "#{base_url}/invoice/#{bi.share_token}" : nil,
      invoice_pdf_url: bi&.share_token.present? ? "#{base_url}/invoice/#{bi.share_token}/download" : nil,
      whatsapp: booking_whatsapp_links(b, public_url)
    )
  end

  # Map pin for the booking: the customer's saved link / coordinates, else a
  # maps search for the delivery address.
  def location_json(b)
    c = b.customer
    lat = c&.latitude&.to_f
    lng = c&.longitude&.to_f
    address = b.delivery_address.presence || c&.try(:shipping_address).presence || c&.address
    link = c&.try(:location_link).presence ||
           (lat && lng ? "https://maps.google.com/?q=#{lat},#{lng}" : nil) ||
           (address.present? ? "https://www.google.com/maps/search/?api=1&query=#{ERB::Util.url_encode(address)}" : nil)
    { latitude: lat, longitude: lng, address: address, maps_url: link }
  end

  def booking_whatsapp_links(b, public_url)
    phone = b.customer&.mobile.presence || b.customer_phone
    {
      send_invoice: wa_link(phone, booking_send_invoice_message(b, public_url)),
      payment_thank_you: wa_link(phone, booking_payment_thanks_message(b, invoice: booking_invoice(b))),
      payment_reminder: (b.payment_status_paid? ? nil : wa_link(phone, payment_reminder_message(b)))
    }
  end

  def payment_reminder_message(b)
    paid = booking_paid_amount(b)
    due = (b.total_amount.to_f - paid).round(2)
    name = b.customer&.display_name || b.customer_name.presence || 'Customer'
    date = (b.booking_date || b.created_at || Time.current).in_time_zone.strftime('%d-%b-%Y')
    ref = b.invoice_number.presence || b.booking_number
    lines = ["Dear #{name},", '',
             "This is a gentle reminder that a payment of Rs. #{format('%.2f', due)} is pending for #{b.invoice_number.present? ? 'Invoice' : 'Booking'} #{ref} dated #{date}."]
    lines << "Total: Rs. #{format('%.2f', b.total_amount.to_f)}, Paid: Rs. #{format('%.2f', paid)}" if paid.positive?
    lines += ['', 'Kindly clear the balance at your earliest convenience. Please ignore if already paid.', '',
              'Thank you,', 'Dhanvantari Naturals']
    lines.join("\n")
  end

  # ---- vendors -------------------------------------------------------------

  def vendor_json(v)
    { id: v.id, name: v.name, phone: v.phone, email: v.email, address: v.address, gst_no: v.try(:gst_no),
      payment_type: v.payment_type, status: v.status }
  end

  def vendor_purchase_json(vp, full: false)
    h = { id: vp.id, vendor: vp.vendor && { id: vp.vendor.id, name: vp.vendor.name },
          purchase_date: vp.purchase_date&.iso8601, total_amount: money(vp.total_amount),
          paid_amount: money(vp.paid_amount), due_amount: money(vp.total_amount.to_f - vp.paid_amount.to_f),
          payment_status: vp.payment_status, payment_mode: vp.payment_mode, status: vp.status, notes: vp.notes }
    if full
      h[:items] = vp.vendor_purchase_items.map do |i|
        { id: i.id, product_id: i.product_id, product_variant_id: i.product_variant_id,
          name: i.product_variant ? "#{i.product&.name} (#{i.product_variant.label})" : i.product&.name,
          quantity: i.quantity.to_f, purchase_price: money(i.purchase_price), selling_price: money(i.selling_price),
          line_total: money(i.quantity.to_f * i.purchase_price.to_f) }
      end
    end
    h
  end
end

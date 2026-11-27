module Admin::BookingsHelper
  # wa.me link carrying a "payment received, thank you" note to the booking's
  # customer, or nil when there's no usable mobile number. Plain text on
  # purpose: emojis arrive garbled through wa.me (₹ is fine).
  def booking_payment_thanks_whatsapp_url(booking, invoice: nil)
    booking_whatsapp_url(booking, booking_payment_thanks_message(booking, invoice: invoice))
  end

  # wa.me link with a gentle "payment pending" reminder (the "R" button next
  # to Mark Paid). nil when there's no usable mobile number.
  def booking_payment_reminder_whatsapp_url(booking, invoice: nil)
    booking_whatsapp_url(booking, booking_payment_reminder_message(booking, invoice: invoice))
  end

  # Reminder wording as supplied by the client. Amount = what's still pending
  # (total minus anything already paid); falls back to the booking number when
  # no invoice has been generated yet.
  def booking_payment_reminder_message(booking, invoice: nil)
    invoice ||= Invoice.find_by(invoice_number: booking.invoice_number) if booking.invoice_number.present?
    total = (invoice&.total_amount || booking.total_amount).to_f
    pending = [total - invoice&.paid_amount.to_f, 0].max
    pending = total if pending.zero?
    name = booking.customer&.display_name || booking.customer_name.presence || 'Customer'
    reference = if invoice&.invoice_number.present? then "Invoice number: #{invoice.invoice_number}"
                else "Booking number: #{booking.booking_number}"
                end

    ["Dear #{name},", '',
     "This is a gentle reminder regarding the pending payment of Rs. #{format('%.2f', pending)} for your order (#{reference}).", '',
     'Kindly complete the payment at your earliest convenience and share the payment screenshot with us for confirmation.', '',
     'Thank you for shopping with Dhanvantari Naturals.'].join("\n")
  end

  # wa.me link with the "delivery tomorrow" reminder (the "R" button in the
  # Booking Details column). nil when there's no usable mobile number.
  def booking_delivery_reminder_whatsapp_url(booking)
    booking_whatsapp_url(booking, booking_delivery_reminder_message(booking))
  end

  # Wording as supplied by the client.
  def booking_delivery_reminder_message(booking)
    name = booking.customer&.display_name || booking.customer_name.presence || 'Customer'
    ["Dear #{name},", '',
     'Greetings from Dhanvantari Naturals! 🌿', '',
     'This is a reminder that your order is scheduled for delivery tomorrow.', '',
     'Kindly ensure that someone is available to receive the order.', '',
     'Thank you for shopping with us!', '',
     'Warm regards,', 'Dhanvantari Naturals'].join("\n")
  end

  def booking_whatsapp_url(booking, text)
    digits = (booking.customer&.mobile || booking.customer_phone).to_s.gsub(/\D/, '').sub(/^0+/, '')
    digits = digits.delete_prefix('91') if digits.length == 12
    return nil unless digits.length == 10

    "https://wa.me/91#{digits}?text=#{ERB::Util.url_encode(text)}"
  end

  # The one WhatsApp thank-you text used by every "Thanks" button. Wording as
  # requested by the client (based on their accounting app's "Payment-in" receipt).
  # A booking with nothing paid yet quotes its full amount as the booking total.
  def booking_payment_thanks_message(booking, invoice: nil)
    invoice ||= Invoice.find_by(invoice_number: booking.invoice_number) if booking.invoice_number.present?
    total = (invoice&.total_amount || booking.total_amount).to_f
    paid = booking.payment_status_paid? ? total : invoice&.paid_amount.to_f
    name = booking.customer&.display_name || booking.customer_name.presence || 'Customer'
    reference = invoice&.invoice_number.presence || booking.booking_number

    if paid > 0
      received_on = (invoice&.paid_at || booking.payment_completed_at || Time.current).in_time_zone.strftime('%d-%b-%Y')
      ref_label = invoice&.invoice_number.present? ? 'Invoice number' : 'Booking number'
      headline = "Payment (#{ref_label}: #{reference}) of Rs. #{format('%.2f', paid)} has been received from you on #{received_on}"
    else
      booked_on = (booking.booking_date || booking.created_at || Time.current).in_time_zone.strftime('%d-%b-%Y')
      headline = "Booking(number: #{booking.booking_number}) of Rs. #{format('%.2f', total)} has been received from you on #{booked_on}"
    end
    payment_thanks_text(name, headline, due: total - paid)
  end

  # "Send Invoice" text: points the customer at the booking's public bill page
  # (/booking/:token). No emojis for the same wa.me reason as above (₹ is fine).
  def booking_send_invoice_message(booking, public_url)
    name = booking.customer&.display_name || booking.customer_name.presence || 'Customer'
    date = (booking.booking_date || booking.created_at || Time.current).in_time_zone.strftime('%d %b %Y')
    amount = number_to_currency(booking.total_amount.to_f, unit: '₹', precision: 2)
    ["Dear #{name},", '', 'Thank you for your booking with Dhanvantari Naturals!', '',
     "Booking #: #{booking.booking_number}", "Date: #{date}", "Amount: #{amount}", '',
     "View your booking: #{public_url}", '', 'We appreciate your trust in us!', '',
     'Dhanvantari Naturals'].join("\n")
  end

  def payment_thanks_text(name, headline, due: 0)
    lines = ["Dear #{name},", '', headline]
    lines << "Balance due: Rs. #{format('%.2f', due.round(2))}" if due.round(2) > 0
    lines += ['', 'Thank you for your business. We appreciate your trust in us!', '', 'Dhanvantari Naturals']
    lines.join("\n")
  end
end

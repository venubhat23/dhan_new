module Admin::BookingsHelper
  # wa.me link carrying a "payment received, thank you" note to the booking's
  # customer, or nil when there's no usable mobile number. Plain text on
  # purpose: emojis arrive garbled through wa.me (₹ is fine).
  def booking_payment_thanks_whatsapp_url(booking, invoice: nil)
    digits = (booking.customer&.mobile || booking.customer_phone).to_s.gsub(/\D/, '').sub(/^0+/, '')
    digits = digits.delete_prefix('91') if digits.length == 12
    return nil unless digits.length == 10

    "https://wa.me/91#{digits}?text=#{ERB::Util.url_encode(booking_payment_thanks_message(booking, invoice: invoice))}"
  end

  # The one WhatsApp thank-you text used by every "Thanks" button. Wording as
  # requested by the client (mirrors their accounting app's "Payment-in" receipt).
  # A booking with nothing paid yet quotes its full amount as the booking total.
  def booking_payment_thanks_message(booking, invoice: nil)
    invoice ||= Invoice.find_by(invoice_number: booking.invoice_number) if booking.invoice_number.present?
    total = (invoice&.total_amount || booking.total_amount).to_f
    paid = booking.payment_status_paid? ? total : invoice&.paid_amount.to_f
    name = booking.customer&.display_name || booking.customer_name.presence || 'Customer'
    reference = invoice&.invoice_number.presence || booking.booking_number

    if paid > 0
      received_on = (invoice&.paid_at || booking.payment_completed_at || Time.current).in_time_zone.strftime('%d-%b-%Y')
      headline = "Payment-in(number: #{reference}) of Rs. #{format('%.2f', paid)} has been received from you on #{received_on}"
    else
      booked_on = (booking.booking_date || booking.created_at || Time.current).in_time_zone.strftime('%d-%b-%Y')
      headline = "Booking(number: #{booking.booking_number}) of Rs. #{format('%.2f', total)} has been received from you on #{booked_on}"
    end
    payment_thanks_text(name, headline, due: total - paid)
  end

  def payment_thanks_text(name, headline, due: 0)
    lines = ["Dear #{name},", '', headline]
    lines << "Balance due: Rs. #{format('%.2f', due.round(2))}" if due.round(2) > 0
    lines += ['', 'Thank you for your business. We appreciate your trust in us!', '', 'Dhanvantari Naturals']
    lines.join("\n")
  end
end

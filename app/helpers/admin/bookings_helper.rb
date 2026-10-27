module Admin::BookingsHelper
  # wa.me link carrying a "payment received, thank you" note to the booking's
  # customer, or nil when there's no usable mobile number. Plain text on
  # purpose: emojis arrive garbled through wa.me (₹ is fine).
  def booking_payment_thanks_whatsapp_url(booking, invoice: nil)
    digits = (booking.customer&.mobile || booking.customer_phone).to_s.gsub(/\D/, '').sub(/^0+/, '')
    digits = digits.delete_prefix('91') if digits.length == 12
    return nil unless digits.length == 10

    invoice ||= Invoice.find_by(invoice_number: booking.invoice_number) if booking.invoice_number.present?
    total = (invoice&.total_amount || booking.total_amount).to_f
    paid = booking.payment_status_paid? ? total : invoice&.paid_amount.to_f
    due = (total - paid).round(2)

    name = booking.customer&.display_name || booking.customer_name.presence || 'Customer'
    received_on = (invoice&.paid_at || booking.payment_completed_at || Time.current).in_time_zone.strftime('%d-%b-%Y')
    reference = invoice&.invoice_number.presence || booking.booking_number

    # Wording as requested by the client (mirrors their accounting app's "Payment-in" receipt).
    lines = ["Dear #{name},", '',
             "Payment-in(number: #{reference}) of Rs. #{format('%.2f', paid)} has been received from you on #{received_on}"]
    lines << "Balance due: Rs. #{format('%.2f', due)}" if due > 0
    lines += ['', 'Thank you for your business.', '', 'Dhanvantari Naturals']

    "https://wa.me/91#{digits}?text=#{ERB::Util.url_encode(lines.join("\n"))}"
  end
end

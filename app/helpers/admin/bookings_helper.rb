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

    booking.ensure_share_token!
    name = booking.customer&.display_name || booking.customer_name.presence || 'Customer'

    lines = ["Dear #{name},", '',
             "We have received your payment of ₹#{number_with_delimiter(format('%.2f', paid))} for booking #{booking.booking_number}. Thank you!"]
    lines << "Balance due: ₹#{number_with_delimiter(format('%.2f', due))}" if due > 0
    lines += ['', "View your booking: #{request.base_url}/booking/#{booking.share_token}", '',
              'Thank you for choosing Dhanvantari Naturals.', 'Dhanvantari Naturals Team']

    "https://wa.me/91#{digits}?text=#{ERB::Util.url_encode(lines.join("\n"))}"
  end
end

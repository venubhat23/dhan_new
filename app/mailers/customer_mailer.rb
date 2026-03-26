class CustomerMailer < ApplicationMailer
  default from: 'maralisanthe@gmail.com'
  layout 'mailer'

  def password_reset_instructions(customer)
    @customer = customer
    @reset_token = customer.password_reset_token
    @app_name = 'Marali Santhe'

    mail(
      to: @customer.email,
      subject: 'Password Reset Instructions - Marali Santhe'
    )
  end

  def password_changed_notification(customer)
    @customer = customer
    @app_name = 'Marali Santhe'

    mail(
      to: @customer.email,
      subject: 'Your Password Has Been Changed - Marali Santhe'
    )
  end

  def booking_confirmation(booking)
    @booking = booking
    @customer = booking.customer
    @app_name = 'Marali Santhe'
    @order_date = @booking.created_at.strftime('%d/%m/%Y at %I:%M %p')

    # Generate public invoice URL if invoice exists
    if @booking.has_invoice?
      if @booking.associated_invoice&.share_token
        # Use the public invoice route for regular invoices
        @invoice_url = "https://maralisanthe.com/invoices_public/#{@booking.associated_invoice.share_token}"
      elsif @booking.booking_invoices.any? && @booking.booking_invoices.first.respond_to?(:share_token) && @booking.booking_invoices.first.share_token.present?
        # Use the public invoice route for booking invoices
        @invoice_url = "https://maralisanthe.com/invoice/#{@booking.booking_invoices.first.share_token}"
      end
    end

    mail(
      to: @customer.email,
      subject: "Order Confirmation ##{@booking.booking_number} - Marali Santhe"
    )
  end
end
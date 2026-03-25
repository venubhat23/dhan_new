class CustomerMailer < ApplicationMailer
  default from: 'maralisanthe@gmail.com'
  layout 'mailer'

  def password_reset_instructions(customer)
    @customer = customer
    @reset_url = customer_reset_password_url(token: @customer.password_reset_token, host: 'maralisanthe.com', protocol: 'https')
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
end
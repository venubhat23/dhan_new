# POST /api/v1/app/auth/login           admin login (email or mobile + password)
# POST /api/v1/app/auth/delivery_login  delivery person login (mobile or email + password)
# GET  /api/v1/app/auth/me              who the token belongs to
class Api::V1::App::AuthController < Api::V1::App::BaseController
  skip_before_action :authenticate!, only: [:login, :delivery_login]

  def login
    login = params[:username].presence || params[:email].presence || params[:mobile].presence
    password = params[:password].to_s
    return render_error('Username and password are required', :unprocessable_entity) if login.blank? || password.blank?

    user = find_admin(login.to_s.strip)
    unless user && user.valid_password?(password)
      return render_error('Invalid username or password', :unauthorized)
    end
    return render_error('This account is not an admin account', :forbidden) unless active_admin?(user)

    user.update_columns(last_login_at: Time.current, login_count: user.login_count.to_i + 1) rescue nil
    render_success({ token: self.class.issue_token('admin', user.id), token_type: 'Bearer',
                     expires_in: TOKEN_TTL.to_i, role: 'admin', user: admin_json(user) },
                   message: 'Login successful')
  end

  def delivery_login
    login = params[:mobile].presence || params[:username].presence || params[:email].presence
    password = params[:password].to_s
    return render_error('Mobile and password are required', :unprocessable_entity) if login.blank? || password.blank?

    dp = find_delivery_person(login.to_s.strip)
    unless dp && delivery_password_ok?(dp, password)
      return render_error('Invalid mobile or password', :unauthorized)
    end
    return render_error('This delivery account is inactive', :forbidden) unless dp.status

    render_success({ token: self.class.issue_token('delivery_person', dp.id), token_type: 'Bearer',
                     expires_in: TOKEN_TTL.to_i, role: 'delivery_person', delivery_person: delivery_person_json(dp) },
                   message: 'Login successful')
  end

  def me
    if current_admin
      render_success({ role: 'admin', user: admin_json(current_admin) })
    else
      render_success({ role: 'delivery_person', delivery_person: delivery_person_json(current_delivery_person) })
    end
  end

  private

  def find_admin(login)
    scope = User.where(user_type: 'admin')
    user = scope.find_by('LOWER(email) = ?', login.downcase)
    return user if user

    digits = login.gsub(/\D/, '').last(10)
    return nil unless digits.length == 10

    scope.where("RIGHT(REGEXP_REPLACE(mobile, '\\D', '', 'g'), 10) = ?", digits).first
  end

  def find_delivery_person(login)
    dp = DeliveryPerson.find_by('LOWER(email) = ?', login.downcase)
    return dp if dp

    digits = login.gsub(/\D/, '').last(10)
    return nil unless digits.length == 10

    DeliveryPerson.where("RIGHT(REGEXP_REPLACE(mobile, '\\D', '', 'g'), 10) = ?", digits).first
  end

  # Admin → Delivery Persons sets the password on the DeliveryPerson when
  # creating, but editing only changes the linked User (user_type
  # 'delivery_person', same email) — so accept either.
  def delivery_password_ok?(dp, password)
    return true if dp.password_digest.present? && dp.authenticate(password)

    user = User.find_by(email: dp.email, user_type: 'delivery_person') if dp.email.present?
    user.present? && user.valid_password?(password)
  end

  def admin_json(u)
    { id: u.id, name: [u.first_name, u.last_name].compact_blank.join(' '), email: u.email, mobile: u.mobile, user_type: u.user_type }
  end

  def delivery_person_json(dp)
    { id: dp.id, name: dp.display_name, mobile: dp.mobile, email: dp.email, vehicle_type: dp.vehicle_type,
      vehicle_number: dp.vehicle_number }
  end
end

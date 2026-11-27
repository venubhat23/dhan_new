# Mobile app API (admin app + delivery app) — /api/v1/app/...
#
# Stateless JSON API authenticated with a Bearer JWT issued by
# Api::V1::App::AuthController. Two kinds of tokens:
#   kind: 'admin'           → a User with user_type 'admin'
#   kind: 'delivery_person' → a DeliveryPerson (sees only their own bookings)
#
# All business logic is the same model code the web admin uses (Booking,
# Invoice#record_payment!, VendorPurchase, StockBatch ...), so actions taken in
# the app behave exactly like the same actions in /admin.
class Api::V1::App::BaseController < ActionController::API
  include Api::V1::App::Serializers

  TOKEN_TTL = 30.days

  before_action :authenticate!

  rescue_from ActiveRecord::RecordNotFound do |e|
    render_error("#{e.model || 'Record'} not found", :not_found)
  end
  rescue_from ActiveRecord::RecordInvalid do |e|
    render_error(e.record.errors.full_messages.to_sentence, :unprocessable_entity, e.record.errors.full_messages)
  end
  rescue_from ActionController::ParameterMissing do |e|
    render_error(e.message, :bad_request)
  end

  attr_reader :current_admin, :current_delivery_person

  def self.issue_token(kind, id)
    payload = { kind: kind, id: id, exp: TOKEN_TTL.from_now.to_i }
    JWT.encode(payload, secret, 'HS256')
  end

  def self.secret
    "#{Rails.application.secret_key_base}:mobile-app"
  end

  private

  def authenticate!
    token = request.headers['Authorization'].to_s.split(' ').last
    return render_error('Authorization token is required', :unauthorized) if token.blank?

    payload = JWT.decode(token, self.class.secret, true, algorithm: 'HS256').first
    case payload['kind']
    when 'admin'
      @current_admin = User.find_by(id: payload['id'])
      return render_error('Account not found or disabled', :unauthorized) unless active_admin?(@current_admin)
    when 'delivery_person'
      @current_delivery_person = DeliveryPerson.find_by(id: payload['id'])
      return render_error('Account not found or disabled', :unauthorized) unless @current_delivery_person&.status
    else
      render_error('Invalid token', :unauthorized)
    end
  rescue JWT::ExpiredSignature
    render_error('Token expired, please log in again', :unauthorized)
  rescue JWT::DecodeError
    render_error('Invalid token', :unauthorized)
  end

  def active_admin?(user)
    user && user.user_type == 'admin' && user.status != false && user.deleted_at.nil?
  end

  def require_admin!
    render_error('Admin access only', :forbidden) unless current_admin
  end

  def require_delivery_person!
    render_error('Delivery person access only', :forbidden) unless current_delivery_person
  end

  def render_success(data = {}, message: nil, status: :ok, meta: nil)
    body = { success: true }
    body[:message] = message if message
    body[:data] = data
    body[:meta] = meta if meta
    render json: body, status: status
  end

  def render_error(message, status = :bad_request, errors = nil)
    body = { success: false, message: message }
    body[:errors] = errors if errors.present?
    render json: body, status: status
  end

  def page
    [params[:page].to_i, 1].max
  end

  def per_page
    n = params[:per_page].to_i
    n.positive? ? [n, 100].min : 20
  end

  def paginate(scope)
    rows = scope.page(page).per(per_page)
    [rows, { page: rows.current_page, per_page: per_page, total_pages: rows.total_pages, total_count: rows.total_count }]
  end

  def base_url
    request.base_url
  end
end

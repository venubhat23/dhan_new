class StoreAdmin::ApplicationController < ApplicationController
  protect_from_forgery with: :exception
  skip_load_and_authorize_resource if respond_to?(:skip_load_and_authorize_resource)
  before_action :authenticate_user!
  before_action :ensure_store_admin_access
  before_action :set_current_store
  layout 'store_admin'

  protected

  def ensure_store_admin_access
    unless current_user&.store_admin? || current_user&.super_admin?
      redirect_to root_path, alert: 'Access denied. Store admin privileges required.'
    end
  end

  def set_current_store
    @current_store = current_user.primary_store
    unless @current_store
      redirect_to root_path, alert: 'No store assigned. Please contact administrator.'
    end
  end

  def store_admin_sidebar_permissions
    return @store_admin_permissions if defined?(@store_admin_permissions)
    @store_admin_permissions = {
      'dashboard' => true,
      'bookings' => current_user.can_create_bookings?,
      'expenses' => true
    }
  end

  helper_method :store_admin_sidebar_permissions
end

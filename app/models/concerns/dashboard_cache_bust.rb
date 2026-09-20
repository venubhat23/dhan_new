# Include in any model whose rows feed the admin dashboard figures. Any committed
# change drops the cached dashboard (see DashboardController#load_ecommerce_dashboard_data),
# so a new booking/customer/etc. shows up on the very next dashboard load instead of
# after the cache TTL. Bulk writes that skip callbacks (update_all / insert_all) are
# covered by the short TTL.
module DashboardCacheBust
  extend ActiveSupport::Concern

  included do
    after_commit :bust_dashboard_cache
  end

  private

  def bust_dashboard_cache
    FastCache.bust_dashboard!
  end
end

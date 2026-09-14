# Process-local memory cache for tiny, read-heavy, rarely-changing values
# (sidebar badge counts, a handful of SystemSetting lookups) that are read on
# nearly every admin page load.
#
# Rails.cache is solid_cache here, which stores entries in the same remote
# Render Postgres as every other table (see config/database.yml — the
# `cache` database uses the same DATABASE_URL as `primary`). On this host
# each round trip costs ~250-300ms, so a "cached" read via Rails.cache is
# just as slow as the query it's meant to avoid. FastCache keeps these few
# hot values in this process's memory instead, at the cost of each Puma
# worker holding its own (short-lived) copy — acceptable for values that
# were already tolerating a multi-minute TTL.
module FastCache
  STORE = ActiveSupport::Cache::MemoryStore.new(size: 4.megabytes)

  def self.fetch(key, expires_in:, &block)
    STORE.fetch(key, expires_in: expires_in, &block)
  end
end

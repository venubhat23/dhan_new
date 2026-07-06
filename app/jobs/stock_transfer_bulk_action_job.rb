class StockTransferBulkActionJob < ApplicationJob
  queue_as :default

  CACHE_EXPIRY = 30.minutes

  # Runs approve!/reject! for every still-pending transfer in the given
  # groups. Pulled out of the controller because looping over hundreds of
  # transfers inline blocks the request until it hits Render's timeout,
  # which shows up to the admin as the bulk action "hanging". Progress is
  # written to the cache under `token` so the admin UI can poll it and show
  # a percentage while this runs.
  def perform(group_ids, action, actor_id, rejection_reason = nil, token = nil)
    actor = User.find(actor_id)
    scope = StockTransfer.pending.where(transfer_group_id: Array(group_ids))
    total = scope.count
    processed = 0
    failures = []

    write_progress(token, total: total, processed: processed, done: false, failed: 0) if token

    scope.find_each do |transfer|
      case action.to_s
      when 'approve'
        transfer.approve!(actor)
      when 'reject'
        transfer.reject!(actor, rejection_reason)
      end
    rescue => e
      failures << "#{transfer.id} (#{transfer.product&.name}): #{e.message}"
    ensure
      processed += 1
      write_progress(token, total: total, processed: processed, done: false, failed: failures.size) if token
    end

    write_progress(token, total: total, processed: processed, done: true, failed: failures.size) if token
    Rails.logger.error("StockTransferBulkActionJob failures: #{failures.join(' | ')}") if failures.any?
  end

  private

  def write_progress(token, total:, processed:, done:, failed:)
    Rails.cache.write("stock_transfer_bulk_progress:#{token}",
                       { total: total, processed: processed, done: done, failed: failed },
                       expires_in: CACHE_EXPIRY)
  end
end

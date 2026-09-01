# Dedupe products that share the same name.
# Keeps ONE product per name (the one with the most child records; tie -> lowest id),
# repoints every child row to the keeper, then destroys the losers.
#
# In rails console:
#   load 'scripts/dedupe_products.rb'
#   DeleteDuplicates.preview   # show what would happen, changes nothing
#   DeleteDuplicates.run!      # actually apply

module DeleteDuplicates
  CHILD_MODELS = %w[
    BookingItem OrderItem InvoiceItem VendorPurchaseItem StockBatch StockMovement
    SaleItem ProductVariant ProductReview ProductRating DeliveryRule Wishlist
    MilkSubscription SubscriptionTemplate MilkDeliveryTask StockTransfer
    BookingSchedule CustomerFormat
  ].filter_map { |n| n.safe_constantize }

  module_function

  def refs(product)
    CHILD_MODELS.sum { |m| m.where(product_id: product.id).count }
  end

  def preview = execute(apply: false)
  def run!    = execute(apply: true)

  def execute(apply:)
    names = Product.group(:name).having("COUNT(*) > 1").count.keys
    puts "#{names.size} duplicated names\n\n"

    ActiveRecord::Base.transaction do
      names.each do |name|
        group  = Product.where(name: name).order(:id).to_a
        keeper = group.max_by { |p| [refs(p), -p.id] }

        puts "== #{name}"
        puts "   KEEP ##{keeper.id} (cat #{keeper.category_id}, sku #{keeper.sku}, refs #{refs(keeper)})"
        (group - [keeper]).each do |loser|
          moved = CHILD_MODELS.filter_map do |m|
            c = m.where(product_id: loser.id).count
            next if c.zero?
            m.where(product_id: loser.id).update_all(product_id: keeper.id) if apply
            "#{c} #{m.name}"
          end
          puts "   DROP ##{loser.id} (cat #{loser.category_id}, sku #{loser.sku})#{moved.any? ? " -> move #{moved.join(', ')}" : ''}"
          loser.destroy! if apply
        end
        puts
      end

      unless apply
        puts "PREVIEW ONLY - nothing changed. Run DeleteDuplicates.run! to apply."
        raise ActiveRecord::Rollback
      end
      puts "DONE - duplicates removed."
    end
  end
end

puts "Loaded. Run:  DeleteDuplicates.preview   then   DeleteDuplicates.run!"

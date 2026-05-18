class Admin::StoreFinancialsController < Admin::ApplicationController
  before_action :authenticate_user!

  def vendor_tracking
    @stores = Store.all.order(:name)
    @selected_store_id = params[:store_id].presence

    batch_scope = StockBatch.where.not(store_id: nil).includes(:product, :vendor)
    batch_scope = batch_scope.where(store_id: @selected_store_id) if @selected_store_id.present?

    grouped = batch_scope.group_by(&:store_id)

    @store_vendor_data = grouped.map do |store_id, batches|
      store = Store.find_by(id: store_id)
      next unless store

      vendor_breakdown = batches.group_by(&:vendor).map do |vendor, vb|
        {
          vendor: vendor,
          batches_count: vb.size,
          items_received: vb.sum(&:quantity_purchased).to_f,
          total_cost: vb.sum { |b| b.quantity_purchased.to_f * b.purchase_price.to_f }
        }
      end.sort_by { |v| -v[:total_cost] }

      {
        store: store,
        vendor_breakdown: vendor_breakdown,
        total_procurement: batches.sum { |b| b.quantity_purchased.to_f * b.purchase_price.to_f },
        vendors_count: vendor_breakdown.size
      }
    end.compact.sort_by { |d| -d[:total_procurement] }
  end

  def commission
    @stores = Store.all.order(:name)
    @month  = params[:month].present? ? Date.parse(params[:month]) : Date.current.beginning_of_month
    period  = @month.beginning_of_month..@month.end_of_month

    @commission_data = @stores.map do |store|
      revenue = store.bookings
                     .where(created_at: period)
                     .where(status: %w[completed delivered])
                     .sum(:total_amount).to_f

      pct         = store.commission_percentage.to_f
      store_share = (revenue * pct / 100.0).round(2)
      company_share = (revenue - store_share).round(2)

      {
        store:         store,
        revenue:       revenue,
        commission_pct: pct,
        store_share:   store_share,
        company_share: company_share
      }
    end

    @total_revenue      = @commission_data.sum { |d| d[:revenue] }
    @total_store_share  = @commission_data.sum { |d| d[:store_share] }
    @total_company_share = @commission_data.sum { |d| d[:company_share] }
  end

  def gst_report
    @stores            = Store.all.order(:name)
    @selected_store_id = params[:store_id].presence
    @month             = params[:month].present? ? Date.parse(params[:month]) : Date.current.beginning_of_month
    period             = @month.beginning_of_month..@month.end_of_month

    store_scope = @selected_store_id.present? ? Store.where(id: @selected_store_id) : Store.all.order(:name)

    @gst_data = store_scope.map do |store|
      bookings    = store.bookings.where(created_at: period)
      booking_ids = bookings.pluck(:id)

      total_revenue = bookings.sum(:total_amount).to_f
      total_tax     = bookings.sum(:tax_amount).to_f

      {
        store:         store,
        total_revenue: total_revenue,
        total_tax:     total_tax,
        cgst:          (total_tax / 2.0).round(2),
        sgst:          (total_tax / 2.0).round(2),
        igst:          0.0,
        taxable_amount: (total_revenue - total_tax).round(2),
        bookings_count: bookings.count
      }
    end

    @grand_total = {
      revenue: @gst_data.sum { |d| d[:total_revenue] },
      tax:     @gst_data.sum { |d| d[:total_tax] },
      cgst:    @gst_data.sum { |d| d[:cgst] },
      sgst:    @gst_data.sum { |d| d[:sgst] }
    }
  end
end

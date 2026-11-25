class Admin::BalanceSheetController < Admin::ApplicationController
  PER_PAGE = 200

  def index
    @register = BalanceSheetRegister.new(from: params[:from], to: params[:to], type: params[:type], payment_mode: params[:payment_mode])
    rows = @register.rows
    @total_count = rows.size
    @total_pages = [(@total_count.to_f / PER_PAGE).ceil, 1].max
    @page = params[:page].to_i.clamp(1, @total_pages)
    @rows = rows.slice((@page - 1) * PER_PAGE, PER_PAGE) || []
  end
end

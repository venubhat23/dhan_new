# Accounts › Accountant › Receipts — full CRUD using the same form as Manual Journals.
class Admin::ReceiptsController < Admin::ApplicationController
  before_action :set_receipt, only: [:show, :edit, :update, :destroy, :publish, :mark_draft, :clone]
  before_action :load_form_data, only: [:new, :create, :edit, :update, :clone]

  def index
    scope = Receipt.includes(:created_by, :store, receipt_lines: :ledger_account)
    @status = %w[draft published].include?(params[:status]) ? params[:status] : 'all'
    scope = scope.where(status: @status) unless @status == 'all'
    scope = scope.where('receipts.receipt_date >= ?', params[:from]) if params[:from].present?
    scope = scope.where('receipts.receipt_date <= ?', params[:to]) if params[:to].present?
    if params[:account_id].present?
      scope = scope.where(id: ReceiptLine.where(ledger_account_id: params[:account_id]).select(:receipt_id))
    end
    if params[:search].present?
      q = "%#{params[:search].strip}%"
      scope = scope.where('receipts.notes ILIKE :q OR receipts.reference_number ILIKE :q OR CAST(receipts.receipt_number AS TEXT) = :n OR ' \
                          'receipts.id IN (SELECT receipt_id FROM receipt_lines WHERE description ILIKE :q OR contact_name ILIKE :q)',
                          q: q, n: params[:search].strip.delete('#'))
    end

    @count        = scope.count
    @total_amount = scope.sum(:total_amount).to_f
    @draft_count  = Receipt.drafts.count
    @month_total  = Receipt.published.where(receipt_date: Date.current.all_month).sum(:total_amount).to_f
    @accounts     = LedgerAccount.ordered

    @per_page = 25
    @page = [params[:page].to_i, 1].max
    @total_pages = [(@count.to_f / @per_page).ceil, 1].max
    @receipts = scope.recent.offset((@page - 1) * @per_page).limit(@per_page)
  end

  def show; end

  def new
    @receipt = Receipt.new(receipt_date: Date.current, receipt_number: Receipt.next_number, reporting_method: 'accrual_and_cash')
    2.times { |i| @receipt.receipt_lines.build(position: i) }
  end

  def clone
    source = @receipt
    @receipt = Receipt.new(source.attributes.slice('reference_number', 'notes', 'reporting_method', 'currency', 'store_id')
                                 .merge(receipt_date: Date.current, receipt_number: Receipt.next_number))
    source.receipt_lines.each do |l|
      @receipt.receipt_lines.build(l.attributes.slice('ledger_account_id', 'description', 'contact_name', 'debit', 'credit', 'position'))
    end
    render :new
  end

  def create
    @receipt = Receipt.new(receipt_params)
    @receipt.created_by = current_user
    apply_status(@receipt)
    if @receipt.save
      redirect_to admin_receipt_path(@receipt), notice: "Receipt ##{@receipt.receipt_number} #{@receipt.published? ? 'published' : 'saved as draft'}."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    @receipt.assign_attributes(receipt_params)
    apply_status(@receipt)
    if @receipt.save
      redirect_to admin_receipt_path(@receipt), notice: "Receipt ##{@receipt.receipt_number} updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @receipt.destroy!
    redirect_to admin_receipts_path, notice: "Receipt ##{@receipt.receipt_number} deleted."
  end

  def publish
    @receipt.publish!
    redirect_to admin_receipt_path(@receipt), notice: 'Receipt published.'
  end

  def mark_draft
    @receipt.mark_draft!
    redirect_to admin_receipt_path(@receipt), notice: 'Receipt moved back to draft.'
  end

  private

  def set_receipt
    @receipt = Receipt.includes(receipt_lines: :ledger_account).find(params[:id])
  end

  def load_form_data
    @account_options = LedgerAccount.grouped_options
    @stores = Store.order(:name)
    @contacts = (Vendor.order(:name).limit(500).pluck(:name) +
                 Customer.where.not(full_name: [nil, '']).order(:full_name).limit(1000).pluck(:full_name) +
                 StaffMember.order(:name).limit(300).pluck(:name)).compact.map(&:strip).uniq
  end

  def apply_status(receipt)
    if params[:commit_action] == 'publish'
      receipt.status = 'published'
      receipt.published_at ||= Time.current
    elsif params[:commit_action] == 'draft'
      receipt.status = 'draft'
      receipt.published_at = nil
    end
  end

  def receipt_params
    params.require(:receipt).permit(
      :receipt_date, :receipt_number, :reference_number, :notes, :reporting_method, :store_id,
      receipt_lines_attributes: [:id, :ledger_account_id, :description, :contact_name, :debit, :credit, :position, :_destroy]
    )
  end
end

class Admin::ManualJournalsController < Admin::ApplicationController
  before_action :set_journal, only: [:show, :edit, :update, :destroy, :publish, :mark_draft, :clone]
  before_action :load_form_data, only: [:new, :create, :edit, :update, :clone]
  before_action :protect_auto_journal, only: [:edit, :update, :destroy, :publish, :mark_draft]

  def index
    scope = ManualJournal.includes(:created_by, :store, manual_journal_lines: :ledger_account)
    @status = %w[draft published].include?(params[:status]) ? params[:status] : 'all'
    scope = scope.where(status: @status) unless @status == 'all'
    @origin = %w[manual auto].include?(params[:origin]) ? params[:origin] : 'all'
    scope = scope.manual_only if @origin == 'manual'
    scope = scope.automatic if @origin == 'auto'
    scope = scope.where(entry_kind: params[:kind]) if AutoJournal::KINDS.key?(params[:kind])
    scope = scope.where('manual_journals.journal_date >= ?', params[:from]) if params[:from].present?
    scope = scope.where('manual_journals.journal_date <= ?', params[:to]) if params[:to].present?
    if params[:account_id].present?
      scope = scope.where(id: ManualJournalLine.where(ledger_account_id: params[:account_id]).select(:manual_journal_id))
    end
    if params[:search].present?
      q = "%#{params[:search].strip}%"
      scope = scope.where('manual_journals.notes ILIKE :q OR manual_journals.reference_number ILIKE :q OR CAST(manual_journals.journal_number AS TEXT) = :n OR ' \
                          'manual_journals.id IN (SELECT manual_journal_id FROM manual_journal_lines WHERE description ILIKE :q OR contact_name ILIKE :q)',
                          q: q, n: params[:search].strip.delete('#'))
    end

    @count        = scope.count
    @total_amount = scope.sum(:total_amount).to_f
    @draft_count  = ManualJournal.drafts.count
    @auto_count   = ManualJournal.automatic.count
    month         = Date.current.beginning_of_month..Date.current.end_of_month
    @month_expense = ManualJournalLine.joins(:manual_journal, :ledger_account).merge(ManualJournal.published.manual_only)
                                      .where(manual_journals: { journal_date: month })
                                      .where(ledger_accounts: { account_type: %w[expense cost_of_goods_sold other_expense] })
                                      .sum('manual_journal_lines.debit - manual_journal_lines.credit').to_f
    @accounts = LedgerAccount.ordered

    @per_page = 25
    @page = [params[:page].to_i, 1].max
    @total_pages = [(@count.to_f / @per_page).ceil, 1].max
    @journals = scope.recent.offset((@page - 1) * @per_page).limit(@per_page)
  end

  def show; end

  def new
    @journal = ManualJournal.new(journal_date: Date.current, journal_number: ManualJournal.next_number, reporting_method: 'accrual_and_cash')
    2.times { |i| @journal.manual_journal_lines.build(position: i) }
  end

  def clone
    source = @journal
    @journal = ManualJournal.new(source.attributes.slice('reference_number', 'notes', 'reporting_method', 'currency', 'store_id')
                                       .merge(journal_date: Date.current, journal_number: ManualJournal.next_number))
    source.manual_journal_lines.each do |l|
      @journal.manual_journal_lines.build(l.attributes.slice('ledger_account_id', 'description', 'contact_name', 'debit', 'credit', 'position'))
    end
    render :new
  end

  def create
    @journal = ManualJournal.new(journal_params)
    @journal.created_by = current_user
    apply_status(@journal)
    if @journal.save
      redirect_to admin_manual_journal_path(@journal), notice: "Journal ##{@journal.journal_number} #{@journal.published? ? 'published' : 'saved as draft'}."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    @journal.assign_attributes(journal_params)
    apply_status(@journal)
    if @journal.save
      redirect_to admin_manual_journal_path(@journal), notice: "Journal ##{@journal.journal_number} updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @journal.destroy!
    redirect_to admin_manual_journals_path, notice: "Journal ##{@journal.journal_number} deleted."
  end

  def publish
    @journal.publish!
    redirect_to admin_manual_journal_path(@journal), notice: 'Journal published — it now shows in Profit & Loss.'
  end

  def mark_draft
    @journal.mark_draft!
    redirect_to admin_manual_journal_path(@journal), notice: 'Journal moved back to draft.'
  end

  private

  def set_journal
    @journal = ManualJournal.includes(manual_journal_lines: :ledger_account).find(params[:id])
  end

  # Auto journals mirror an invoice/purchase/payment; change the source document instead.
  def protect_auto_journal
    return unless @journal.automatic?

    redirect_to admin_manual_journal_path(@journal),
                alert: "This journal was posted automatically from a #{@journal.entry_kind_label.to_s.downcase}. Edit or cancel the source document and the journal updates itself."
  end

  def load_form_data
    @account_options = LedgerAccount.grouped_options
    @stores = Store.order(:name)
    @contacts = (Vendor.order(:name).limit(500).pluck(:name) +
                 Customer.where.not(full_name: [nil, '']).order(:full_name).limit(1000).pluck(:full_name) +
                 StaffMember.order(:name).limit(300).pluck(:name)).compact.map(&:strip).uniq
  end

  def apply_status(journal)
    if params[:commit_action] == 'publish'
      journal.status = 'published'
      journal.published_at ||= Time.current
    elsif params[:commit_action] == 'draft'
      journal.status = 'draft'
      journal.published_at = nil
    end
  end

  def journal_params
    params.require(:manual_journal).permit(
      :journal_date, :journal_number, :reference_number, :notes, :reporting_method, :store_id,
      manual_journal_lines_attributes: [:id, :ledger_account_id, :description, :contact_name, :debit, :credit, :position, :_destroy]
    )
  end
end

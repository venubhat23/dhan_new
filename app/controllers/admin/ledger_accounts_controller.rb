class Admin::LedgerAccountsController < Admin::ApplicationController
  before_action :set_account, only: [:show, :update, :toggle_active, :destroy]

  def index
    @accounts = LedgerAccount.ordered.to_a
    published = ManualJournalLine.joins(:manual_journal).merge(ManualJournal.published)
    sums = published.group(:ledger_account_id).pluck(:ledger_account_id, Arel.sql('SUM(debit)'), Arel.sql('SUM(credit)'), Arel.sql('COUNT(*)'))
    @stats = sums.to_h { |id, dr, cr, n| [id, { dr: dr.to_f, cr: cr.to_f, count: n }] }
    @type = params[:type].presence
    @accounts = @accounts.select { |a| a.account_type == @type } if @type && LedgerAccount::TYPE_LABELS.key?(@type)
    @accounts = @accounts.select { |a| a.name.downcase.include?(params[:search].downcase) } if params[:search].present?
    @new_account = LedgerAccount.new(account_type: 'expense')
  end

  def show
    @lines = @account.manual_journal_lines.joins(:manual_journal).includes(:manual_journal)
                     .order('manual_journals.journal_date DESC, manual_journals.journal_number DESC')
    @balance = @account.balance
  end

  def create
    @account = LedgerAccount.new(account_params)
    if @account.save
      redirect_to admin_ledger_accounts_path(type: params[:return_type].presence), notice: "Account \"#{@account.name}\" created."
    else
      redirect_to admin_ledger_accounts_path, alert: @account.errors.full_messages.to_sentence
    end
  end

  def update
    if @account.update(account_params)
      redirect_back fallback_location: admin_ledger_accounts_path, notice: "Account \"#{@account.name}\" updated."
    else
      redirect_back fallback_location: admin_ledger_accounts_path, alert: @account.errors.full_messages.to_sentence
    end
  end

  def toggle_active
    @account.update!(active: !@account.active)
    redirect_back fallback_location: admin_ledger_accounts_path, notice: "Account #{@account.active ? 'activated' : 'deactivated'}."
  end

  def destroy
    if @account.destroy
      redirect_to admin_ledger_accounts_path, notice: 'Account deleted.'
    else
      redirect_to admin_ledger_accounts_path, alert: 'This account has journal entries — deactivate it instead.'
    end
  end

  private

  def set_account
    @account = LedgerAccount.find(params[:id])
  end

  def account_params
    params.require(:ledger_account).permit(:name, :account_type, :code, :description)
  end
end

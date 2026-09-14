class Admin::CustomerWalletsController < Admin::ApplicationController
  include ConfigurablePagination
  before_action :set_customer_wallet, only: [:show, :edit, :update, :destroy, :add_money, :deduct_money, :transaction_history]

  def index
    @customer_wallets = CustomerWallet.joins(:customer).includes(:customer)
    @customer_wallets = @customer_wallets.where("customers.full_name ILIKE ? OR customers.email ILIKE ?",
                                               "%#{params[:search]}%", "%#{params[:search]}%") if params[:search].present?
    @customer_wallets = paginate_records(@customer_wallets.order('customers.full_name'))

    # Batch the "last transaction" column instead of one .recent.first query
    # per wallet row (see CustomerWallet#last_transaction).
    wallet_ids = @customer_wallets.map(&:id)
    latest_by_wallet = WalletTransaction.where(customer_wallet_id: wallet_ids)
                                        .order(:customer_wallet_id, created_at: :desc)
                                        .select('DISTINCT ON (customer_wallet_id) *')
                                        .index_by(&:customer_wallet_id)
    @customer_wallets.each { |w| w.last_transaction = latest_by_wallet[w.id] }

    @stats = {
      total_wallets: CustomerWallet.count,
      active_wallets: CustomerWallet.where(status: true).count,
      total_balance: CustomerWallet.sum(:balance),
      avg_balance: CustomerWallet.average(:balance) || 0
    }
  end

  def show
    @transactions = @customer_wallet.wallet_transactions.recent.limit(10)
  end

  def new
    @customer_wallet = CustomerWallet.new
    @customers = Customer.where.not(id: CustomerWallet.select(:customer_id)).order(:full_name)
  end

  def create
    @customer_wallet = CustomerWallet.new(customer_wallet_params)

    if @customer_wallet.save
      redirect_to admin_customer_wallet_path(@customer_wallet), notice: 'Customer wallet was successfully created.'
    else
      @customers = Customer.where.not(id: CustomerWallet.select(:customer_id)).order(:full_name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @customer_wallet.update(customer_wallet_params)
      redirect_to admin_customer_wallet_path(@customer_wallet), notice: 'Customer wallet was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @customer_wallet.destroy
    redirect_to admin_customer_wallets_path, notice: 'Customer wallet was successfully deleted.'
  end

  def add_money
    amount = params[:amount].to_f
    description = params[:description]

    if amount > 0 && @customer_wallet.add_money(amount, description)
      redirect_to admin_customer_wallet_path(@customer_wallet), notice: "₹#{amount} added to wallet successfully."
    else
      redirect_to admin_customer_wallet_path(@customer_wallet), alert: 'Failed to add money to wallet.'
    end
  end

  def deduct_money
    amount = params[:amount].to_f
    description = params[:description]

    if amount > 0 && @customer_wallet.deduct_money(amount, description)
      redirect_to admin_customer_wallet_path(@customer_wallet), notice: "₹#{amount} deducted from wallet successfully."
    else
      redirect_to admin_customer_wallet_path(@customer_wallet), alert: 'Failed to deduct money from wallet. Insufficient balance.'
    end
  end

  def transaction_history
    @transactions = @customer_wallet.wallet_transactions.recent
    @transactions = paginate_records(@transactions)
  end

  private

  def set_customer_wallet
    @customer_wallet = CustomerWallet.find(params[:id])
  end

  def customer_wallet_params
    params.require(:customer_wallet).permit(:customer_id, :balance, :status, :notes)
  end
end

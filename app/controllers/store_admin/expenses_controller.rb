class StoreAdmin::ExpensesController < StoreAdmin::ApplicationController
  before_action :set_expense, only: [:show, :edit, :update, :destroy]

  def index
    @expenses = @current_store.expenses.order(expense_date: :desc, created_at: :desc)

    if params[:start_date].present? && params[:end_date].present?
      @expenses = @expenses.where(expense_date: params[:start_date]..params[:end_date])
    end

    if params[:category].present?
      @expenses = @expenses.where(category: params[:category])
    end

    @expenses = @expenses.page(params[:page]).per(20) if @expenses.respond_to?(:page)

    @total_expenses = @current_store.expenses.sum(:amount)
    @monthly_expenses = @current_store.expenses
                                      .where(expense_date: Date.current.beginning_of_month..Date.current.end_of_month)
                                      .sum(:amount)
    @category_breakdown = @current_store.expenses
                                        .where(expense_date: Date.current.beginning_of_month..Date.current.end_of_month)
                                        .group(:category).sum(:amount)
  end

  def show
  end

  def new
    @expense = @current_store.expenses.build
    @expense.expense_date = Date.current
  end

  def create
    @expense = @current_store.expenses.build(expense_params)
    @expense.created_by = current_user

    if @expense.save
      redirect_to store_admin_expenses_path, notice: 'Expense recorded successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @expense.update(expense_params)
      redirect_to store_admin_expense_path(@expense), notice: 'Expense updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @expense.destroy
    redirect_to store_admin_expenses_path, notice: 'Expense deleted successfully.'
  end

  private

  def set_expense
    @expense = @current_store.expenses.find(params[:id])
  end

  def expense_params
    params.require(:expense).permit(:title, :description, :amount, :category, :expense_date)
  end
end

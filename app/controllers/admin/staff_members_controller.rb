class Admin::StaffMembersController < Admin::ApplicationController
  before_action :set_staff_member, only: [:show, :edit, :update, :toggle_status]

  def index
    scope = StaffMember.includes(:store).order(:name)
    scope = scope.where(store_id: params[:store_id]) if params[:store_id].present?
    @staff_members = scope

    @stores         = Store.order(:name)
    @total_count    = @staff_members.count
    @active_count   = @staff_members.select(&:active?).count
    @inactive_count = @total_count - @active_count

    today = Date.current
    @total_pending = @staff_members.select(&:active?).sum { |s| s.pending_for(today.month, today.year) }
  end

  def show
    @month = (params[:month] || Date.current.month).to_i
    @year  = (params[:year] || Date.current.year).to_i

    @attendances = @staff_member.staff_attendances
                                .where(attendance_date: Date.new(@year, @month, 1)..Date.new(@year, @month, -1))
                                .order(attendance_date: :desc)
    @payments = @staff_member.staff_payments
                             .where(month: @month, year: @year)
                             .order(payment_date: :desc)

    @attendance_summary = @staff_member.attendance_summary_for(@month, @year)
    @paid    = @staff_member.paid_for(@month, @year)
    @pending = @staff_member.pending_for(@month, @year)
  end

  def new
    @staff_member = StaffMember.new(joining_date: Date.current)
    @stores = Store.active.order(:name)
  end

  def create
    @staff_member = StaffMember.new(staff_member_params)

    if @staff_member.save
      redirect_to admin_staff_member_path(@staff_member), notice: 'Staff member added successfully.'
    else
      @stores = Store.active.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @stores = Store.active.order(:name)
  end

  def update
    if @staff_member.update(staff_member_params)
      redirect_to admin_staff_member_path(@staff_member), notice: 'Staff member updated successfully.'
    else
      @stores = Store.active.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def toggle_status
    @staff_member.update(status: @staff_member.active? ? 'inactive' : 'active')
    redirect_to admin_staff_members_path, notice: "#{@staff_member.name} has been #{@staff_member.active? ? 'enabled' : 'disabled'}."
  end

  private

  def set_staff_member
    @staff_member = StaffMember.find(params[:id])
  end

  def staff_member_params
    params.require(:staff_member).permit(:store_id, :name, :mobile, :email, :designation, :monthly_salary, :joining_date, :notes)
  end
end

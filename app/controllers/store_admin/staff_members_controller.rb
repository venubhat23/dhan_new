class StoreAdmin::StaffMembersController < StoreAdmin::ApplicationController
  before_action :set_staff_member, only: [:show, :edit, :update, :toggle_status]

  def index
    @staff_members  = @current_store.staff_members.order(:name)
    @total_count    = @staff_members.count
    @active_count   = @staff_members.active.count
    @inactive_count = @staff_members.inactive.count

    today = Date.current
    @total_pending = @staff_members.active.sum { |s| s.pending_for(today.month, today.year) }
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
    @staff_member = @current_store.staff_members.build(joining_date: Date.current)
  end

  def create
    @staff_member = @current_store.staff_members.build(staff_member_params)

    if @staff_member.save
      redirect_to store_admin_staff_member_path(@staff_member), notice: 'Staff member added successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @staff_member.update(staff_member_params)
      redirect_to store_admin_staff_member_path(@staff_member), notice: 'Staff member updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def toggle_status
    @staff_member.update(status: @staff_member.active? ? 'inactive' : 'active')
    redirect_to store_admin_staff_members_path, notice: "#{@staff_member.name} has been #{@staff_member.active? ? 'enabled' : 'disabled'}."
  end

  private

  def set_staff_member
    @staff_member = @current_store.staff_members.find(params[:id])
  end

  def staff_member_params
    params.require(:staff_member).permit(:name, :mobile, :email, :designation, :monthly_salary, :joining_date, :notes)
  end
end

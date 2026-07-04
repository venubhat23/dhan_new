class Admin::StaffAttendancesController < Admin::ApplicationController
  def create
    staff_member = StaffMember.find(attendance_params[:staff_member_id])
    attendance = staff_member.staff_attendances.find_or_initialize_by(attendance_date: attendance_params[:attendance_date])
    attendance.status = attendance_params[:status]
    attendance.notes  = attendance_params[:notes]

    if attendance.save
      redirect_to admin_staff_member_path(staff_member, month: params[:month], year: params[:year]), notice: 'Attendance recorded.'
    else
      redirect_to admin_staff_member_path(staff_member), alert: attendance.errors.full_messages.join(', ')
    end
  end

  def bulk_create
    staff_member = StaffMember.find(attendance_params[:staff_member_id])
    status = attendance_params[:status].presence || 'present'
    dates = Array(params[:dates]).reject(&:blank?)

    marked = 0
    dates.each do |date_str|
      date = Date.parse(date_str) rescue next
      attendance = staff_member.staff_attendances.find_or_initialize_by(attendance_date: date)
      attendance.status = status
      marked += 1 if attendance.save
    end

    redirect_to admin_staff_member_path(staff_member, month: params[:month], year: params[:year]),
                notice: "Marked #{marked} day(s) as #{status.humanize}."
  end

  def destroy
    staff_member = StaffMember.find(params[:staff_member_id])
    staff_member.staff_attendances.find(params[:id]).destroy
    redirect_to admin_staff_member_path(staff_member), notice: 'Attendance record removed.'
  end

  private

  def attendance_params
    params.require(:staff_attendance).permit(:staff_member_id, :attendance_date, :status, :notes)
  end
end

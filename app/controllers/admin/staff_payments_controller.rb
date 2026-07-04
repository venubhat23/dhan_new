class Admin::StaffPaymentsController < Admin::ApplicationController
  def create
    staff_member = StaffMember.find(payment_params[:staff_member_id])
    payment = staff_member.staff_payments.build(payment_params.except(:staff_member_id))

    if payment.save
      redirect_to admin_staff_member_path(staff_member, month: payment.month, year: payment.year), notice: 'Payment recorded.'
    else
      redirect_to admin_staff_member_path(staff_member), alert: payment.errors.full_messages.join(', ')
    end
  end

  def destroy
    staff_member = StaffMember.find(params[:staff_member_id])
    staff_member.staff_payments.find(params[:id]).destroy
    redirect_to admin_staff_member_path(staff_member), notice: 'Payment record removed.'
  end

  private

  def payment_params
    params.require(:staff_payment).permit(:staff_member_id, :amount, :payment_date, :month, :year, :notes)
  end
end

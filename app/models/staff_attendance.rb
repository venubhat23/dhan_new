class StaffAttendance < ApplicationRecord
  belongs_to :staff_member

  STATUSES = %w[present absent half_day leave].freeze

  validates :attendance_date, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :attendance_date, uniqueness: { scope: :staff_member_id, message: 'already has an attendance record for this date' }
end

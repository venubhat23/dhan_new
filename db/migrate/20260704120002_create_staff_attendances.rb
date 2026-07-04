class CreateStaffAttendances < ActiveRecord::Migration[7.1]
  def change
    create_table :staff_attendances do |t|
      t.references :staff_member, null: false, foreign_key: true
      t.date :attendance_date, null: false
      t.string :status, null: false, default: 'present'
      t.text :notes

      t.timestamps
    end

    add_index :staff_attendances, [:staff_member_id, :attendance_date], unique: true, name: 'index_staff_attendances_on_member_and_date'
  end
end

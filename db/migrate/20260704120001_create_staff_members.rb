class CreateStaffMembers < ActiveRecord::Migration[7.1]
  def change
    create_table :staff_members do |t|
      t.references :store, null: false, foreign_key: true
      t.string :name, null: false
      t.string :mobile
      t.string :email
      t.string :designation
      t.decimal :monthly_salary, precision: 10, scale: 2, null: false, default: 0
      t.date :joining_date
      t.string :status, null: false, default: 'active'
      t.text :notes

      t.timestamps
    end

    add_index :staff_members, :status
  end
end

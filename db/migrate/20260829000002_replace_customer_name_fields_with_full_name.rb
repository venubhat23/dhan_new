class ReplaceCustomerNameFieldsWithFullName < ActiveRecord::Migration[8.0]
  def up
    add_column :customers, :full_name, :string

    execute <<~SQL
      UPDATE customers
      SET full_name = NULLIF(TRIM(REGEXP_REPLACE(CONCAT_WS(' ', first_name, middle_name, last_name), '\\s+', ' ', 'g')), '')
    SQL

    remove_column :customers, :first_name
    remove_column :customers, :middle_name
    remove_column :customers, :last_name
  end

  def down
    add_column :customers, :first_name, :string
    add_column :customers, :middle_name, :string
    add_column :customers, :last_name, :string

    execute <<~SQL
      UPDATE customers SET first_name = full_name
    SQL

    remove_column :customers, :full_name
  end
end

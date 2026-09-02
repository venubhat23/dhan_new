class SetupRolePermissions < ActiveRecord::Migration[8.0]
  # The Roles & Permissions module (models/controllers/views) was carried over
  # from the earlier admin app, but its schema was never fully migrated here:
  #   * `permissions` was created with `resource` / `action` columns, while the
  #     Permission model expects `module_name` / `action_type`.
  #   * the `role_permissions` join table was never created at all, so
  #     `Role.includes(:permissions)` blows up with PG::UndefinedTable.
  # This migration brings the schema in line with the code.
  def up
    # --- align the permissions table with the Permission model ---------------
    rename_column :permissions, :resource, :module_name if column_exists?(:permissions, :resource) && !column_exists?(:permissions, :module_name)
    rename_column :permissions, :action, :action_type   if column_exists?(:permissions, :action)   && !column_exists?(:permissions, :action_type)

    add_column :permissions, :module_name, :string unless column_exists?(:permissions, :module_name)
    add_column :permissions, :action_type, :string unless column_exists?(:permissions, :action_type)

    unless index_exists?(:permissions, [:module_name, :action_type])
      add_index :permissions, [:module_name, :action_type], name: "index_permissions_on_module_name_and_action_type"
    end

    # --- role_permissions join table --------------------------------------
    unless table_exists?(:role_permissions)
      create_table :role_permissions do |t|
        t.references :role,       null: false, foreign_key: true
        t.references :permission, null: false, foreign_key: true

        t.timestamps
      end

      add_index :role_permissions, [:role_id, :permission_id],
                unique: true, name: "index_role_permissions_on_role_id_and_permission_id"
    end
  end

  def down
    drop_table :role_permissions if table_exists?(:role_permissions)

    if index_exists?(:permissions, [:module_name, :action_type], name: "index_permissions_on_module_name_and_action_type")
      remove_index :permissions, name: "index_permissions_on_module_name_and_action_type"
    end
    rename_column :permissions, :module_name, :resource  if column_exists?(:permissions, :module_name)
    rename_column :permissions, :action_type, :action    if column_exists?(:permissions, :action_type)
  end
end

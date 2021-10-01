class CreateObjectRolePermissions< ActiveRecord::Migration[4.2]
  def change
    create_table :object_role_permissions do |t|
      t.references :ref_obj, polymorphic: { limit: UTF8MB4_VARCHAR_LIMIT }
      t.belongs_to :role
      t.belongs_to :object_permission

      t.timestamps null: false
    end
    add_index :object_role_permissions, [:ref_obj_id, :ref_obj_type], name: "index_object_role_permissions_on_ref_obj"
    add_index :object_role_permissions, :role_id
    add_index :object_role_permissions, :object_permission_id
  end
end

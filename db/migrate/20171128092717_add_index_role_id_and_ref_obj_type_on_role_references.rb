class AddIndexRoleIdAndRefObjTypeOnRoleReferences< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table :role_references do |t|
        t.add_index [:role_id, :ref_obj_type]
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table :role_references do |t|
        t.remove_index [:role_id, :ref_obj_type]
      end
    end
  end
end

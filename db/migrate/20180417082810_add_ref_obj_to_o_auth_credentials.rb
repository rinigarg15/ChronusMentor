class AddRefObjToOAuthCredentials < ActiveRecord::Migration[4.2]
  def add_new_columns_index
    ChronusMigrate.ddl_migration do
      Lhm.change_table :o_auth_credentials do |cm|
        cm.rename_column :member_id, :ref_obj_id
        cm.add_column :ref_obj_type, "varchar(#{UTF8MB4_VARCHAR_LIMIT})"
        cm.add_index :ref_obj_type, :ref_obj_id
      end
    end
  end

  def do_data_migrations
    ChronusMigrate.data_migration do
      ActiveRecord::Base.transaction do
        OAuthCredential.update_all(ref_obj_type: "Member")
      end
    end
  end

  def up
    add_new_columns_index
    do_data_migrations
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table :o_auth_credentials do |cm|
        cm.remove_index :ref_obj_type, :ref_obj_id
        cm.remove_column :ref_obj_type
        cm.rename_column :ref_obj_id, :member_id
      end
    end
  end
end

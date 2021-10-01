class RemoveSecureInviteLinkEnabledFromSecuritySettings< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table SecuritySetting.table_name do |t|
        t.remove_column :secure_invite_link_enabled
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table SecuritySetting.table_name do |t|
        t.add_column :secure_invite_link_enabled, "tinyint(1) DEFAULT '1'"
      end
    end
  end
end

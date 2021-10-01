class RenameLastAppliedTaskFilterUserInfoOfConnectionMemberships< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table :connection_memberships do |cm|
        cm.rename_column :last_applied_task_filter_user_info, :last_applied_task_filter
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table :connection_memberships do |cm|
        cm.rename_column :last_applied_task_filter, :last_applied_task_filter_user_info
      end
    end
  end
end

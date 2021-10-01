class AddAllowJoinToGroupMembershipSetting< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table Group::MembershipSetting.table_name do |t|
        t.add_column :allow_join, "tinyint(1)"
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table Group::MembershipSetting.table_name do |t|
        t.remove_column :allow_join
      end
    end
  end
end

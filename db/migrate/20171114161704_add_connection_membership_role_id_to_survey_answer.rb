class AddConnectionMembershipRoleIdToSurveyAnswer< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table SurveyAnswer.table_name do |table|
        table.add_column :connection_membership_role_id, "int(11) DEFAULT NULL"
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table SurveyAnswer.table_name do |table|
      table.remove_column :connection_membership_role_id
      end
    end
  end
end

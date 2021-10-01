class AddApiTokenToMemberMeeting< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table :member_meetings do |m|
        m.add_column :api_token, "varchar(255)"
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table :member_meetings do |m|
        m.remove_column :api_token
      end
    end
  end
end

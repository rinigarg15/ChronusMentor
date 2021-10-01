class AddLinkedinAccessTokenToMembers< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table Member.table_name do |t|
        t.add_column :linkedin_access_token, "text"
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table Member.table_name do |t|
        t.remove_column :linkedin_access_token
      end
    end
  end
end
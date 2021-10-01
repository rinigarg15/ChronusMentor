class ChangeIndexUserSearchActivity < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table UserSearchActivity.table_name do |t|
        t.change_column :session_id, "varchar(#{UTF8MB4_VARCHAR_LIMIT})"
      end
    end
  end

  def down
  end
end

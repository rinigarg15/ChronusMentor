class RemoveLinkedinUrlFromMembers< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table Member.table_name do |t|
        t.remove_column :linkedin_url
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table Member.table_name do |t|
        t.add_column :linkedin_url, :string
      end
    end
  end
end

class AddLastVisitedTabToConnectionMemberships< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table Connection::Membership.table_name do |t|
        t.add_column :last_visited_tab, "varchar(191)"
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table Connection::Membership.table_name do |t|
        t.remove_column :last_visited_tab
      end
    end
  end
end
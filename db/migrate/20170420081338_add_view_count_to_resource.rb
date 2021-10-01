class AddViewCountToResource< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table :resources do |r|
        r.add_column :view_count, "int(11) DEFAULT 0"
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table :resources do |r|
        r.remove_column :view_count
      end
    end
  end
end

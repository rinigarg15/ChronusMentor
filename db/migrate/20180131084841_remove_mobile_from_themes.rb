class RemoveMobileFromThemes < ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      Theme.where(mobile: true).destroy_all
    end

    ChronusMigrate.ddl_migration do
      Lhm.change_table "themes" do |t|
        t.remove_column :mobile
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table "themes" do |t|
        t.add_column :mobile, "TINYINT(1) DEFAULT 0"
      end
    end
  end
end
class RemoveActiveMobileThemeFromPrograms < ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table "programs" do |t|
        t.remove_column :active_mobile_theme
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table "programs" do |t|
        t.add_column :active_mobile_theme, "INT(11)"
      end
    end
  end
end
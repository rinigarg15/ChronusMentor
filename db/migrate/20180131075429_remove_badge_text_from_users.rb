class RemoveBadgeTextFromUsers < ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table "users" do |t|
        t.remove_column :badge_text
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table "users" do |t|
        t.add_column :badge_text, "VARCHAR(255)"
      end
    end
  end
end
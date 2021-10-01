class RemoveColumnAllowLegalLinks < ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table "programs" do |t|
        t.remove_column :allow_legal_links
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table "programs" do |t|
        t.add_column :allow_legal_links, "TINYINT(1) DEFAULT 1"
      end
    end
  end
end

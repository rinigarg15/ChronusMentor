class AddDetailsToProgressStatus < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table :progress_statuses do |t|
        t.add_column :details, "text"
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table :progress_statuses do |t|
        t.remove_column :details
      end
    end
  end
end
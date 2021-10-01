class AddIndexToDelayedJob< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table :delayed_jobs do |t|
        t.add_index :queue
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table :delayed_jobs do |t|
        t.remove_index :queue
      end
    end
  end
end

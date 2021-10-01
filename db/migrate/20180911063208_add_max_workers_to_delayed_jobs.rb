class AddMaxWorkersToDelayedJobs < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.ddl_migration do
      unless column_exists?(:delayed_jobs, :max_workers)
        Lhm.change_table :delayed_jobs do |r|
          r.add_column :max_workers, "int(11)"
          r.add_index [:locked_at, :failed_at, :max_workers]
        end
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table :delayed_jobs do |r|
        r.remove_index [:locked_at, :failed_at, :max_workers]
        r.remove_column :max_workers
      end
    end
  end
end

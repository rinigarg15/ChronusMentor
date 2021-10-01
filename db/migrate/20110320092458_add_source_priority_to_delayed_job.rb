class AddSourcePriorityToDelayedJob < ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      unless column_exists?(:delayed_jobs, :source_priority)
        Lhm.change_table :delayed_jobs do |r|
          r.add_column :source_priority, "int(11)"
          r.add_column :organization_id, "int(11)"
        end
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table :delayed_jobs do |r|
        r.remove_column :source_priority
        r.remove_column :organization_id
      end
    end
  end
end

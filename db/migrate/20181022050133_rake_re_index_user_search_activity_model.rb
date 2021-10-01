class RakeReIndexUserSearchActivityModel < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      DeploymentRakeRunner.add_rake_task("es_indexes:full_indexing MODELS='UserSearchActivity'")
    end
  end

  def down
    # Do nothing
  end
end

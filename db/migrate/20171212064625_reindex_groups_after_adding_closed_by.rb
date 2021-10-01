class ReindexGroupsAfterAddingClosedBy< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      DeploymentRakeRunner.add_rake_task("es_indexes:full_indexing MODELS='Group'")
    end
  end

  def down
    #Do nothing
  end
end

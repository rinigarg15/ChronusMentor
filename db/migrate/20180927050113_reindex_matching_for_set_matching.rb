class ReindexMatchingForSetMatching < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      DeploymentRakeRunner.add_rake_task("single_time:reindex_matching_for_set_matching")
    end
  end

  def down
    # Do nothing
  end
end

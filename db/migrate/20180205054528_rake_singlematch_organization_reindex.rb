class RakeSinglematchOrganizationReindex< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      DeploymentRakeRunner.add_rake_task("matching:full_index_and_refresh")
    end
  end

  def down
    # Do nothing
  end
end

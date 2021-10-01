class CleanUpOrganizationProgramsCount < ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      DeploymentRakeRunner.add_rake_task("common:organization_manager:set_programs_count")
    end
  end

  def down
    #Do nothing
  end
end
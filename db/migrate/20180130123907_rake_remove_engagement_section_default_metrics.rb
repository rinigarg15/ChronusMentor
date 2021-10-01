class RakeRemoveEngagementSectionDefaultMetrics  < ActiveRecord::Migration[4.2]

  def up
    ChronusMigrate.data_migration(:has_downtime => false) do
      DeploymentRakeRunner.add_rake_task("single_time:remove_engagement_section_default_metrics")
    end
  end

  def down
    #nothing
  end
end

class CreateMissingDefaultReportSectionsRake< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.production? || Rails.env.productioneu? || Rails.env.veteransadmin? || Rails.env.demo? || Rails.env.nch?
        DeploymentRakeRunner.add_rake_task("single_time:create_missing_default_report_sections")
      end
    end
  end

  def down
    #Do Nothing
  end
end

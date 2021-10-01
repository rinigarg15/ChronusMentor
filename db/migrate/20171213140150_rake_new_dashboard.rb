class RakeNewDashboard< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.production? || Rails.env.productioneu? || Rails.env.veteransadmin? || Rails.env.demo? || Rails.env.nch?
        DeploymentRakeRunner.add_rake_task("single_time:create_abstract_views_for_new_dashboard")
        DeploymentRakeRunner.add_rake_task("single_time:move_metrics_from_other_section") unless (Rails.env.demo? || Rails.env.nch?)
      end
    end
  end

  def down
    #Do Nothing
  end
end

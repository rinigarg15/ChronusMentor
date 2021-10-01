class UpdateClosureReasonRake< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.production?
        DeploymentRakeRunner.add_rake_task('single_time:update_closure_reason')
      end
    end
  end

  def down
  end
end

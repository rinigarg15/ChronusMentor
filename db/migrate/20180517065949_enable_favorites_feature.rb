class EnableFavoritesFeature < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      DeploymentRakeRunner.add_rake_task("single_time:enable_favorites_feature")
    end
  end

  def down
  end
end

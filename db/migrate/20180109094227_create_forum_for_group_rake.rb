class CreateForumForGroupRake  < ActiveRecord::Migration[4.2]

  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      DeploymentRakeRunner.add_rake_task('single_time:find_or_create_group_forum')
    end
  end

  def down
  end
end

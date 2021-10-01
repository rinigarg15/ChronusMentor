class RolesAsDefaultSurveyResponseColumn< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      DeploymentRakeRunner.add_rake_task("single_time:update_connection_membership_role_id_in_survey_answers")
      DeploymentRakeRunner.add_rake_task("single_time:add_user_roles_survey_column")
    end
  end

  def down
    # Do nothing
  end
end

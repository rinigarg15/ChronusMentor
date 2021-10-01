class RakeUpdateMeetingMentoringRequestsMailerTemplates < ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(:has_downtime => false) do
      DeploymentRakeRunner.add_rake_task("single_time:update_meeting_mentoring_requests_mailer_templates")
    end
  end

  def down
    #nothing
  end
end

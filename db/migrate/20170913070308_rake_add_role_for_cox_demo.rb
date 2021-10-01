class RakeAddRoleForCoxDemo< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.demo?
        DeploymentRakeRunner.add_rake_task("common:teacher_role_manager:add DOMAIN='chronus.com' SUBDOMAIN='cox.demo' ROOTS='project-mentoring,career-mentoring-program'")
      end
    end
  end

  def down
    # Do nothing
  end
end

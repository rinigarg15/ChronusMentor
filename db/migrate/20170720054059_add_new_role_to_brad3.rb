class AddNewRoleToBrad3< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.demo?
        role = RoleConstants::TEACHER_NAME
        DeploymentRakeRunner.add_rake_task("common:role_manager:add DOMAIN='chronus.com' SUBDOMAIN='brad3.demo' ROOTS='career-mentoring-program' ROLE_NAME='#{role}' FOR_MENTORING='true'")
      end
    end
  end

  def down
    # Do nothing
  end
end

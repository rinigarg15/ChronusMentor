class RakeRoleManager< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.productioneu?
        role = RoleConstants::TEACHER_NAME
        DeploymentRakeRunner.add_rake_task("common:role_manager:add DOMAIN='edu.au' SUBDOMAIN='mentoring.app.uq' ROOTS='p2' ROLE_NAME='#{role}' FOR_MENTORING='true'")
      end
    end
  end

  def down
    # Do nothing
  end
end

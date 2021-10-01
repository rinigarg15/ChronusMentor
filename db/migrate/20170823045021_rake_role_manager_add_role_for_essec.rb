class RakeRoleManagerAddRoleForEssec< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.production?
        DeploymentRakeRunner.add_rake_task("common:teacher_role_manager:add DOMAIN='essec.edu' SUBDOMAIN='mentoring' ROOTS='p2'")
      end
    end
  end

  def down
    # Do nothing
  end
end

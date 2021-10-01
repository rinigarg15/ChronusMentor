class RakeRemoveTeacherRoleFromUwcomotion< ActiveRecord::Migration[4.2]

  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.production?
        DeploymentRakeRunner.add_rake_task("common:teacher_role_manager:remove DOMAIN='chronus.com' SUBDOMAIN='uwcomotion' ROOTS='p2,p3'")
      end
    end
  end

  def down
  end
end
class RemoveLocalResorucesFromEyCollegeMap< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.production?
        organization = Program::Domain.get_organization("chronus.com", "eycollegemap")
        program_roots = organization.programs.where.not(root: "p1").pluck(:root).join(",")
        DeploymentRakeRunner.add_rake_task("common:data_scrubber:scrub DOMAIN='chronus.com' SUBDOMAIN='eycollegemap' ROOTS='#{program_roots}' SCRUB_ITEM='resources'")
      end
    end
  end

  def down
    # Do nothing
  end
end

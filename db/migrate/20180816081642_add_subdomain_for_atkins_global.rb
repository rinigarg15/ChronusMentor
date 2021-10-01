class AddSubdomainForAtkinsGlobal < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.production?
        DeploymentRakeRunner.add_rake_task("common:program_domain_manager:add DOMAIN='chronus.com' SUBDOMAIN='atkinsglobal' NEW_DOMAIN='chronus.com' NEW_SUBDOMAIN='pbsj'")
      end
    end
  end

  def down
  end
end

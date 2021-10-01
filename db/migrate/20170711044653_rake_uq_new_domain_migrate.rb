class RakeUqNewDomainMigrate< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.productioneu?
        DeploymentRakeRunner.add_rake_task("common:url_updater:change_urls DOMAIN='chronus.com' SUBDOMAIN='uqmentor' NEWDOMAIN='edu.au' NEWSUBDOMAIN='mentoring.app.uq'")
        DeploymentRakeRunner.add_rake_task("common:program_domain_manager:add DOMAIN='chronus.com' SUBDOMAIN='uqmentor' NEW_DOMAIN='edu.au' NEW_SUBDOMAIN='mentoring.app.uq' DEFAULT='true'")
      end
    end
  end

  def down
    # Do Nothing
  end
end

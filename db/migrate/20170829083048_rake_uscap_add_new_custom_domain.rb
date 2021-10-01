class RakeUscapAddNewCustomDomain< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.production?
        DeploymentRakeRunner.add_rake_task("common:url_updater:change_urls DOMAIN='chronus.com' SUBDOMAIN='uscapmentoring' NEWDOMAIN='uscap.org' NEWSUBDOMAIN='mentoring'")
        DeploymentRakeRunner.add_rake_task("common:program_domain_manager:add DOMAIN='chronus.com' SUBDOMAIN='uscapmentoring' NEW_DOMAIN='uscap.org' NEW_SUBDOMAIN='mentoring' DEFAULT='true'")
      end
    end
  end

  def down
    # Do Nothing
  end
end

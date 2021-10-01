class RakeUrlUpdaterChangeUrlsForSmu< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.production?
        DeploymentRakeRunner.add_rake_task("common:url_updater:change_urls DOMAIN='edu.sg' SUBDOMAIN='mentoring.alumni.smu' ROOT='2016-Session1' NEWROOT='p1'")
      end
    end
  end

  def down
    # Do nothing
  end
end

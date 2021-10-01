class RakeRemoveProgramFromLeeds< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.production?
        DeploymentRakeRunner.add_rake_task("common:programs_remover:remove DOMAIN='colorado.edu' SUBDOMAIN='leedsmentoring' ROOTS='shieldscholars'")
      end
    end
  end

  def down
    # do nothing
  end
end
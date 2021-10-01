class SetPreprocessorForWbg< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.production?
        DeploymentRakeRunner.add_rake_task("common:feed_import_configuration_manager:set_preprocessor DOMAIN='chronus.com' SUBDOMAIN='wbg' PREPROCESSOR='WbgPreprocessor'")
      end
    end
  end

  def down
    # Do nothing
  end
end

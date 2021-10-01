class EnableExplicitPreferencesFeatureInAllPrograms < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      org_ids_to_skip = {production: [1347, 1217, 735, 1733], staging: [2451, 1438]}
      DeploymentRakeRunner.add_rake_task("common:feature_manager:enable_feature_in_all_programs FEATURE='EXPLICIT_USER_PREFERENCES' SKIPPED_ORG_IDS='#{org_ids_to_skip}'")
    end
  end

  def down
    # Do nothing
  end
end

class RakeCreateMatchConfigDiscrepancyCache < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      ActiveRecord::Base.transaction do
        Program.includes([:match_configs, :translations, :enabled_db_features, :disabled_db_features, organization: [:enabled_db_features, :disabled_db_features]]).select(&:can_have_match_report?).each do |program|
          program.create_default_match_config_discrepancy_cache
        end
      end
    end
  end

  def down
  end
end

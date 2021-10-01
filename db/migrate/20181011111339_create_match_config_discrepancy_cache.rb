class CreateMatchConfigDiscrepancyCache < ActiveRecord::Migration[5.1]
  TEXT_BYTES = 1_073_741_823
  def self.up
    ChronusMigrate.ddl_migration do
      create_table :match_config_discrepancy_caches do |t|
        t.references :match_config, index: true
        t.text       :top_discrepancy, limit: TEXT_BYTES
        t.timestamps null: false
      end
    end
  end

  def self.down
    ChronusMigrate.ddl_migration do
      drop_table :match_config_discrepancy_caches
    end
  end
end

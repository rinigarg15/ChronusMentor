class CreateFeedExporterConfiguration < ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      create_table :feed_exporter_configurations do |t|
        t.references :feed_exporter
        t.boolean :enabled, default: false
        t.text :configuration_options
        t.string :type
        t.timestamps null: false
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      drop_table :feed_exporter_configurations
    end
  end
end

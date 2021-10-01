class CreateFeedImportConfigurations< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      create_table :feed_import_configurations do |t|
        t.references :organization
        t.string :sftp_user_name
        t.integer :frequency
        t.text :configuration_options
        t.text :source_options
        t.boolean :enabled, :default => false
        t.string :preprocessor

        t.timestamps null: false
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      drop_table :feed_import_configurations
    end
  end
end
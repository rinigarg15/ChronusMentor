class CreateLoginIdentifiers< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      create_table :login_identifiers do |t|
        t.references :member, index: true
        t.references :auth_config, index: true
        t.string :identifier, limit: UTF8MB4_VARCHAR_LIMIT, index: true
        t.timestamps null: false
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      drop_table :login_identifiers
    end
  end
end
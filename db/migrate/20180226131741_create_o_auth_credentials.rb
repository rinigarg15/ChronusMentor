class CreateOAuthCredentials < ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      create_table :o_auth_credentials do |t|
        t.text :access_token
        t.text :refresh_token
        t.string :type
        t.references :member, index: true

        t.timestamps null: false
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      drop_table :o_auth_credentials
    end
  end
end

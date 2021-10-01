class CreateAuthConfigSettings< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      create_table :auth_config_settings do |t|
        t.references :organization
        t.string :default_section_title
        t.string :custom_section_title
        t.text :default_section_description
        t.text :custom_section_description
        t.integer :show_on_top, default: AuthConfigSetting::Section::CUSTOM
        t.timestamps null: false
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      drop_table :auth_config_settings
    end
  end
end
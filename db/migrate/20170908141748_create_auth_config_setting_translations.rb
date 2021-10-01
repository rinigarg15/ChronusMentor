class CreateAuthConfigSettingTranslations< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      AuthConfigSetting.create_translation_table!( {
        default_section_title: :string,
        custom_section_title: :string,
        default_section_description: :text,
        custom_section_description: :text
        }, {
        migrate_data: false
      } )
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      AuthConfigSetting.drop_translation_table! migrate_data: true
    end
  end
end
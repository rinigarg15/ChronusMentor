class AddTitleTranslationColumnForAuthConfig< ActiveRecord::Migration[4.2]
  include MigrationHelpers

  def up
    add_translation_column(AuthConfig, :title, "text")
  end

  def down
    remove_column :auth_config_translations, :title
  end
end
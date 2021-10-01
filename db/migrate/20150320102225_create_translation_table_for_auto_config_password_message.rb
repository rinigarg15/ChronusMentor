class CreateTranslationTableForAutoConfigPasswordMessage< ActiveRecord::Migration[4.2]
  def up
    AuthConfig.create_translation_table!({
      :password_message => :text
    }, {
      :migrate_data => false
    })
  end

  def down
    AuthConfig.drop_translation_table! :migrate_data => true
  end
end

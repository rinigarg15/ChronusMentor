class AddTranslationTableForContactAdminSetting< ActiveRecord::Migration[4.2]
  def up
    ContactAdminSetting.create_translation_table!({
      :label_name => :string,
      :content => :text
    }, {
      :migrate_data => true
    })
  end

  def down
    ContactAdminSetting.drop_translation_table! :migrate_data => true
  end
end
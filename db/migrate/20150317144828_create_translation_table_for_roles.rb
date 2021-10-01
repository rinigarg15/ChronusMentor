class CreateTranslationTableForRoles< ActiveRecord::Migration[4.2]
  def up
    Role.create_translation_table!({
      :description => :text
    }, {
      :migrate_data => true
    })
  end

  def down
    Role.drop_translation_table! :migrate_data => true
  end
end
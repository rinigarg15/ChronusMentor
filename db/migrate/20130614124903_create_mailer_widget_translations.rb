class CreateMailerWidgetTranslations< ActiveRecord::Migration[4.2]
  def up
    Mailer::Widget.create_translation_table!({
      source: :text
    }, {
      migrate_data: true
    })
  end

  def down
    Mailer::Widget.drop_translation_table! migrate_data: true
  end
end

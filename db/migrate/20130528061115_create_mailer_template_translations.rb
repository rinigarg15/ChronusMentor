class CreateMailerTemplateTranslations< ActiveRecord::Migration[4.2]
  def up
    Mailer::Template.create_translation_table!({
      subject: :text,
      source: :text
    }, {
      migrate_data: true
    })
  end

  def down
    Mailer::Template.drop_translation_table! migrate_data: true
  end
end

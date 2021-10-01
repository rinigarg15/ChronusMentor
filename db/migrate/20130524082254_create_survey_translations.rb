class CreateSurveyTranslations< ActiveRecord::Migration[4.2]
  def up
    Survey.unscoped.create_translation_table!({
      name: :string
    }, {
      migrate_data: true
    })
  end

  def down
    Survey.unscoped.drop_translation_table! migrate_data: true
  end
end

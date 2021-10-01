class CreateQuestionChoiceTranslations< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      QuestionChoice.create_translation_table!({
        text: :text
      }, {
        migrate_data: true
      })
      add_index :question_choice_translations, :text, length: UTF8MB4_VARCHAR_LIMIT
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      QuestionChoice.drop_translation_table! migrate_data: true
    end
  end
end

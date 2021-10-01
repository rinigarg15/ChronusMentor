class AddQuestionInfoOfCommonQuestionToTranslations< ActiveRecord::Migration[4.2]
  include MigrationHelpers

  def up
    add_translation_column(CommonQuestion, :question_info, "text")
  end

  def down
    remove_column :common_question_translations, :question_info
  end
end

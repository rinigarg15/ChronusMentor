class AddProfileQuestionInfoToTranslations< ActiveRecord::Migration[4.2]
  include MigrationHelpers

  def up
    add_translation_column(ProfileQuestion, :question_info, "text")
  end

  def down
    remove_column :profile_question_translations, :question_info
  end
end
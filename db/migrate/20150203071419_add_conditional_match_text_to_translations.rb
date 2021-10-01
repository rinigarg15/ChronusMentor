class AddConditionalMatchTextToTranslations< ActiveRecord::Migration[4.2]
  include MigrationHelpers

  def up
    add_translation_column(ProfileQuestion, :conditional_match_text, "text")
  end

  def down
    remove_column :profile_question_translations, :conditional_match_text
  end
end

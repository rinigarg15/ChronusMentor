class AddAllowMentoringRequestsMessageToProgramTranslations< ActiveRecord::Migration[4.2]
  include MigrationHelpers

  def up
    add_translation_column(AbstractProgram, :allow_mentoring_requests_message, "text")
  end

  def down
    remove_column :program_translations, :allow_mentoring_requests_message
  end
end

class AddZeroMatchScoreMessageTranslatableColumnToProgram< ActiveRecord::Migration[4.2]
  include MigrationHelpers

  def up
    add_translation_column(Program, :zero_match_score_message, "text")
  end

  def down
    remove_column :program_translations, :zero_match_score_message
  end
end
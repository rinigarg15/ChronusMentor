class AddZeroMatchScoreMessageToProgram< ActiveRecord::Migration[4.2]
  def change
    add_column :programs, :zero_match_score_message, :text
  end
end

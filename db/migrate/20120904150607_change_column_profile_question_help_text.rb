class ChangeColumnProfileQuestionHelpText< ActiveRecord::Migration[4.2]
  def up
  	change_column :profile_questions, :help_text, :text
  end
end
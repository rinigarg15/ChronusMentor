class AddOptionsCountToProfileQuestions< ActiveRecord::Migration[4.2]
  def change
    add_column :profile_questions, :options_count, :integer
  end
end

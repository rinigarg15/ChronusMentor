class AddLastAnsweredAtToSurveyAnswer< ActiveRecord::Migration[4.2]
  def change
    add_column :common_answers, :last_answered_at, :datetime
  end
end

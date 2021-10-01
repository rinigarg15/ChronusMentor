class RenameSurveyUserCountToTotalResponses< ActiveRecord::Migration[4.2]
  def change
    rename_column :surveys, :users_count, :total_responses
  end
end

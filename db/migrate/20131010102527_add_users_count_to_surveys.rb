class AddUsersCountToSurveys< ActiveRecord::Migration[4.2]
  def up
    add_column :surveys, :users_count, :integer, null: false, default: 0
    say_with_time "Updating users_count values" do
      SurveyAnswer.unscoped.group(:survey_id).count("DISTINCT user_id").each do |survey_id, users_count|
        Survey.unscoped.find(survey_id).update_attribute(:users_count, users_count)
      end
    end
  end

  def down
    remove_column :surveys, :users_count
  end
end

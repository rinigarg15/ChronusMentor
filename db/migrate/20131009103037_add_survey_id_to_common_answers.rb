class AddSurveyIdToCommonAnswers< ActiveRecord::Migration[4.2]
  def up
    add_column :common_answers, :survey_id, :integer
    say_with_time "Updating common_answers survey_id" do
      Survey.unscoped.find_each do |s|
        s.survey_answers.update_all("common_answers.survey_id=#{s.id}")
      end
    end
    add_index :common_answers, [:type, :survey_id]
  end

  def down
    remove_index :common_answers, [:type, :survey_id]
    remove_column :common_answers, :survey_id
  end
end

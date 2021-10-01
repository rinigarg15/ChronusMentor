class UpdateGroupIdForEngagementSurveyAnswers< ActiveRecord::Migration[4.2]
  def change
    Survey.unscoped.of_engagement_type.each do |survey|
      survey.survey_answers.each do |ans|
      	if ans.task.present?
	        ans.group_id = ans.task.group_id 
	        ans.save!
	    end
      end
    end
  end
end

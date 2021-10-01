class AddInviterIdToThreeSixtySurveyReviewers< ActiveRecord::Migration[4.2]
  def up
    add_column :three_sixty_survey_reviewers, :inviter_id, :integer
    ThreeSixty::SurveyReviewer.includes(:survey_assessee).each do |reviewer|
      reviewer.update_attribute(:inviter_id, reviewer.survey_assessee.member_id)
    end
  end

  def down
    remove_column :three_sixty_survey_reviewers, :inviter_id
  end
end

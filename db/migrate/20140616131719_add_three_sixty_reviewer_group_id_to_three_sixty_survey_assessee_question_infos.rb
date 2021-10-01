class AddThreeSixtyReviewerGroupIdToThreeSixtySurveyAssesseeQuestionInfos< ActiveRecord::Migration[4.2]
  def up
    add_column :three_sixty_survey_assessee_question_infos, :three_sixty_reviewer_group_id, :integer, :null => false, :default => 0
    add_index :three_sixty_survey_assessee_question_infos, [:three_sixty_reviewer_group_id, :three_sixty_question_id], :name => "index_three_sixty_saqi_on_rg_id_and_q_id"
  end

  def down
    remove_column :three_sixty_survey_assessee_question_infos, :three_sixty_reviewer_group_id
    remove_index :three_sixty_survey_assessee_question_infos, :name => "index_three_sixty_saqi_on_rg_id_and_q_id"
  end
end

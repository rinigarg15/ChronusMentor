class AddOrganizationIdToThreeSixtyQuestions< ActiveRecord::Migration[4.2]
  def up
    add_column :three_sixty_questions, :organization_id, :integer, :null => false
    change_column :three_sixty_questions, :three_sixty_competency_id, :integer, :null => true

    add_column :three_sixty_survey_questions, :three_sixty_survey_id, :integer, :null => false
    change_column :three_sixty_survey_questions, :three_sixty_survey_competency_id, :integer, :null => true

    ActiveRecord::Base.transaction do
      ThreeSixty::Question.includes(:competency).each do |question|
        question.update_attribute(:organization_id, question.competency.organization_id) if question.three_sixty_competency_id.present?
      end

      ThreeSixty::SurveyQuestion.includes(:survey_competency).each do |sq|
        sq.update_attribute(:three_sixty_survey_id, sq.survey_competency.three_sixty_survey_id) if sq.three_sixty_survey_competency_id.present?
      end
    end
  end

  def down
    #Not changing three_sixty_competency_id, three_sixty_survey_competency_id null to false as null values could have been entered
    remove_column :three_sixty_questions, :organization_id
    remove_column :three_sixty_survey_questions, :three_sixty_survey_id
  end
end

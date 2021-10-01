class CreateThreeSixtyCompetencyInfosAndPopulateIt< ActiveRecord::Migration[4.2]
  def change
    create_table :three_sixty_survey_assessee_competency_infos do |t|
      t.belongs_to :three_sixty_survey_assessee, :null => false
      t.belongs_to :three_sixty_competency, :null => false
      t.belongs_to :three_sixty_reviewer_group, :null => false
      t.float :average_value, :null => false, :default => 0.0
      t.integer :answer_count, :null => false, :default => 0
      t.timestamps null: false
    end
    add_index :three_sixty_survey_assessee_competency_infos, :three_sixty_survey_assessee_id, :name => "index_three_sixty_asse_comp_info_on_survey_assessee_id"
    add_index :three_sixty_survey_assessee_competency_infos, :three_sixty_competency_id, :name => "index_three_sixty_asse_comp_info_on_question_id"

    survey_assessee_ids=[]
    ActiveRecord::Base.transaction do
      survey_assessee_ids = ThreeSixty::SurveyAssesseeQuestionInfo.pluck(:three_sixty_survey_assessee_id).uniq
      ThreeSixty::SurveyAssessee.where(:id => survey_assessee_ids).each do |sa|
        array = sa.survey_assessee_question_infos.joins(:question).select("SUM(answer_count*average_value)/SUM(answer_count) as competency_average_value, SUM(answer_count) as competency_answer_count, three_sixty_reviewer_group_id, three_sixty_questions.three_sixty_competency_id").group("three_sixty_reviewer_group_id, three_sixty_questions.three_sixty_competency_id")
        array.each do |elt|
          comp_info = ThreeSixty::SurveyAssesseeCompetencyInfo.new
          comp_info.three_sixty_survey_assessee_id = sa.id
          comp_info.three_sixty_reviewer_group_id = elt.three_sixty_reviewer_group_id
          comp_info.three_sixty_competency_id = elt.three_sixty_competency_id
          comp_info.average_value = elt.competency_average_value
          comp_info.answer_count = elt.competency_answer_count
          comp_info.save!
        end
      end
    end
  end
end

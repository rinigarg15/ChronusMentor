class ThreeSixtySurveyQuestionPopulator < PopulatorTask

  def patch(options = {})
    return unless @options[:common]["three_sixty_survey_enabled?"]
    three_sixty_survey_ids = @program.three_sixty_surveys.pluck(:id)
    three_sixty_survey_questions_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, three_sixty_survey_ids)
    process_patch(three_sixty_survey_ids, three_sixty_survey_questions_hsh) 
  end

  def add_three_sixty_survey_questions(three_sixty_survey_ids, count, options = {})
    self.class.benchmark_wrapper "Three Sixty Survey Question" do
      program = options[:program]
      questions = program.organization.three_sixty_questions
      three_sixty_surveys = ThreeSixty::Survey.where(id: three_sixty_survey_ids)
      three_sixty_surveys.each do |survey|
        questions_to_skip = survey.questions
        questions = questions - questions_to_skip
        iterator = ThreeSixty::SurveyCompetency.where(:three_sixty_survey_id => survey.id).pluck(:position).max.to_i + 1
        ThreeSixty::SurveyQuestion.populate count do |survey_question|
          question = questions.sample
          if question.three_sixty_competency_id.nil? 
            survey_question.three_sixty_survey_competency_id = nil
          else
            survey_competency = question.competency.survey_competencies.where(:three_sixty_survey_id => survey.id).sample
            survey_competency = ThreeSixty::SurveyCompetency.create(:three_sixty_survey_id => survey.id, :three_sixty_competency_id => question.competency.id) if survey_competency.nil?
            survey_question.three_sixty_survey_competency_id = survey_competency.id
          end
          survey_question.three_sixty_question_id = question.id
          survey_question.three_sixty_survey_id = survey.id
          survey_question.position = iterator
          iterator += 1 
          self.dot
        end
      end
      self.class.display_populated_count(three_sixty_survey_ids.size * count, "Three Sixty Survey Question")
    end
  end

  def remove_three_sixty_survey_questions(three_sixty_survey_ids, count, options = {})
    self.class.benchmark_wrapper "Removing three_sixty_survey_questions................" do
      three_sixty_survey_question_ids = ThreeSixty::SurveyQuestion.where(:three_sixty_survey_id => three_sixty_survey_ids).select([:id, :three_sixty_survey_id]).group_by(&:three_sixty_survey_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      ThreeSixty::SurveyQuestion.where(:id => three_sixty_survey_question_ids).destroy_all
      self.class.display_deleted_count(three_sixty_survey_ids.size * count, "Three Sixty Survey Question")
    end
  end
end
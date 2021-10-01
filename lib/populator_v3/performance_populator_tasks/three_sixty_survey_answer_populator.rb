class ThreeSixtySurveyAnswerPopulator < PopulatorTask

  def patch(options = {})
    return unless @options[:common]["three_sixty_survey_enabled?"]
    @program.three_sixty_surveys.includes(:reviewers, :survey_questions).each do |three_sixty_survey|
      @options[:three_sixty_survey] = three_sixty_survey
      three_sixty_survey_reviewer_ids = three_sixty_survey.reviewers.pluck(:id)
      three_sixty_survey_answers_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, three_sixty_survey_reviewer_ids)
      process_patch(three_sixty_survey_reviewer_ids, three_sixty_survey_answers_hsh) 
    end
  end

  def add_three_sixty_survey_answers(three_sixty_survey_reviewer_ids, count, options = {})
    self.class.benchmark_wrapper "Three Sixty Survey answers" do
      temp_three_sixty_survey_reviewer_ids = three_sixty_survey_reviewer_ids * count
      three_sixty_survey_question_ids = options[:three_sixty_survey].survey_questions.pluck(:id)
      return if three_sixty_survey_question_ids.blank?
      ThreeSixty::SurveyAnswer.populate(three_sixty_survey_reviewer_ids.size * count, :per_query => 50_000) do |survey_answer|
        survey_answer.three_sixty_survey_question_id = three_sixty_survey_question_ids.first
        survey_answer.three_sixty_survey_reviewer_id = temp_three_sixty_survey_reviewer_ids.shift
        survey_answer.answer_value = rand(0..5)
        survey_answer.answer_text = Populator.words(4..6)
        three_sixty_survey_question_ids = three_sixty_survey_question_ids.rotate
        self.dot
      end
      self.class.display_populated_count(three_sixty_survey_reviewer_ids.size * count, "Three Sixty Survey answers")
    end
  end

  def remove_three_sixty_survey_answers(three_sixty_survey_reviewer_ids, count, options = {})
    self.class.benchmark_wrapper "Removing Three Sixty Survey Answer................" do
      survey_answer_ids = ThreeSixty::SurveyAnswer.where(:three_sixty_survey_reviewer_id => three_sixty_survey_reviewer_ids).select([:id, :three_sixty_survey_reviewer_id]).group_by(&:three_sixty_survey_reviewer_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      ThreeSixty::SurveyAnswer.where(:id => survey_answer_ids).destroy_all
      self.class.display_deleted_count(three_sixty_survey_reviewer_ids.size * count, "Three Sixty Reviewer Group")
    end
  end
end
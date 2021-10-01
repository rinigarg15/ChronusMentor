class ThreeSixtySurveyAssesseeQuestionInfoPopulator < PopulatorTask

  def patch(options = {})
    return unless @options[:common]["three_sixty_survey_enabled?"]
    three_sixty_survey_assessee_ids = @program.three_sixty_survey_assessees.pluck(:id)
    three_sixty_survey_assessee_question_infos_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, three_sixty_survey_assessee_ids)
    process_patch(three_sixty_survey_assessee_ids, three_sixty_survey_assessee_question_infos_hsh) 
  end

  def add_three_sixty_survey_assessee_question_infos(three_sixty_survey_assessee_ids, count, options = {})
    self.class.benchmark_wrapper "Three Sixty Survey assessee_question_infos" do
      program = options[:program]
      temp_three_sixty_survey_assessee_ids = three_sixty_survey_assessee_ids * count
      three_sixty_question_ids = program.organization.three_sixty_questions.pluck(:id)
      three_sixty_reviewer_group_ids = program.organization.three_sixty_reviewer_groups.pluck(:id)
      ThreeSixty::SurveyAssesseeQuestionInfo.populate(three_sixty_survey_assessee_ids.size * count, :per_query => 50_000) do |question_info|
        temp_three_sixty_question_ids = three_sixty_question_ids.dup if temp_three_sixty_question_ids.blank?
        temp_three_sixty_reviewer_group_ids = three_sixty_reviewer_group_ids.dup if temp_three_sixty_reviewer_group_ids.blank?
        question_info.three_sixty_survey_assessee_id = temp_three_sixty_survey_assessee_ids.shift
        question_info.three_sixty_reviewer_group_id = three_sixty_reviewer_group_ids.first
        question_info.three_sixty_question_id = three_sixty_question_ids.first
        three_sixty_question_ids = three_sixty_question_ids.rotate
        three_sixty_reviewer_group_ids = three_sixty_reviewer_group_ids.rotate
        question_info.average_value = rand(0.0..5)
        question_info.answer_count = rand(0..100)
        self.dot
      end
      self.class.display_populated_count(three_sixty_survey_assessee_ids.size * count, "Three Sixty Survey assessee_question_infos")
    end
  end

  def remove_three_sixty_survey_assessee_question_infos(three_sixty_survey_assessee_ids, count, options = {})
    self.class.benchmark_wrapper "Removing Three Sixty Survey assessee_question_infos ................" do
      survey_assessee_question_info_ids = ThreeSixty::SurveyAssesseeQuestionInfo.where(:three_sixty_survey_assessee_id => three_sixty_survey_assessee_ids).select([:id, :three_sixty_survey_assessee_id]).group_by(&:three_sixty_survey_assessee_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      ThreeSixty::SurveyAssesseeQuestionInfo.where(:id => survey_assessee_question_info_ids).destroy_all
      self.class.display_deleted_count(three_sixty_survey_assessee_ids.size * count, "Three Sixty Survey assessee_question_infos")
    end
  end
end
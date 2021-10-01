class SurveyAnswerPopulator < PopulatorTask
  def patch(options = {})
    survey_ids = @program.surveys.where(type: Survey::Type.admin_createable).pluck(:id).sort
    survey_question_ids =  SurveyQuestion.where(:survey_id => survey_ids).pluck(:id)
    survey_answer_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, survey_question_ids)
    process_patch(survey_question_ids, survey_answer_hsh) 
    @program.surveys.joins(:survey_answers).each{|survey| survey.update_total_responses!}
  end

  def add_survey_answers(survey_question_ids, survey_answers_count, options = {})
    self.class.benchmark_wrapper "Survey Answers" do
      program = options[:program]
      group_ids = program.groups.where(:status=> Group::Status::CLOSED).pluck(:id)
      user_ids = program.users.active.pluck(:id)
      temp_user_ids = user_ids.dup
      survey_questions = SurveyQuestion.where(:id => survey_question_ids)
      survey_questions.each do |survey_question|
        SurveyAnswer.populate(survey_answers_count, :per_query => 10_000) do |survey_answer|
          temp_user_ids = user_ids.dup if temp_user_ids.blank?
          survey_answer.is_draft = false
          survey_answer.user_id = temp_user_ids.shift
          survey_answer.common_question_id = survey_question.id
          survey_answer.last_answered_at = survey_question.created_at..Time.now
          survey_answer.response_id = survey_answer.user_id
          survey_answer.group_id = group_ids if survey_question.survey.type == Survey::Type::ENGAGEMENT
          survey_answer.type = SurveyAnswer.to_s
          set_common_answer_text!(survey_question, survey_answer)
          self.dot
        end
      end
      self.class.display_populated_count(survey_question_ids.size * survey_answers_count, "Survey Answers")
    end
  end

  def remove_survey_answers(survey_question_ids, count, options = {})
    self.class.benchmark_wrapper "Removing Survey Answers....." do
      survey_answer_ids = SurveyAnswer.where(:common_question_id => survey_question_ids).select("common_answers.id, common_question_id").group_by(&:common_question_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      SurveyAnswer.where(:id => survey_answer_ids).destroy_all
      self.class.display_deleted_count(survey_question_ids.size * count, "Survey Answers")
    end
  end
end
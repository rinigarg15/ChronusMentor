class SurveyQuestionPopulator < PopulatorTask
  def patch(options = {})
    survey_ids = @program.surveys.where(type: Survey::Type.admin_createable).pluck(:id)
    survey_question_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, survey_ids)
    process_patch(survey_ids, survey_question_hsh)
  end

  def add_survey_questions(survey_ids, survey_questions_count, options = {})
    self.class.benchmark_wrapper "Surveys Questions" do
      program = options[:program]
      total_survey_question = 0
      program_id = program.id
      choice_based = [CommonQuestion::Type::MULTI_CHOICE , CommonQuestion::Type::SINGLE_CHOICE]
      other_question = CommonQuestion::Type.all - [CommonQuestion::Type::FILE] - choice_based
      survey_ids.each do |survey_id|
        iterator = 0
        total_survey_question += survey_questions_count
        number_of_choice_based = 0.8*survey_questions_count
        SurveyQuestion.populate survey_questions_count do |common_question|
          question_text = Populator.words(5..8)
          help_text = Populator.words(3..5)

          common_question.type = SurveyQuestion.to_s
          common_question.program_id = program_id
          common_question.question_type = number_of_choice_based > 0 ? choice_based.sample : other_question.sample
          common_question.survey_id = survey_id
          common_question.position = iterator += 1
          common_question.required = [false, false, true]
          common_question.allow_other_option = [false, false, true]
          common_question.created_at = program.created_at
          common_question.updated_at = program.created_at..Time.now
          common_question.positive_outcome_options = nil

          locales = @translation_locales.dup
          SurveyQuestion::Translation.populate @translation_locales.count do |survey_question_translation|
            survey_question_translation.question_text = DataPopulator.append_locale_to_string(question_text, locales.last)
            survey_question_translation.help_text = DataPopulator.append_locale_to_string(help_text, locales.last)
            survey_question_translation.common_question_id = common_question.id
            survey_question_translation.question_info = nil
            survey_question_translation.locale = locales.pop
          end
          populate_question_choices(common_question, CommonQuestion.name, @translation_locales)
          number_of_choice_based -= 1
        end
        self.dot
      end
      self.class.display_populated_count(survey_ids.size * survey_questions_count, "Surveys Questions")
    end
  end

  def remove_survey_questions(survey_ids, count, options = {})
    self.class.benchmark_wrapper "Removing Survey Questions....." do
      survey_question_ids = SurveyQuestion.where(:survey_id => survey_ids).select("common_questions.id, survey_id").group_by(&:survey_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      SurveyQuestion.where(:id => survey_question_ids).destroy_all
      self.class.display_deleted_count(survey_ids.size * count, "Surveys Questions")
    end
  end
end
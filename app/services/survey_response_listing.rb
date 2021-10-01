class SurveyResponseListing

  def initialize(program, meeting_or_group, options)
    @program = program
    @options = options
    @meeting_or_group = meeting_or_group
  end

  def get_survey_questions_for_meeting_or_group
    @program.surveys.find(@options[:survey_id]).survey_questions.select(["common_questions.id, survey_id, question_type"]).includes(:translations, rating_questions: [:translations], question_choices: :translations)
  end

  def get_user_for_meeting_or_group
    @program.users.find(@options[:user_id])
  end

  def get_survey_answers_for_meeting_or_group
    @meeting_or_group.survey_answers.where(user_id: @options[:user_id], response_id: @options[:response_id]).select("common_answers.id, common_question_id, answer_text, common_answers.last_answered_at").includes(:answer_choices).index_by(&:common_question_id)
  end
end
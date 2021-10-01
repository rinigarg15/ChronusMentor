class ThreeSixty::SurveyAnswerService
  def initialize(survey_reviewer)
    @survey_reviewer = survey_reviewer
    @survey = @survey_reviewer.survey
    @survey_questions = @survey.survey_questions.includes(:question, :answers)
  end

  def process_answers(answer_hash)
    answer_hash.each do |id, answer|
      survey_question = @survey_questions.find{|sq| sq.id == id.to_i}
      create_or_update_answer(survey_question, answer)
    end
  end

  private

  def create_or_update_answer(survey_question, answer)
    answer_hash = survey_question.question.of_rating_type? ? {:answer_value => answer} : {:answer_text => answer}
    survey_answer = survey_question.answers.find{|a| a.three_sixty_survey_reviewer_id == @survey_reviewer.id} || survey_question.answers.new(:survey_reviewer => @survey_reviewer)
    answer.present? ? survey_answer.update_attributes!(answer_hash) : (survey_answer.destroy unless survey_answer.new_record?)
  end
end
class ThreeSixty::SurveyPolicy

  attr_accessor :error_message

  def initialize(survey)
    @survey = survey
  end

  def not_accessible?
    self.error_message = "flash_message.three_sixty.surveys.expired".translate unless @survey.not_expired?
  end

  def not_editable?
    self.error_message = "flash_message.three_sixty.surveys.survey_not_editable_message".translate unless @survey.drafted?
  end

  def settings_error?
    self.error_message = if !@survey.not_expired?
      "flash_message.three_sixty.surveys.invalid_expiration_date".translate
    elsif @survey.reviewer_groups.excluding_self_type.empty?
      "flash_message.three_sixty.surveys.no_reviewer_groups_v1".translate
    end
  end

  def questions_error?
    self.error_message = "flash_message.three_sixty.surveys.no_questions".translate if @survey.survey_questions.empty?
  end
end
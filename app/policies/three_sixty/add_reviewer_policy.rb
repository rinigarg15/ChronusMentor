class ThreeSixty::AddReviewerPolicy
  def initialize(survey_assessee, member, user)
    @survey_assessee = survey_assessee
    @member = member
    @user = user
  end

  def admin_managing_survey?
    @survey_assessee.survey.only_admin_can_add_reviewers? && (@member.admin? || (@user && @survey_assessee.survey.program == @user.program && @user.is_admin?))
  end

  def can_add_reviewers?
    self.admin_managing_survey? || (@survey_assessee.survey.only_assessee_can_add_reviewers? && @survey_assessee.is_for?(@member))
  end

  def can_update_reviewer?(survey_reviewer)
    self.can_add_reviewers?
  end
end
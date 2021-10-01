class ThreeSixty::CommonController < ApplicationController

  module Tab
    COMPETENCIES = 'competencies'
    SURVEYS = 'surveys'
    SETTINGS = 'settings'
  end

  skip_before_action :login_required_in_program, :require_program
  before_action :login_required_in_organization
  allow :exec => "admin_at_current_level?"

  private

  def fetch_survey(id)
    @survey = current_program_or_organization.three_sixty_surveys.find(id)
  end

end
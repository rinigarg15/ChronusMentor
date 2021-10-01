class ThreeSixty::SurveyCompetenciesController < ThreeSixty::CommonController
  before_action {fetch_survey(params[:survey_id])}
  before_action :fetch_survey_competency, :only => [:destroy, :reorder_questions]

  allow :exec => "@survey.drafted?"

  def create
    @competency = @current_organization.three_sixty_competencies.find(params[:competency_id])
    @survey_competency = @survey.add_competency(@competency)
    set_available_competencies if @survey_competency.valid?
  end

  def destroy
    @survey_competency.destroy
    set_available_competencies
  end

  def reorder_questions
    ReorderService.new(@survey_competency.survey_questions).reorder(params[:new_order])
    head :ok
  end

  private

  def fetch_survey_competency
    @survey_competency = @survey.survey_competencies.find(params[:id])
  end

  def set_available_competencies
    @available_competencies = @current_organization.three_sixty_competencies.with_questions - @survey.competencies
  end
end
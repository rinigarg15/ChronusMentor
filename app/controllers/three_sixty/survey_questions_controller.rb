class ThreeSixty::SurveyQuestionsController < ThreeSixty::CommonController
  before_action {fetch_survey(params[:survey_id])}
  before_action :fetch_survey_competency, :only => [:new, :create]
  before_action :fetch_survey_question, :only => [:destroy]

  allow :exec => "@survey.drafted?"

  def new
    @questions = @survey_competency.competency.questions - @survey_competency.questions
    render :partial => "three_sixty/survey_questions/new"
  end

  def create
    if @survey_competency.present?
      question_ids = params[:questions]
      @survey_competency.add_questions(question_ids)
      @survey_questions = @survey_competency.survey_questions.where(:three_sixty_question_id => question_ids)
    else
      @survey_question = @survey.survey_questions.create(:three_sixty_question_id => params[:question_id])
      @available_oeqs = @current_organization.three_sixty_oeqs - @survey.open_ended_questions
    end
  end

  def destroy
    @survey_competency = @survey_question.survey_competency
    @survey_question.destroy
    @available_competencies = @current_organization.three_sixty_competencies.with_questions - @survey.competencies
    @available_oeqs = @current_organization.three_sixty_oeqs - @survey.open_ended_questions
  end

  private

  def fetch_survey_competency
    @survey_competency = @survey.survey_competencies.find(params[:competency_id]) if params[:competency_id]
  end

  def fetch_survey_question
    @survey_question = @survey.survey_questions.find(params[:id])
  end
end
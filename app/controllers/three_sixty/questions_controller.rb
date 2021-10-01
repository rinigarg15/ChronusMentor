class ThreeSixty::QuestionsController < ThreeSixty::CommonController
  
  allow :exec => "wob_member.admin?"
  before_action :fetch_question, :only => [:edit, :update, :destroy]

  def create
    @question = @current_organization.three_sixty_questions.create(question_params(:create))
  end

  def create_and_add_to_survey
    @question = @current_organization.three_sixty_questions.create(question_params(:create_and_add_to_survey))
    @survey = @current_organization.three_sixty_surveys.drafted.find(params[:three_sixty_question][:survey_id])
    @survey_question = @question.survey_questions.create(:three_sixty_survey_id => @survey.id) if @question.valid?
  end

  def edit
  end

  def update
    @question.update_attributes(question_params(:update))
  end

  def destroy
    @question.destroy
  end

  private

  def question_params(action)
    params.require(:three_sixty_question).permit(ThreeSixty::Question::MASS_UPDATE_ATTRIBUTES[action])
  end

  def fetch_question
    @question = @current_organization.three_sixty_questions.find(params[:id])
  end
end
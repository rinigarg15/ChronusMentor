class SurveyQuestionsController < ApplicationController
  before_action :find_survey

  # All actions are allowed only for admin
  allow :user => :can_manage_surveys?
  allow :exec => :is_engagement_survey_accessible?


  # Lists questions that can be edited inline.
  def index
    @survey_questions = @survey.survey_questions.includes(:translations, :survey, {question_choices: :translations}, {rating_questions: :translations})
  end

  def new
    @common_question = @survey.survey_questions.new
    render :template => 'common_questions/new', :formats => [:js]
  end

  def show
    @question = @survey.survey_questions.includes(:translations).select(:id).find(params[:id])
    filter_params = Survey::Report.get_updated_report_filter_params(params[:newparams]||{}, {}, nil, params[:format], only_new_params: true)
    srds = SurveyResponsesDataService.new(@survey, {:filter => {:filters => filter_params}})
    @answers = @question.survey_answers.includes(:answer_choices).where(response_id: srds.response_ids).select([:id, :user_id, :answer_text, :updated_at, :common_question_id]).order(:updated_at)
  end

  def create
    @common_question = @survey.survey_questions.new(survey_question_params(:create))
    @common_question.program = @current_program
    begin
      @common_question.create_survey_question(survey_question_internal_params, survey_question_internal_params(:matrix_question))
    rescue ActiveRecord::RecordInvalid => _invalid
      # suppress active record invalid exceptions
    end
    render :template => 'common_questions/create', :formats => [:js]
  end

  def update
    @common_question = @survey.survey_questions.find(params[:id])
    @last_question_for_meeting_cancelled_or_completed_scenario = @survey.last_question_for_meeting_cancelled_or_completed_scenario?(@common_question, survey_question_params(:update)[:condition].to_i)
    begin
      unless @last_question_for_meeting_cancelled_or_completed_scenario
        @common_question.update_survey_question(survey_question_params(:update), survey_question_internal_params(:matrix_question), survey_question_internal_params)
      end
    rescue ActiveRecord::RecordInvalid => _invalid
      # suppress active record invalid exceptions
    end
    @common_question.reload
    render :template => 'common_questions/update', :formats => [:js]
  end

  def destroy
    @common_question = @survey.survey_questions.find(params[:id])

    # Only the current program's question can be destroyed
    allow! :exec => lambda { @common_question.program == @current_program}

    @last_question_for_meeting_cancelled_or_completed_scenario = @survey.last_question_for_meeting_cancelled_or_completed_scenario?(@common_question, nil)
    @common_question.destroy unless @last_question_for_meeting_cancelled_or_completed_scenario
    render :template => 'common_questions/destroy', :formats => [:js]
  end

  # Sorts the survey questions with the new order.
  def sort
    survey_questions = @survey.survey_questions.includes(:translations)
    ReorderService.new(survey_questions).reorder(params[:new_order])
    head :ok
  end

  private

  def survey_question_internal_params(param = :common_question)
    inner_param = (param == :common_question) ? :existing_question_choices_attributes : :existing_rows_attributes

    return params[param] unless params[param].try(:[], inner_param).present?
    params[param][inner_param][0] = permit_internal_attributes(params[param][inner_param][0], [:text])
    params[param]
  end

  def survey_question_params(action)
    params.require(:survey_question).permit(SurveyQuestion::MASS_UPDATE_ATTRIBUTES[action])
  end

  def find_survey
    @survey = @current_program.surveys.find_by(id: params[:survey_id])
    unless @survey.present?
      flash[:error] = "flash_message.survey_flash.survey_not_found".translate
      redirect_to program_root_path
    end
  end

  def is_engagement_survey_accessible?
    !@survey.engagement_survey? || @current_program.ongoing_mentoring_enabled?
  end

end
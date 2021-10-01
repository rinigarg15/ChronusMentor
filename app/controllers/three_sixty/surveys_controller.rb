class ThreeSixty::SurveysController < ThreeSixty::CommonController
  DEFAULT_PER_PAGE = 5
  MAX_MATCHES = 100000 #max_matches value for thinking sphinx set in thinking_sphinx.yml
  before_action(:only => [:destroy, :edit, :update, :add_questions, :preview, :add_assessees, :publish, :show, :reorder_competencies]) {fetch_survey(params[:id])}
  before_action :set_survey_policy, :except => [:new, :create, :dashboard]
  before_action :redirect_unless_survey_is_editable, :except => [:new, :create, :dashboard, :show]
  before_action :redirect_to_survey_edit_if_settings_error, :only => [:add_questions, :preview, :add_assessees]
  before_action :redirect_to_survey_questions_if_questions_error, :only => [:preview, :add_assessees]
  before_action :set_view, :only => [:new, :create, :edit, :update, :add_questions, :preview, :add_assessees]
  before_action :set_drafted_surveys, :only => [:dashboard]
  before_action :set_back_link_to_dashboard, :only => [:show, :edit, :create, :new, :add_questions, :preview, :add_assessees]
  allow :exec => "@survey.published?", :only => [:show]
  before_action :fetch_survey_competencies_and_oeqs, :only => [:show, :add_questions, :preview]

  def show
    @survey_assessees = @survey.survey_assessees.includes(:survey, :assessee, :reviewers => [:answers, :survey_reviewer_group => :reviewer_group])
  end

  def new
    @survey = @current_organization.three_sixty_surveys.new
    @reviewer_groups = @current_organization.three_sixty_reviewer_groups.excluding_self_type
    @reviewer_group_names = []
  end

  def create
    @survey = @current_organization.three_sixty_surveys.new(:program => @current_program)
    handle_survey_create_or_update    
  end

  def edit
    @reviewer_groups = @current_organization.three_sixty_reviewer_groups.excluding_self_type
    @reviewer_group_names = @survey.reviewer_groups.excluding_self_type.collect(&:name)
  end

  def update
    handle_survey_create_or_update
  end

  def add_questions
    @available_competencies = @current_organization.three_sixty_competencies.with_questions - @survey_competencies.collect(&:competency)
    @available_oeqs = @current_organization.three_sixty_oeqs - @survey_oeqs.collect(&:question)
    @show_actions = wob_member.admin?
  end

  def preview
  end

  def add_assessees
    @survey_assessees = @survey.survey_assessees.includes(:assessee, :reviewers => [:survey_reviewer_group => :reviewer_group])
    @allow_admin_to_add_reviewers = @survey.only_admin_can_add_reviewers?
    @survey_reviewer_groups = @survey.survey_reviewer_groups.includes(:reviewer_group) if @allow_admin_to_add_reviewers
  end

  def destroy
    @survey.destroy
    if request.xhr?
      set_drafted_surveys
      if @surveys.empty? && params[:page] && params[:page] != "1"
        params[:page] = (params[:page].to_i - 1).to_s
        set_drafted_surveys
      end
    else
      redirect_to dashboard_three_sixty_surveys_path
    end
  end

  def publish
    if @survey.may_publish?
      @survey.publish!
      @survey.send_later(:notify_assessees)
      @survey.send_later(:notify_reviewers) if @survey.only_admin_can_add_reviewers?
      flash[:notice] = "flash_message.three_sixty.surveys.publish_success".translate(:survey_title => @survey.title)
      redirect_to three_sixty_survey_path(@survey) unless request.xhr?
    else
      unless request.xhr?
        flash[:error] = "flash_message.three_sixty.surveys.no_assessees".translate
        redirect_to(add_assessees_three_sixty_survey_path(@survey)) and return
      end
    end
  end

  def dashboard
    @active_tab = Tab::SURVEYS
    unless params[:published] == "false"
      @survey_assessees = ThreeSixty::SurveyAssessee.get_es_results(@options = ThreeSixty::SurveyService.new.survey_dashboard(params, ThreeSixty::Survey::PUBLISHED, @current_organization, @current_program))
    end
  end

  def reorder_competencies
    ReorderService.new(@survey.survey_competencies).reorder(params[:new_order])
    head :ok
  end

  private
  def set_back_link_to_dashboard
    @back_link = {:label => "feature.three_sixty.survey.dashboard".translate, :link => dashboard_three_sixty_surveys_path}
  end

  def set_survey_policy
    @survey_policy = ThreeSixty::SurveyPolicy.new(@survey)
  end

  def set_drafted_surveys
    unless params[:published] == "true"
      @surveys = ThreeSixty::Survey.get_es_results(@options = ThreeSixty::SurveyService.new.survey_dashboard(params, ThreeSixty::Survey::DRAFTED, @current_organization, @current_program))
    end
  end

  def redirect_unless_survey_is_editable
    if @survey_policy.not_editable?
      if request.xhr?
        render :partial => "three_sixty/surveys/policy_warning"
      else
        flash[:error] = @survey_policy.error_message
        redirect_to dashboard_three_sixty_surveys_path
      end
      return
    end
  end

  def redirect_to_survey_edit_if_settings_error
    if @survey_policy.settings_error?
      flash[:error] = @survey_policy.error_message
      redirect_to(edit_three_sixty_survey_path(@survey)) and return
    end
  end

  def redirect_to_survey_questions_if_questions_error
    if @survey_policy.questions_error?
      flash[:error] = @survey_policy.error_message
      redirect_to(add_questions_three_sixty_survey_path(@survey)) and return
    end
  end

  def set_view
    @view = case params[:action]
    when "new", "create", "edit", "update"
      ThreeSixty::Survey::View::SETTINGS
    when "add_questions"
      ThreeSixty::Survey::View::QUESTIONS
    when "preview"
      ThreeSixty::Survey::View::PREVIEW
    when "add_assessees"
      ThreeSixty::Survey::View::ASSESSEES
    end
  end

  def handle_survey_create_or_update
    @reviewer_group_names = params[:survey_reviewer_groups].split(",")
    three_sixty_survey_params = params[:three_sixty_survey]
    three_sixty_survey_params[:expiry_date] = get_en_datetime_str(three_sixty_survey_params[:expiry_date]) if three_sixty_survey_params[:expiry_date].present?
    @survey.update_attributes(survey_params(:handle_survey_create_or_update, three_sixty_survey_params))
    if @survey.valid?
      @survey.add_reviewer_groups(@reviewer_group_names)
      flash[:notice] = (params[:action] == "create") ? "flash_message.three_sixty.surveys.create_success".translate : "flash_message.three_sixty.surveys.update_success".translate
      redirect_to add_questions_three_sixty_survey_path(@survey)
    else
      @reviewer_groups = @current_organization.three_sixty_reviewer_groups.excluding_self_type
      flash.now[:error] = "flash_message.three_sixty.surveys.create_failure".translate
      params[:action] == "create" ? render(:action => 'new') : render(:action => 'edit')
    end
  end

  def fetch_survey_competencies_and_oeqs
    @survey_competencies = @survey.survey_competencies.includes(:competency => :questions, :survey_questions => :question)
    @survey_oeqs = @survey.survey_oeqs.includes(:question)
  end

  private

  def survey_params(action, action_params)
    action_params.permit(ThreeSixty::Survey::MASS_UPDATE_ATTRIBUTES[action])
  end
end
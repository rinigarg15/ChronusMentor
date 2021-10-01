class ThreeSixty::SurveyAssesseesController < ApplicationController
  skip_before_action :login_required_in_program, :require_program
  before_action :login_required_in_organization
  before_action :fetch_drafted_survey, :only => [:create, :destroy]
  before_action :fetch_published_survey, :only => [:add_reviewers, :notify_reviewers]
  before_action :fetch_published_survey_for_admin, :only => [:destroy_published, :survey_report]
  before_action :fetch_assessee, :except => [:create, :index]
  before_action :redirect_unless_survey_is_accessible, :except => [:create, :destroy_published, :destroy, :survey_report, :index]

  allow :exec => :can_add_reviewers?, :only => [:add_reviewers, :notify_reviewers]
  allow :exec => "admin_at_current_level?", :only => [:create, :destroy, :destroy_published, :survey_report]

  def index
    @survey_assessees = current_program_or_organization.three_sixty_survey_assessees.for_member(wob_member).accessible.includes(:survey, :reviewers => :answers)
    @self_reviewers = wob_member.three_sixty_survey_reviewers.for_self.includes(:answers).group_by(&:three_sixty_survey_assessee_id)
  end

  def create
    email = Member.extract_email_from_name_with_email(params[:member][:name_with_email] || "")
    assessee = @current_organization.members.find_by(email: email)
    @survey_assessee = @survey.survey_assessees.create(:member_id => assessee.try(:id))
    @allow_admin_to_add_reviewers = @survey.only_admin_can_add_reviewers?
    @survey_reviewer_groups = @survey.survey_reviewer_groups.includes(:reviewer_group) if @allow_admin_to_add_reviewers
  end

  def destroy
    @survey_assessee.destroy
  end

  def destroy_published
    @survey_assessee.destroy
    fetch_survey_assessees
    if params[:from_dashboard] && @survey_assessees.empty? && params[:page] != "1"
      params[:page] = (params[:page].to_i - 1).to_s
      fetch_survey_assessees
    end
  end

  def add_reviewers
    case params[:view]
    when ThreeSixty::Survey::SURVEY_SHOW
      @back_link = {:label => @survey.title, :link => three_sixty_survey_path(@survey)}
    when ThreeSixty::Survey::MY_SURVEYS
      @back_link = {:label => "quick_links.program.three_sixty_surveys_v1".translate, :link => three_sixty_my_surveys_path}
    end
    @survey_reviewer_groups = @survey.survey_reviewer_groups.includes(:reviewer_group)
    @invited_survey_reviewers = @survey_assessee.reviewers.invited.except_self.includes(:survey_reviewer_group => :reviewer_group)
    @pending_survey_reviewers = @survey_assessee.reviewers.with_pending_invites.except_self.includes(:survey_reviewer_group => :reviewer_group)
    @survey_reviewer = @survey_assessee.reviewers.new
    @show_edit_survey_response = params[:src] == "email"
  end

  def notify_reviewers
    if @survey_assessee.threshold_met? || @add_reviewer_policy.admin_managing_survey?
      @survey_assessee.send_later(:notify_pending_reviewers)
      flash[:notice] = "flash_message.three_sixty.survey_assessees.notify_reviewers_success".translate
      redirect_to root_organization_path
    else
      flash[:error] = "flash_message.three_sixty.survey_assessees.threshold_not_met_v1".translate
      redirect_to add_reviewers_three_sixty_survey_assessee_path(@survey, @survey_assessee)
    end
  end

  def survey_report
    @competency_infos = @survey_assessee.survey_assessee_competency_infos
    @question_infos = @survey_assessee.survey_assessee_question_infos
    @reviewers = @survey_assessee.reviewers.includes(:answers).group_by(&:three_sixty_survey_reviewer_group_id)
    self_reviewer = @survey_assessee.self_reviewer
    @text_answers_for_self = self_reviewer.answers.of_text_type
    @rating_answers_for_self = self_reviewer.answers.of_rating_type
    @average_reviewer_group_answer_values = @survey_assessee.average_reviewer_group_answer_values
    @average_competency_reviewer_group_answer_values = @survey_assessee.average_competency_reviewer_group_answer_values
    @question_percentiles = @survey_assessee.question_percentiles
    @competency_percentiles = @survey_assessee.competency_percentiles
    @survey_reviewer_groups = @survey.survey_reviewer_groups.excluding_self_type.includes(:reviewer_group)
    @reviewer_group_for_self = @current_organization.three_sixty_reviewer_groups.of_self_type.first
    @survey_competencies = @survey.survey_competencies.includes(:competency, :survey_questions => [:question => :survey_assessee_question_infos])
    @survey_oeqs = @survey.survey_oeqs.includes(:question)

    respond_to do |format|
      format.pdf do
        # Not globalizing to avoid special charecters.
        render :pdf => "feature.three_sixty.report.pdf_name".translate.gsub(" ", "_")
      end
    end
  end

  private

  def fetch_survey_assessees
    if params[:from_dashboard]
      unless params[:published] == "false"
        @survey_assessees = ThreeSixty::SurveyAssessee.get_es_results(@options = ThreeSixty::SurveyService.new.survey_dashboard(params, ThreeSixty::Survey::PUBLISHED, @current_organization, @current_program))
      end
      @options[:from_dashboard] = true
    end
  end

  def fetch_drafted_survey
    @survey = current_program_or_organization.three_sixty_surveys.drafted.find(params[:survey_id])
  end

  def fetch_published_survey
    @survey = @current_organization.three_sixty_surveys.published.find(params[:survey_id])
  end

  def fetch_published_survey_for_admin
    @survey = current_program_or_organization.three_sixty_surveys.published.find(params[:survey_id])
  end

  def fetch_assessee
    @survey_assessee = @survey.survey_assessees.find(params[:id])
  end

  def redirect_unless_survey_is_accessible
    survey_policy = ThreeSixty::SurveyPolicy.new(@survey)
    if survey_policy.not_accessible?
      flash[:error] = survey_policy.error_message
      redirect_to root_organization_path and return
    end
  end

  def can_add_reviewers?
    @add_reviewer_policy = ThreeSixty::AddReviewerPolicy.new(@survey_assessee, wob_member, current_user)
    @add_reviewer_policy.can_add_reviewers?
  end
end
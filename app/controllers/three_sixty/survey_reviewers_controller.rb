class ThreeSixty::SurveyReviewersController < ApplicationController
  skip_before_action :login_required_in_program, :require_program
  before_action :login_required_in_organization, :only => [:create, :destroy, :edit, :update]
  before_action :fetch_survey_and_survey_assessee, :only => [:create, :destroy, :edit, :update]
  before_action :fetch_published_survey_and_survey_assessee, :only => [:show_reviewers, :answer]
  before_action :fetch_reviewer_from_code, :only => [:show_reviewers, :answer]
  before_action :fetch_survey_reviewer_groups, :only => [:create, :edit, :update]
  before_action :fetch_survey_reviewer, :only => [:destroy, :edit, :update]
  before_action :redirect_unless_survey_is_accessible
  before_action :login_required_for_self_review, :only => [:show_reviewers, :answer]
  before_action :set_add_reviewer_policy, :only => [:create, :destroy, :edit, :update]
  allow :exec => :can_add_reviewers?, :only => [:create]
  allow :exec => :can_update_reviewer?, :only => [:destroy, :edit, :update]

  def show_reviewers
    @back_link = {:label => "quick_links.program.three_sixty_surveys_v1".translate, :link => three_sixty_my_surveys_path} if params[:view] == ThreeSixty::Survey::MY_SURVEYS
    if @survey_reviewer.for_self?
      @is_for_self = true
      if @survey_reviewer.answered? && params[:src] == 'email' && @survey.only_assessee_can_add_reviewers?
        redirect_to(add_reviewers_three_sixty_survey_assessee_path(@survey, @survey_assessee, :src => "email")) and return
      end
    else
      @no_tabs = !logged_in_organization?
    end
    fetch_survey_competencies_oeqs_and_reviewer_answers
  end

  def create
    @survey_reviewer = @survey_assessee.reviewers.create(survey_reviewers_params(:create).merge({:inviter => wob_member}))
  end

  def edit
  end

  def update
    @survey_reviewer.update_attributes(survey_reviewers_params(:update))
  end

  def destroy
    @survey_reviewer.destroy
    @no_pending_reviewers = @survey_assessee.reviewers.with_pending_invites.except_self.empty?
  end

  def answer
    ThreeSixty::SurveyAnswerService.new(@survey_reviewer).process_answers(params[:three_sixty_survey_answers]||[])
    if @survey_reviewer.for_self?
      flash[:notice] = "flash_message.three_sixty.survey_reviewers.self_answered".translate(:name => @survey_assessee.name)
      if @survey.only_assessee_can_add_reviewers?
        redirect_to add_reviewers_three_sixty_survey_assessee_path(@survey, @survey_assessee)
      else
        redirect_to root_path and return
      end
    else
      @no_tabs = !logged_in_organization?
      @survey_reviewer.update_attributes(survey_reviewers_params(:answer))
      if @survey_reviewer.valid?
        flash[:notice] = "flash_message.three_sixty.survey_reviewers.answer_success".translate(:name => @survey_assessee.name)
        redirect_to about_path
      else
        fetch_survey_competencies_oeqs_and_reviewer_answers
        flash[:error] = "flash_message.three_sixty.survey_reviewers.no_name".translate
        render :action => 'show_reviewers'
      end
    end
  end

  private

  def survey_reviewers_params(action)
    return {} if action == :answer && params[:three_sixty_survey_reviewer].blank?
    params.require(:three_sixty_survey_reviewer).permit(ThreeSixty::SurveyReviewer::MASS_UPDATE_ATTRIBUTES[action])
  end

  def fetch_survey_and_survey_assessee
    @survey = (wob_member.admin? || current_user && current_user.is_admin?) ? @current_organization.three_sixty_surveys.find(params[:survey_id]) : @current_organization.three_sixty_surveys.published.find(params[:survey_id])
    @survey_assessee = @survey.survey_assessees.find(params[:assessee_id])
  end

  def fetch_published_survey_and_survey_assessee
    @survey = @current_organization.three_sixty_surveys.published.find(params[:survey_id])
    @survey_assessee = @survey.survey_assessees.find(params[:assessee_id])
  end

  def fetch_reviewer_from_code
    @survey_reviewer = @survey_assessee.reviewers.find_by(invitation_code: params[:code])
  end

  def fetch_survey_reviewer
    @survey_reviewer = @survey_assessee.reviewers.except_self.find(params[:id])
  end

  def fetch_survey_reviewer_groups
    @survey_reviewer_groups = @survey.survey_reviewer_groups.includes(:reviewer_group)
  end

  def redirect_unless_survey_is_accessible
    @survey_policy = ThreeSixty::SurveyPolicy.new(@survey)
    if @survey_policy.not_accessible?
      if request.xhr?
        render :partial => "three_sixty/surveys/policy_warning"
      else
        flash[:error] = @survey_policy.error_message
        redirect_to about_path
      end
      return
    end
  end

  def login_required_for_self_review
    if @survey_reviewer.for_self?
      access_denied and return if !logged_in_organization?
      allow! :exec => "@survey_assessee.is_for?(wob_member)"
    end
  end

  def set_add_reviewer_policy
    @add_reviewer_policy = ThreeSixty::AddReviewerPolicy.new(@survey_assessee, wob_member, current_user)
  end

  def can_add_reviewers?
    @add_reviewer_policy.can_add_reviewers?
  end

  def can_update_reviewer?
    @add_reviewer_policy.can_update_reviewer?(@survey_reviewer)
  end

  def fetch_survey_competencies_oeqs_and_reviewer_answers
    @survey_competencies = @survey.survey_competencies.includes(:competency => :questions, :survey_questions => :question)
    @survey_oeqs = @survey.survey_oeqs.includes(:question)
    @answers = @survey_reviewer.answers
  end
end
class SurveyResponsesController < ApplicationController
  respond_to :json, :only => :data

  before_action :set_bulk_dj_priority, only: [:email_report, :export_as_xls]
  before_action :find_survey
  before_action :fetch_individual_survey_params, :only => [:show, :export_as_xls, :email_response]
  before_action :get_emails_and_users, only: [:email_response, :email_report]
  before_action :set_locales, only: [:email_response, :email_report, :download, :export_as_xls]
  before_action :compute_xls_data_for_response, only: [:export_as_xls, :email_response]
  before_action :compute_xls_data, only: [:download, :email_report]
  before_action :email_report_or_responses, only: [:email_response, :email_report]

  allow :user => :can_manage_surveys?
  allow :exec => :is_engagement_survey_accessible?

  class EmailWithProgram
    attr_accessor :program, :email

    def initialize(email, program)
      @email = email
      @program = program
    end
  end

  def index
    @survey_questions = @survey.survey_questions.includes(:translations, question_choices: :translations)
    srds = SurveyResponsesDataService.new(@survey, {})
    @total_count = srds.total_count
    @entries_in_page = [SurveyResponsesDataService::DEFAULT_PAGE_SIZE, @total_count].min
  end

  def show

  end

  def export_as_xls
    respond_to do |format|
      format.xls do
        filename = (@user.name(:name_only => true) + " " + @survey.name + " "  + @submitted_at.to_i.to_s).downcase.split(" ").join("_")
        send_data @xls_data[current_locale], :filename => "#{filename}.xls",
          :disposition => 'attachment', :encoding => 'utf8', :stream => false, :type => 'application/excel'
      end
    end
  end

  def data
    srds = SurveyResponsesDataService.new(@survey, params)
    @responses = srds.get_page_data
    @total_count = srds.total_count
    respond_to do |format|
      format.json
    end
  end

  def select_all_ids
    srds = SurveyResponsesDataService.new(@survey, params)
    render :json => {:ids => srds.response_ids.map{|id| id.to_s }, :total_count => srds.total_count}.to_json
  end

  def download
    respond_to do |format|
      format.xls do
        send_data @xls_data[current_locale], :filename => "#{@survey.name.to_html_id}.xls",
          :disposition => 'attachment', :encoding => 'utf8', :stream => false, :type => 'application/excel'
      end
    end
  end

  def email_report_popup
    @response_id = params[:response_id]
    path = @response_id.present? ? email_response_survey_response_path(@survey, @response_id, format: :js) : email_report_survey_responses_path(@survey, format: :js)
    render(:partial => "survey_responses/email_report_popup", locals: {path: path, subject: "feature.survey.email_report.subject".translate(report_name: @survey.name), content: "feature.survey.email_report.message".translate(report_name: @survey.name)})
  end

  def email_report

  end

  def email_response

  end

  private

  def get_user(email)
    member = @current_organization.members.find_by(email: email)
    member.present? ? @current_program.users.of_member(member).first : nil
  end

  def get_locale(user_or_email)
    user_or_email.is_a?(User) ? Language.for_member(user_or_email.member, @current_program) : I18n.default_locale
  end

  def fetch_individual_survey_params
    # expecting at least one answer to be present
    @response_id = params[:id]
    load_survey_response_params(@survey, @response_id)
    @user = @first_survey_answer.user
    connection_membership_role_id = nil
    if @survey.engagement_survey?
      @group = @first_survey_answer.group
      connection_membership_role =  @first_survey_answer.role
    end
    @user_roles = compute_user_roles(@user, @group, connection_membership_role)
  end

  def compute_user_roles(user, group, connection_membership_role)
    if group.present?
      connection_membership_role.present? ? connection_membership_role.customized_term.term : "-"
    else
      RoleConstants.to_program_role_names(current_program, user.role_names).join(AdminViewColumn::ROLES_SEPARATOR)
    end
  end

  def find_survey
    @survey = @current_program.surveys.find_by(id: params[:survey_id])
  end

  def is_engagement_survey_accessible?
    !@survey.engagement_survey? || @current_program.ongoing_mentoring_enabled?
  end

  def process_params_for_filter_and_sort_options(params)
    params[:sort] = {0=>{"field" => params[:responses_sort_field] || params[:email_responses_sort_field], "dir" => params[:responses_sort_dir] || params[:email_responses_sort_dir]}}
    params[:response_ids] = (params[:response_ids] || params[:email_response_ids]).split(',').map{|s| s.to_i}
    return params
  end

  def compute_xls_data
    @xls_data = {}
    @locales_needed.each do |locale|
      options = process_params_for_filter_and_sort_options(params)
      srds = SurveyResponsesDataService.new(@survey, options)
      @xls_data[locale] = SurveyResponsesXlsDataService.new(@survey, current_program, @current_organization, locale, srds.sorted_response_ids).build_xls_data_for_survey
    end
  end

  def compute_xls_data_for_response
    @xls_data = {}
    survey_content_hash = { survey_questions: @survey_questions, survey_answers: @survey_answers, user: @user, group: @group, user_roles: @user_roles, meeting: @meeting, submitted_at: @submitted_at }
    @locales_needed.each do |locale|
      export_as_xls_service = SurveyResponseExportAsXlsService.new(survey_content_hash, locale)
      @xls_data[locale] = export_as_xls_service.build_xls_data_for_survey
    end
  end

  def get_emails_and_users
    @emails_and_users = []
    emails = params[:recipients]
    emails.each do |email|
      next unless email.present?
      @emails_and_users << (get_user(email) || EmailWithProgram.new(email, program))
    end
  end

  def set_locales
    @locales_needed = []
      if @emails_and_users.present?
      @emails_and_users.each do |user_or_email|
        @locales_needed << get_locale(user_or_email)
      end
    else
      @locales_needed = [current_locale]
    end
    @locales_needed.uniq!
  end

  def get_filename(locale)
    GlobalizationUtils.run_in_locale(locale) do
      "#{@survey.name.to_html_id}.xls"
    end
  end

  def email_report_or_responses
    @emails_and_users.each do |user_or_email|
      ChronusMailer.email_report(user_or_email, current_program, params[:subject], params[:message], get_filename(get_locale(user_or_email)), {:mime_type => 'application/excel',:content => @xls_data[get_locale(user_or_email)]}).deliver_now
    end
  end
end
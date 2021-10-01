class SurveysController < ApplicationController
  include ConnectionFilters
  include MentoringModelUtils
  before_action :old_meeting_feedback_survey?, :only => [:edit_answers] 
  before_action :find_survey, :except => [:new, :create, :index]
  before_action :find_task_and_group, :only => [:edit_answers, :update_answers]
  before_action :ensure_survey_is_not_overdue, :only => [:edit_answers, :update_answers]
  before_action :get_meeting_details, :only => [:edit_answers, :update_answers]
  before_action :meeting_state_set?, :only => [:edit_answers]
  skip_before_action :back_mark_pages, :except => [:index, :report]
  before_action :check_report_access, :only => [:report]
  before_action :set_report_category, only: :report

  # Only update_answers is for non survey managers.
  allow :user => :can_manage_surveys?, :only => [:index, :new, :show, :edit, :create, :update, :destroy, :publish, :clone, :export_questions, :destroy_prompt, :edit_columns, :reminders]
  allow :exec => :meeting_details_present?, only: [:update_answers, :edit_answers]
  allow :exec => :survey_allowed_to_attend?, :only => [:update_answers]
  allow :exec => :authorize_user_for_edit_answers, :only => [:edit_answers]
  allow :exec => :can_destroy_survey?, :only => [:destroy]
  allow :exec => :is_survey_accessible?, :only => [:show, :edit, :clone, :update, :destroy, :update_answers, :edit_answers, :report, :reminders]
  allow :exec => :has_reminders?, :only => [:reminders]


  module SurveyResponseColumnGroup
    DEFAULT = "default"
    SURVEY = "survey"
    PROFILE = "profile"
  end
  SURVEY_RESPONSE_COLUMN_SPLITTER = ":"

  def index
    @surveys_by_type = Survey.by_type(@current_program)
    @surveys = @surveys_by_type.values.flatten
  end

  # New survey form
  def new
    @survey = @current_program.surveys.new
    @survey_type = params[:survey_type].to_s if params[:survey_type].to_s.in?(Survey::Type.admin_createable)
  end

  # Exports the survey report to a CSV file.
  def show
    respond_to do |format|
      format.xls do
        @filter_params = Survey::Report.get_updated_report_filter_params(params[:newparams]||{}, params[:oldparams]||{}, params[:filtertype], params[:format])
        srds = SurveyResponsesDataService.new(@survey, {:filter => {:filters => @filter_params}})
        xls_data = SurveyResponsesXlsDataService.new(@survey, current_program, @current_organization, current_locale, srds.response_ids).build_xls_data_for_survey
        send_data xls_data, :filename => "#{@survey.name.to_html_id}.xls",
          :disposition => 'attachment', :encoding => 'utf8', :stream => false, :type => 'application/excel'
      end
    end
  end

  # Edit report summary with questions list.
  def edit
    @survey_questions = @survey.survey_questions.includes({question_choices: :translations}, :translations)
  end

  def clone
    factory = Survey::CloneFactory.new(@survey, @current_program)
    new_survey = factory.clone
    new_survey.name = params[:clone_survey_name]
    if new_survey.save
      flash[:notice] = "flash_message.survey_flash.copied_successfully".translate
      redirect_to survey_survey_questions_path(new_survey)
    else
      flash.now[:error] = "flash_message.survey_flash.error_in_copying".translate
    end
  end

  def create
    @survey_type = params[:survey][:type]
    survey_params = survey_permitted_params(:create).merge(:program => @current_program)
    survey_params[:due_date] = get_en_datetime_str(survey_params[:due_date]) if survey_params[:due_date].present?
    @survey = @survey_type.constantize_only(permitted_survey_types_for_create).new(survey_params)
    csv_questions_stream = params[:survey][:questions_file]
    questions_content = csv_questions_stream.present? ? csv_questions_stream.read : nil

    render :action => "new" and return if questions_content.present? && invalid_file?(csv_questions_stream, questions_content)

    set_recipient_role_names
    set_progress_report

    ActiveRecord::Base.transaction do
      if @survey.save
        @survey.create_survey_questions(questions_content)
        flash[:notice] = csv_questions_stream.present? ?
        "flash_message.survey_flash.create_success_incase_of_questions_import".translate :
          "flash_message.survey_flash.create_success".translate
        redirect_to survey_survey_questions_path(@survey)
      else
        render :action => "new"
      end
    end
  end

  def update
    if params[:survey][:survey_response_columns].present?
      survey_response_columns = params[:survey][:survey_response_columns]
      columns_array = {}
      survey_response_columns.each do |opt|
        key, val = opt.split(SURVEY_RESPONSE_COLUMN_SPLITTER)
        (columns_array[key] ||= []) << val
      end
      @survey.save_survey_response_columns(columns_array)
      redirect_to survey_responses_path(@survey) and return
    else
      survey_params = survey_permitted_params(:update)
      survey_params[:due_date] = get_en_datetime_str(survey_params[:due_date]) if survey_params[:due_date].present?
      @survey.assign_attributes(survey_params)
      set_recipient_role_names
      set_progress_report
      @survey.save
    end

    render :action => "update", :formats => [:js]
  end

  def destroy
    @survey.destroy
    if @survey.engagement_survey?
      associated_tasks = MentoringModel::Task.where(action_item_id: @survey.id, action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY)
      if associated_tasks.present?
        closed_group_ids = current_program.groups.closed.pluck(:id)
        associated_tasks.where(group_id: closed_group_ids).destroy_all
      end
    end
    flash[:notice] = "flash_message.survey_flash.delete_success".translate
    redirect_to surveys_path
  end

  def edit_columns
    render :partial => "survey_responses/edit_columns"
  end

  # NON-RESTful actions --------------------------------------------------------

  # Page for answering all questions in the survey.
  def edit_answers
    @from_src = params[:src].try(:to_i) || Survey::SurveySource::NON_CONN_SURVEY
    show_error_flash unless survey_allowed_to_attend?
    response_id = params[:response_id].to_i if params[:response_id].present?
    response_id ||= current_user.survey_answers.drafted.where(survey_id: @survey.id).order(:last_answered_at).last.try(:response_id) if @survey.program_survey?
    options = {:survey_id => @survey.id, :user_id => current_user.id, :task_id => @task.try(:id), :response_id => response_id, :group_id => @group.try(:id), member_meeting_id: @member_meeting.try(:id), meeting_occurrence_time: @meeting_timing}.keep_if{|k,v| v.present?}
    @response = Survey::SurveyResponse.new(@survey, options)
    meeting = @member_meeting.try(:meeting)

    # Questions that erred during last attempt to update answers.
    @error_question_ids = params[:error_q_ids] || []
  end

  # Updates answers to all questions in the survey. The answers texts are passed
  # in a hash params[:survey_answers], indexed by question ids.
  #
  def update_answers
    @from_src = params[:src].try(:to_i) || Survey::SurveySource::NON_CONN_SURVEY
    response_id = params[:response_id].to_i if params[:response_id].present?
    is_draft = params[:is_draft].to_s.to_boolean
    options = {:user_id => current_user.id, :response_id => response_id, :is_draft => is_draft, :survey_id => @survey.id}
    group = @feedback_survey_group || @group
    options.merge!(:task_id => @task.id) if @task.present?
    options.merge!(:group_id => group.id) if group.present?
    options.merge!(:member_meeting_id => @member_meeting.id) if @member_meeting.present?
    options.merge!(:meeting_occurrence_time => @meeting_timing) if @meeting_timing.present?
    params[:survey_answers] = params[:survey_answers].present? ? params[:survey_answers] : {}
    options[:collect_response] = true
    @status, @response = @survey.update_user_answers(params[:survey_answers], options)
    @not_published = @response.not_published
    if @status == true && @survey.engagement_survey? && @task.present? && !is_draft
      @task.update_attributes!({:status => MentoringModel::Task::Status::DONE, :completed_date => Date.today})
      track_activity_for_ei(EngagementIndex::Activity::COMPLETE_TASK)
      group.closure_survey?(@task) ? track_activity_for_ei(EngagementIndex::Activity::COMPLETE_CLOSURE_SURVEY) : track_activity_for_ei(EngagementIndex::Activity::COMPLETE_ENGAGEMENT_SURVEY)
      share_progress_report(@survey, group, @response.id, @not_published && !is_draft)
    end

    if @from_src == Survey::SurveySource::POPUP && !is_draft
      connection_membership = @group.membership_of(current_user)
      last_overdue_survey_task = connection_membership.get_last_outstanding_survey_task if connection_membership.present?
      @last_overdue_survey = current_program.surveys.find_by(id: last_overdue_survey_task.action_item_id) if last_overdue_survey_task.present?
      @new_survey_answer_path = edit_answers_survey_path(@last_overdue_survey, :task_id => last_overdue_survey_task.id, :src => Survey::SurveySource::FLASH) if @last_overdue_survey.present?
    end

    respond_to do |format|
      format.html do
        if @status == true
          track_activity_for_ei(EngagementIndex::Activity::COMPLETE_FLASH_MEETING_SURVEY) if @survey.meeting_feedback_survey? && !is_draft
          flash[:notice] =  is_draft ? get_draft_flash(@survey, group) : get_published_flash(@from_src == Survey::SurveySource::POPUP && @last_overdue_survey.present?)
          handle_redirection(params[:meeting_area], is_draft)
        else
          failed_question = @status[1]
          flash[:error] = "flash_message.user_flash.required_fields".translate
          options = {:error_q_ids => [failed_question.id], :src => @from_src}
          options.merge!(task_id: @task.id) if @task.present?
          redirect_to edit_answers_survey_path(@survey, options)
        end
      end
      format.js do
      end
    end
  end

  # Report page for the survey. Summarizes the reponses from users and displays
  # them.
  def report
    @filter_params = Survey::Report.get_updated_report_filter_params(params[:newparams]||{}, {}, nil, params[:format], only_new_params: true)

    initialize_filter_variables

    @survey_questions = @survey.survey_questions.includes(:translations, {question_choices: [:translations, :answer_choices]}, {rating_questions: [:translations, matrix_question: {question_choices: [:translations, :answer_choices]}]} )
    srds = SurveyResponsesDataService.new(@survey, {:filter => {:filters => @filter_params}})

    @report_data = @survey.get_report(:survey_questions => @survey_questions, :response_ids => srds.response_ids)
    # Tabs should no be shown if directed from reports page
    @show_tabs = params[:report] ? false : true

    @filtered_responses_count = srds.total_count

    @response_rate_hash = set_filters_hash(srds, @filter_params, @filtered_responses_count) if @survey.show_response_rates?
    @filters_count = srds.filters_count
    
    respond_to do |format|
      format.html
      format.js
      format.pdf do
        @title = "feature.survey.header.survey_pdf_report".translate(:survey_name => @survey.name)
        render :pdf => "feature.survey.label.survey_pdf_name".translate(:survey_name => @survey.name)
      end
    end

  end

  # Publish page that guides the user how to send out the survey to users.
  def publish
  end

  def destroy_prompt
    @mentoring_models = MentoringModel::TaskTemplate.where(action_item_id: @survey.id, action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY).collect(&:mentoring_model).uniq
  end

  def export_questions
    questions = @survey.survey_questions.includes(:translations, question_choices: :translations)
    questions += @survey.matrix_rating_questions
    file_path = "#{Rails.root.to_s}/tmp/survey-#{Time.now.to_i}.csv"
    SolutionPack::Exporter.export_contents(file_path, "SurveyQuestion", questions, from_survey: true)
    send_data File.read(file_path), :type => 'text/csv; charset=iso-8859-1; header=present',
          :disposition => "attachment; filename=#{@survey.name.to_html_id}.csv"
    FileUtils.rm file_path
  end

  def reminders
    @questions_count = @survey.survey_questions.count
    @campaign = @survey.campaign
  end

  private

  def survey_permitted_params(action)
    params.require(:survey).permit(Survey::MASS_UPDATE_ATTRIBUTES[action])
  end

  def can_share_progress_report?(survey, group)
    params[:share_progress_report].to_s.to_boolean && survey.can_share_progress_report?(group)
  end

  def share_progress_report(survey, group, response_id, is_published)
    return unless can_share_progress_report?(survey, group)
    s3_file_key = generate_progress_report_pdf_content(survey, group, response_id)
    EngagementSurvey.delay.generate_and_email_progress_report_pdf(survey.id, is_published, user_id: current_user.id, group_id: group.id, program_id: current_program.id, s3_file_key: s3_file_key, locale: I18n.locale)
  end

  def generate_progress_report_pdf_content(survey, group, response_id)
    load_survey_response_params(survey, response_id)
    @hide_logo_in_pdf = true
    @title = survey.name
    html_content = render_to_string "survey_responses/_response_content", layout: 'layouts/pdf', locals: {survey_answers: @survey_answers, survey_questions: @survey_questions, submitted_at: @submitted_at, survey: survey, group: group, user: current_user,  pdf_view: true, meeting: @meeting}

    s3_prefix = survey.progress_report_s3_location

    file_name = ChronusS3Utils::S3Helper.write_to_file_and_store_in_s3(html_content, s3_prefix, file_name: survey.progress_report_file_name, file_extension: ".#{FORMAT::HTML}", skip_link_generation: true)

    return "#{s3_prefix}/#{file_name}"
  end

  def set_progress_report
    @survey.progress_report = if @survey.engagement_survey? && @current_program.share_progress_reports_enabled?
                                params[:survey][:progress_report].to_s.to_boolean
                              else
                                false
                              end
  end

  def set_recipient_role_names
    if @survey.program_survey?
      recipient_role_names = params[:survey].delete(:recipient_role_names)
      recipient_role_names.reject!(&:blank?) if recipient_role_names
      @survey.recipient_role_names = recipient_role_names
    end
  end

  def initialize_filter_variables
    @start_date, @end_date = Survey::Report.get_applied_date_range(@filter_params.values, @current_program)
    @roles = get_roles_for_filtering
    @profile_questions = @survey.program.profile_questions_for(@survey.program.roles_without_admin_role.pluck(:name), {default: false, skype: false, fetch_all: true, pq_translation_include: true})
  end

  def get_roles_for_filtering
    case @survey.type
    when Survey::Type::PROGRAM
      @current_program.roles.non_administrative
    when Survey::Type::ENGAGEMENT
      @current_program.roles.for_mentoring
    when Survey::Type::MEETING_FEEDBACK
      @current_program.roles.with_name([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
    end
  end

  def find_survey
    @survey = @current_program.surveys.find_by(id: params[:id])
    if @survey.nil?
      flash[:error] = "flash_message.survey_flash.survey_deleted".translate(:program => _Program, :administrator => _Admin)
      redirect_to_back_mark_or_default(program_root_path)
    end
  end

  def find_task_and_group
    @task = MentoringModel::Task.includes(:group).where("groups.program_id = ?", @current_program.id).references(:group).find_by(id: params[:task_id])
    @feedback_survey_group = @current_program.groups.where(id: params[:feedback_group_id]).first
    if @task.present?
      @group = @task.group
    elsif params[:group_id].present?
      @group = @current_program.groups.find_by(id: params[:group_id])
    end

    if @group.present?
      allow! :exec => "survey_allowed_to_attend?"
      fetch_current_connection_membership
      prepare_template(skip_survey_initialization: true)
    end
  end

  def get_meeting_details
    @member_meeting = MemberMeeting.includes([:member, :meeting]).find_by(id: params[:member_meeting_id])
    @meeting_timing = Meeting.parse_occurrence_time(params[:meeting_occurrence_time])
  end

  def meeting_details_present?
    @survey.meeting_feedback_survey? ? @member_meeting.present? && @meeting_timing.present? : true
  end

  def show_error_flash
    flash.now[:error] = "feature.survey.content.permission_denied".translate(recipients: @survey.formatted_recipient_role_names(:pluralize => true).downcase) if @survey.program_survey?
    flash.now[:error] = "feature.survey.content.engagement_survey_without_task_v1".translate(:A_Mentoring_Connection => _a_Mentoring_Connection.capitalize) if @survey.engagement_survey?
    flash.now[:error] = "feature.survey.content.meeting_survey_without_member_meeting".translate(:Meeting => _Meeting) if @survey.meeting_feedback_survey?
  end

  def handle_redirection(meeting_area, is_draft)
    case @survey.type
      when EngagementSurvey.name
        redirect_to(@group)
      when MeetingFeedbackSurvey.name
        if !meeting_area
          redirect_to(member_path(wob_member, meeting_id: @member_meeting.meeting_id, current_occurrence_time: @meeting_timing, :tab => MembersController::ShowTabs::AVAILABILITY)) 
        else
	        redirect_to_back_mark_or_default(program_root_path, {additional_params: "ei_src=" + "#{EngagementIndex::Src::AccessFlashMeetingArea::PROVIDE_FEEDBACK}"})
        end
      when ProgramSurvey.name
        if is_draft
          redirect_to program_root_path
        else
          redirect_to_back_mark_or_default(program_root_path)
        end
    end
  end

  def get_published_flash(flash_with_new_survey)
    if flash_with_new_survey
      "flash_message.survey_flash.answers_updated_with_next_survey_html".translate(next_survey_link: @new_survey_answer_path)
    else
      "flash_message.survey_flash.answers_updated_v1".translate(survey_name: @survey.name)
    end
  end

  def get_draft_flash(survey, group)
    flash = ["flash_message.survey_flash.draft_success".translate(survey_name: survey.name)]
    flash << "flash_message.survey_flash.response_not_sent".translate if can_share_progress_report?(survey, group)
    flash.join(" ")
  end

  # Redirect back or to home page if the survey has passed due date.
  def ensure_survey_is_not_overdue
    if @survey.program_survey? && @survey.overdue?
      flash[:error] = "flash_message.survey_flash.program_survey_expired".translate
      redirect_to program_root_path
    end
  end

  def authorize_user_for_edit_answers
    current_user.can_manage_surveys? || survey_allowed_to_attend?
  end

  def survey_allowed_to_attend?
    @survey.allowed_to_attend?(current_user, @task, @group, @feedback_survey_group, {member_meeting: @member_meeting, meeting_timing: @meeting_timing})
  end

  def check_report_access
    allow! :exec => Proc.new {current_user.can_manage_surveys? || (params[:report] && current_user.can_view_reports?)}
  end

  def can_destroy_survey?
    @survey.destroyable?
  end

  def is_survey_accessible?
    # Connection Feedback Survey is engagement-type survey. Its accessible even in v2 disabled programs.
    # So, don't tie V2 and engagement-surveys.
    @survey.present? && ((@current_program.ongoing_mentoring_enabled? && @survey.engagement_survey?) || (@survey.meeting_feedback_survey? && @current_program.calendar_enabled?) || @survey.program_survey?)
  end

  def permitted_survey_types_for_create
    permitted_types = Survey::Type.program_survey_type
    current_program.ongoing_mentoring_enabled? ? permitted_types + Survey::Type.engagement_dependent_survey_type : permitted_types
  end

  def old_meeting_feedback_survey?
    return true unless (current_program.get_old_meeting_feedback_survey.present? && params[:id].to_i == current_program.get_old_meeting_feedback_survey.id)
    member_meeting = wob_member.member_meetings.find_by(id: params[:member_meeting_id])
    survey = current_program.get_meeting_feedback_survey_for_user_in_meeting(current_user, member_meeting.meeting)
    url_options = {}
    params.each { |key, value| url_options[key.to_sym] = value }
    url_options[:id] = survey.id
    url_options[:root] ||= survey.program.root
    url_options[:src] = Survey::SurveySource::MAIL
    redirect_to participate_survey_path(url_options)
  end

  def meeting_state_set?
    ei_src = params[:ei_src]
    meeting = @member_meeting.try(:meeting)
    redirect_to meeting_path(meeting, :current_occurrence_time => params[:meeting_occurrence_time], ei_src: ei_src) and return if(@survey.meeting_feedback_survey? && meeting.present? && meeting.state.blank? && meeting.group_id.blank? && meeting.archived?)
  end

  def invalid_file?(csv_stream, questions_content)
    invalid_file = false

    if !File.size?(csv_stream.path) || File.extname(csv_stream.original_filename) != ".csv" || !valid_columns?(questions_content)
      flash[:error] = "flash_message.survey_flash.upload_valid_csv".translate
      invalid_file = true
    end
    return invalid_file
  end

  def valid_columns?(questions_content)
    if questions_content.present?
      questions_content = CSV.parse(questions_content)
      column_names = questions_content[0].compact
      return false if SurveyQuestion.attribute_names.sort != column_names.sort
    end
    return true
  end

  def set_filters_hash(srds, filter_params, filtered_responses_count)
    users_responded_count, users_responded_groups_or_meetings_count = @survey.find_users_who_responded(srds.response_ids)

    filter_params = SurveyResponsesDataService::FilterResponses.dynamic_filter_params({:filter => {:filters => filter_params}})
    overdue_responses_count, overdue_ids = @survey.calculate_overdue_responses(srds.user_ids, filter_params)

    users_overdue_count, users_overdue_groups_or_meetings_count = (@survey.engagement_survey? ? @survey.find_users_groups_with_overdue_responses(overdue_ids)  : MemberMeeting.get_members_and_meetings_count(overdue_ids))

    total_responses = filtered_responses_count + overdue_responses_count if overdue_responses_count.present?
    response_rate = Survey.calculate_response_rate(filtered_responses_count, total_responses)

    percentage_error = Survey.percentage_error(filtered_responses_count, total_responses)
    response_rate_hash = {:responses_count => filtered_responses_count, :users_responded => users_responded_count, :users_responded_groups_or_meetings_count => users_responded_groups_or_meetings_count, :overdue_responses_count => overdue_responses_count, :users_overdue => users_overdue_count, :users_overdue_groups_or_meetings_count => users_overdue_groups_or_meetings_count, :response_rate => response_rate, :percentage_error => percentage_error }
  end

  def has_reminders?
    @survey.can_have_campaigns?
  end
end
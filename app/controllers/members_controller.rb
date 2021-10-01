class MembersController < ApplicationController
  include CommonProfileIncludes
  include MentoringModelUtils
  include UserPreferencesHash
  include FirstVisitSectionCookies
  include FirstVisitSectionQuestions

  module EditSection
    GENERAL         = 'general'
    EDU_EXP         = 'edu_exp'
    SETTINGS        = 'settings'
    PROFILE         = 'profile' # Role not specified. Will be inferred from the users' role.
    NOTIFICATIONS = "notifications"
    MENTORING_SETTINGS = 'mentoring_settings'
    CALENDAR_SYNC_V2_SETTINGS = "calendar_sync_v2_settings"
  end

  module ShowTabs
    PROFILE  = "profile"
    ARTICLES = "articles"
    QA_QUESTIONS = 'qa_questions'
    QA_ANSWERS = "qa_answers"
    MANAGE_CONNECTIONS = "manage_connections"
    AVAILABILITY = "availability"
  end

  module Tabs
    PROFILE = "profile"
    SETTINGS = "settings"
    NOTIFICATIONS = "notifications"
  end

  ANSWERS_PER_SHOW_MORE = 5
  SEPARATOR = ", "

  skip_action_callbacks_for_autocomplete :auto_complete_for_name, :auto_complete_for_name_or_email
  before_action :flash_keep, :only => [:account_settings]
  skip_before_action :require_program, :login_required_in_program, :except => [:edit, :update, :update_answers, :fill_section_profile_detail, :answer_mandatory_qs, :update_mandatory_answers]

  before_action :login_required_at_current_level, :except => [:upload_answer_file]
  before_action :force_back_mark, :only => :edit
  allow :exec => :check_organization_profile_enabled_for_dormant_members, :only => [:show]
  before_action :load_member_and_check_account_settings_update_access, :only => [:update_settings, :update_notifications]
  before_action :load_member_and_check_profile_update_access, :only => [:edit, :update, :update_answers, :skip_answer, :fill_section_profile_detail]
  before_action :fetch_profile_member, :only => [:show, :destroy, :destroy_prompt, :skip_answer]
  before_action :add_custom_parameters_for_newrelic, :only => [:show, :edit]
  before_action :get_profile_user_and_member, :only => [:answer_mandatory_qs, :update_mandatory_answers]
  after_action :expire_profile_cached_fragments, :only => [:update, :update_answers, :update_mandatory_answers]
  before_action :set_is_admin_view, :only => [:update, :update_settings, :update_notifications, :update_answers, :show, :account_settings]
  allow :exec => :check_admin_access, :only => [:invite_to_program, :update_state, :destroy, :destroy_prompt]
  after_action :track_profile_view, only: [:show]

  allow :exec => "wob_member.admin?", only: [:add_member_as_admin]
  allow :exec => :can_manage_locked_out_members?, :only => [:account_lockouts, :reactivate_account]
  allow :exec => :check_pdf_access, :only => [:show]

  # Profile view of members.
  def show
    @view = params[:view] ? params[:view].to_i : Group::View::DETAILED
    @profile_tab = (logged_in_at_current_level? && params[:tab]) || MembersController::ShowTabs::PROFILE
    # redirecting to profile tab from article tab if at org level as article is deprecated from org level.
    @profile_tab = ShowTabs::PROFILE if !program_view? && @profile_tab == ShowTabs::ARTICLES
    ProgramsListingService.fetch_programs self, @current_organization do |all_programs|
      all_programs.ordered.includes(:translations)
    end
    @dormant_view = @current_organization.standalone? && @profile_member.users.empty?
    @global_profile_view = (@dormant_view || organization_view?)
    @logged_in_program_and_not_dormant_view = (logged_in_program? && !@dormant_view)
    if params[:src] == 'quick_connect_box'
      mentor_profile_ei_src = EngagementIndex::Src::VisitMentorsProfile::HOME_PAGE_RECOMMENDATIONS
      @back_link = {:label => 'feature.meetings.content.all_mentors'.translate(:Mentors => _Mentors), :link => users_path(src: EngagementIndex::Src::BrowseMentors::MENTOR_PROFILE_PAGE)}
    elsif params[:src] == MentorRecommendation::Source::NEW_PAGE
      @back_link = {:label => "feature.mentor_recommendation.back_link".translate(connection: _mentoring_connection), :link => new_mentor_request_path}
    elsif params[:src] == EngagementIndex::Src::BrowseMentors::MENTOR_LISTING_PAGE
      mentor_profile_ei_src = params[:src]
    elsif params[:src] == EngagementIndex::Src::VisitMentorsProfile::CAMPAIGN_WIDGET_RECOMMENDATIONS
      mentor_profile_ei_src = EngagementIndex::Src::VisitMentorsProfile::CAMPAIGN_WIDGET_RECOMMENDATIONS
      @open_connect_popup = params[:open_connect_popup]
    else
      @back_link = {:link => session[:back_url] } if session[:back_url].present?
    end

    # If viewed from within a program, fetch the User.
    fetch_profile_user unless @global_profile_view

    @profile_member_or_user = @profile_user || @profile_member

    allow! :exec => lambda {@profile_user.visible_to?(current_user)} if logged_in_program? && @profile_user

    @is_self_view = (wob_member == @profile_member)
    @is_viewing_admin_profile = (@global_profile_view ? @profile_member.admin? : @profile_user.is_admin_only?)
    @is_student_view = logged_in_at_current_level? ? current_user_or_member.is_student? : false
    is_mentor_view = logged_in_at_current_level? ? current_user_or_member.is_mentor? : false

    @is_owner_mentor  = @profile_member_or_user.is_mentor?
    @is_owner_student = @profile_member_or_user.is_student?
    @is_owner_admin_only = !(@is_owner_mentor || @is_owner_student) && @is_viewing_admin_profile
    pdf_request = (request.format == Mime[:pdf])

    @show_connections = @logged_in_program_and_not_dormant_view && current_user.can_manage_connections? && @profile_user.roles.for_mentoring.exists?
    @show_articles = @logged_in_program_and_not_dormant_view && @current_program.articles_enabled? && @profile_user.can_write_article? && current_user.can_view_articles?
    @show_meeting_requests = @logged_in_program_and_not_dormant_view && @current_program.calendar_enabled? && current_user.is_mentor?
    @show_connection_requests = @logged_in_program_and_not_dormant_view && @current_program.ongoing_mentoring_enabled? && current_user.is_mentor? && @current_program.matching_by_mentee_alone?
    @show_answers = @logged_in_program_and_not_dormant_view && @current_program.qa_enabled? && (@profile_member_or_user.can_ask_question? || @profile_member_or_user.can_answer_question?) && current_user.can_view_questions?
    @show_meetings = @logged_in_program_and_not_dormant_view && @is_self_view && @current_program.is_meetings_enabled_for_calendar_or_groups? && !@profile_user.is_admin_only? && @profile_tab != MembersController::ShowTabs::AVAILABILITY
    @show_tags = @logged_in_program_and_not_dormant_view && @is_admin_view && @current_organization.has_feature?(FeatureName::MEMBER_TAGGING)
    @show_connect = !@is_self_view && program_view? && ((is_mentor_view && @is_owner_student) || (@is_student_view && @is_owner_mentor))
    prepare_profile_side_pane_data if !@dormant_view

    if is_profile_show_tab?
      if !@global_profile_view
        track_activities_for_show(mentor_profile_ei_src, @profile_user.id)
        if can_set_available_slots?
          @current_and_next_month_session_slots = current_and_next_month_session_slots
        end
        @can_see_match_label = can_see_match_label?
        @can_see_match_score = can_see_match_score?(current_user)
        @show_meeting_availability = can_show_meeting_availability?
        @program_questions_for_user = fetch_program_questions_for_user(@current_program, @profile_user, current_user, @current_organization.skype_enabled?, @is_owner_admin_only)
      elsif @global_profile_view && @current_organization.org_profiles_enabled?
        @all_answers = @profile_member.profile_answers.includes([:profile_question, :answer_choices, :educations, :experiences, :publications, :location]).group_by(&:profile_question_id)
        @program_questions_for_user = @current_organization.profile_questions_with_email_and_name - [@current_organization.name_question]
      end
    elsif @profile_tab == ShowTabs::ARTICLES && @show_articles
      includes_list = [:article_content => [:list_items, :labels]]
      @user_articles = @profile_user.articles.published.order(Article::DEFAULT_SORT_FIELD).includes(includes_list)
      @comments_count_hash = Article::Publication.where(article_id: @user_articles.collect(&:id), program_id: current_program.id).joins(:comments).group("article_publications.article_id").count
      @drafts = @profile_member.articles.drafts.includes(includes_list) if @is_self_view
    elsif @profile_tab == ShowTabs::QA_QUESTIONS && @show_answers
      @qa_questions = @profile_member_or_user.qa_questions.includes([:user, :program])
    elsif @profile_tab == ShowTabs::QA_ANSWERS && @show_answers
      @qa_answered_questions = @profile_member_or_user.answered_qa_questions.includes([ :program,  :user => {:member => :profile_picture}]).all
      qa_answered_questions_ids = @qa_answered_questions.collect{|q| q.id}
      user_ids = program_view? ? [@profile_user.id] : @profile_member.users.collect(&:id)
      # don't select or use qa_answers.id, score, updated_attributes - It returns incorrect results in next query
      latest_qa_answer_by_user = QaAnswer.select("qa_answers.user_id, qa_answers.qa_question_id, SUBSTRING_INDEX(GROUP_CONCAT(content ORDER BY created_at DESC), ',', 1) content, MAX(created_at) created_at")
                                                                    .where(:qa_question_id => qa_answered_questions_ids, :user_id => user_ids )
                                                                    .group(:qa_question_id)
                                                                    .includes(:user => {:member => :profile_picture})
      @latest_qa_answer = Hash.new
      latest_qa_answer_by_user.each{|answer| @latest_qa_answer[answer.qa_question_id] = answer}
      @qa_answers_count = QaAnswer.where(:qa_question_id => qa_answered_questions_ids, :user_id => user_ids)
                                                            .group(:qa_question_id).count
    elsif @profile_tab == ShowTabs::MANAGE_CONNECTIONS && @show_connections
      initialize_status_filters
      @filter_field = GroupsController::StatusFilters::MAP[@status_filter]
      @groups_scope = @profile_user.groups
      @groups = @groups_scope.with_status(@filter_field).includes([:program, {:mentors => [:roles, :member], :students => [:roles, :member]}]).order("#{get_groups_sort_field} DESC")
      @connection_questions = Connection::Question.get_viewable_or_updatable_questions(@current_program, true) if [Group::Status::DRAFTED, Group::Status::PENDING, Group::Status::PROPOSED, Group::Status::REJECTED].include?(@filter_field)
      @from_member_profile = true
    elsif @profile_tab == ShowTabs::AVAILABILITY && @current_program.is_meetings_enabled_for_calendar_or_groups?
      @source = params[:src]
      @past_meetings_selected = params[:meetings_tab] == MeetingsController::MeetingsTab::PAST
      @meeting_id = program.meetings.where(id: params[:meeting_id]).select(:id).first.try(:id).try(:to_s)
      valid_meeting = populate_feedback_id(params, current_program)
      if valid_meeting
        if @is_self_view
          @from_my_availability = true
          @outside_group = true
          meetings_to_be_held, archived_meetings = Meeting.recurrent_meetings(Meeting.get_meetings_for_view(nil, nil, wob_member, @current_program, {from_my_availability: @from_my_availability}))
          @meetings_to_be_held, @archived_meetings = Meeting.paginated_meetings(meetings_to_be_held, archived_meetings, params, wob_member)
        end
        @load_feedback_popup = @meeting_id && params[:feedback]
        @can_current_user_create_meeting = current_user.can_create_meeting?(@current_program)
        @ei_src = EngagementIndex::Src::UpdateMeeting::MEMBER_MEETING_LISTING
      else
        flash[:error] = "feature.meetings.flash_message.inactive_meeting".translate(meeting: _meeting)
        redirect_to root_path and return
      end
    end

    initialize_unanswered_questions

    state_based_flash_message = get_state_based_flash_message
    flash.now[:error] = state_based_flash_message if state_based_flash_message.present?

    # For viewing any profile other than admin-only users, select appropriate tab.
    if !@global_profile_view && !@is_self_view && !@is_viewing_admin_profile
      if @is_owner_mentor
        activate_tab(tab_info[_Mentors])
      elsif @is_owner_student
        activate_tab(tab_info[_Mentees])
      end
    end

    if params[:show_reviews] && current_program.coach_rating_enabled? && current_user && current_user.can_view_coach_rating?
      @show_reviews = true
    end

    if params[:show_mentor_request_popup] && current_user && @profile_user
      @show_mentor_request_popup, @invalid_mentor_request_flash = current_user.can_send_mentor_request_to_mentor_with_error_flash?(@profile_user, {:Mentor => _Mentor, :mentoring => _mentoring, :meetings => _meetings, :mentor => _mentor, :mentoring_connection => _mentoring_connection, :mentors => _mentors, :program => _program, :admin => _admin, :mentoring_connections => _mentoring_connections})
      @mentor_request_url = new_mentor_request_path(mentor_id: @profile_user.id, format: :js, src: params[:src]) if @show_mentor_request_popup
    end

    set_profile_download_pdf_name if @profile_user.present?

    if !@global_profile_view && pdf_request
      prawnto :filename => @pdf_name, :inline => true
      respond_to do |format|
        format.html {}
        format.pdf { render :layout => false }
      end
    elsif @is_owner_mentor && params[:archived_page].blank? && params[:upcoming_page].blank?
      set_user_preferences_hash if show_favorite_ignore_links?
      @favorite_user_ids = params[:favorite_user_ids]
      render :action => 'show_mentor' # Special template for mentor profile.
    end
    track_activity_for_ei(EngagementIndex::Activity::VIEW_SELF_PROFILE) if @is_self_view
  end

  def edit
    set_edit_instance_variables
    prepare_profile_side_pane_data
    initialize_unanswered_questions
    # Program view. Load only program specific questions.
    @program_questions_for_user = get_program_questions_for_user
    @profile_sections = @program_questions_for_user.reject { |q| q.section.default_field? }.collect(&:section).uniq.sort_by(&:position) unless @is_profile_completion

    fill_all_answers
    @grouped_role_questions = @current_program.role_questions_for(@profile_user.role_names, user: current_user, include_privacy_settings: true).role_profile_questions.group_by(&:profile_question_id)
    set_first_visit_section if @is_first_visit
    # When a pending user visits the edit action
    if @is_first_visit && @profile_user.profile_pending? && params[:landing_directly]
      incomplete_roles = @profile_user.profile_incomplete_roles
      if incomplete_roles.empty? && @program_questions_for_user.present?
        flash.now[:warning] = "flash_message.user_flash.edit_profile_page_for_direct_landing_just_publish".translate
      elsif @program_questions_for_user.blank?
        redirect_when_no_sections_to_show and return
      else
        incomplete_roles -= @current_program.roles.administrative.collect(&:name)
        @role_str = RoleConstants.human_role_string(incomplete_roles, program: @current_program)
        role_str_downcase = RoleConstants.human_role_string(incomplete_roles, program: @current_program, no_capitalize: true)
        flash.now[:warning] = "flash_message.user_flash.edit_profile_page_for_direct_landing".translate(role: role_str_downcase)
      end
    end

    if @section == EditSection::PROFILE
      if @is_first_visit || params[:src] == UserConstants::PROFILE_UPDATE_PROMPT
        # Disable profile update prompt (by setting the DISABLE_PROFILE_PROMPT
        # cookie) for
        # 1. all new users
        # 2. If the user comes to the edit page from the profile update prompt
        profile_update_timestamp = @current_program.profile_questions_last_update_timestamp(@profile_user).to_s
        cookies[DISABLE_PROFILE_PROMPT] = { :value => profile_update_timestamp, :expires => ProfileConstants::PROFILE_CHANGE_PROMPT_PERIOD.from_now }
      end
      if @program_questions_for_user.blank?
        if @is_first_visit
          redirect_to program_root_path
          return
        else
          redirect_to_back_mark_or_default program_root_path
          return
        end
      end
    end

    # For viewing any profile other than admin-only users, select appropriate tab.
    if !@is_self_view && !@is_viewing_admin_profile
      if @is_owner_mentor
        activate_tab(tab_info[_Mentors])
      elsif @is_owner_student
        activate_tab(tab_info[_Mentees])
      end
    end

    @program_custom_term = {}
    @program_custom_term[:mentoring_connection_term] = @profile_user.program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM)
    @profile_user.program.roles.each do |role|
      @program_custom_term["role_term_#{role.name}_name".to_sym] = @profile_user.program.term_for(CustomizedTerm::TermType::ROLE_TERM, role.name)
    end

    if @is_first_visit
      chronus_ab_counter_inc("Step 0", ProgramAbTest::Experiment::SIGNUP_WIZARD, !is_ie_less_than?(9)) if @section == EditSection::GENERAL
      render :edit_first_visit
    end

    set_profile_download_pdf_name if @profile_user.present?
    @ei_src = params[:ei_src]
    track_activity_for_ei(EngagementIndex::Activity::EDIT_PROFILE, context_place: @ei_src) if @is_self_view 
  end

  def answer_mandatory_qs
    fill_all_answers
    get_pending_profile_questions
    get_grouped_required_role_questions
  end

  # Entry points are the following use cases.
  #
  # 1. Profile update
  # 2. Notification settings update.
  #
  # ==== Params
  # first_visit ::  1, if profile update by user just after signup i.e., 'Create Profile' page.
  #
  def update
    @section ||= params[:section]
    @is_profile_completion = (params[:prof_c]=="true")
    @error_message = []

    # Commenting out the XHR requirement for now for testing purposes
    if (params[:user] && params[:user][:admin_notes]) # && request.xhr?)
      return update_admin_notes
    end

    member_attrs = params[:member] if params[:member]

    @is_self_view = current_user == @profile_user
    @is_admin_editing = !@is_self_view

    picture = member_attrs.delete(:profile_picture) if member_attrs && @is_first_visit
    @profile_member.build_profile_picture(profile_picture_params(picture)) if picture && (picture[:image].present? || picture[:image_url].present?)
    permitted_member_attrs = member_attrs.present? ? member_params(:update) : {}
    @profile_member.attributes = permitted_member_attrs
    @profile_member.email_changer = wob_member
    update_user_settings if params[:user] && params[:user][:user_settings]

    mentoring_mode = params[:user].delete(:mentoring_mode).to_i if params[:user].present? && params[:user][:mentoring_mode].present?
    @profile_user.mentoring_mode = mentoring_mode if program_view? && mentoring_mode.present? && @current_program.consider_mentoring_mode? && @profile_user.is_mentor?

    permitted_user_attrs = params[:user].present? ? user_params(:update, params[:user]) : {}
    @profile_user.attributes = permitted_user_attrs if program_view?

    handle_mentoring_mode_change(@current_program || @profile_user.program)

    # TODO this is turning out to be costly as @profile_user.save will trigger delta indexing
    @profile_user.updated_by_admin = @is_admin_view
    if @profile_member.save && (!@profile_user || (!@settings_error_case && @profile_user.save))
      @successfully_updated = true
      update_profile_answers
      initialize_unanswered_questions
    else
      # When mentor enters number less than the number of students in his active groups, we show this error
      @settings_flash_error = (@error_message.present? && @error_message.join(" ")) || get_error_flash_messages(@profile_user)

      if request.xhr?
        @error_case = true
      else
        serialize_to_session(@profile_member)
        # When mentor enters number less than the number of students in his active groups, we show this error
        flash[:error] = @settings_flash_error if @settings_flash_error
        redirect_to edit_member_path(@profile_member, first_visit: @is_first_visit, section: @section)
      end
    end
  end

  def fill_section_profile_detail
    @profile_user   = deserialize_from_session(User, @profile_user)
    @profile_member = deserialize_from_session(Member, @profile_member, :admin)

    @is_self_view             = current_user == @profile_user
    @is_admin_view            = current_user.is_admin?

    @is_viewing_admin_profile = @profile_user.is_admin_only?
    @is_owner_mentor          = @profile_user.is_mentor?
    @is_owner_student         = @profile_user.is_student?
    @allowed_individual_slot_duration = @current_program.get_calendar_slot_time

    @section_for = @current_organization.sections.find_by(id: params[:section_id].to_i)
    @profile_questions = @current_program.profile_questions_for(@profile_user.role_names, {:default => false, :skype => @current_organization.skype_enabled?, user: current_user, pq_translation_include: true}).select{|q| q.section_id == @section_for.id}.sort_by(&:position)
    fill_all_answers
    @grouped_role_questions = @current_program.role_questions_for(@profile_user.role_names, user: current_user, include_privacy_settings: true).role_profile_questions.group_by(&:profile_question_id)
    @last_section = params[:last_section]
    @file_present = @profile_questions.collect(&:question_type).include?(ProfileQuestion::Type::FILE)
  end

  def destroy
    allow! exec: Proc.new { wob_member.can_remove_or_suspend?(@profile_member) }

    member_name = @profile_member.name
    @profile_member.destroy
    flash[:notice] = "flash_message.user_flash.user_destroy_v1".translate(user: member_name)
    redirect_to root_path
  end

  def destroy_prompt
    @programs_statistic = []
    @profile_member.users.each do |user|
      @programs_statistic << {
        :articles_count           => user.articles.count,
        :qa_questions_count       => user.qa_questions.count,
        :qa_answers_count         => user.qa_answers.count,
        :active_connections_count => user.groups.active.count,
        :closed_connections_count => user.groups.closed.count,
        :user                     => user,
        :program                  => user.program
      }
    end
  end

  def update_settings
    if params[:user]
      @error_message = []
      program = @current_program || @profile_user.program
      columns = [:program_notification_setting]
      columns << :group_notification_setting if program.ongoing_mentoring_enabled?
      columns << :max_connections_limit if !program.consider_mentoring_mode? || User::MentoringMode.ongoing_sanctioned.include?(params[:user][:mentoring_mode] ? params[:user][:mentoring_mode].to_i : @profile_user.mentoring_mode )
      columns << :mentoring_mode if program.consider_mentoring_mode? && @profile_user.is_mentor?
      @profile_user.attributes = user_update_settings_params(params[:user], columns)
      # max_connections_limit has a very specific error case depending on the number of students etc.
      # So, handling this separately; for other exceptions an airbrake will be raised.
      handle_mentoring_mode_change(program)
      save_and_handle_user_errors(program)
      update_user_settings if params[:user][:user_settings]
      notify_user_to_update_availability
    end
    if params[:member]
      @profile_member.attributes = member_params(:update_settings)
      @alert_availability_setting = (@profile_member.changes[:will_set_availability_slots] == [false, true])
      @profile_member.save!
      @profile_user.reload if @profile_user
    end
    if params[:sign_out_of_all_other_sessions]
      @profile_member.sign_out_of_other_sessions(request.session_options[:id], cookies[:auth_token], is_mobile_app? && cookies.signed[MobileV2Constants::MOBILE_V2_AUTH_TOKEN])
    end
  end

  def notify_user_to_update_availability
    return unless @profile_user.saved_changes[:mentoring_mode].present? && @profile_user.can_set_availability? && params[:acc_settings].blank?

    @notify_user_if_unavailable = true
    @is_connection_limit_zero = @profile_user.program.allow_mentor_update_maxlimit? && @profile_user.max_connections_limit.zero?
    @is_meeting_limit_zero = !@profile_user.is_max_capacity_setting_initialized? || @profile_user.user_setting.max_meeting_slots.zero?
  end

  def update_notifications
    setting_enabled = params[:value].to_boolean
    if setting_enabled
      notification_setting_object = @profile_user.user_notification_settings.find_by(notification_setting_name: params[:setting_name])
      if notification_setting_object
        notification_setting_object.update_attributes!(:disabled => false)
      end
    else
      notification_setting_object = @profile_user.user_notification_settings.find_or_initialize_by(notification_setting_name: params[:setting_name])
      notification_setting_object.update_attributes!(:disabled => true)
    end
    head :ok
  end


  def update_time_zone
    wob_member.update_attributes!(time_zone: params[:member][:time_zone])
    redirect_to_back_mark_or_default program_root_path
  end

  def update_mandatory_answers
    answers = params[:profile_answers]
    if update_user_answers(@profile_user, answers)
      track_activity_for_ei(EngagementIndex::Activity::UPDATE_PROFILE)
      handle_profile_update(@profile_user, answers.keys)
      @profile_user.reload
      @unanswered_mandatory_profile_qs = get_pending_profile_questions
      if @unanswered_mandatory_profile_qs.present?
        get_grouped_required_role_questions
      else
        @back_url = raw(session[:back_url])
      end
      profile_question_ids = answers.keys.map(&:to_i)
      User.delay.clear_invalid_answers(@profile_user.id, @profile_user.class, @profile_user.program.organization.id, profile_question_ids)
    else
      @error_message = "flash_message.user_flash.required_fields".translate
    end
    fill_all_answers
  end

  # This complements UsersController#edit, profile view.
  def update_answers
    @is_profile_completion = (params[:prof_c]=="true")
    @section_updated = @current_organization.sections.find(params[:section_id]) unless @is_first_visit
    update_profile_answers
    initialize_unanswered_questions
  end

  def upload_answer_file
    member_id = ('new' == params[:id]) ? 'new' : @current_organization.members.find(params[:id]).id
    question_id = params[:question_id]
    question = @current_organization.profile_questions.find(question_id)
    @file_uploader = FileUploader.new(question.id, member_id, params[:profile_answers][question.id.to_s], base_path: ProfileAnswer::TEMP_BASE_PATH, max_file_size: AttachmentSize::END_USER_ATTACHMENT_SIZE)
    @file_uploader.save
  end

  def update_state
    @member = @current_organization.members.find(params[:id])

    case params[:new_state].to_i
    when Member::Status::SUSPENDED
      allow! exec: Proc.new { wob_member.can_remove_or_suspend?(@member) }
      @member.suspend!(wob_member, params[:state_change_reason])
      flash[:notice] = "flash_message.user_flash.membership_suspended_v1".translate(member: @member.name, programs: _programs)
    when Member::Status::ACTIVE
      @member.reactivate!(wob_member)
      flash[:notice] = "flash_message.user_flash.membership_reactivated_v2".translate(member: @member.name)
    end
    redirect_back(fallback_location: root_path)
  end

  #
  # Autocomplete for member. Returns "name <email>" pairs as response.
  #
  # ==== Params
  # * <tt>search</tt> the autocomplete query
  #
  def auto_complete_for_name
    # Restrict to the programs the member belongs to and group by the member
    # so as to avoid getting duplicates.
    options = get_dormant_member_search_options
    if params[:filter].present?
      @members_json = get_members_field_for_filters_autocomplete(params, options)
    else
      options[:with].merge!({state: [Member::Status::ACTIVE, Member::Status::DORMANT]}) unless params[:show_all_members] == "true"
      @members = Member.get_filtered_members(params[:search].strip, options.merge(match_fields: ["name_only.autocomplete"]))
      flash.keep
    end
    respond_to do |format|
      format.json { render :json => fetch_json_objects_for_autocomplete(params)  }
    end
  end

  def auto_complete_for_name_or_email
    # Restrict to the programs the member belongs to and group by the member
    # so as to avoid getting duplicates.
    options = get_dormant_member_search_options
    options[:with].merge!(get_program_ids_to_filter_for_autocomplete)
    @members = Member.get_filtered_members(params[:search].strip, options.merge(match_fields: ["name_only.autocomplete", "email.autocomplete"]))
    respond_to do |format|
      format.json {render :json => @members.map(&:name_with_email).to_json}
      format.all {render :layout => false}
    end
  end

  # Account settings page
  def account_settings
    @member = wob_member
    deserialize_from_session(Member, @member, :admin)
  end

  def invite_to_program
    if params[:role].blank? || (@role_names = params[params[:role]]).blank?
      flash[:error] = "flash_message.program_invitation_flash.roles_empty".translate
      redirect_to member_path(@member) and return
    end
    role_type = ProgramInvitation::RoleType::STRING_TO_TYPE[params[:role]] || ProgramInvitation::RoleType::ASSIGN_ROLE
    @member = @current_organization.members.find(params[:member_id])
    @program = @current_organization.programs.find(params[:program_id])
    invitor = wob_member.user_in_program(@program)
    invited = @program.invite_member_for_roles(@role_names, invitor, @member, params[:message], role_type, locale: current_locale)

    flash[:notice] = if invited
      click_here = view_context.link_to("flash_message.program_invitation_flash.click_here".translate, program_invitations_path(:root => @program.root))
      "flash_message.user_flash.member_invite_to_program_success".translate(member: h(@member.name), program: h(@program.name)).html_safe + " " + "flash_message.program_invitation.click_here_to_view_invitations_html".translate(click_here: click_here)
    else
      "flash_message.user_flash.member_already_exist_in_program".translate(member: @member.name, program: @program.name)
    end
    redirect_to member_path(@member)
  end

  def account_lockouts
    @locked_out_members = @current_organization.get_locked_out_members
  end

  def reactivate_account
    member = @current_organization.members.find(params[:id])
    member.reactivate_account!
    @locked_out_members = @current_organization.get_locked_out_members
  end

  def add_member_as_admin
    member = @current_organization.members.find(params[:id])
    if params[:program_id] == "-1"
      member.promote_as_admin!
      flash[:notice] = "flash_message.organization_admin_flash.promoted_v1".translate(member: member.name(name_only: true), admins: _admins)
    else
      program = @current_organization.programs.find(params[:program_id])
      promoted_by = wob_member.user_in_program(program)
      program.create_or_promote_user_as_admin(member, promoted_by)
      flash[:notice] = "flash_message.admin_flash.promoted_v1".translate(member: member.name(name_only: true), admins: _admins)
    end
    redirect_to member_path(member)
  end

  def get_invite_to_program_roles
    @program = @current_organization.programs.find(params[:program_id])
    @user = wob_member.user_in_program(@program)
  end

  def skip_answer
    @home_page = params[:home_page]
    if params[:profile_picture]
      unless @profile_member.profile_picture.present?
        profile_picture = @profile_member.build_profile_picture
        profile_picture.not_applicable = true
        profile_picture.save!
      end
    else
      @question = @current_organization.profile_questions.find(params[:question_id])
      unless @profile_member.answer_for(@question).present?
        profile_answer = ProfileAnswer.new(:ref_obj_id => @profile_member.id, :ref_obj_type => Member.to_s, :profile_question => @question)
        profile_answer.user_or_membership_request = @profile_user
        profile_answer.not_applicable = true
        profile_answer.save!
      end
    end
  end

  private

  def get_program_ids_to_filter_for_autocomplete
    return { "users.program_id" => [@current_program.id] } if @current_program.present?
    { "users.program_id" => wob_member.programs.pluck(:id) }
  end

  def get_program_questions_for_user
    @current_program.profile_questions_for(@profile_user.role_names, {:default => false, :skype => @current_organization.skype_enabled?, user: current_user, pq_translation_include: true})
  end

  def redirect_when_no_sections_to_show
    handle_profile_answers_update(@profile_user)
    handle_last_section_redirect_on_first_visit(@profile_user, @section, @is_first_visit)
  end

  def set_first_visit_section
    set_all_section_titles
    answered_profile_questions = @profile_member.answered_profile_questions
    @program_questions_for_user = handle_answered_and_conditional_questions(@profile_member, @program_questions_for_user, answered_profile_questions)
    remove_sections_filled_from_cookies
    compute_first_visit_section
  end

  def remove_sections_filled_from_cookies
    set_sections_filled_from_cookies
    @program_questions_for_user = @program_questions_for_user.select{|q| !@sections_filled.include?(q.section_id.to_s)} if @sections_filled.present?
  end

  def compute_first_visit_section
    default_section_questions = @program_questions_for_user.select{|q| q.section.id == @current_organization.default_section.id }
    @section = default_section_questions.blank? ? MembersController::EditSection::PROFILE : MembersController::EditSection::GENERAL unless params[:section].present?
  end

  def set_edit_instance_variables
    @is_profile_completion = params[:prof_c].to_s.to_boolean && !@is_first_visit
    @skip_scrolling = params[:skip_scrolling].to_s.to_boolean
    @scroll_to = params[:scroll_to]
    @edit_view = true

    set_edit_instance_user_member

    @is_self_view = current_user == @profile_user
    @is_admin_view = current_user.is_admin?
    
    set_edit_instance_section_and_back_link
    set_edit_instance_owner_src_and_slot_duration
  end

  def set_edit_instance_user_member
    # If viewed from within a program, fetch the User.
    @profile_user   = deserialize_from_session(User, @profile_user)
    # Deserialize Profile member in order to display errors if any on member object
    @profile_member = deserialize_from_session(Member, @profile_member, :admin)
  end

  def set_edit_instance_section_and_back_link
    # Default to the General section.
    @section = params[:section] || EditSection::GENERAL
    @back_link = {:link => session[:back_url] } if session[:back_url].present? && !@is_first_visit
  end

  def set_edit_instance_owner_src_and_slot_duration
    @is_viewing_admin_profile = @profile_user.is_admin_only?
    @is_owner_mentor          = @profile_user.is_mentor?
    @is_owner_student         = @profile_user.is_student?
    @allowed_individual_slot_duration = @current_program.get_calendar_slot_time
    @ei_calendar_connect_src = params[:ei_calendar_connect_src] || EngagementIndex::Src::ConnectCalendar::EDIT_PROFILE_SETTINGS
  end

  def get_pending_profile_questions
    role_names = @profile_user.role_names
    @pending_profile_questions = @profile_user.profile_incomplete_questions(role_names, @current_program)

    @pending_profile_questions << get_child_qs_in_the_same_section(role_names)

    @pending_profile_questions = @pending_profile_questions.flatten.uniq
  end

  def get_child_qs_in_the_same_section(role_names)
    all_profile_questions = @current_program.role_questions_for(role_names, user: @profile_user).role_profile_questions.includes(:profile_question => :translations).collect(&:profile_question).uniq
    additional_pending_profile_questions = []
    @pending_profile_questions.each do |q|
      additional_pending_profile_questions << get_dependent_questions_tree_in_same_section(all_profile_questions, q.dependent_questions_tree)
    end
    additional_pending_profile_questions
  end

  def get_dependent_questions_tree_in_same_section(all_profile_questions, dependent_question_ids)
    rejected_questions = []
    dependent_questions = all_profile_questions.select{|q| dependent_question_ids.include?(q.id)}
    dependent_questions.each do |q|
      rejected_questions << q.dependent_questions_tree if q.conditional_question.present? && q.section_id != q.conditional_question.section_id
    end
    dependent_questions.reject!{|q| rejected_questions.flatten.include?(q.id)}
    dependent_questions
  end

  def get_grouped_required_role_questions
    @grouped_role_questions = @current_program.role_questions_for(@profile_user.role_names, user: @profile_user).role_profile_questions.group_by(&:profile_question_id)
  end

  def view_requestors_ei_activity?
    @side_pane_requests_count > 0 || (@is_student_view && @new_mentor_offers.present? && @new_mentor_offers.from_mentor(@profile_user).count > 0) 
  end

  def view_mentors_ei_activity?
    @is_owner_mentor && !@is_self_view && @is_student_view
  end

  def member_params(action)
    params.require(:member).permit(Member::MASS_UPDATE_ATTRIBUTES[action])
  end

  def show_favorite_ignore_links?
    @show_favorite_ignore_links = program_view? && @current_user.allowed_to_ignore_and_mark_favorite? && !@is_self_view
  end

  def fill_all_answers(profile_member = @profile_member)
    @all_answers = profile_member.profile_answers.includes([{profile_question: [:section]}, :answer_choices, :location, :publications, :experiences, :educations]).group_by(&:profile_question_id)
  end

  def get_groups_sort_field
    case @status_filter
    when GroupsController::StatusFilters::Code::ACTIVE, GroupsController::StatusFilters::Code::INACTIVE, GroupsController::StatusFilters::Code::CLOSED, GroupsController::StatusFilters::Code::ONGOING, GroupsController::StatusFilters::Code::PUBLISHED
      "published_at"
    when GroupsController::StatusFilters::Code::REJECTED, GroupsController::StatusFilters::Code::WITHDRAWN
      "closed_at"
    when GroupsController::StatusFilters::Code::PENDING
      "last_activity_at"
    when GroupsController::StatusFilters::Code::DRAFTED
      "last_member_activity_at"
    else
      "created_at"
    end
  end

  def track_profile_view
    ProfileView.create!(user: @profile_user, viewed_by: current_user) if @profile_user && !current_user.is_admin_only?
  end

  def profile_picture_params(picture_params)
    picture_params.permit(Member::MASS_UPDATE_ATTRIBUTES[:profile_picture])
  end

  def user_update_settings_params(update_settings_params, columns)
    update_settings_params.permit(columns)
  end

  def user_params(action, action_params)
    action_params.permit(Member::MASS_UPDATE_ATTRIBUTES[:user][action])
  end

  def set_profile_download_pdf_name
    time_stamp = DateTime.localize(Time.now, format: :pdf_timestamp)
    @pdf_name = "#{@profile_user.name(:name_only => true).to_html_id}-#{time_stamp}.pdf"
  end

  def can_manage_locked_out_members?
    wob_member.admin? && @current_organization.login_attempts_enabled?
  end

  def fetch_profile_member
    @profile_member = @current_organization.members.find(params[:id])
  end

  def fetch_profile_user
    @profile_user = @current_program.users.of_member(@profile_member).first!
  end

  def initialize_status_filters
    @status_filter = (params[:filter] || GroupsController::StatusFilters::Code::ONGOING).to_i
  end

  # Check validity of user updating user settings from organization or program levels,
  # else validity of user updating member settings

  def load_member_and_check_account_settings_update_access
    fetch_profile_member
    if params[:user] # Updating program level account settings
      program_id = params[:user][:program_id]
      @profile_user = params[:acc_settings] ? @profile_member.user_in_program(program_id) : fetch_profile_user
    elsif program_view?
      fetch_profile_user
    end
    if program_view? 
      allow! :exec => lambda {@profile_user == current_user || current_user.is_admin?}
    else
      allow! :exec => lambda {wob_member.is_admin? || (@profile_user.present? ? (@profile_user == wob_member.user_in_program(program_id)) : (@profile_member == wob_member))}
    end
  end

  def load_member_and_check_profile_update_access
    fetch_profile_member
    @is_first_visit = params[:first_visit].presence

    if program_view?
      fetch_profile_user
      allow! exec: lambda { @profile_user == current_user || current_user.is_admin? }
    else
      allow! exec: lambda { @profile_member == wob_member || wob_member.admin? }
    end
  end

  def get_profile_user_and_member
    @profile_member = wob_member
    @profile_user = current_user
    @is_self_view = true
  end

  # Updates admin notes with the given data and renders js.erb as response
  def update_admin_notes
    # Only admin can edit admin notes.
    allow! :user => :is_admin?
    @profile_user.update_attribute(:admin_notes, params[:user][:admin_notes])

    if request.xhr?
      render :action => :admin_note_update
    else
      redirect_to member_path(@profile_member)
    end
  end

  #
  # Override the filter for escaping profile completion check for edit/update
  # profile related actions.
  #
  def handle_pending_profile_or_unanswered_required_qs
    actions_allowed_for_first_visit = params[:first_visit] && ["edit", "update", "update_answers"].include?(action_name)
    file_uploading = "upload_answer_file" == action_name
    if actions_allowed_for_first_visit || file_uploading
      true
    else
      super
    end
  end

  #
  # Handles the following tasks to be done when a users's profile is updated.
  #
  #   * Match delta indexing
  #   * If not basic profile, set last profile update time
  #   * If not basic profile, activate the user if the profile was pending and
  #   is nowcomplete.
  #
  def handle_profile_update(user, profile_question_ids = [])
    Matching.perform_users_delta_index_and_refresh_later([user.id], user.program, profile_question_ids: profile_question_ids)
    handle_profile_answers_update(user)
  end

  # Sets last profile update time and activates the user profile
  def handle_profile_answers_update(user)
    user.set_last_profile_update_time

    if user.profile_pending? && user.profile_incomplete_roles.empty?
      user.update_attribute(:state, User::Status::ACTIVE)
      track_activity_for_ei(EngagementIndex::Activity::PUBLISH_PROFILE) if (current_user ? (user == current_user) : (user.member == wob_member))
    end
  end

  def expire_profile_cached_fragments
    return if @profile_user.is_admin_only?
    
    role_names = @profile_user.role_names
    role_names.each do |role|
      @current_program.roles.collect(&:name).each do |viewer_role|
        key = CacheConstants::Members::PROFILE_SUMMARY_FIELDS.call(@profile_user.id, role, viewer_role, @current_program.role_questions_last_update_timestamp(role))
        expire_fragment(key)
      end
    end
  end

  def update_profile_answers
    # The user or member whose profile is being updated.
    @section = params[:section] || EditSection::GENERAL
    @section_id = params[:section_id]
    if (params[:profile_answers].blank? && params[:persisted_files].blank?) || update_user_answers(@profile_user, params[:profile_answers], params[:persisted_files])
      track_activity_for_ei(EngagementIndex::Activity::UPDATE_PROFILE) if current_user == @profile_user
      # When updating common organization profile, set +profile_updated_at+
      # for each of the users of the member and also set status to 'active' if
      # the profiles are no more pending.
      params[:profile_answers].present? ? handle_profile_update(@profile_user, params[:profile_answers].keys) : handle_profile_answers_update(@profile_user)
      profile_question_ids = params[:profile_answers].present? ? params[:profile_answers].keys.map(&:to_i) : []
      User.delay.clear_invalid_answers(@profile_user.id, @profile_user.class, @profile_user.program.organization.id, profile_question_ids)

      if @is_first_visit
        chronus_ab_counter_inc("Step #{params[:ab_test]}", ProgramAbTest::Experiment::SIGNUP_WIZARD, !is_ie_less_than?(9)) if params[:ab_test].present?
        set_first_time_sections_cookie
        # The condition is true when the last section of the profile is being edited
        if params[:last_section].to_s.to_boolean
          handle_last_section_redirect_on_first_visit(@profile_user, @section, @is_first_visit)
        else
          flash[:notice] = "flash_message.user_flash.complete_mentoring_profile_v1".translate if @section == EditSection::GENERAL
          redirect_to edit_member_path(@profile_member, section: EditSection::PROFILE, first_visit: @is_first_visit, ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION)
        end
      else
        if request.xhr?
          @successfully_updated = true
        else
          flash[:notice] = "flash_message.program_flash.updated".translate
          redirect_to edit_member_path(@profile_member, section: EditSection::PROFILE, prof_c: @is_profile_completion, skip_scrolling: true, ei_src: EngagementIndex::Src::EditProfile::UPDATING_PROFILE)
        end
      end
    else
      flash[:error] = "flash_message.user_flash.required_fields".translate
      if @is_first_visit
        redirect_to edit_member_path(@profile_member, section: EditSection::PROFILE, first_visit: @is_first_visit, ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION)
      else
        redirect_to edit_member_path(@profile_member, section: EditSection::PROFILE, prof_c: @is_profile_completion, skip_scrolling: true, ei_src: EngagementIndex::Src::EditProfile::UPDATING_PROFILE) unless request.xhr?
      end
    end
  end

  # Update the user answers. No exception should occur here.
  def update_user_answers(user, answers, answers_to_delete = {})
    answers = answers.try(:permit!).to_h
    questions = answered_profile_qs(answers).group_by(&:id)
    answers_to_delete = answers_to_delete.delete_if {|k, v| v == '1' } if answers_to_delete.present?

    if answers_to_delete.present? && !answers.map{|k, v| v.present? && answers_to_delete.include?(k)}.include?(true)
      questions_for_deletation = @current_organization.profile_questions.where(:id => answers_to_delete.keys).includes(question_choices: :translations).group_by(&:id)
      answers_to_delete.each_pair do |question_id, answer_text|
        ques_obj = questions_for_deletation[question_id.to_i][0]
        next unless ques_obj.editable_by?(current_user_or_member, user)
        answer = user.answer_for(ques_obj)
        answer.destroy if answer.profile_question.file_type? && !answer.profile_question.required_for(@current_program, user.role_names)
      end
    end

    answers.each_pair do |question_id, answer_text|
      ques_obj = questions[question_id.to_i][0]
      next unless ques_obj.editable_by?(current_user_or_member, user)
      return false unless update_question_answer(user, ques_obj, answer_text) || @is_admin_view
    end
  end

  def update_question_answer(user, ques_obj, answer_text)
    return true if ques_obj.handled_after_check_for_conditional_question_applicability?(user.member)
    member = user.member
    saved_successfully = if ques_obj.education?
      member.update_education_answers(ques_obj, answer_text, user, @is_admin_view)
    elsif ques_obj.experience?
      member.update_experience_answers(ques_obj, answer_text, user, @is_admin_view)
    elsif ques_obj.publication?
      member.update_publication_answers(ques_obj, answer_text, user, @is_admin_view)
    elsif ques_obj.manager?
      member.update_manager_answers(ques_obj, answer_text, user, @is_admin_view)
    elsif ques_obj.file_type?
      saved = false
      if path_to_file = FileUploader.get_file_path(ques_obj.id, user.member.id, ProfileAnswer::TEMP_BASE_PATH, { code: params["question_#{ques_obj.id}_code"], file_name: answer_text })
        File.open(path_to_file, 'rb') do |file_stream|
          saved = user.save_answer!(ques_obj, file_stream) rescue false
        end
      end
      saved
    else
      user.save_answer!(ques_obj, answer_text) rescue false
    end
    ques_obj.update_dependent_questions(user.member) if saved_successfully
    saved_successfully
  end

  def answered_profile_qs(answers)
    @current_organization.profile_questions.includes([:role_questions, {question_choices: :translations}]).where(:id => answers.keys)
  end

  def check_admin_access
    wob_member.admin?
  end

  def check_organization_profile_enabled_for_dormant_members
    (@current_organization.members.find(params[:id]).present? && !@current_organization.members.find(params[:id]).dormant?) ||
    (@current_organization.org_profiles_enabled? && wob_member.present? && wob_member.admin?)
  end

  def update_user_settings
    user_setting = UserSetting.find_or_initialize_by(user_id: @profile_user.id)
    user_settings_params = params[:user].delete(:user_settings)
    user_setting.update_attributes!(user_params(:user_settings, user_settings_params))
  end

  def save_and_handle_user_errors(program)
    @profile_user.updated_by_admin = @is_admin_view
    if @profile_user.opting_for_ongoing_mentoring?
      if !@settings_error_case && (@profile_user.valid? || @profile_user.errors[:max_connections_limit].blank?)
        @profile_user.save!
      else
        @error_message.push(get_error_flash_messages(@profile_user)).compact!
      end
    else
      @profile_user.save! if !@settings_error_case
    end
  end

  def handle_mentoring_mode_change(program)
    pending_items = []
    if program.consider_mentoring_mode?
      case @profile_user.mentoring_mode
      when User::MentoringMode::ONGOING
        if @profile_user.received_meeting_requests.active.any?
          @settings_error_case = true
          pending_items << "flash_message.user_flash.mentoring_mode_change_failure.meeting_request_pending".translate(meeting: _meeting)
        end
      when User::MentoringMode::ONE_TIME
        if @profile_user.received_mentor_requests.active.any?
          @settings_error_case = true
          pending_items << "flash_message.user_flash.mentoring_mode_change_failure.mentor_request_pending".translate(mentoring: _mentoring)
        end
        if @profile_user.sent_mentor_offers.pending.any?
          @settings_error_case = true
          pending_items << "flash_message.user_flash.mentoring_mode_change_failure.mentor_offer_pending".translate(mentoring: _mentoring)
        end
      end
      str = pending_items.join(", ")
      index = str.rindex(",")
      str[index] = " " + "display_string.and".translate if index
      @error_message << "flash_message.user_flash.mentoring_mode_change_failure.kindly_reply_first".translate(mentoring: _mentoring, items: str) if pending_items.present?
    end
  end

  def max_connections_limit_error_flash(user)
    students_size = user.students.size
    student_string = "#{students_size} #{_mentee}(s)"
    "flash_message.user_flash.max_connections_limit_error_v1".translate(mentees: _mentees, student_string: student_string, students_count: students_size, :mentoring_connections => _mentoring_connections, :mentoring => _mentoring)
  end

  def can_change_connections_limit_error_flash(user)
    if user.max_connections_limit > user.program.default_max_connections_limit
      "flash_message.user_flash.max_connections_limit_only_increase_error".translate(:mentoring_connection => _mentoring_connection, :limit => user.program.default_max_connections_limit)
    else
      "flash_message.user_flash.max_connections_limit_only_decrease_error".translate(:mentoring_connection => _mentoring_connection, :limit => user.program.default_max_connections_limit)
    end
  end

  def negative_connections_limit_error_flash(user)
    "flash_message.user_flash.negative_connections_limit_error".translate(mentoring_connection: _mentoring_connection)
  end

  def set_is_admin_view
    @is_admin_view = logged_in_program? ? current_user.is_admin? : (logged_in_organization? ? wob_member.admin? : false)
  end

  def flash_keep
    flash.keep unless logged_in_program?
  end

  def initialize_unanswered_questions
    @unanswered_questions = @profile_user.unanswered_questions if @profile_user && @current_program.profile_completion_alert_enabled?
  end

  def current_and_next_month_session_slots
    start_time = Time.now.utc + current_program.get_allowed_advance_slot_booking_time.hours
    end_time = start_time.next_month.end_of_month
    return @profile_member.available_slots(current_program, start_time, end_time)
  end

  def get_state_based_flash_message
    if program_view? && @profile_user.present?
      message = @profile_user.get_state_based_message({ program: _program, programs: _programs } )
      if @profile_member.suspended? && wob_member.admin?
        link_to_org_profile = view_context.link_to("display_string.click_here".translate, @current_organization.standalone? ? admin_view_all_members_path : member_path(@profile_member, organization_level: true))
        message = "#{message} #{'flash_message.user_flash.reactivate_org_profile_html'.translate(click_here: link_to_org_profile, organization_name: @current_organization.name)}".html_safe
      end
    elsif @profile_member.suspended?
      message = "flash_message.user_flash.membership_suspended_v1".translate(member: @profile_member.name, programs: _programs)
    end
    message
  end


  def get_error_flash_messages(profile_user)
    #If there are any connection limit errors in user object we update flash content accordingly
    if(profile_user.errors.messages.values.flatten & UserConstants::CONNECTIONS_LIMIT_ERRORS).present?
      @settings_error_case = true
      UserConstants::CONNECTIONS_LIMIT_ERRORS.each do |error|
        return send("#{error}_flash".to_sym, profile_user) if profile_user.errors[:max_connections_limit].include?(error)
      end
    end
  end

  def handle_last_section_redirect_on_first_visit(profile_user, section, first_visit)
    set_sections_filled_from_cookies
    if calendar_sync_v2_settings_tab?(section)
      redirect_to edit_member_path(profile_user.member, section: EditSection::CALENDAR_SYNC_V2_SETTINGS, first_visit: first_visit, ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION)
    elsif show_mentoring_settings_section?(section, profile_user)
      redirect_to edit_member_path(profile_user.member, section: EditSection::MENTORING_SETTINGS, first_visit: first_visit, ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION)
    else
      finished_chronus_ab_test(ProgramAbTest::Experiment::SIGNUP_WIZARD, !is_ie_less_than?(9))
      redirect_to program_root_path(from_first_visit: first_visit)
    end
  end

  def show_mentoring_settings_section?(section, profile_user)
    can_edit_mentoring_settings_section?(profile_user) && section != EditSection::MENTORING_SETTINGS && !@sections_filled.include?(EditSection::MENTORING_SETTINGS)
  end

  def can_edit_mentoring_settings_section?(profile_user)
    return true if profile_user.is_mentor? && current_program.consider_mentoring_mode?
    return true if profile_user.allowed_to_edit_max_connections_limit?(current_program)
    return true if can_show_one_time_settings?(profile_user)
    return false
  end

  def fetch_json_objects_for_autocomplete(params)
    json_objects = if params[:filter].present?
      @members_json
    elsif params[:for_autocomplete].present?
      @members.map(&:name_with_email)
    elsif params[:admin_message].present?
      @members.map do |member|
      {
        label: member.name(name_only: true),
        name: member.name(name_only: true),
        object_id: member.id
      }
      end
    end
    return json_objects.to_json
  end

  def calendar_sync_v2_settings_tab?(section)
    current_program.calendar_sync_v2_for_member_applicable? && (section != EditSection::CALENDAR_SYNC_V2_SETTINGS) && (section != EditSection::MENTORING_SETTINGS) && !@sections_filled.include?(EditSection::CALENDAR_SYNC_V2_SETTINGS)
  end

  def can_show_one_time_settings?(user)
    return false unless current_program.calendar_enabled?
    return true if user.is_mentor?
    show_one_time_settings = user.member.show_one_time_settings?(@current_program)
    return show_one_time_settings && check_calendar_related_permissions_for_user?(user)
  end

  def check_calendar_related_permissions_for_user?(profile_user)
    profile_user.can_set_availability? || profile_user.can_set_meeting_preference?
  end

  def check_pdf_access
    # filter to restrict access to user profile pdf for non admins
    !request.format.pdf? || @is_admin_view || params[:id] == wob_member.id.to_s
  end

  def is_profile_show_tab?
    @profile_tab == ShowTabs::PROFILE
  end

  def track_activities_for_show(mentor_profile_ei_src, mentor_id)
    track_activity_for_ei(EngagementIndex::Activity::VISIT_REQUESTORS_PROFILE) if view_requestors_ei_activity?
    track_activity_for_ei(EngagementIndex::Activity::VISIT_MENTORS_PROFILE, {context_place: mentor_profile_ei_src, context_object: mentor_id}) if view_mentors_ei_activity?
  end

  def is_non_self_view_and_owner_mentor_and_current_user_student? 
    !@is_self_view && @is_owner_mentor && current_user && current_user.is_student? 
  end 

  def can_set_available_slots?
    !@is_owner_admin_only && @is_owner_mentor && current_program.calendar_enabled? && @profile_user.opting_for_one_time_mentoring? && @profile_user.ask_to_set_availability?
  end

  def can_see_match_label?
    is_non_self_view_and_owner_mentor_and_current_user_student? && (current_user.can_send_mentor_request? || @current_program.calendar_enabled?)
  end

  def can_see_match_score?(user)
    @can_see_match_label && user && @current_program.allow_user_to_see_match_score?(user)
  end

  def can_show_meeting_availability?
    is_non_self_view_and_owner_mentor_and_current_user_student? && @profile_user.opting_for_one_time_mentoring? && @current_program.only_one_time_mentoring_enabled?
  end
end
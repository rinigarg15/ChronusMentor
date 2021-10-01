# Filters and other auth logic common to all pages (controllers) contained
# within the mentoring connection.
include ScrapExtensions
module ConnectionFilters
  def self.included(controller)
    controller.extend CommonExtensions
    controller.send :include, CommonInclusions
  end

  module CommonExtensions
    def common_extensions(options = {})
      before_action :fetch_group, :fetch_current_connection_membership

      allow exec: :check_member_or_admin, only: [:index]
      allow exec: :check_action_access, except: [:index]

      unless options[:skip_check_group_active]
        allow exec: :check_group_active, except: [:index]
      end

      before_action :prepare_template, only: [:index]
      allow exec: :can_access_mentoring_area?, only: [:index]
      before_action :update_login_count, only: [:index]
      after_action :update_last_visited_tab, only: [:index]
    end
  end

  module CommonInclusions
    # Load the Group from params[:group_id]
    def fetch_group
      @group = @current_program.groups.find(params[:group_id])
      load_user_membership_params
    end

    def load_user_membership_params
      @is_member_view ||= @group.has_member?(current_user)
      if @is_member_view
        @is_mentor_in_group ||= @group.has_mentor?(current_user)
      end
    end

    def fetch_current_connection_membership
      return if @group.nil?
      @current_connection_membership = @group.membership_of(current_user)
      @is_member_view ||= @current_connection_membership.present?
    end

    def check_group_active
      return true if @group.nil?
      @group.active?
    end

    def check_group_open
      return true if @group.nil?
      @group.open?
    end

    # Check whether the user can access the page.
    def check_member_or_admin
      return true if @group.nil?
      is_member = @group.has_member?(current_user)
      is_admin = current_user.can_manage_connections?
      @is_admin_view = !is_member && is_admin
      is_member || is_admin
    end

    # Check whether the user can access meeting page.
    def check_member_or_admin_for_meeting
      is_member = @meeting.has_member?(wob_member)
      is_admin = current_user.can_manage_connections?
      @is_admin_view = !is_member && is_admin
      is_member || is_admin
    end

    # Check permissions for the user to perform action on the group.
    def check_action_access
      @is_member_view || @group.has_member?(current_user)
    end

    def prepare_template_base(options = {})
      return if @group.nil?
      prepare_navigation

      return if handle_confidential_access
      prepare_tabs
      prepare_side_pane
      fetch_random_tip

      unless options[:skip_survey_initialization]
        initialize_overdue_engagement_survey
        initialize_feedback_survey
      end

      @user_is_member_or_can_join_pending_group = @group.pending? && (@is_member_view || @group.available_roles_for_user_to_join(current_user).present?)

      compute_page_controls_allowed
      compute_past_meeting_controls_allowed
      compute_surveys_controls_allowed
      set_circle_start_date_params

      # Register the visit of the user; used for tracking activity.
      @group.send_later(:mark_visit, current_user) unless working_on_behalf?
      @new_meeting = wob_member.meetings.build(group: @group) if (@show_meetings_tab && (@page_controls_allowed || @past_meeting_controls_allowed))
      @new_scrap = @group.scraps.new if @page_controls_allowed
    end

    def prepare_template(options = {})
      return if request.xhr?
      prepare_template_base(options)
    end

    def prepare_template_for_ajax
      prepare_template_base
    end

    def set_circle_start_date_params
      @show_set_start_date_popup = defined?(group_params) ? group_params[:show_set_start_date_popup].to_s.to_boolean : params[:show_set_start_date_popup].to_s.to_boolean
      @manage_circle_members = defined?(group_params) ? group_params[:manage_circle_members].to_s.to_boolean : params[:manage_circle_members].to_s.to_boolean
    end

    def compute_page_controls_allowed
      # Allow page actions(Except surveys) for members if open connection.
      @page_controls_allowed ||= (is_member_view_only? && (@group.pending? || (@group.active? && !@group.expired?)))
    end

    def compute_past_meeting_controls_allowed
      #Allow access to Record past meeting for active and expired connections
      @past_meeting_controls_allowed ||= (is_member_view_only? && (@group.active? || (@group.expiry_time && @group.expired?)))
    end

    def compute_surveys_controls_allowed
      # Allow surveys_access for members for active, inactive & closed connections.
      @surveys_controls_allowed ||= (is_member_view_only? && @group.published?)
    end

    def compute_coaching_goals_side_pane
      coaching_goals = @group.coaching_goals
      @side_pane_coaching_goals = coaching_goals.select(&:overdue?) + coaching_goals.select(&:in_progress?) + coaching_goals.select(&:completed?)
    end

    def compute_mentoring_model_goals_side_pane
      @mentoring_model_goals = @group.mentoring_model_goals
      @required_tasks = @group.mentoring_model_tasks.required.where(goal_id: @mentoring_model_goals.collect(&:id))
    end

    def can_access_mentoring_area?
      return true if @group.nil?
      @group.admin_enter_mentoring_connection?(current_user, super_console?)
    end

    def update_login_count
      return if @from_connection_home_page_widget || working_on_behalf?
      visited_cookies = cookies[CookiesConstants::MENTORING_AREA_VISITED]
      if @current_connection_membership.present? && (visited_cookies.blank? || !visited_cookies.split(',').include?(@group.id.to_s))
        cookies[CookiesConstants::MENTORING_AREA_VISITED] = visited_cookies.blank? ? @group.id.to_s : "#{visited_cookies},#{@group.id}"
        @current_connection_membership.increment_login_count
      end
    end

    def prepare_template_for_connection_widget
      fetch_group_for_homepage_widget
      return if @group.nil?
      fetch_current_connection_membership
      prepare_tabs
      compute_page_controls_allowed
      compute_past_meeting_controls_allowed
      handle_connection_tab
    end

    def fetch_group_for_homepage_widget
      @page = params[:page].to_i
      @groups = current_user.get_active_or_recently_closed_groups.paginate(page: @page, per_page: 1)
      @group = @groups[0]
      @groups_size = @groups.count
      return if @group.nil?
      load_user_membership_params
      @badge_counts = @group.badge_counts(current_user)
    end

    def group_last_visited_tab
      case @current_connection_membership.last_visited_tab
        when ScrapsController.controller_path 
          Group::Tabs::MESSSAGES if @show_messages_tab
        when MeetingsController.controller_path
          Group::Tabs::MEETINGS if @show_meetings_tab
        when GroupsController.controller_path
          Group::Tabs::TASKS if @show_plan_tab
      end
    end

    def handle_connection_tab
      @tab_to_open = Group::Tabs::MESSSAGES if @badge_counts[:unread_message_count] > 0
      @tab_to_open = Group::Tabs::FORUMS if @badge_counts[:unread_posts_count] > 0 && @tab_to_open.blank?
      @tab_to_open = Group::Tabs::TASKS if @badge_counts[:tasks_count] > 0 && @tab_to_open.blank?
      if @show_meetings_tab && @tab_to_open.blank?
        meetings = Meeting.get_meetings_for_view(@group, @is_admin_view, wob_member, current_program)
        meetings_to_be_held, archived_meetings = Meeting.recurrent_meetings(meetings)
        @tab_to_open = Group::Tabs::MEETINGS if meetings_to_be_held.present?
      end
      if @tab_to_open.blank?
        if @group.scraps_enabled? && check_member_or_admin
          member_scraps = @group.scraps
          root_scrap_ids = member_scraps.present? ? member_scraps.select("DISTINCT root_id").collect(&:root_id) : []
          @tab_to_open = Group::Tabs::MESSSAGES if is_latest_message_present?(root_scrap_ids, wob_member)
        end
        @tab_to_open = Group::Tabs::FORUMS if @tab_to_open.blank? && @group.forum_enabled? && @group.forum.topics.present?
        tasks = @group.mentoring_model_tasks.owned_by(current_user)
        @tab_to_open = Group::Tabs::TASKS if tasks.overdue.present? && @tab_to_open.blank?
        @tab_to_open = group_last_visited_tab if @tab_to_open.blank?
      end
    end

    def update_last_visited_tab
      return if @current_connection_membership.blank?

      last_visited_tab = defined?(group_params) ? group_params[:controller] : params[:controller]
      @current_connection_membership.update_column(:last_visited_tab, last_visited_tab)
    end

    def prepare_tabs
      @connection_questions = Connection::Question.get_viewable_or_updatable_questions(@current_program, current_user.can_manage_or_own_group?(@group))
      return unless @group.open_or_closed?

      @can_access_tabs = can_access_tabs
      @show_messages_tab = show_messages
      @show_forum_tab = show_forum

      if @group.published?
        @show_plan_tab = true
        @show_meetings_tab = show_meetings
        @show_mentoring_model_goals_tab = show_mentoring_model_goals
        @show_private_journals_tab = show_private_journals
        @is_tab_or_connection_questions_present_in_page = @can_show_tabs = true
      else
        @show_profile_tab = @connection_questions.present?
        @show_plan_tab = (@can_access_tabs || @group.global?) && mentoring_model_template_objects_present?
        @can_show_tabs = [@show_messages_tab, @show_forum_tab, @show_profile_tab, @show_plan_tab].select(&:present?).size > 1
        @is_tab_or_connection_questions_present_in_page = [@show_messages_tab, @show_forum_tab, @show_profile_tab, @show_plan_tab].any?(&:present?)
      end
    end

    def mentoring_model_template_objects_present?
      return false if @group.mentoring_model.blank?

      @mentoring_model_milestones = @group.mentoring_model.mentoring_model_milestone_templates
      @mentoring_model_tasks = @group.mentoring_model.mentoring_model_task_templates
      @mentoring_model_milestones.present? || @mentoring_model_tasks.present?
    end

    def set_src
      @src_path = defined?(group_params) ? group_params[:src] : params[:src]
    end

    def set_from_find_new
      @from_find_new = defined?(group_params) ? group_params[:from_find_new] : params[:from_find_new]
    end

    def set_group_profile_view
      return if @group.nil?
      @is_group_profile_view = @group.pending? || (defined?(group_params) && group_params[:action] == "profile")
    end

    def get_meetings_for_sidepanes(group, is_admin_view)
      # Fetch data for the right pane.
      include_options = [{:member_meetings => [:survey_answers, :member_meeting_responses, :member]}, :owner]
      recurrent_options = {}
      upcoming_meetings = Meeting.upcoming_recurrent_meetings(group.meetings.includes(include_options))
      upcoming_meetings = is_admin_view ? Meeting.has_attendance_more_than(upcoming_meetings, 0) : wob_member.get_attending_and_not_responded_meetings(upcoming_meetings)
      upcoming_meetings_in_next_seven_days = []
      upcoming_meetings = upcoming_meetings.first(OrganizationsController::MY_MEETINGS_COUNT - 1)
      upcoming_meetings.each do |upcoming_meeting|
        upcoming_meetings_in_next_seven_days << upcoming_meeting if upcoming_meeting[:current_occurrence_time] < 7.days.from_now
      end
      return upcoming_meetings, upcoming_meetings_in_next_seven_days
    end

    private

    def prepare_side_pane
      group_peers = (@is_admin_view || @outsider_view)  ? @group.members : @group.get_groupees(current_user)

      last_last_seen_at = group_peers.collect(&:last_seen_at).compact.max
      time_stamp = last_last_seen_at ? last_last_seen_at.strftime("%d%b%Y") : nil
      @summary_pane_cache_key = CacheConstants::Groups::SUMMARY_PANE.call(@group.id, current_user.id, @group.mentors.size, @group.students.size, @group.custom_users.size , @group.owner_ids.join("_"), time_stamp)

      # Show error flash if any of the members is inactive.
      inactive_members = group_peers.reject{|user| user.active_or_pending?}
      if inactive_members.any? && !session[:inactive_members_in_a_group_flash]
        inactive_names = inactive_members.collect(&:name).to_sentence
        flash.now[:warning] = "flash_message.user_flash.user_inactive_v1".translate(user: inactive_names, count: inactive_members.size)
        session[:inactive_members_in_a_group_flash] = true
      end

      @show_side_pane_mentoring_model_goals = !@skip_mentoring_model_goals_side_pane && show_mentoring_model_goals
      if @show_side_pane_mentoring_model_goals
        compute_mentoring_model_goals_side_pane
      end

      @show_side_pane_meetings = !@skip_meetings_side_pane && show_meetings
      if @show_side_pane_meetings
        @upcoming_meetings, @upcoming_meetings_in_next_seven_days = get_meetings_for_sidepanes(@group, @is_admin_view)
      end

      @show_side_pane_coaching_goals = !@skip_coaching_goals_side_pane && @current_program.coaching_goals_enabled?
      if @show_side_pane_coaching_goals
        compute_coaching_goals_side_pane
      end

      @viewable_or_updatable_questions = Connection::Question.get_viewable_or_updatable_questions(@current_program, current_user.is_admin? && !@user_edit_view)
    end

    def show_private_journals
      @can_access_tabs && !@is_admin_view && @current_program.allow_private_journals? && !working_on_behalf?
    end

    def can_access_tabs
      @is_admin_view || @is_member_view
    end

    def show_meetings
      @can_access_tabs && @current_program.mentoring_connection_meeting_enabled? && (!@current_program.mentoring_connections_v2_enabled? || manage_mm_meetings_at_end_user_level?(@group))
    end

    def show_mentoring_model_goals
      @can_access_tabs && @current_program.mentoring_connections_v2_enabled? && (manage_mm_goals_at_admin_level?(@group) || manage_mm_goals_at_end_user_level?)
    end

    def show_messages
      @can_access_tabs && @group.scraps_enabled?
    end

    def show_forum
      @can_access_tabs && @group.forum_enabled?
    end

    def handle_confidential_access
      if @is_admin_view && @current_program.confidentiality_audit_logs_enabled?
        @latest_log = current_user.confidentiality_audit_logs.find_by(group_id: @group.id)

        if (@latest_log.blank? || @latest_log.created_at < 120.minutes.ago) && (@group.published?)
          if request.xhr?
            render :update do |page|
              render :js => "window.location.href = \"#{new_confidentiality_audit_log_path(:group_id => @group.id)}\";" and return true
            end
          else
            redirect_to new_confidentiality_audit_log_path(:group_id => @group.id)
            return true
          end
        end
      end
    end

    def is_member_view_only?
      @is_member_view && !@is_admin_view
    end

    def fetch_random_tip
      return if !@is_member_view || !@current_program.mentoring_insights_enabled?

      @random_tip = @current_program.mentoring_tips.enabled.for_role(@current_connection_membership.role.name).sample
    end

    def initialize_overdue_engagement_survey
      return if @current_connection_membership.blank? || !@group.published?

      oldest_overdue_survey_task = @current_connection_membership.get_last_outstanding_survey_task
      cookie_name = "#{GroupsController::OVERDUE_SURVEY_POPUP_COOKIE_FORMAT}_#{@current_connection_membership.id}"
      if oldest_overdue_survey_task.present? && !working_on_behalf? && !cookies[cookie_name].present?
        survey_options = { task_id: oldest_overdue_survey_task.id, format: :js, src: Survey::SurveySource::POPUP }
        response_id = oldest_overdue_survey_task.survey_answers.drafted.for_user(current_user).pluck(:response_id).first
        survey_options.merge!(response_id: response_id) if response_id.present?
        @oldest_overdue_survey = @current_program.surveys.find_by(id: oldest_overdue_survey_task.action_item_id)
        @survey_answer_url = edit_answers_survey_path(@oldest_overdue_survey, survey_options) if @oldest_overdue_survey
        cookies[cookie_name] = { value: true, expires: GroupsController::OVERDUE_SURVEY_POPUP_COOKIE_EXPIRY_TIME }
      end
    end

    def initialize_feedback_survey
      return if !@is_member_view || !@group.published?

      if @current_program.feedback_survey.present? && (@current_program.allow_connection_feedback? || @current_program.connection_feedback_enabled?)
        @feedback_survey = @current_program.feedback_survey
        @feedback_questions = @feedback_survey.survey_questions
        @feedback_response = Survey::SurveyResponse.new(@feedback_survey, user_id: current_user.id, group_id: @group.id)
        @show_feedback_form = !working_on_behalf? && @feedback_questions.present? &&
          (@group.time_for_feedback_from?(current_user) || @group.can_be_activated?) &&
          !session[UsersController::SessionHidingKey::INACTIVITY_CONNECTION_FEEDBACK]
      end
    end

    def prepare_navigation
      @logo_url = @group.logo_url if @current_program.connection_profiles_enabled?
      back_mark("#{_Mentoring_Connection}")

      if @group.has_member?(current_user)
        @select_connection_tab = true
        deactivate_tabs
      else
        activate_tab(tab_info[TabConstants::MANAGE])
      end
    end
  end
end
module UserSearch
  include UserListingExtensions
  extend ActiveSupport::Concern

  module SortParam
    RELEVANCE = "relevance"
    PREFERENCE = "preference"
  end

  # Number of education and experiences to show in listing page per mentor.
  MAX_MENTOR_EDU_EXP_IN_INDEX = 3

  # Number of recommended mentors we show by default in "Find a Mentor" for admin
  RECOMMENDED_MENTORS_BATCH_SIZE = 20

  DEFAULT_CALENDAR_AVAILABILITY_RANGE_LENGTH = 30.days
  SHOW_NO_MATCH_FILTER = "show_no_match"

  def get_indexed_users(params, items_size = nil, options={})
    initialize_params(params, items_size)
    initialize_role_options
    initialize_pagination_options
    initialize_user_references
    initialize_filterable_and_summary_questions
    initialize_search_and_filter_options(options)
    initialize_role_specific_values
    initialize_sort_values(@current_user, options)
    display_flash_for_moderated_group(options[:from_weekly_updates])
    @quick_connect = options[:quick_connect]
    get_filtered_users(@current_user, options)
    user_ids = @users.collect(&:id)

    if !!@current_user
      if @role == RoleConstants::STUDENT_NAME
        defined?(initialize_student_actions_for_users) ? initialize_student_actions_for_users(user_ids) : User.initialize_student_actions_for_users(user_ids)
      elsif @role == RoleConstants::MENTOR_NAME
        defined?(initialize_mentor_actions_for_users) ? initialize_mentor_actions_for_users(user_ids) : User.initialize_mentor_actions_for_users(user_ids)
      end
    end
  end


  # Return the mysql sort string based on the given params
  def users_sort_order_string(sort_param, sort_order, program)
    if sort_param == 'name'
      if program.nil? || program.sort_users_by == Program::SortUsersBy::FULL_NAME
        return "name_only.sort", sort_order
      elsif program.sort_users_by == Program::SortUsersBy::LAST_NAME
        return ["last_name.sort", "first_name.sort"], sort_order
      end
    else
      return sort_param, sort_order
    end
  end

  protected

  # Adds search filters, if available, to the query and returns the query.
  def make_search_query(search_filters, search_query)
    # Convert query string of the form 'Hello World' to 'Hello | World' so as
    # to simulate *ANY* mode matching
    quick_search_string = search_filters.blank? ? "" : search_filters[:quick_search]
    @my_filters << {label: "#{'feature.user.filter.Keyword'.translate} (#{quick_search_string})", reset_suffix: "quick_search"} if quick_search_string.present?

    (search_query || quick_search_string || '').squeeze(" ")
  end

  # Constructs search parameters hash containing page, role conditions, etc., for the current query.
  def make_search_options(role, search_filters_param, has_es_options=false, applicable_user_ids=[], skip_explicit_preferences=false)
    
    with_options = get_default_with_options(role)

    if (@role == RoleConstants::MENTOR_NAME)
      merge_additional_options_to_with_options_for_mentor_role!(with_options)
    end

    if @role == RoleConstants::STUDENT_NAME && @current_program.ongoing_mentoring_enabled?
      merge_additional_options_to_with_options_for_student_role_in_ongoing_case!(with_options)
    end

    # XXX We need to get all results so that we can apply matching
    # logic on top of it. So, passing :per_page => <Maximum user count> and page
    # => 1. Is their a cleaner way of disabling pagination during search?

    options = {
      page: 1,
      per_page: ES_MAX_PER_PAGE,
      with: with_options
    }

    merge_explicit_preference_options_to_options!(options, skip_explicit_preferences)

    merge_user_ids_to_with_options!(with_options, options, has_es_options, applicable_user_ids)

    options = set_sort_field_and_order(options)

    options = apply_location_search(search_filters_param, options)

    options[:with].merge!({state: get_state_filter_options})

    merge_relevance_sort_options_to_options!(options)

    return options
  end

  def get_state_filter_options
    if @is_matches_for_student
      [User::Status::ACTIVE, User::Status::PENDING]
    elsif (!@current_user || !(@current_user && @current_user.can_manage_user_states?))
      User::Status::ACTIVE
    elsif @state && @current_user && @current_user.can_manage_user_states?
      @state
    else
      [User::Status::ACTIVE, User::Status::PENDING]
    end
  end

  def apply_calendar_filters(user_ids, filter_field)
    check_for_mentor_availability = included_or_equal_to(filter_field, UsersIndexFilters::Values::AVAILABLE)
    start_date = Time.now.in_time_zone(@current_user.member.get_valid_time_zone)
    end_date = start_date.next_month
    start_date += @current_program.get_allowed_advance_slot_booking_time.hours

    @status_filter_label = "feature.user.filter.availability_status".translate
    @my_filters ||= []
    @my_filters << {:label => @status_filter_label, :reset_suffix => @status_filter_label.to_html_id}

    student = @current_user.is_student? ? @current_user : nil
    # Users need not be scoped under program as already these ids were got from sphinx
    user_ids_string = user_ids.join(',')
    users = User.where(:id => user_ids)
    users = users.order("field(users.id,#{user_ids_string})") if user_ids.any?
    users = users.available_for_sessions if @current_program.consider_mentoring_mode? && !check_for_mentor_availability
    
    if @program_only_has_general_availabilty_meeting_filter
      mentor_member_ids_with_unlimited_slots = users.joins("LEFT JOIN user_settings ON users.id= user_settings.user_id").where("user_settings.max_meeting_slots is null").pluck(:member_id)

      mentor_member_ids_with_slot_setting = users.joins("LEFT JOIN user_settings ON users.id= user_settings.user_id").where("max_meeting_slots > 0").pluck(:member_id)

      available_mentor_member_ids_on_start_date = available_mentors_for_meeting_with_limit_in_period(mentor_member_ids_with_slot_setting, start_date)

      available_mentor_member_ids_on_end_date = available_mentors_for_meeting_with_limit_in_period(mentor_member_ids_with_slot_setting, end_date)

      @available_mentor_member_ids = mentor_member_ids_with_unlimited_slots + (available_mentor_member_ids_on_start_date + available_mentor_member_ids_on_end_date).uniq

      @available_mentor_member_ids = remove_slots_preferring_mentors_without_available_slots(@available_mentor_member_ids, start_date, end_date.end_of_month) if @current_user.is_allowed_to_set_slot_availability?

      return users.where(member_id: @available_mentor_member_ids).pluck("users.id").uniq
    else
      students_meetings = student.member.meetings.of_program(@current_program).between_time(start_date.beginning_of_month, end_date.end_of_month).includes(:members)
      mentor_ids_involved_in_meeting_with_student = @current_program.mentor_users.where(member_id: students_meetings.map(&:members).flatten.map(&:id)).pluck(:id)

      users = users.includes([member: [:meetings, :mentoring_slots], user_setting: []])
      filtered_users = users.select do |user|
        student_user = mentor_ids_involved_in_meeting_with_student.include?(user.id) ? student : nil
        
        (check_for_mentor_availability && user.cached_available_and_can_accept_request?) || (user.member.has_availability_between?(@current_program, start_date.beginning_of_month, end_date.end_of_month, student_user, {mentor_user: user, with_offset: true}))
      end
      filtered_users.collect(&:id)
    end
  end

  def remove_slots_preferring_mentors_without_available_slots(mentors_member_ids, start_time, end_time)
    members_ids_with_slot_availability = Member.where(will_set_availability_slots: true, id: mentors_member_ids).pluck(:id)
    members_ids_with_general_availability = mentors_member_ids - members_ids_with_slot_availability

    meetings = Meeting.of_program(@current_program).accepted_or_pending_meetings.between_time(start_time, end_time)
    meeting_ids_involving_mentors = MemberMeeting.where(member_id: members_ids_with_slot_availability, meeting_id: meetings.collect(&:id)).pluck(:meeting_id)
    meetings = meetings.where(id: meeting_ids_involving_mentors)

    non_recurring_slots = MentoringSlot.non_recurring.between_time(start_time, end_time).where(member_id: members_ids_with_slot_availability).includes(:member)
    recurring_slots = MentoringSlot.recurring.recurring_between_time(end_time).where(member_id: members_ids_with_slot_availability).includes(:member)
    all_slots = @current_user.member.get_mentoring_slots(start_time, end_time, false, nil, false, false, false, false, {:mentoring_slots => non_recurring_slots + recurring_slots})

    slots_after_meetings = @current_user.member.get_member_availability_after_meetings(all_slots, start_time, end_time, @current_program, {meets: meetings, flash_meetings_only: true})

    member_ids_having_slots_after_meetings = slots_after_meetings.map{|slot_hash| slot_hash[:eventMemberId]}.uniq

    return members_ids_with_general_availability + member_ids_having_slots_after_meetings
  end

  def available_mentors_for_meeting_with_limit_in_period(mentors_member_ids, view_date)
    return [] unless mentors_member_ids.present?
    start_time, end_time = Meeting.fetch_start_end_time_for_the_month(view_date)

    accepted_meetings_ids = Meeting.of_program(@current_program).accepted_meetings.between_time(start_time, end_time).pluck(:id)

    program_pending_meeting_requests_id = @current_program.meeting_requests.active.pluck(:id)

    pending_meeting_request_ids_with_proposed_slots = MeetingProposedSlot.where(:meeting_request_id => program_pending_meeting_requests_id).earliest_slots.between_time(start_time, end_time).pluck(:meeting_request_id)

    pending_meeting_request_ids_with_proposed_slots += [-1] # adding to make NOT IN work in case above query returns []

    pending_meeting_request_ids_without_slots = Meeting.of_program(@current_program).between_time(start_time, end_time).joins(:meeting_request).where("mentor_requests.status = ? AND meeting_request_id NOT IN (?)", AbstractRequest::Status::NOT_ANSWERED, pending_meeting_request_ids_with_proposed_slots).pluck(:meeting_request_id)

    pending_meetings_ids = Meeting.of_program(@current_program).where(:meeting_request_id => pending_meeting_request_ids_with_proposed_slots + pending_meeting_request_ids_without_slots).pluck(:id)

    member_meetings_member_ids = MemberMeeting.where(meeting_id: accepted_meetings_ids + pending_meetings_ids, member_id: mentors_member_ids).pluck("member_id")

    members_meeting_count_hash = {}

    member_meetings_member_ids.each do |member_id|
      members_meeting_count_hash[member_id] = members_meeting_count_hash[member_id].present? ? members_meeting_count_hash[member_id] + 1 : 1
    end

    mentors_user_ids_with_meetings = @current_program.mentor_users.where(member_id: members_meeting_count_hash.keys & mentors_member_ids).pluck(:id)

    unavailable_mentors_member_ids = []

    user_settings = UserSetting.where(user_id: mentors_user_ids_with_meetings).joins(:user).select("users.member_id, user_settings.max_meeting_slots")

    user_settings.each do |user_setting|
      allowed_meeting_slots = user_setting.max_meeting_slots
      meeting_slots_used = members_meeting_count_hash[user_setting.member_id]
      if !has_available_slots?(allowed_meeting_slots, meeting_slots_used)
        unavailable_mentors_member_ids << user_setting.member_id
      end
    end

    return mentors_member_ids - unavailable_mentors_member_ids
  end

  def sort_and_paginate_users(user)
    # For student, find match compatibilities with mentor profiles.
    # Perform score ordering if sort field is 'match'.
    if @match_view && @student_document_available
      @match_results = user.student_cache_normalized(@is_matches_for_student)
      @user_ids.reject!{ |id| @match_results[id].to_i.zero? } if @hide_no_match_users
      # Sort by rank if required.
      if @is_sort_by_match
        sort_users_by_match_score        
      elsif @is_sort_by_preference && !@hide_no_match_users
        move_not_a_match_mentors_to_last
      end
    end
    @user_ids = @user_ids.paginate(@pagination_options)
    # Build users based on the user_ids
    user_ids_string = @user_ids.join(',')
    users = User.where(:id => @user_ids).
      includes(@includes_list).
      order(user_ids_string.present? ? "field(id,#{user_ids_string})" : "")
    @users = WillPaginate::Collection.create(@user_ids.current_page, @user_ids.per_page, @user_ids.total_entries) do |pager|
      pager.replace(users)
    end
  end

  def sort_users_by_match_score
    if calendar_filters_present? && @quick_connect
      @user_ids = get_essential_user_ids_to_sort
    end
    availability_indexed_by_user_id_hsh = User.get_availability_slots_for(@user_ids)
    @user_ids = @user_ids.sort_by{|user_id| User.priority_array_for_match_score_sorting(@match_results[user_id], availability_indexed_by_user_id_hsh[user_id]) }
    @user_ids.reverse! if @sort_order == 'asc'
  end

  def move_not_a_match_mentors_to_last
    matched_mentors = []
    not_matched_mentors = []
    @user_ids.each do |id| 
      if @match_results[id].to_i.zero?
        not_matched_mentors << id
      else
        matched_mentors << id
      end
    end
    @user_ids = matched_mentors + not_matched_mentors
  end

  # Returns calendar_filtered users having greater match scores than the last user paginated.
  def get_essential_user_ids_to_sort
    @user_ids = @user_ids.sort_by{|user_id| (-1 * @match_results[user_id].to_i) }
    selected_ids = []
    limit = @pagination_options[:per_page]
    @user_ids.in_groups_of(limit) do|user_ids|
      break if selected_ids.size >= limit
      selected_ids << apply_calendar_filters(user_ids.compact, @filter_field)
      selected_ids.flatten!
    end
    selected_ids = selected_ids.first(limit)
    # Nth users match score. For exact sorting get all the users with match score >= Nth user's match score.
    last_user_match_score = @match_results[selected_ids.last].to_i
    @user_ids.select!{|id| @match_results[id].to_i >= last_user_match_score }
    @user_ids = apply_calendar_filters(@user_ids, @filter_field)
  end

  private

  def get_default_with_options(role)
    # Find which roles to fetch for the program based on the @role
    role_ids = @current_program.get_roles(role).collect(&:id)
    with_options = {"roles.id" => role_ids}

    additional_with_options = defined?(sub_program_search_options) ? sub_program_search_options : {program_id: @current_program.id}
    with_options.merge!(additional_with_options)

    return with_options
  end

  def merge_additional_options_to_with_options_for_mentor_role!(with_options)
    if !!@current_user && @current_program.consider_mentoring_mode?
      merge_mentoring_mode_options_to_with_options!(with_options)
    end
    with_options.merge!(can_accept_request: true) if included_or_equal_to(@filter_field, UsersIndexFilters::Values::AVAILABLE) && @current_program.ongoing_mentoring_enabled?
  end

  def merge_mentoring_mode_options_to_with_options!(with_options)
    with_options.merge!(mentoring_mode: User::MentoringMode.one_time_sanctioned) if is_one_time_sanctioned?
    with_options.merge!(mentoring_mode: User::MentoringMode.ongoing_sanctioned) if is_ongoing_sanctioned?
  end

  def is_one_time_sanctioned?
    included_or_equal_to(@filter_field, UsersIndexFilters::Values::CALENDAR_AVAILABILITY) && !(@params[:action] == "matches_for_student" || included_or_equal_to(@filter_field, UsersIndexFilters::Values::AVAILABLE))
  end

  def is_ongoing_sanctioned?
    (@params[:action] == "matches_for_student" || included_or_equal_to(@filter_field, UsersIndexFilters::Values::AVAILABLE)) && !included_or_equal_to(@filter_field, UsersIndexFilters::Values::CALENDAR_AVAILABILITY)
  end

  def merge_additional_options_to_with_options_for_student_role_in_ongoing_case!(with_options)
    if @filter_field == UsersIndexFilters::Values::CONNECTED
      with_options.merge!(active_mentee_connections_count: 1..Float::INFINITY)
    elsif @filter_field == UsersIndexFilters::Values::UNCONNECTED
      with_options.merge!(active_mentee_connections_count: 0)
    elsif @filter_field == UsersIndexFilters::Values::NEVERCONNECTED
      with_options.merge!(total_mentee_connections_count: 0)
    end
  end

  def merge_explicit_preference_options_to_options!(options, skip_explicit_preferences)
    if (@match_view || @can_apply_explicit_preferences) && @current_user.explicit_preferences_configured? && !skip_explicit_preferences
      options.merge!({explicit_preference: @current_user.get_explicit_user_preferences_should_query})
    end
    options.merge!({sort_by_explicit_preference: true}) if @is_sort_by_preference
  end

  def merge_user_ids_to_with_options!(with_options, options, has_es_options, applicable_user_ids)
    if has_es_options
      options.merge!({includes_list: @includes_list})
      options.merge!(@pagination_options)
      with_options.merge!({id: @user_ids.present? ? @user_ids : [0]})
    elsif applicable_user_ids.any?
      with_options.merge!({id: applicable_user_ids})
    end
  end

  def set_sort_field_and_order(options)
    options[:sort_field], options[:sort_order] = users_sort_order_string(@sort_field, @sort_order, @current_program) unless @is_sort_by_match || @is_sort_by_relevance || @is_sort_by_preference
    return options
  end

  def apply_location_search(search_filters_param, options)
    if search_filters_param.present? && search_filters_param[:location]
      location_filter = UserProfileFilterService.add_location_parameters_to_options(search_filters_param, options, @my_filters, "member.location_answer.location.point")
      options = location_filter[:options]
      @pivot_location = location_filter[:pivot_location]
      @my_filters = location_filter[:my_filters]
    end
    return options
  end

  def merge_relevance_sort_options_to_options!(options)
    options.merge!(
      :sort_field => "_score",
      :sort_order => "desc",
      :fields => ["name_only", "profile_answer_text.language_*"],
      :boost_hash => {"name_only" => 0.7, "profile_answer_text.language_*" => 0.3},
      :apply_boost => true
    ) if @is_sort_by_relevance
  end

  def initialize_params(params, items_size = nil)
    @params = params.presence || {:action => "index", :items_per_page => items_size, :calendar_availability_default => "false", :filter =>["calendar_availability"]}
  end

  def initialize_role_options
    @role = get_role_from_view_param
    @viewer_role = @current_user.get_priority_role if !!@current_user
  end

  def get_role_from_view_param
    @view_param = @params[:view]

    if @view_param.blank? || @view_param == RoleConstants::MENTORS_NAME
      RoleConstants::MENTOR_NAME
    elsif @view_param == RoleConstants::STUDENTS_NAME
      RoleConstants::STUDENT_NAME
    else
      @view_param
    end
  end

  def get_match_view_value
    @current_user.can_send_mentor_request? || (@current_program.calendar_enabled? && @current_user.is_student?)
  end

  def initialize_role_specific_values
    @received_requests_sender_ids = []
    if !!@current_user
      if @role == RoleConstants::STUDENT_NAME
        @filter_field = UsersIndexFilters::Values::ALL unless @current_user.is_admin? || @current_user.can_offer_mentoring?
        @mentee_groups_map = @current_user.mentee_connections_map if @current_user.is_mentor?
        @existing_connections_of_mentor = @mentee_groups_map.values.flatten.select(&:active?) if @current_user.can_offer_mentoring?
        if @current_user.is_mentor?
          if @current_program.calendar_enabled?
            @received_requests_sender_ids.concat(@current_user.pending_received_meeting_requests.pluck(:sender_id))
          end
          if @current_program.ongoing_mentoring_enabled? && @current_program.matching_by_mentee_alone?
            @connection_request_sender_ids = @current_user.received_mentor_requests.active.pluck(:sender_id)
            @received_requests_sender_ids.concat(@connection_request_sender_ids)
          end
        end
      elsif @role == RoleConstants::MENTOR_NAME
        @match_view = get_match_view_value
        @mentor_groups_map = @current_user.mentor_connections_map if @current_user.is_student?
        @student_of_moderted_group = @current_user.student_of_moderated_groups?
        @recommended_users_hash = @current_user.try(:mentor_recommendation).try(:recommendations_hash) || {}  if (@current_program.matching_by_mentee_and_admin_with_preference? || @current_program.matching_by_mentee_alone?)
        if @current_user.is_student? && @current_program.calendar_enabled? && !@current_program.ongoing_mentoring_enabled?
          @show_mentor_availability = true
        end
      end
      @profile_last_updated_at = @current_program.role_questions_last_update_timestamp(@role)
      @show_filters = @current_user.is_admin? || can_display_available_filters? || (@role == RoleConstants::MENTOR_NAME && @current_user.can_send_mentor_request?) || (@role == RoleConstants::STUDENT_NAME && @current_user.can_offer_mentoring?)
    end

    # For students,mentors and admin the default filter is always "all"
    @filter_field = @filter_field || @filter_param.presence || UsersIndexFilters::Values::ALL
  end

  def initialize_pagination_options
    @items_per_page = (@params[:items_per_page] || PER_PAGE).to_i
    @pagination_options = {:page => @params[:page] || 1, :per_page => @items_per_page}
  end

  def can_see_filtering_options_in_mentors_list?
    @current_user.is_student?
  end

  def preset_defaults_search_and_filter_options(options={})
    show_no_match_filter_visible_page_requirements = @current_user.present? && @role == RoleConstants::MENTOR_NAME && (@match_view.nil? ? get_match_view_value : @match_view)
    show_no_match_filter_visible_program_requirements = @current_program.allow_non_match_connection? || @current_program.allow_user_to_see_match_score?(@current_user)
    @show_no_match_filter_visible = show_no_match_filter_visible_page_requirements && show_no_match_filter_visible_program_requirements
    @initialize_filter_fields_js = []
    @program_only_has_general_availabilty_meeting_filter = !@current_program.ongoing_mentoring_enabled? || options[:only_flash_users]

    if !!@current_user
      if (@role == RoleConstants::MENTOR_NAME && can_see_filtering_options_in_mentors_list?) || @student
        if @params[:filter].blank? && @params[:sf].blank? && (!@params[:calendar_availability_default].present? || @params[:calendar_availability_default].to_s.to_boolean) && !@params[:quick_connect_recommendations]
          @calendar_availability_default = true
          @params[:filter] = []
          if !request.xhr?
            @params[:filter] << UsersIndexFilters::Values::AVAILABLE if @current_program.ongoing_mentoring_enabled? && (@current_user.is_admin? || (@role == RoleConstants::MENTOR_NAME && @current_user.can_send_mentor_request?) || (@role == RoleConstants::STUDENT_NAME && @current_user.can_offer_mentoring?))

            @params[:filter] << UsersIndexFilters::Values::CALENDAR_AVAILABILITY if @program_only_has_general_availabilty_meeting_filter
            @params[:filter] << SHOW_NO_MATCH_FILTER if @show_no_match_filter_visible && @current_program.allow_non_match_connection?
          end
        end
      end
    end
    @show_no_match_filter_value = included_or_equal_to(@params[:filter], SHOW_NO_MATCH_FILTER) if @show_no_match_filter_visible
    @hide_no_match_users = !(@show_no_match_filter_visible ? @show_no_match_filter_value : show_no_match_filter_visible_program_requirements)
  end

  def initialize_search_and_filter_options(options={})
    preset_defaults_search_and_filter_options(options)
    @search_filters_param = @params[:sf]
    @search_query = @params[:search]
    @filter_param = @params[:filter]
    filter_param_excluding_show_no_match = (@filter_param.is_a?(Array) ? (@filter_param - [SHOW_NO_MATCH_FILTER]) : @filter_param)

    @my_filters = []
    unless @current_program.project_based?
      @status_filter_label = ( @role == RoleConstants::MENTOR_NAME ? "feature.user.filter.availability_status".translate : "feature.user.filter.connection_status".translate)
      @my_filters << {:label => @status_filter_label, :reset_suffix => @status_filter_label.to_html_id} if filter_param_excluding_show_no_match.present? && filter_param_excluding_show_no_match != UsersIndexFilters::Values::ALL
    end
    @my_filters << {label: "feature.user.filter.match_score".translate, reset_suffix: "feature.user.filter.match_score".translate.to_html_id} if @show_no_match_filter_value

    if defined?(session) && session.present?
      filter_hash_key = "filter_hash_#{@current_program.id}_#{@role}"
      session[filter_hash_key.to_sym] = @params[:ajax_filters] if @params[:ajax_filters].present?
      @session_filters = session[filter_hash_key.to_sym]
    else
      @session_filters = @params[:ajax_filters] || @session_filters
    end
  end

  def initialize_user_references
    customized_role_term = @current_program.term_for(CustomizedTerm::TermType::ROLE_TERM, @role)
    @user_reference_plural = customized_role_term.pluralized_term
    @user_reference = customized_role_term.term
    @user_references_downcase = customized_role_term.pluralized_term_downcase
  end

  def initialize_sort_values(user, options={})
    @student_document_available = user.present? && user.student_document_available?
    if should_sort_by_default_with_preference?(user, options)
      set_sort_field_to_sort_by_preference      
    elsif @match_view && @student_document_available
      set_sort_field_to_sort_by_match_score      
    else
      set_sort_field_to_sort_by_name
    end
    set_sort_by_instance_variables
  end

  def should_sort_by_default_with_preference?(user, options)
    @match_view && user.explicit_preferences_configured? && !options[:skip_explicit_preferences]
  end

  def set_sort_field_to_sort_by_preference
    @sort_field = @params[:sort] || UserSearch::SortParam::PREFERENCE
    @sort_order = @params[:order] || 'desc'
  end

  def set_sort_field_to_sort_by_match_score
    @sort_field = @params[:sort] || 'match'
    @sort_order = @params[:order] || 'desc'
  end

  def set_sort_field_to_sort_by_name
    @sort_field = @params[:sort] || 'name'
    @sort_order = @params[:order] || 'asc'
  end

  def set_sort_by_instance_variables
    @is_sort_by_match = @sort_field == 'match'
    @is_sort_by_relevance = @sort_field == UserSearch::SortParam::RELEVANCE
    @is_sort_by_preference = @sort_field == UserSearch::SortParam::PREFERENCE
  end

  def get_filtered_users(user, options={})
    @custom_profile_filters = UserProfileFilterService.get_profile_filters_to_be_applied(@search_filters_param)
    @includes_list = @current_program.coach_rating_enabled? ? [:user_stat] : []
    @includes_list << :groups if @current_program.project_based? && !@match_view
    @includes_list += [:roles, :member => [{answered_profile_questions: {question_choices: :translations}}, :profile_picture, :profile_answers => [:answer_choices, :location, :educations, :experiences, :publications, :profile_question => [:translations]]]]

    if @match_view
      @user_ids = apply_sphinx_profile_calendar_filters!(options)
      if @is_matches_for_student
        @student_mentors = @student.mentors.uniq
        @user_ids -= [@student.id]
      end
      sort_and_paginate_users(user)
    else
      @user_ids = apply_profile_calendar_filters!
      search_query = make_search_query(@search_filters_param, @search_query)
      search_options = make_search_options(@role, @search_filters_param, true, [], options[:skip_explicit_preferences])
      search_options.merge(search_operator: "OR")
      @users = get_filtered_users_based_on_location(User.get_filtered_users(search_query, search_options), search_query, search_options)
    end
  end

  def get_filtered_users_based_on_location(users, search_query, search_options)
    # need to change the location filter query if number of filtered is less than MINIMUM USERS constant
    if users.count < Location::LocationFilter::MINIMUM_USERS && search_options[:geo].present?
      search_options = UserProfileFilterService.add_location_parameters_based_on_google_geocode(search_options)
      User.get_filtered_users(search_query, search_options)
    else
      users
    end
  end

  def display_flash_for_moderated_group(from_weekly_updates)
    return if from_weekly_updates
    if @match_view && @student_of_moderted_group
      @preferred_mentors = @current_user.get_visible_favorites.includes(:favorite => :member).collect(&:favorite)
      if @current_user.prompt_to_request?
        flash.now[:notice] = view_context.get_prompt_to_request_preferred_mentors_message(@preferred_mentors.size)
      end
    end
  end

  def apply_sphinx_profile_calendar_filters!(options={})
    search_query = make_search_query(@search_filters_param, @search_query)
    search_options = make_search_options(@role, @search_filters_param, false, options[:applicable_user_ids]||[], options[:skip_explicit_preferences])
    user_ids = User.get_filtered_users(search_query, search_options.merge!(source_columns: [:id], search_operator: "OR")).map(&:to_i)
    apply_profile_calendar_filters!(user_ids)
  end

  def apply_profile_calendar_filters!(user_ids=nil)
    user_ids = user_ids || @current_program.users.pluck(:id)
    UserProfileFilterService.apply_profile_filters!(@current_program, user_ids, @filter_questions, @custom_profile_filters, @my_filters) if @custom_profile_filters.any?
    user_ids = apply_calendar_filters(user_ids, @filter_field) if calendar_filters_present? && !@quick_connect
    user_ids
  end

  def can_display_available_filters?
    @current_program.calendar_enabled? && @current_user && @current_user.can_view_mentoring_calendar? && @role == RoleConstants::MENTOR_NAME
  end

  def calendar_filters_present?
    can_display_available_filters? && included_or_equal_to(@filter_field, UsersIndexFilters::Values::CALENDAR_AVAILABILITY)
  end

  def included_or_equal_to(ary_or_val, val)
    [ary_or_val].flatten.include?(val)
  end

  def initialize_filterable_and_summary_questions
    profile_filter_service = UserProfileFilterService.new(@current_program, @current_user, [@role])

    @filter_questions = profile_filter_service.filter_questions
    @in_summary_questions = profile_filter_service.in_summary_questions
    @profile_questions = profile_filter_service.profile_questions
    @profile_filterable_questions = profile_filter_service.profile_filterable_questions
    @non_profile_filterable_questions = profile_filter_service.non_profile_filterable_questions
  end

  def has_available_slots?(allowed_meeting_slots, meeting_slots_used)
    (allowed_meeting_slots - meeting_slots_used) > 0
  end
end
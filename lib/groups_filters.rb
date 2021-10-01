module GroupsFilters
  def initialize_date_range_filter_params(date_filter)
    if date_filter.present? && group_params[:src] == "mail"
      start_time = Date.strptime(date_filter.strip, "date.formats.date_range".translate).beginning_of_day.to_datetime
      end_time = start_time + 8.days
    else
      start_time, end_time = CommonFilterService.initialize_date_range_filter_params(date_filter)
    end
    return start_time, end_time
  end

  def initialize_common_search_filters
    @expiry_start_time, @expiry_end_time = initialize_date_range_filter_params(group_params[:search_filters][:expiry_date])
    @closed_start_time, @closed_end_time = initialize_date_range_filter_params(group_params[:search_filters][:closed_date])
    @close_start_time, @close_end_time = initialize_date_range_filter_params(group_params[:search_filters][:close_date])
    @started_start_time, @started_end_time = initialize_date_range_filter_params(group_params[:search_filters][:started_date])
    @search_params_hash = {
      profile_name: group_params[:search_filters][:profile_name],
      slots_available: group_params[:search_filters][:slots_available],
      slots_unavailable: group_params[:search_filters][:slots_unavailable]
    }
  end

  def initialize_my_filters
    my_filters = []
    sub_filter = (@tab_number.nil? || @tab_number == Group::Status::ACTIVE) && group_params[:sub_filter]
    if sub_filter.present? && !(sub_filter[:active] && sub_filter[:inactive] && sub_filter[:not_started] && (!@add_closed_filter || sub_filter[:closed]))
      my_filters << {:label => 'feature.connection.header.status.Status'.translate, :reset_suffix => 'status'}
    end
    if group_params[:search_filters].present?
      my_filters << {:label => 'feature.connection.header.Closure_reason'.translate, :reset_suffix => 'closure_reason_filters'} if group_params[:tab].to_i == GroupsController::StatusFilters::Code::CLOSED && group_params[:search_filters][:closure_reasons].present?
      my_filters << {:label => 'feature.connection.header.connection_name'.translate(Mentoring_Connection: _Mentoring_Connection), :reset_suffix => 'profile_name'} if @search_params_hash[:profile_name].present?
      my_filters << {:label => "feature.connection.header.slots_available_for".translate, :reset_suffix => :slots_available} if @search_params_hash[:slots_available].present? && Group::Status.slots_availability_filter_allowed_states.include?(group_params[:tab].to_i)
      my_filters << {:label => "feature.connection.header.slots_unavailable_for".translate, :reset_suffix => :slots_unavailable} if @search_params_hash[:slots_unavailable].present? && Group::Status.slots_availability_filter_allowed_states.include?(group_params[:tab].to_i)
      my_filters << {:label => 'feature.connection.header.milestone.Milestones'.translate, :reset_suffix => 'milestones'} if group_params[:search_filters][:milestone_status].present? || group_params[:search_filters][:milestone_id].present?
      my_filters << {:label => 'feature.connection.header.Closes_on'.translate, :reset_suffix => 'expiry_date'} if group_params[:search_filters][:expiry_date].present? && (group_params[:tab].to_i == GroupsController::StatusFilters::Code::ACTIVE)
      my_filters << {:label => 'feature.connection.header.Closed_on'.translate, :reset_suffix => 'closed_date'} if group_params[:search_filters][:closed_date].present? && (group_params[:tab].to_i == GroupsController::StatusFilters::Code::CLOSED)
      my_filters << {:label => 'feature.connection.header.Started_on'.translate, :reset_suffix => 'started_date'} if group_params[:search_filters][:started_date].present?
      my_filters << {:label => "feature.multiple_templates.header.multiple_templates_title_v1".translate(Mentoring_Connection: _Mentoring_Connection), :reset_suffix => 'mentoring_model_filters'} if group_params[:search_filters][:mentoring_models].present?
      if group_params[:search_filters][:v2_tasks_status].present? && @v2_tasks_overdue_filter.present?
        my_filters << {:label => "feature.mentoring_model.label.v2_tasks_status".translate, :reset_suffix => 'v2_tasks_status'}
      end
      my_filters << {:label => "feature.connection.header.status.Status".translate, :reset_suffix => "available_to_join"} if group_params[:search_filters][:available_to_join].present? && group_params[:search_filters][:available_to_join] != GroupsHelper::DEFAULT_AVAILABLE_TO_JOIN_FILTER
    end
    my_filters
  end

  def filter_and_init_connections_questions(options = {})
    if @current_program.connection_profiles_enabled?
      connection_profile_questions = @current_program.connection_questions.includes(:translations)
      connection_profile_questions = connection_profile_questions.admin_only(false) unless @is_manage_connections_view
      if options[:find_new] || ((@view == Group::View::DETAILED) && (@is_open_connections_view || @drafted_connections_view || @is_pending_connections_view || @is_proposed_connections_view || @is_rejected_connections_view))
        @connection_questions = connection_profile_questions
      end
      @filterable_connection_questions = connection_profile_questions.filterable
      handle_connection_questions_based_filters if group_params[:connection_questions]
    end
  end

  def handle_membership_based_filter
    @member_filters = group_params[:member_filters].presence || {}
    @member_filters.select!{|_,v| v.present? }
    if @member_filters.present?
      group_ids, membership_scope, role_term, _ = get_common_member_based_filter_base(@member_filters)
      @member_filters.each do |role_id, name_with_email|
        break if group_ids.blank?
        user_ids = User.search_by_name_with_email(@current_program, name_with_email).collect(&:id)
        group_ids = membership_scope.where(role_id: role_id, user_id: user_ids).collect(&:group_id)
        membership_scope = membership_scope.where(:group_id => group_ids)
        @my_filters << {:label => role_term[role_id.to_i], :reset_suffix => "member_filter_#{role_id}"}
      end
      @with_options[:id] = group_ids.present? ? group_ids : [0]
    end
  end

  def get_common_member_based_filter_base(filter)
    group_ids = @with_options[:id] || @groups_scope.pluck(:id)
    membership_scope = @current_program.connection_memberships.where(group_id: group_ids)
    role_term = {}
    @current_program.roles.includes({customized_term: :translations}).for_mentoring.where(id: filter.keys).each{ |role| role_term[role.id] = role.customized_term.term }
    all_user_ids = current_program.users.pluck(:id)
    [group_ids, membership_scope, role_term, all_user_ids]
  end

  def set_member_profile_filters
    @member_profile_filters = group_params[:member_profile_filters].presence || {}
    @member_profile_filters.each {|key, value| @member_profile_filters[key] = (value.is_a?(String) ? JSON.parse(value) : value) }
    @member_profile_filters.each {|_key, value| value.delete_if {|hash| Survey::Report.invalid_filter_hash(hash)}}
  end

  def get_filtered_subset_of_group_ids(membership_scope, role_id, user_ids, options = {})
    group_ids = membership_scope.where(role_id: role_id, user_id: user_ids).collect(&:group_id)
    group_ids = group_ids - membership_scope.where(role_id: role_id, user_id: options[:removed_user_or_member_ids]).collect(&:group_id) if options[:removed_user_or_member_ids]
    group_ids
  end

  def handle_member_profile_based_filter
    set_member_profile_filters
    if @member_profile_filters.present?
      group_ids, membership_scope, role_term, all_user_ids = get_common_member_based_filter_base(@member_profile_filters)
      @member_profile_filters.each do |role_id, filters|
        filter_options = {get_removed_user_or_member_ids: true}
        user_ids = UserAndMemberFilterService.apply_profile_filtering(all_user_ids, filters, {is_program_view: true, program_id: current_program.id, for_groups_index_filter: true, filter_options: filter_options})
        group_ids = get_filtered_subset_of_group_ids(membership_scope, role_id, user_ids, filter_options)
        membership_scope = membership_scope.where(group_id: group_ids)
        @my_filters << {label: "feature.connection.content.role_profile_fields".translate(role_name: role_term[role_id.to_i]), reset_suffix: "member_profile_filter_#{role_id}"}
      end
      @with_options[:id] = group_ids.present? ? group_ids : [0]
    end
  end

  def construct_group_search_options(filter_params = {})
    search_filters = group_params[:search_filters]
    unless search_filters.nil?
      profile_name = search_filters[:profile_name]
      @es_date_range_format = ElasticsearchConstants::DATE_RANGE_FORMATS::DATE_WITH_TIME_AND_ZONE
      @date_format = ElasticsearchConstants::DATE_RANGE_FORMATS::FORMATS_HASH[@es_date_range_format]
      @with_options.merge!(es_range_formats: {published_at: @es_date_range_format, expiry_time: @es_date_range_format, closed_at: @es_date_range_format})
      if search_filters[:started_date].present?
        @with_options.merge!( { published_at: @started_start_time.strftime(@date_format)..@started_end_time.strftime(@date_format) } )
      end
      if search_filters[:expiry_date].present? && (group_params[:tab].to_i == GroupsController::StatusFilters::Code::ACTIVE)
        @with_options.merge!( { expiry_time: @expiry_start_time.strftime(@date_format)..@expiry_end_time.strftime(
          @date_format) } )
      end
      if search_filters[:closed_date].present? && (group_params[:tab].to_i == GroupsController::StatusFilters::Code::CLOSED)
        @with_options.merge!( { closed_at: @closed_start_time.strftime(@date_format)..@closed_end_time.strftime(@date_format) } )
      end
      if search_filters[:mentoring_models].present?
        @with_options.merge!( { mentoring_model_id: search_filters[:mentoring_models].collect(&:to_i) } )
      end
      if search_filters[:closure_reasons].present? && (group_params[:tab].to_i == GroupsController::StatusFilters::Code::CLOSED)
        @with_options.merge!( { closure_reason_id: search_filters[:closure_reasons].collect(&:to_i) } )
      end
      if search_filters[:v2_tasks_status].present? && @v2_tasks_overdue_filter.present?
        case search_filters[:v2_tasks_status]
        when GroupsController::TaskStatusFilter::OVERDUE
          @with_options.merge!( { has_overdue_tasks: true } )
        when GroupsController::TaskStatusFilter::NOT_OVERDUE
          @with_options.merge!( { has_overdue_tasks: false } )
        else
          @with_options.except!(:has_overdue_tasks)
        end
      end
    end

    if @is_manage_connections_view && @mentoring_model_v2_enabled && search_filters.present? && (@tab_number == Group::Status::ACTIVE || @tab_number.nil? || @tab_number == Group::Status::CLOSED)
      handle_survey_response_filter(search_filters) 
      handle_survey_task_status_filter(search_filters)
      handle_custom_task_status_filter(search_filters)
    end

    status_filter = @with_options.delete(:status_filter).present?
    es_filter_hash = {
      search_conditions: get_search_conditions(profile_name, filter_params[:search_query]),
      es_range_formats: @with_options.delete(:es_range_formats),
      must_filters: @with_options.merge(sub_program_search_options),
      includes_list: filter_params[:includes_list],
      sort: filter_params[:sort],
      per_page: ES_MAX_PER_PAGE
    }
    es_filter_hash.merge!(should_filters: [get_status_filter]) if status_filter.present?
    search_filter_availability_slots_updater(search_filters, :slots_available, {gt: 0}, es_filter_hash) if search_filters && search_filters[:slots_available].present? && Group::Status.slots_availability_filter_allowed_states.include?(group_params[:tab].to_i)
    search_filter_availability_slots_updater(search_filters, :slots_unavailable, {lt: 1}, es_filter_hash) if search_filters && search_filters[:slots_unavailable].present? && Group::Status.slots_availability_filter_allowed_states.include?(group_params[:tab].to_i)
    es_filter_hash = filter_based_on_close_date(es_filter_hash) if search_filters.present? && search_filters[:close_date].present? && @report_view_columns.present?
    es_filter_hash
  end

  private

  def search_filter_availability_slots_updater(search_filters, key, operation, es_filter_hash)
    range_hash = {}
    search_filters[key].map { |role_name| range_hash["membership_setting_slots_remaining.#{role_name}"] = operation }
    es_filter_hash[:should_filters] ||= []
    es_filter_hash[:should_filters] << range_hash
  end

  def handle_connection_questions_based_filters
    connection_questions_filter = group_params[:connection_questions]
    connection_questions_filter.select!{ |_,v| v.present? }
    if connection_questions_filter.present?
      group_ids = @groups_scope.pluck(:id)
      connection_questions = @current_program.connection_questions.where(id: connection_questions_filter.keys).select(:id, :question_type).includes(:translations)
      connection_questions_filter.each do |id, ans|
        question = connection_questions.find{|q| q.id == id.to_i}
        @my_filters << {:label => question.question_text, :reset_suffix => "connection_question_#{question.id}"}
        group_ids = filter_based_on_question_type(group_ids, question, ans)
      end
      @with_options[:id] = group_ids.present? ? group_ids : [0]
    end
  end

  def filter_based_on_question_type(group_ids, question, answer_data)
    return if group_ids.blank?
    if question.select_type?
      query = "SELECT G.id FROM groups G
        join common_answers A on A.group_id = G.id
        join answer_choices AC on AC.ref_obj_id = A.id AND AC.ref_obj_type='#{CommonAnswer.name}'
        AND AC.question_choice_id IN (#{Array(answer_data).join(',')})
        WHERE A.common_question_id = #{question.id}
        AND G.program_id = #{@current_program.id}
        AND A.type ='#{Connection::Answer.name}'"
    else
      ans = answer_data.split(/\s+/)
      ans = ans.collect{|data| Group.connection.quote("%#{data}%")}
      ans = ans.collect{|data| "A.answer_text LIKE #{data}"}.join(' AND ')

      query = "SELECT G.id FROM groups G join common_answers A on A.group_id = G.id
        WHERE #{ans}
        AND A.common_question_id = #{question.id}
        AND G.program_id = #{@current_program.id}
        AND A.type ='#{Connection::Answer.name}'"
    end

    answered_group_ids = ActiveRecord::Base.connection.select_values(query)
    group_ids & answered_group_ids
  end

  def get_status_filter
    no_filter = group_params[:sub_filter].blank?
    if no_filter
      @not_started_filter = true
      @closed_filter = @add_closed_filter
    else
      @not_started_filter = group_params[:sub_filter][:not_started].present?
      @closed_filter = group_params[:sub_filter][:closed].present?
    end
    with_options = {}
    with_options[:status] = Group::Status::CLOSED if @closed_filter
    with_options.merge!({filters: []})
    with_options[:filters] << {must_filters: Group.group_not_started } if @not_started_filter
    with_options[:filters] << {must_filters: Group.group_started_active } if no_filter || group_params[:sub_filter][:active].present?
    with_options[:filters] << {must_filters: Group.group_started_inactive } if no_filter || group_params[:sub_filter][:inactive].present?

    with_options
  end

  def handle_dashboard_health_filters(dashboard_health_filters)
    filtered_group_ids = @with_options[:id] || @groups_scope.pluck(:id)
    group_ids = get_group_id_based_on_dashboard_filters(dashboard_health_filters[:type], dashboard_health_filters[:start_date], dashboard_health_filters[:end_date])
    filtered_group_ids &= group_ids
    @with_options[:id] = filtered_group_ids.present? ? filtered_group_ids : [0]
    return group_ids.size
  end

  def get_group_id_based_on_dashboard_filters(type, start_date, end_date)
    date_range = start_date.to_date.beginning_of_day.in_time_zone(Time.zone)..end_date.to_date.end_of_day.in_time_zone(Time.zone)
    case type
    when GroupsController::DashboardFilter::GOOD
      @current_program.send(:get_group_data_for_positive_outcome_between, date_range)
    when GroupsController::DashboardFilter::NEUTRAL_BAD
      @current_program.send(:get_group_data_for_neutral_outcome_between, date_range)
    when GroupsController::DashboardFilter::NO_RESPONSE
      @current_program.send(:groups_with_overdue_survey_responses_and_active_within, date_range)
    end
  end

  def handle_survey_response_filter(search_filter)
    need_survey_filter = (survey_filter = search_filter[:survey_response]) && survey_filter[:survey_id].present? && survey_filter[:question_id].present? && survey_filter[:answer_text].present?
    if need_survey_filter
      already_filtered_groups = @with_options[:id]
      group_ids = apply_survey_answer_filter(survey_filter, already_filtered_groups)
      @with_options[:id] = group_ids.present? ? group_ids : [0]
    end
  end

  def apply_survey_answer_filter(survey_filter, already_filtered_groups)
    survey = @current_program.surveys.of_engagement_type.find(survey_filter[:survey_id])
    question = survey.get_questions_for_report_filters.find(survey_filter[:question_id])
    @my_filters << {:label => "feature.connection.header.survey_response_filter.labels.survey_response".translate, :reset_suffix => "survey_filter"}
    query = get_query_for_survey_answer_filter(question, survey_filter)
    query += " AND group_id IN (#{already_filtered_groups.join(",")})" if already_filtered_groups.present?
    ActiveRecord::Base.connection.select_values(" " + query)
  end

  def get_query_for_survey_answer_filter(question, survey_filter)
    query = "SELECT group_id FROM common_answers A"
    if question.choice_based?
      query += " JOIN answer_choices AC on AC.ref_obj_id = A.id AND AC.ref_obj_type='#{CommonAnswer.name}' AND AC.question_choice_id IN (#{survey_filter[:answer_text]})
        WHERE common_question_id = #{question.id} AND type = '#{SurveyAnswer.name}'"
    else
      ans = survey_filter[:answer_text].split(/\s+/)
      ans = ans.collect{|data| Group.connection.quote("%#{data}%")}
      ans = ans.collect{|data| "answer_text LIKE #{data}"}.join(' AND ')
      query += " WHERE common_question_id = #{question.id} AND type = '#{SurveyAnswer.name}' AND #{ans}"
    end
    query
  end

  def handle_survey_task_status_filter(search_filter)
    need_survey_tasks_filter = (survey_filter = search_filter[:survey_status]) && survey_filter[:survey_id].present? && survey_filter[:survey_task_status].present? 
    if need_survey_tasks_filter
      already_filtered_groups = @with_options[:id]
      group_ids = apply_survey_task_status_filter(survey_filter, already_filtered_groups)
      @with_options[:id] = group_ids.present? ? group_ids : [0]
    end
  end

  def handle_custom_task_status_filter(search_filters)
    if @v2_tasks_overdue_filter.present? && search_filters[:v2_tasks_status].present? && search_filters[:v2_tasks_status] == GroupsController::TaskStatusFilter::CUSTOM
      if search_filters[:custom_v2_tasks_status] && search_filters[:custom_v2_tasks_status][:rows]
        filtered_group_ids = @with_options[:id]
        search_filters[:custom_v2_tasks_status][:rows].values.each do |filter|
          filtered_group_ids = apply_task_status_filter(filter, filtered_group_ids)
          filtered_group_ids = [0] if filtered_group_ids.empty?
        end
        @with_options[:id] = filtered_group_ids
      end
    end
  end

  def apply_task_status_filter(filter, filtered_group_ids)
    total_tasks = MentoringModel::Task.where(mentoring_model_task_template_id: filter[:task_id])
    tasks = get_filtered_tasks(total_tasks, filter[:operator].to_i)
    group_ids = tasks.pluck("DISTINCT group_id")
    group_ids = group_ids & filtered_group_ids if filtered_group_ids.present?
    return group_ids
  end

  def apply_survey_task_status_filter(survey_filter, already_filtered_groups)
    survey = @current_program.surveys.of_engagement_type.find(survey_filter[:survey_id])
    @my_filters << {:label => "feature.connection.header.survey_status_filter.labels.survey_status".translate, :reset_suffix => "survey_status_filter"}
    total_tasks = MentoringModel::Task.for_the_survey_id(survey.id)
    tasks = get_filtered_tasks(total_tasks, survey_filter[:survey_task_status].to_i)
    group_ids = tasks.pluck(:group_id).uniq
    group_ids = group_ids & already_filtered_groups if already_filtered_groups.present?
    return group_ids
  end

  def get_filtered_tasks(total_tasks, operator)
    case operator
    when MentoringModel::Task::StatusFilter::COMPLETED then total_tasks.status(MentoringModel::Task::Status::DONE)
    when MentoringModel::Task::StatusFilter::NOT_COMPLETED then total_tasks.status(MentoringModel::Task::Status::TODO)
    when MentoringModel::Task::StatusFilter::OVERDUE then total_tasks.overdue
    else total_tasks
    end
  end

  def filter_based_on_close_date(es_filter_hash)
    @my_filters << {:label => 'feature.connection.header.Close_date'.translate, :reset_suffix => 'close_date'} if group_params[:search_filters][:close_date].present? && !@report_view_columns.blank?

    es_filter_hash[:should_filters] ||= []
    es_filter_hash[:should_filters] << { filters: [{ must_filters: { expiry_time: { gt: @close_start_time.strftime(@date_format), lte: @close_end_time.strftime(@date_format) } }, must_not_filters: { exists_query: "closed_at" } }],  closed_at: { gt: @close_start_time.strftime(@date_format), lte: @close_end_time.strftime(@date_format) } }
    return es_filter_hash
  end

  def get_search_conditions(profile_name, search_query)
    search_conditions = []
    if profile_name.present?
      search_conditions << {search_text: profile_name, fields: [:name]}
    end

    if search_query.present?
      search_conditions << {search_text: search_query, fields: ["name", "mentors.name_only", "students.name_only"], operator: "OR"}
    end

    return {} if search_conditions.blank?
    return search_conditions if profile_name.present? && search_query.present?
    return search_conditions[0]
  end
end
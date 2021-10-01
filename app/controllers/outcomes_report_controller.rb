class OutcomesReportController < ApplicationController

  module CacheConstants
    TIME_TO_LIVE = 120.minutes
    REDUCE_TTL = 60
  end

  allow user: :can_view_reports?

  def user_outcomes_report
    options = {
      cache_key: params[:user_ids_cache_key],
      data_side: params[:data_side],
      fetch_user_state: params[:fetch_user_state],
      include_rolewise_summary: params[:include_rolewise_summary],
      only_rolewise_summary: params[:only_rolewise_summary]
    }

    @user_outcomes_report ||= UserOutcomesReport.new(current_program, get_en_datetime_str(params[:date_range]), options)
    @user_outcomes_report.remove_unnecessary_instance_variables
    render json: @user_outcomes_report.to_json
  end

  def connection_outcomes_report
    @connection_outcomes_report ||= ConnectionOutcomesReport.new(current_program, get_en_datetime_str(params[:date_range]), {:status => params[:status], :type => params[:type], :cache_key => params[:user_ids_cache_key], :data_side =>  params[:data_side]})
    @connection_outcomes_report.remove_unnecessary_instance_variables
    render :json => @connection_outcomes_report.to_json
  end

  def meeting_outcomes_report
    @meeting_outcomes_report ||= MeetingOutcomesReport.new(current_program, date_range: get_en_datetime_str(params[:date_range]), type: params[:type], cache_key: params[:user_ids_cache_key])
    @meeting_outcomes_report.remove_program
    render json: @meeting_outcomes_report.to_json
  end

  def positive_outcomes_options_popup
    @questions_data = current_program.get_positive_outcomes_questions_array
    render partial: "reports/outcomes_report/configure_positive_outcomes_popup"
  end

  def detailed_users_outcomes_report_data
    options = { date_range: get_en_datetime_str(params[:date_range]), page: params[:page], page_size: params[:page_size], sort_order: params[:sort_order], sort_field: params[:sort_field], user_ids_cache_key: params[:user_ids_cache_key], fetch_user_data: true }
    @detailed_outcomes_report = DetailedOutcomesReport.new(current_program, options)
    paginationHTML = render_to_string({:partial => 'reports/outcomes_report/detailed_outcomes_report_pagination', :locals => {:detailed_outcomes_report_object => @detailed_outcomes_report.users}}) if @detailed_outcomes_report.users.present?
    render json: {user_data: @detailed_outcomes_report.userData, paginationHTML: paginationHTML}.to_json
  end

  def update_positive_outcomes_options
    page_data = Hash[params[:data].map{|block| [block[:id].to_i, (block[:selected] || []).join(CommonQuestion::SEPERATOR)]}]
    current_program.update_positive_outcomes_options!(page_data)
    (redirect_to global_reports_path(root: nil) and return) if params[:return_to_global_reports].to_s.to_boolean 
    redirect_to outcomes_report_path
  end

  def detailed_connection_outcomes_report_group_data
    options = params.permit(:date_range, :page_size, :sort_field, :sort_type, :group_table_cache_key, :profile_filter_cache_key).to_h.merge(page_number: params[:page], fetch_group_data: true)
    options[:date_range] = get_en_datetime_str(options[:date_range]) if options[:date_range].present?

    generate_filter_options_for_detailed_connection_outcomes_report_group_data(options)

    @detailed_outcomes_report = DetailedOutcomesReport.new(current_program, options)
    paginationHTML = render_to_string({:partial => 'reports/outcomes_report/detailed_outcomes_report_pagination', :locals => {:detailed_outcomes_report_object => @detailed_outcomes_report.groups}}) if @detailed_outcomes_report.groups.present?
    render json: {groups_data: @detailed_outcomes_report.groupsData, groups_table_hash: @detailed_outcomes_report.groupsTableHash, group_table_cache_key: @detailed_outcomes_report.groupsTableCacheKey, pagination_html: paginationHTML}.to_json
  end

  def detailed_connection_outcomes_report_user_data
    options = params.permit(:date_range, :page_size, :page, :sort_field, :sort_type, :user_table_cache_key, :profile_filter_cache_key).to_h.merge(fetch_user_data_for_connection_report: true)
    options[:date_range] = get_en_datetime_str(options[:date_range]) if options[:date_range].present?
    options[:for_role] = params[:for_role].to_i unless params[:for_role].to_i.zero?

    @detailed_outcomes_report = DetailedOutcomesReport.new(current_program, options)
    paginationHTML = render_to_string({:partial => 'reports/outcomes_report/detailed_outcomes_report_pagination', :locals => {:detailed_outcomes_report_object => @detailed_outcomes_report.users}}) if @detailed_outcomes_report.users.present?
    render json: {users_data: @detailed_outcomes_report.userData, users_table_hash: @detailed_outcomes_report.usersTableHash, user_table_cache_key: @detailed_outcomes_report.usersTableCacheKey, pagination_html: paginationHTML}.to_json
  end

  def detailed_connection_outcomes_report_non_table_data
    options = params.permit(:tab, :section).to_h.merge(cache_key: params[:user_ids_cache_key])
    options[:role] = params[:for_role].to_i unless params[:for_role].to_i.zero?
    @connection_detailed_outcomes_data = ConnectionDetailedReport.new(current_program, get_en_datetime_str(params[:date_range]), options)
    render :json => @connection_detailed_outcomes_data.to_json
  end

  def get_filtered_users
    profile_filter_params = Survey::Report.remove_incomplete_report_filters(params[:report][:profile_questions]) if params[:report].present? && params[:report][:profile_questions].present?
    @filters_count = 0
    if profile_filter_params.present?
      dynamic_profile_filter_params = ReportsFilterService.dynamic_profile_filter_params(profile_filter_params)
      @filters_count += 1 if dynamic_profile_filter_params.present?
      user_ids = UserAndMemberFilterService.apply_profile_filtering(current_program.users.pluck(:id), dynamic_profile_filter_params, {:is_program_view => true, :program_id => current_program.id, :for_report_filter => true})
      write_in_cache(user_ids)
    end
    date_filter = {}
    date_range = get_en_datetime_str(params[:date_range]).split(DATE_RANGE_SEPARATOR).collect{|date| date.strip.to_datetime}
    date_filter[:start], date_filter[:end] = date_range[0], date_range[1]
    render partial: "reports/outcomes_report/get_filtered_users", locals: {cache_key: @cache_key, date_filter: date_filter}
  end

  def filter_users_on_profile_questions
    @my_filters = []
    search_filters_param = params[:sf]
    custom_profile_filters = UserProfileFilterService.get_profile_filters_to_be_applied(search_filters_param)
    if custom_profile_filters.any? || (search_filters_param.present? && search_filters_param[:location])
      user_ids = apply_profile_filters_and_location_filters(search_filters_param, custom_profile_filters)
      write_in_cache(user_ids)
      response_hash = generate_response_hash_for_profile_filters(@cache_key, OutcomesReportController::CacheConstants::TIME_TO_LIVE, search_filters_param, @my_filters, @pivot_location)
    else
      response_hash = {cache_key: nil, time_to_live: 0, location: {invalid_location_filter: false}, my_filters: []}
    end
    render json: response_hash.to_json
  end

  private

  def write_in_cache(user_ids)
    group_ids = Connection::Membership.where(:user_id => user_ids).pluck(:group_id).uniq
    member_ids = User.where(:id => user_ids).pluck(:member_id).uniq
    @cache_key = Time.now.to_i.to_s + ((rand*1000).floor).to_s
    Rails.cache.write(@cache_key+"_users", user_ids, :time_to_live => OutcomesReportController::CacheConstants::TIME_TO_LIVE)
    Rails.cache.write(@cache_key+"_groups", group_ids, :time_to_live => OutcomesReportController::CacheConstants::TIME_TO_LIVE)
    Rails.cache.write(@cache_key+"_members", member_ids, :time_to_live => OutcomesReportController::CacheConstants::TIME_TO_LIVE)
  end

  def get_positive_outcomes_questions_array(program)
    questions_array = []
    meeting_or_engagement_surveys_scope_for(program).includes(:translations, survey_questions: [:translations, { question_choices: :translations } ]).select(:id).collect do |survey|
      questions_array << {text: survey.name, children: get_survey_questions_for_outcomes(survey)}
    end
    return questions_array
  end

  def get_survey_questions_for_outcomes(survey)
    survey.get_questions_in_order_for_report_filters.select(&:choice_based?).map{|question| {id: question.id,
        text: question.question_text_for_display,
        choices: question.values_and_choices.map{|qc_id, qc_text| {id: qc_id, text: qc_text}},
        selected: question.positive_choices}}
  end

  def meeting_or_engagement_surveys_scope_for(program)
    surveys = program.surveys
    program.ongoing_mentoring_enabled? ? surveys.of_engagement_type : surveys.of_meeting_feedback_type
  end

  def apply_profile_filters_and_location_filters(search_filters_param, custom_profile_filters)
    roles_for_mentoring = current_program.roles.for_mentoring
    filter_questions = OutcomesReportUtils.get_profile_filters_for_outcomes_report(current_program)
    user_ids = []

    # Applying location filter
    if search_filters_param.present? && search_filters_param[:location]
      additional_with_options = sub_program_search_options
      with_options = {"roles.id" => roles_for_mentoring.pluck(:id)}
      with_options.merge!(additional_with_options)
      options = {
        page: 1,
        per_page: ES_MAX_PER_PAGE,
        with: with_options,
        source_columns: [:id]
      }
      location_params_hash = UserProfileFilterService.add_location_parameters_to_options(search_filters_param, options, @my_filters, "member.location_answer.location.point")
      search_options = location_params_hash[:options]
      @pivot_location = location_params_hash[:pivot_location]
      @my_filters = location_params_hash[:my_filters]
      user_ids = @pivot_location.nil? ? [] : User.get_filtered_users("", search_options)
    else
      user_ids = current_program.users.pluck(:id)
    end

    # Applying all other profile filters
    user_ids = user_ids.to_a
    # custom_profile_filters = UserProfileFilterService.get_profile_filters_to_be_applied(search_filters_param)
    UserProfileFilterService.apply_profile_filters!(current_program, user_ids, filter_questions, custom_profile_filters, @my_filters) if custom_profile_filters.any?
    return user_ids
  end

  def generate_response_hash_for_profile_filters(cache_key, time_to_live, search_filters_param, my_filters, pivot_location)
    response_hash = {cache_key: cache_key, time_to_live: (time_to_live.to_i - OutcomesReportController::CacheConstants::REDUCE_TTL), location: {}, my_filters: my_filters}
    response_hash[:location][:invalid_location_filter] = false
    if search_filters_param.present? && search_filters_param[:location]
      response_hash[:location][:invalid_location_filter] = (!pivot_location)
      response_hash[:location][:error_message] = "feature.user.content.unknown_location".translate unless pivot_location
    end
    return response_hash
  end

  def generate_filter_options_for_detailed_connection_outcomes_report_group_data(options)
    return if params[:status_filter].nil?
    return unless [DetailedReports::GroupsFilterAndSortService::CurrentStatus::ONGOING, DetailedReports::GroupsFilterAndSortService::CurrentStatus::COMPLETED, DetailedReports::GroupsFilterAndSortService::CurrentStatus::DISCARDED].include?(params[:status_filter])
    options.merge!({filter: {current_status: params[:status_filter]}})
  end

end

# Provides reporting to be viewed by the administrators.
class ReportsController < ApplicationController

  include HealthReportsHelper
  include GroupsReportExtensions
  include GroupsFilters
  include Report::SectionsControllerUtils
  include Report::Customization

  module ManagementReportConstants
    DEFAULT_LIMIT = 30.days

    module AsyncLoadingSections
      ENROLLMENT = 'enrollment'
      MATCHING = 'matching'
      ENGAGEMENTS = 'groups'
      GROUPS_ACTIVITY = 'groups_activity'
      COMMUNITY = 'community'

      MAPPING = {
        ENROLLMENT => {element_id: "enrollment_health_report", partial: "reports/management_report/enrollment_health_report"},
        MATCHING => {element_id: "matching_health_report", partial: "reports/management_report/matching_health_report"},
        ENGAGEMENTS => {element_id: "engagements_info", partial: "reports/management_report/display_engagements_report"},
        GROUPS_ACTIVITY => {element_id: "connections_activity_info", partial: "reports/management_report/display_group_activity_report"},
        COMMUNITY => {element_id: "dashboard_community", partial: "reports/management_report/display_community_report"}
      }

      TILE_MAPPING = {
        DashboardReportSubSection::Tile::ENROLLMENT => ENROLLMENT,
        DashboardReportSubSection::Tile::MATCHING => MATCHING,
        DashboardReportSubSection::Tile::ENGAGEMENTS => ENGAGEMENTS,
        DashboardReportSubSection::Tile::GROUPS_ACTIVITY => GROUPS_ACTIVITY
      }
    end
  end

  # Chart related constants
  CHART_COLOR   = "99BB44"
  CHART_COLOR_1 = "8866CC"
  CHART_COLOR_2 = "BB8866"
  CHART_SIZE    = "570x200"

  # Groups report table content
  GROUPS_REPORT_PER_PAGE = 25
  DEMOGRAPHIC_REPORT_PER_PAGE = 10

  # Groups Report default date range: 3.months.ago - Time.now
  DEFAULT_GROUPS_REPORT_START_DATE = 3.months.ago

  ALL = 'all'
  COUNTRY_REGEXP = /\s|\(|\)|\,/

  module DateRangeOptions
    PROGRAM_TO_DATE = "program_to_date"
    MONTH_TO_DATE = "month_to_date"
    QUARTER_TO_DATE = "quarter_to_date"
    YEAR_TO_DATE = "year_to_date"
    LAST_MONTH = "last_month"
    LAST_QUARTER = "last_quarter"
    LAST_YEAR = "last_year"
    CUSTOM = "custom"

    def self.presets
      [PROGRAM_TO_DATE, MONTH_TO_DATE, QUARTER_TO_DATE, YEAR_TO_DATE, LAST_MONTH, LAST_QUARTER, LAST_YEAR]
    end
  end

  module ProgramGoalCompletionTab
    BY_TIME = 0
    BY_MENTOR = 1
    BY_MENTORING_TEMPLATE = 2
  end

  module GoogleAnalytics
    MEETING_SESSIONS_REPORT_LABEL = "Meeting Sessions"
    MEETING_REQUESTS_REPORT_LABEL = "Meeting Requests"
    MEMBERSHIP_REQUESTS_REPORT_LABEL = "Membership Requests"
    MENTOR_OFFERS_REPORT_LABEL = "Mentor Offers"
    MENTORING_SESSIONS_REPORT_LABEL = "Mentoring Sessions"
    SURVEY_REPORT = "Survey Report"
    DEMOGRAPHIC_REPORT_LABEL = "Demographic Report"
    MENTOR_REQUESTS_REPORT_LABEL = "Mentoring Requests"
    CONNECTION_ACTIVITY_REPORT_LABEL = "Connection Activity Report"
    PROJECT_REQUESTS_REPORT_LABEL = "Project Requests"

    LABEL_ID_MAPPING = {
      MEETING_SESSIONS_REPORT_LABEL => 2,
      MEETING_REQUESTS_REPORT_LABEL => 3,
      MENTOR_OFFERS_REPORT_LABEL => 4,
      MEMBERSHIP_REQUESTS_REPORT_LABEL => 5,
      MENTORING_SESSIONS_REPORT_LABEL => 6,
      SURVEY_REPORT => 7,
      DEMOGRAPHIC_REPORT_LABEL => 8,
      MENTOR_REQUESTS_REPORT_LABEL => 9,
      CONNECTION_ACTIVITY_REPORT_LABEL => 10,
      PROJECT_REQUESTS_REPORT_LABEL => 11
    }
  end

  before_action :show_pendo_launcher_in_all_devices, only: [:management_report]
  before_action :initialize_filter_params, only: [:demographic_report]
  before_action :set_report_category, only: [:activity_report, :executive_summary, :health_report, :demographic_report, :groups_report, :outcomes_report]

  # Check permissions to view reports.
  allow user: :can_view_reports?
  allow exec: :show_groups_report?, only: [:groups_report]

  helper_method :group_params

  def index
    @categories = Category.all.map do |category|
      category_name, description = get_categoary_title_and_description(Category::NAMES[category])
      {
        category: category,
        name: category_name,
        description: description,
        icon: Category::ICONS[category]
      }
    end
  end

  def categorized
    @category = params[:category].to_i
    @title, @title_description = get_categoary_title_and_description(Category::NAMES[@category])

    @reports_attributes_list = ReportItem.get_valid_report_attributes(@category, current_program, current_user)
    @reports_by_subcategory_hash = @reports_attributes_list.group_by{ |report_attribute| report_attribute[:subcategory].call(@category) }
  end

  def initialize_activity_report_filter_params
    if params[:date_range_filter].blank?
      t0 = Time.current.to_datetime
      t1 = @current_program.created_at
      t2 = t0 - 1.month
      @start_time, @end_time = t1 > t2 ? t1 : t2, t0
    else
      user_time_zone = wob_member.short_time_zone
      range = params[:date_range_filter].split(DATE_RANGE_SEPARATOR).collect do |date|
        Date.strptime(date.strip, date_range_format).to_datetime.change(offset: user_time_zone)
      end
      if range.count > 1
        @start_time, @end_time =  range[0], range[1]
      else
        @start_time, @end_time =  range[0], range[0]
      end
    end
    @date_range_preset = params[:date_range_preset]

    @role_filters = params[:role_filters].presence || @current_program.roles_without_admin_role.collect(&:name)
  end

  def activity_report
    initialize_activity_report_filter_params
    @program_health_report = HealthReport::ProgramHealthReport.new(current_program)
    @program_health_report.compute(@start_time, @end_time, @role_filters)

    respond_to do |format|
      format.html
      format.pdf do
        @title = "feature.reports.header.activity_report".translate
        render :pdf => "feature.reports.label.activity_report_name".translate(role_names: RoleConstants.human_role_string(@role_filters, program: @current_program), start_time: @start_time.to_date, end_time: @end_time.to_date)
      end
      format.csv do
        activity_report_csv_file_basename = "feature.reports.label.activity_report_name".translate(role_names: RoleConstants.human_role_string(@role_filters, program: @current_program), start_time: @start_time.to_date, end_time: @end_time.to_date)
        send_data activity_report_csv_data,
          :type => 'text/csv; charset=iso-8859-1; header=present',
          :disposition => "attachment; filename=#{activity_report_csv_file_basename}.csv"
      end
    end
  end

  def health_report
    @health_report ||= HealthReport::Base.new(current_program)
    @start_time = @current_program.created_at

    respond_to do |format|
      format.html do
        @health_report.growth.compute_summary_data
      end
      format.js do
        @sub_report = HealthReport::Base::SubReports::MAPPING[params[:report]]
        @health_report.send(@sub_report).compute
      end
      format.pdf do
        @health_report.compute
        @title = "feature.reports.header.program_health_report".translate
        render :pdf => "feature.reports.label.program_health_report_name".translate(Program: _Program)
      end
    end
  end

  def management_report
    @my_all_connections_count = current_user.groups.published.size if current_user.roles.for_mentoring.exists?
    set_date_range_preset
  end

  def management_report_async_loading
    section = params[:section] || ManagementReportConstants::AsyncLoadingSections::TILE_MAPPING[params[:tile]]
    @partial = ManagementReportConstants::AsyncLoadingSections::MAPPING[section][:partial]
    @element_id = ManagementReportConstants::AsyncLoadingSections::MAPPING[section][:element_id]
    @skip_hiding_loader = true
    set_date_range_preset
  end

  def filter_management_report
    set_date_range_preset
    @tile = params[:filters][:tile]
    @engagement_type = program.get_engagement_type
  end

  def outcomes_report
    initialize_outcomes_report_date_params
    @show_flash_mentoring_sections = !current_program.ongoing_mentoring_enabled?
    @ongoing_mentoring_enabled = current_program.ongoing_mentoring_enabled?
    @positive_outcome_surveys = current_program.get_positive_outcome_surveys
    set_profile_questions_for_outcomes_report
    @my_filters = []

    respond_to do |format|
      format.html
      format.pdf do
        @is_pdf = true
        @title = "feature.reports.header.program_outcomes_report".translate(Program: _Program)
        @applied_filters = (params[:filters].present?) ? params[:filters].split(",") : []
        set_date_range_text
        initalize_data_for_outcomes_report_pdf
        render :pdf => "feature.outcomes_report.pdf_name".translate(Program: _Program), :show_as_html => params[:debug].present?
      end
    end
  end

  def detailed_user_outcomes_report
    initialize_outcomes_report_date_params
    set_profile_questions_for_outcomes_report
    @my_filters = []
  end

  def detailed_connection_outcomes_report
    @tab = params[:tab].to_i
    initialize_outcomes_report_date_params
    set_profile_questions_for_outcomes_report
    @my_filters = []
  end

  def executive_summary
    # Fetch data... Membership distribution.
    @users_count_hash = {}
    all_user_ids = []
    @current_program.roles_without_admin_role.each do |role|
      user_ids = @current_program.send("#{role.name}_users").active.pluck(:id)
      @users_count_hash[role.name] = user_ids.size
      all_user_ids += user_ids
    end

    @total_users_count = all_user_ids.uniq.size
    @multi_roles_users_count = all_user_ids.group_by{|x| x}.select{|_, x| x.size > 1}.size
    # Connection related information
    @pending_requests_cnt = @current_program.mentor_requests.active.size unless @current_program.matching_by_admin_alone?
    @active_groups_cnt = @current_program.groups.active.size
    @closed_groups_cnt = @current_program.groups.closed.size

    # Mentoring sessions related information
    fetch_meeting_data_for_executive_summary_report if calendar_feature_enabled?

    respond_to do |format|
      format.html
      format.pdf do
        @title = "feature.reports.header.executive_summary_report".translate
        render :pdf => "feature.reports.label.executive_summary_report_name".translate, show_as_html: params[:debug_pdf].present?
      end
    end

  end

  def demographic_report
    location_question = @current_organization.profile_questions.location_questions.first
    if location_question.present?
      @role_column_mapping = @current_program.demographic_report_role_based_view_columns
      all_roles = @role_column_mapping.keys
      @roles = []

      all_roles.each do |role_name|
        @roles << role_name if @current_program.role_questions_for(role_name).role_profile_questions.where(:profile_question_id => location_question.id).first.present?
      end

      @show_for_all_roles = (all_roles.length == @roles.length) && @roles.length > 1

      if @roles.present?
        all_role_ids = @current_program.get_roles(@roles).collect(&:id)
        users_scope = User.active.where(:program_id => @current_program.id)
        locations_scope = Location.where.not(lat:nil, lng: nil, country: nil)
        profile_answer_scope = ProfileAnswer.joins("INNER JOIN users ON (profile_answers.ref_obj_type = 'Member' and profile_answers.ref_obj_id = users.member_id) INNER JOIN locations ON (profile_answers.location_id = locations.id) INNER JOIN role_references ON (role_references.ref_obj_type = 'User' and role_references.ref_obj_id = users.id)").merge(locations_scope).merge(users_scope)
        all_roles_scope = RoleReference.where(role_id: all_role_ids)
        location_select = "country, full_address, lat, lng, city, COUNT(DISTINCT users.member_id) AS location_count"
        @all_users_locations = profile_answer_scope.select(location_select).merge(all_roles_scope).group(:location_id)
        @role_locations = {}
        @role_locations_without_select = {}
        roles_scope = {}
        select_queries = ["country, full_address, lat, lng, city, COUNT(DISTINCT users.member_id) AS all_users_count"]
        @roles.each do |role_name|
          role_ids = @current_program.get_roles(role_name).collect(&:id)
          select_queries << "SUM(CASE WHEN role_references.role_id IN (#{role_ids.join(", ")}) THEN 1 ELSE 0 end) AS #{role_name}_users_count"
          roles_scope[role_name] = RoleReference.where(role_id:role_ids)
          @role_locations[role_name] = profile_answer_scope.select(location_select).merge(roles_scope[role_name]).group(:location_id)
          @role_locations_without_select[role_name] = profile_answer_scope.merge(roles_scope[role_name])
        end

        @most_users_country = profile_answer_scope.select(select_queries).merge(all_roles_scope).group(:country).order("all_users_count DESC").first.try(:country)
        @all_locations = profile_answer_scope.select(select_queries).merge(all_roles_scope).group(:location_id)
      end
    end

    if @most_users_country.present?
      @map_filter = @filter_params[:map_filter]
      initialize_map! if @map_filter || !request.xhr?
      initialize_table_view! if !@map_filter || !request.xhr?
    end
  end

  def groups_report
    @point_interval = group_params[:point_interval].try(:to_i) || GroupsReport::PointInterval::WEEK
    @chart_updated = !(["pagination"].include? group_params[:from])
    update_groups_report_view!(@current_program, params[:columns]) if params[:columns].present?
    @report_view_columns = @current_program.get_groups_report_view_columns
    initialize_groups_report_params

    @is_manage_connections_view = true
    @groups_scope = @current_program.groups.published
    @mentoring_model_v2_enabled = @current_program.mentoring_connections_v2_enabled?

    @search_filters = group_params[:search_filters] || {}
    initialize_common_search_filters if @search_filters.present?
    initialize_status_filters

    @sub_filter = group_params[:sub_filter]

    @v2_tasks_overdue_filter = @mentoring_model_v2_enabled && @is_manage_connections_view
    @my_filters = group_params[:my_filters] || initialize_my_filters

    filter_and_init_connections_questions
    handle_membership_based_filter if group_params[:member_filters]
    handle_member_profile_based_filter if group_params[:member_profile_filters]
    @es_filter_hash = construct_group_search_options
    group_ids = Group.get_filtered_group_ids(@es_filter_hash)
    groups = @current_program.published_groups_in_date_range(@start_date, @end_date).where(id: group_ids)

    sorted_groups = sort_by_groups_report_column(groups, @sort_param, @sort_order, @start_date, @end_date)
    group_ids = groups.pluck(:id)
    @filters_count = @my_filters.size
    groups_report_respond_to_format(sorted_groups, group_ids)
  end

  def edit_groups_report_view
    @report_view_columns = @current_program.get_groups_report_view_columns
    initialize_groups_report_params
    render :partial => "reports/edit_columns_popup"
  end

  def group_params
    params[:filters].presence || params
  end

  private

  def set_date_range_preset
    start_date, end_date = ReportsFilterService.get_report_date_range(params[:filters], ManagementReportConstants::DEFAULT_LIMIT.ago)
    start_time = start_date.beginning_of_day.in_time_zone(Time.zone)
    end_time = end_date.end_of_day.in_time_zone(Time.zone)
    @date_range = start_time..end_time
    @date_range_preset = params[:filters].present? ? params[:filters][:date_range_preset].presence : DateRangePresets::LAST_30_DAYS
  end

  def show_groups_report?
    @current_program.show_groups_report?
  end

  def calendar_feature_enabled?
    @current_program.calendar_enabled?
  end

  def initialize_outcomes_report_date_params
    @program_start_date = current_program.created_at # program start date need for some datepicker initialization
    @start_date = @program_start_date # this is the default start date used, changing this will change the UI elements appropriately
    @end_date = Time.current
  end

  def fetch_meeting_data_for_executive_summary_report
    time_intervals_hash = MentoringSlot.session_hours_intervals
    meetings_count_hash = MentoringSlot.generate_meeting_hash(@current_program.meetings, time_intervals_hash)
    non_recurring_slots_hash, recurring_slots_hash = MentoringSlot.generate_slot_hashes(@current_program, nil, time_intervals_hash)

    last_month_session_hours = non_recurring_slots_hash['last2'].to_f + recurring_slots_hash['last2'].to_f
    @last_month_session_stats = {
      :hours_available => last_month_session_hours,
      :hours_blocked => meetings_count_hash['last2'].to_f
    }

    this_month_session_hours = non_recurring_slots_hash['last'].to_f + recurring_slots_hash['last'].to_f
    @this_month_session_stats = {
      :hours_available => this_month_session_hours,
      :hours_blocked => meetings_count_hash['last'].to_f
    }

    next_month_session_hours = non_recurring_slots_hash['next'].to_f + recurring_slots_hash['next'].to_f
    @next_month_session_stats = {
      :hours_available => next_month_session_hours,
      :hours_blocked => meetings_count_hash['next'].to_f
    }
  end

  #Outcomes Report
  def set_date_range_text
    if(params[:date_range].present?)
      date_range = params[:date_range].split("-")
      @start_date_text = date_range[0].strip
      @end_date_text = date_range[1].strip
    end
  end

  def initalize_data_for_outcomes_report_pdf
    if(params[:enabled].present?)
      registered_users_enabled_status = params[:enabled][:users]
      if(@show_flash_mentoring_sections)
        closed_meetings_enabled_status = params[:enabled][:closed]
        positive_meetings_enabled_status = params[:enabled][:positive]
      else
        total_connections_enabled_status = params[:enabled][:total]
        closed_connections_enabled_status = params[:enabled][:closed]
        positive_connections_enabled_status = params[:enabled][:positive]
      end
    end

    en_date_range = get_en_datetime_str(params[:date_range])

    @user_outcomes_report ||= UserOutcomesReport.new(current_program, en_date_range, {:data_side => OutcomesReportUtils::DataType::ALL_DATA, :cache_key => params[:cache_key], :enabled_status => registered_users_enabled_status})
    @user_outcomes_report.remove_unnecessary_instance_variables
    if(@show_flash_mentoring_sections)
      @closed_meeting_outcomes_report ||= MeetingOutcomesReport.new(current_program, {:date_range => en_date_range, :type => MeetingOutcomesReport::Type::CLOSED, :cache_key => params[:cache_key], :enabled_status => closed_meetings_enabled_status})
      @positive_meeting_outcomes_report ||= MeetingOutcomesReport.new(current_program, {:date_range => en_date_range, :type => MeetingOutcomesReport::Type::POSITIVE_OUTCOMES, :cache_key => params[:cache_key], :enabled_status => positive_meetings_enabled_status})
      [@closed_meeting_outcomes_report, @positive_meeting_outcomes_report].each {|report| report.remove_program}
    else
      @active_connection_outcomes_report ||= ConnectionOutcomesReport.new(current_program, en_date_range, {:data_side => OutcomesReportUtils::DataType::ALL_DATA, :cache_key => params[:cache_key], :enabled_status => total_connections_enabled_status})
      @closed_connection_outcomes_report ||= ConnectionOutcomesReport.new(current_program, en_date_range, {:status => Group::Status::CLOSED, :data_side => OutcomesReportUtils::DataType::ALL_DATA, :cache_key => params[:cache_key], :enabled_status => closed_connections_enabled_status})
      @positive_connection_outcomes_report ||= ConnectionOutcomesReport.new(current_program, en_date_range, {:type => ConnectionOutcomesReport::POSITIVE_OUTCOMES, :data_side => OutcomesReportUtils::DataType::ALL_DATA, :cache_key => params[:cache_key], :enabled_status => positive_connections_enabled_status})
      [@active_connection_outcomes_report, @closed_connection_outcomes_report, @positive_connection_outcomes_report].each {|report| report.remove_unnecessary_instance_variables}
    end
  end

  # Groups Report
  def initialize_groups_report_params
    @sort_param = group_params[:sort].presence || (@report_view_columns.present? ? @report_view_columns.first.column_key : ReportViewColumn::GroupsReport::Key::GROUP)
    @sort_order = group_params[:order].presence || "asc"
    @page = params[:page].to_i != 0 ? params[:page].to_i : 1
    current_tz_offset = Time.current.strftime("%z")
    if group_params[:date_range].present?
      start_date = group_params[:date_range].split(DATE_RANGE_SEPARATOR)[0]
      end_date = group_params[:date_range].split(DATE_RANGE_SEPARATOR)[1]
    end
    @start_date = (
      if start_date.present?
        Date.strptime(start_date.strip, MeetingsHelper::DateRangeFormat.call)
      else
        ((@current_program.created_at > DEFAULT_GROUPS_REPORT_START_DATE) ? @current_program.created_at : DEFAULT_GROUPS_REPORT_START_DATE)
      end
    ).to_datetime.beginning_of_day.change(offset: current_tz_offset)
    @end_date = Date.strptime(end_date.strip, MeetingsHelper::DateRangeFormat.call).to_datetime.end_of_day.change(offset: current_tz_offset) if end_date.present?
    @end_date ||= DateTime.current
    @date_range = group_params[:date_range]
    @custom_term_options = {
      :Mentor => _Mentor,
      :Mentee => _Mentee,
      :Mentors => _Mentors,
      :Mentees => _Mentees,
      :Meetings => _Meetings,
      :Mentoring_Connection => _Mentoring_Connection
    }
  end

  def initialize_status_filters
    @with_options = (@is_manage_connections_view && @mentoring_model_v2_enabled) ? {:status_filter => true} : {}
    @add_closed_filter = true
    @status_filter = if @sub_filter.present?
      if (@sub_filter[:active].present? && @sub_filter[:inactive].present?) || (@sub_filter[:active].blank? && @sub_filter[:inactive].blank?)
        GroupsController::StatusFilters::Code::ONGOING
      elsif @sub_filter[:active].present?
        GroupsController::StatusFilters::Code::ACTIVE
      else
        GroupsController::StatusFilters::Code::INACTIVE
      end
    else
      GroupsController::StatusFilters::Code::ONGOING
    end
  end

  def groups_report_respond_to_format(sorted_groups, group_ids)
    column_keys = @report_view_columns.collect(&:column_key)
    @groups_report = GroupsReport.new(@current_program, column_keys, {group_ids: group_ids, point_interval: @point_interval, start_time: @start_date, end_time: @end_date})
    respond_to do |format|
      format.html do
        @groups_report.compute_data_for_view
        paginated_groups = sorted_groups.paginate(:page => @page, :per_page => GROUPS_REPORT_PER_PAGE)
        @groups = paginated_groups.includes(get_groups_report_eager_loadables(column_keys))
      end
      format.js do
        @chart_updated ? @groups_report.compute_data_for_view : @groups_report.compute_table_totals
        paginated_groups = sorted_groups.paginate(:page => @page, :per_page => GROUPS_REPORT_PER_PAGE)
        @groups = paginated_groups.includes(get_groups_report_eager_loadables(column_keys))
      end
      format.csv do
        if @report_view_columns.blank?
          flash[:notice] = "feature.reports.content.no_mentoring_connections_for_exporting".translate(:mentoring_connections => _mentoring_connections)
          redirect_to groups_report_path
        else
          sorted_groups = sorted_groups.includes(get_groups_report_eager_loadables(column_keys))
          @groups_report.compute_data_for_table_row_or_csv
          render_groups_report_csv(sorted_groups)
        end
      end
    end
  end

  def render_groups_report_csv(groups)
    formatted_start_date = DateTime.localize(@start_date, format: :full_display_no_time)
    formatted_end_date = DateTime.localize(@end_date, format: :full_display_no_time)
    groups_report_csv_name = "feature.reports.label.group_activity_report_name".translate(Mentoring_Connection: _Mentoring_Connection, program_name: @current_program.name, start_date: formatted_start_date, end_date: formatted_end_date)
    CSVStreamService.new(response).setup!(groups_report_csv_name, self) do |stream|
      export_groups_report_to_stream(stream, @groups_report, groups, @report_view_columns, @custom_term_options)
    end
  end

  def initialize_map!
    @my_filters = []
    @locations = []
    @selected_countries = @filter_params[:countries] || []

    @most_role_country = {}

    @role_locations_without_select.each do |role_name, locations|
      @most_role_country[role_name] = locations.order("count_all DESC").group("country").count.first.try(:first)
    end

    filtered_locations = @role_locations.fetch(@filter_params[:role].to_s.singularize) do
      @all_users_locations
    end
    users_for_map = @selected_countries.present? ? filtered_locations.where("locations.country IN (?)", @selected_countries) : filtered_locations
    users_for_map.each{|val| @locations.fill([val.full_address, val.lat, val.lng], @locations.size, val.location_count) }
  end

  def initialize_table_view!
    keys = [ReportViewColumn::DemographicReport::Key::COUNTRY]
    keys += [ReportViewColumn::DemographicReport::Key::ALL_USERS_COUNT] if @show_for_all_roles
    keys += @roles.collect do |role_name|
      @role_column_mapping[role_name]
    end
    @report_view_columns = @current_program.report_view_columns.for_demographic_report.where(column_key: keys)
    @page = params[:page].to_i != 0 ? params[:page].to_i : 1
    @sort_param = params[:sort_param].presence || ReportViewColumn::DemographicReport::Key::COUNTRY
    @sort_order = params[:sort_order] || "asc"
    @all_grouped_locations = @all_locations.group_by(&:country)
    @sorted_locations = @all_grouped_locations.sort_by do |country,location|
      if @sort_param == ReportViewColumn::DemographicReport::Key::COUNTRY
        country
      elsif aggregation = ReportViewColumn::DemographicReport::Key::AGGREGATION[@sort_param]
        location.sum(&aggregation)
      end
    end
    @locations_for_table = @sorted_locations
    @locations_for_table = @locations_for_table.reverse if @sort_order == 'desc'
    @locations_for_table = @locations_for_table.paginate(:page => @page, :per_page => DEMOGRAPHIC_REPORT_PER_PAGE)
  end

  def set_profile_questions_for_outcomes_report
    @profile_questions = OutcomesReportUtils.get_profile_filters_for_outcomes_report(current_program)
  end

  def initialize_filter_params
    @filter_params = params[:filters].presence || {}
    @filters_count = 0
    @filters_count += 1 if @filter_params[:role].present?
    @filters_count += 1 if @filter_params[:countries].present?
  end

  def get_categoary_title_and_description(category_name)
    [ ReportsController.get_translated_report_category_name(category_name), ReportsController.get_translated_report_category_description(category_name).call(current_program) ]
  end
end

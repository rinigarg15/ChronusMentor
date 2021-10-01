module DashboardHelper

  ENGAGEMENT_WITH_GOOD_SURVEY_RESPONSES_COLOR = "#1ab394"
  ENGAGEMENT_WITHOUT_SURVEY_RESPONSES_COLOR = "#d1dade"
  ENGAGEMENT_WITH_NOT_GOOD_SURVEY_RESPONSES_COLOR = "#f8ac59"

  REPORT_TYPE_DATA_MAPPING = {
    DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE => {method: :get_invitation_acceptance_rate_data, partial: "reports/management_report/enrollment/get_published_or_accepted_enrollment_data"},
    DashboardReportSubSection::Type::Enrollment::APPLICATIONS_STATUS => {method: :get_applications_status_data, partial: "reports/management_report/enrollment/application_status"},
    DashboardReportSubSection::Type::Enrollment::PUBLISHED_PROFILES => {method: :get_published_profiles_data, partial: "reports/management_report/enrollment/get_published_or_accepted_enrollment_data"},

    DashboardReportSubSection::Type::Matching::CONNECTED_USERS => {method: :get_connected_ongoing_users_data, partial: "reports/management_report/matching/connected_users"},
    DashboardReportSubSection::Type::Matching::CONNECTED_FLASH_USERS => {method: :get_connected_flash_users_data, partial: "reports/management_report/matching/connected_users"},
    DashboardReportSubSection::Type::Matching::MENTOR_REQUESTS => {method: :get_mentor_requests_data, partial: "reports/management_report/matching/display_requests"},
    DashboardReportSubSection::Type::Matching::PROJECT_REQUESTS => {method: :get_project_requests_data, partial: "reports/management_report/matching/display_requests"},
    DashboardReportSubSection::Type::Matching::MEETING_REQUESTS => {method: :get_meeting_requests_data, partial: "reports/management_report/matching/display_requests"}
  }

  GROUPS_ACTIVITY_REPORT_ICONS = {
    Program::Dashboard::GroupsActivityReport::Activities::MESSAGES_ACTIVITY => "fa-envelope",
    Program::Dashboard::GroupsActivityReport::Activities::TASKS_ACTIVITY => "fa-check-square-o",
    Program::Dashboard::GroupsActivityReport::Activities::MEETINGS_ACTIVITY => "fa-calendar",
    Program::Dashboard::GroupsActivityReport::Activities::SURVEYS_ACTIVITY => "fa-comments",
    Program::Dashboard::GroupsActivityReport::Activities::POSTS_ACTIVITY => "fa-comment",
    Program::Dashboard::GroupsActivityReport::MeetingActivities::ACCEPTED => "fa-handshake-o",
    Program::Dashboard::GroupsActivityReport::MeetingActivities::SCHEDULED => "fa-calendar",
    Program::Dashboard::GroupsActivityReport::MeetingActivities::UNSCHEDULED => "fa-calendar-o",
    Program::Dashboard::GroupsActivityReport::MeetingActivities::PENDING => "fa-exclamation-triangle",
    Program::Dashboard::GroupsActivityReport::MeetingActivities::COMPLETED => "fa-calendar-check-o",
    Program::Dashboard::GroupsActivityReport::MeetingActivities::CANCELLED => "fa-calendar-times-o",
    Program::Dashboard::GroupsActivityReport::MeetingActivities::MESSAGES => "fa-envelope",
    Program::Dashboard::GroupsActivityReport::MeetingActivities::MENTOR_SURVEY => "fa-comments-o",
    Program::Dashboard::GroupsActivityReport::MeetingActivities::MENTEE_SURVEY => "fa-comments-o"
  }

  GROUPS_ACTIVITY_REPORT_TEXTS = {
    Program::Dashboard::GroupsActivityReport::Activities::MESSAGES_ACTIVITY => Proc.new{|custom_term_hash| "feature.reports.content.messages_exchanged".translate(custom_term_hash)},
    Program::Dashboard::GroupsActivityReport::Activities::TASKS_ACTIVITY => Proc.new{|custom_term_hash| "feature.reports.groups_report_columns.tasks_count_v1".translate(custom_term_hash)},
    Program::Dashboard::GroupsActivityReport::Activities::MEETINGS_ACTIVITY => Proc.new{|custom_term_hash| "feature.reports.content.meetings_scheduled".translate(custom_term_hash)},
    Program::Dashboard::GroupsActivityReport::Activities::SURVEYS_ACTIVITY => Proc.new{|custom_term_hash| "feature.survey.label.survey_responses_v1".translate(custom_term_hash)},
    Program::Dashboard::GroupsActivityReport::Activities::POSTS_ACTIVITY => Proc.new{|custom_term_hash| "feature.reports.groups_report_columns.posts_count".translate(custom_term_hash)},
    Program::Dashboard::GroupsActivityReport::MeetingActivities::ACCEPTED => Proc.new{|custom_term_hash| "feature.reports.content.accepted_meetings".translate(custom_term_hash)},
    Program::Dashboard::GroupsActivityReport::MeetingActivities::SCHEDULED => Proc.new{|custom_term_hash| "feature.reports.content.scheduled_meetings".translate(custom_term_hash)},
    Program::Dashboard::GroupsActivityReport::MeetingActivities::UNSCHEDULED => Proc.new{|custom_term_hash| "feature.reports.content.unscheduled_meetings".translate(custom_term_hash)},
    Program::Dashboard::GroupsActivityReport::MeetingActivities::PENDING => Proc.new{|custom_term_hash| "feature.reports.content.meetings_pending_status".translate(custom_term_hash)},
    Program::Dashboard::GroupsActivityReport::MeetingActivities::COMPLETED => Proc.new{|custom_term_hash| "feature.reports.content.completed_meetings".translate(custom_term_hash)},
    Program::Dashboard::GroupsActivityReport::MeetingActivities::CANCELLED => Proc.new{|custom_term_hash| "feature.reports.content.cancelled_meetings".translate(custom_term_hash)},
    Program::Dashboard::GroupsActivityReport::MeetingActivities::MESSAGES => Proc.new{|custom_term_hash| "feature.reports.content.messages_exchanged".translate(custom_term_hash)},
    Program::Dashboard::GroupsActivityReport::MeetingActivities::MENTOR_SURVEY => Proc.new{|custom_term_hash| "feature.reports.content.mentor_survey_responses".translate(custom_term_hash)},
    Program::Dashboard::GroupsActivityReport::MeetingActivities::MENTEE_SURVEY => Proc.new{|custom_term_hash| "feature.reports.content.mentee_survey_responses".translate(custom_term_hash)}
  }

  GROUPS_ACTIVITY_REPORT_CONDITIONS = {
    Program::Dashboard::GroupsActivityReport::Activities::MESSAGES_ACTIVITY => Proc.new{|program| program.group_messaging_enabled?},
    Program::Dashboard::GroupsActivityReport::Activities::TASKS_ACTIVITY => Proc.new{|program| program.mentoring_connections_v2_enabled?},
    Program::Dashboard::GroupsActivityReport::Activities::MEETINGS_ACTIVITY => Proc.new{|program| program.mentoring_connection_meeting_enabled?},
    Program::Dashboard::GroupsActivityReport::Activities::SURVEYS_ACTIVITY => Proc.new{|program| program.mentoring_connections_v2_enabled? && program.surveys.of_engagement_type.present?},
    Program::Dashboard::GroupsActivityReport::Activities::POSTS_ACTIVITY => Proc.new{|program| program.group_forum_enabled?}
  }


  COMMUNITY_FORUMS_AND_ARTICLES_ICONS = {
    Program::Dashboard::CommunityForumsArticlesReport::Features::FORUM_POSTS => "fa fa-comments",
    Program::Dashboard::CommunityForumsArticlesReport::Features::ARTICLES_SHARED => "fa fa-file-text",
    Program::Dashboard::CommunityForumsArticlesReport::Features::COMMENTS_ON_ARTICLES => "fa fa-comment"
  }

  COMMUNITY_FORUMS_AND_ARTICLES_TEXTS = {
    Program::Dashboard::CommunityForumsArticlesReport::Features::FORUM_POSTS => Proc.new{|custom_term_hash| "feature.reports.label.forum_posts_v1".translate(custom_term_hash)},
    Program::Dashboard::CommunityForumsArticlesReport::Features::ARTICLES_SHARED => Proc.new{|custom_term_hash| "feature.reports.content.articles_shared".translate(custom_term_hash)},
    Program::Dashboard::CommunityForumsArticlesReport::Features::COMMENTS_ON_ARTICLES => Proc.new{|custom_term_hash| "feature.reports.content.comments_on_articles".translate(custom_term_hash)}
  }

  def get_current_status_data(program, options = {})
    current_status = program.current_status
    roles = program.roles.for_mentoring
    current_status_data = []
    current_status_data << get_current_status_user_details(current_status, roles, program, options)
    current_status_data << get_current_status_connection_details(current_status, program, options)
    current_status_data << get_current_status_user_connection_details(current_status, roles, program, options)
    return current_status_data
  end

  def get_current_status_user_details(current_status, roles, program, options = {})
    data = {title: "feature.reports.content.active_users".translate, title_tooltip_id: "current_status_active_users", title_tooltip: "feature.reports.content.active_users_tooltip".translate(track: _program), icon_class: "fa-user", total: get_current_status_admin_view_link(current_status[:users][:total], options)}
    data[:sub_sections] = []
    roles.each do |role|
      value = get_current_status_admin_view_link(current_status[:users][role.name], program: program, role: role.name)
      data[:sub_sections] << {title: role.customized_term.pluralized_term, value: value}
    end
    return data
  end

  def get_current_status_connection_details(current_status, program, options = {})
    if program.only_one_time_mentoring_enabled?
      title, total, sub_sections = get_title_total_sub_sections_for_current_status_meeting_connection_details(current_status, options.merge(program: program))
      icon_class = "fa-calendar"
    else
      title, total, sub_sections = get_title_total_sub_sections_for_current_status_group_connection_details(current_status, program, options)
      icon_class = "fa-share-alt"
    end
    return {title: title, icon_class: icon_class, total: total, sub_sections: sub_sections}
  end

  def get_title_total_sub_sections_for_current_status_meeting_connection_details(current_status, options = {})
    meetings_term = options[:program] ? options[:program].term_for(CustomizedTerm::TermType::MEETING_TERM).pluralized_term : _Meetings
    title = "feature.reports.content.all_meetings".translate(Meetings: meetings_term)
    total = link_to(current_status[:connections][:total], calendar_sessions_path(get_common_total_link_options_merged_path({dashboard_filters: MeetingsController::CalendarSessionConstants::DashboardFilter::ALL}, options)))
    sub_sections = [{title: "feature.meetings.header.upcoming".translate, value: link_to(current_status[:connections][:upcoming], calendar_sessions_path(dashboard_filters: MeetingsController::CalendarSessionConstants::DashboardFilter::UPCOMING))}, 
                    {title: "feature.meetings.header.past".translate, value: link_to(current_status[:connections][:past], calendar_sessions_path(dashboard_filters: MeetingsController::CalendarSessionConstants::DashboardFilter::PAST))},
                    {title: "feature.meetings.header.completed".translate, value: link_to(current_status[:connections][:completed], calendar_sessions_path(dashboard_filters: MeetingsController::CalendarSessionConstants::DashboardFilter::COMPLETED))}]
    return [title, total, sub_sections]
  end

  def get_common_total_link_options_merged_path(merge_params, options = {})
    (options[:common_total_link_options] || {}).merge(merge_params)
  end

  def get_title_total_sub_sections_for_current_status_group_connection_details(current_status, program, options = {})
    title = "feature.reports.content.Ongoing_Connections".translate(Connections: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).pluralized_term)
    total = link_to(current_status[:connections][:ongoing], groups_path(get_common_total_link_options_merged_path({tab: Group::Status::ACTIVE}, options)))
    sub_sections = get_sub_sections_for_current_status_group_connection_details(current_status, program)
    return [title, total, sub_sections]
  end

  def get_sub_sections_for_current_status_group_connection_details(current_status, program)
    sub_sections = [{title: "feature.reports.content.All_Connections".translate, value: link_to(current_status[:connections][:total], groups_path)}]
    sub_sections << {title: "feature.connection.header.status.Available".translate, value: link_to(current_status[:connections][:available], groups_path(tab: Group::Status::PENDING))} if program.project_based?
    sub_sections << {title: "feature.connection.header.status.Closed".translate, value: link_to(current_status[:connections][:closed], groups_path(tab: Group::Status::CLOSED))}
    return sub_sections
  end

  def get_current_status_user_connection_details(current_status, roles, program, options = {})
    total = program.only_one_time_mentoring_enabled? ? current_status[:connected_users][:total] : get_current_status_admin_view_link(current_status[:connected_users][:total], options.merge(connected: true))
    tooltip_text = program.only_one_time_mentoring_enabled? ? "feature.reports.content.connected_flash_users_tooltip".translate(sessions: _meetings) : "feature.reports.content.connected_users_tooltip".translate(connections: _mentoring_connections)
    title = program.only_one_time_mentoring_enabled? ? "feature.reports.content.all_connected_users".translate : "feature.reports.content.connected_users".translate
    data = {title: title, title_tooltip_id: "current_status_connected_users", title_tooltip: tooltip_text, icon_class: "fa-users", total: total}
    data[:sub_sections] = get_current_status_user_connection_details_sub_sections(current_status, roles, program)
    return data
  end

  def get_current_status_user_connection_details_sub_sections(current_status, roles, program)
    sub_sections = []
    roles.each do |role|
      value = program.only_one_time_mentoring_enabled? ? current_status[:connected_users][role.name] : get_current_status_admin_view_link(current_status[:connected_users][role.name], program: program, role: role.name, connected: true)
      sub_sections << {title: role.customized_term.pluralized_term, value: value}
    end
    return sub_sections
  end

  def get_current_status_admin_view_link(count, options={})
    path_options = get_common_total_link_options_merged_path({dynamic_filters: {state: User::Status::ACTIVE}.merge(options.slice(:connected, :role))}, options)
    path = admin_view_all_users_path(path_options)
    return link_to(count, path)
  end

  def get_dashboard_data_for(program, report_type)
    program.send(REPORT_TYPE_DATA_MAPPING[report_type][:method])
  end

  def get_dashboard_partial_for(report_type)
    REPORT_TYPE_DATA_MAPPING[report_type][:partial]
  end

  def render_dashboard_report(program, report_type)
    locals = {data: get_dashboard_data_for(program, report_type)}
    render(partial: get_dashboard_partial_for(report_type), locals: locals)
  end

  def render_community_tile_report(program, report_type, options={})
    locals = get_management_report_locals(program, report_type, options)
    case report_type
    when DashboardReportSubSection::Type::CommunityAnnouncementsEvents::ANNOUNCEMENTS_AND_EVENTS
      render(partial: "reports/management_report/community_announcements_and_events/announcements_and_events", locals: locals)
    when DashboardReportSubSection::Type::CommunityResources::RESOURCES
      render(partial: "reports/management_report/community_resources/resources", locals: locals)
    when DashboardReportSubSection::Type::CommunityForumsArticles::FORUMS_AND_ARTICLES
      render(partial: "reports/management_report/community_forums_articles/forums_and_articles", locals: locals)
    end
  end

  def get_lower_ibox_locals(report_type, options={})
    case report_type
    when DashboardReportSubSection::Type::CommunityAnnouncementsEvents::ANNOUNCEMENTS_AND_EVENTS
      locals = {show_date_filter: false, object_links: [{link: announcements_path, name: "feature.reports.content.view_all_announcements_html".translate}]}
      locals[:object_links] << {link: program_events_path, name: "feature.reports.content.view_all_events_html".translate} if options[:program].program_events_enabled?
      locals
    when DashboardReportSubSection::Type::CommunityResources::RESOURCES
      {show_date_filter: false, object_links: [{link: resources_path, name: "feature.reports.content.view_all_resources_html".translate(Resources: _Resources)}]}
    when DashboardReportSubSection::Type::CommunityForumsArticles::FORUMS_AND_ARTICLES
      {show_date_filter: true, object_links: [], date_range: options[:date_range], date_range_preset: options[:date_range_preset], tile: DashboardReportSubSection::Tile::COMMUNITY_FORUMS_AND_ARTICLES}
    end
  end

  def get_community_tile_reports_to_display(program)
    community_reports = []
    community_reports << DashboardReportSubSection::Type::CommunityAnnouncementsEvents::ANNOUNCEMENTS_AND_EVENTS if program.community_announcement_event_report_enabled?
    community_reports << DashboardReportSubSection::Type::CommunityResources::RESOURCES if program.community_resource_report_enabled?
    community_reports << DashboardReportSubSection::Type::CommunityForumsArticles::FORUMS_AND_ARTICLES if program.community_forum_articles_report_enabled?
    community_reports
  end


  def render_engagements_report(program, report_type, options={})
    locals = get_management_report_locals(program, report_type, options)
    locals.merge!({engagement_type: options[:engagement_type]})

    case report_type
    when DashboardReportSubSection::Type::Engagements::ENGAGEMENTS_HEALTH
      render(partial: "reports/management_report/engagements/engagements_health", locals: locals)
    when DashboardReportSubSection::Type::Engagements::ENGAGEMENTS_SURVEY_RESPONSES
      render(partial: "reports/management_report/engagements/engagement_survey_responses", locals: locals)
    end
  end

  def render_groups_activity_report(program, options={})
    report_type = program.get_groups_activity_report_to_display
    locals = get_management_report_locals(program, report_type, options)
    if program.only_one_time_mentoring_enabled?
      render(partial: "reports/management_report/groups_activity/meeting_activity", locals: locals)
    else
      render(partial: "reports/management_report/groups_activity/groups_activity_pie_chart", locals: locals) + render(partial: "reports/management_report/groups_activity/groups_activity_summary", locals: locals)
    end
  end

  def get_dashboard_groups_activiy_report_lower_ibox_link_options(program)
    program.only_one_time_mentoring_enabled? ? [{link: calendar_sessions_path, name: "feature.reports.content.view_recent_meetings_html".translate(Meetings: _Meetings)}] : [{link: groups_report_path, name: "feature.reports.content.view_activity_report_html".translate}]
  end

  def render_tiles_with_date_filter(program, tile, options={})
    case tile
    when DashboardReportSubSection::Tile::COMMUNITY_FORUMS_AND_ARTICLES
      render_community_tile_report(program, DashboardReportSubSection::Type::CommunityForumsArticles::FORUMS_AND_ARTICLES, options)
    when DashboardReportSubSection::Tile::ENGAGEMENTS
      display_engagements_reports(program, options)
    when DashboardReportSubSection::Tile::GROUPS_ACTIVITY
      render_groups_activity_report(program, options)
    end
  end

  def display_engagements_reports(program, options)
    engagement_reports = program.get_engagements_reports_to_display
    content = ""
    engagement_reports.each do |report|
      content += render_engagements_report(program, report, options)
    end
    content.html_safe
  end

  def get_management_report_locals(program, report_type, options={})
    (Program::Dashboard::REPORT_TYPE_DATA_METHOD_MAPPING_WITH_DATE_RANGE.key?(report_type) ? {data: program.get_data_in_date_range_for(report_type, options[:date_range]), date_range: options[:date_range], date_range_preset: options[:date_range_preset]} : {data: program.get_data_for(report_type)})
  end

  def get_enrollment_tips(program, user)
    tips = []
    tips << "feature.reports.content.campaign_tip_html".translate(email_campaigns_link: link_to("feature.reports.content.email_campaigns".translate, campaign_management_user_campaigns_path)) if program.campaign_management_enabled?
    tips << "feature.reports.content.announcement_tip_html".translate(announcements_link: link_to("feature.reports.content.announcements".translate, announcements_path)) if user.can_manage_announcements?
    tips << "feature.reports.content.invitations_tip_html".translate(invitation_emails_link: link_to("feature.reports.content.invitation_emails".translate, new_program_invitation_path)) if program.invitable_roles_by_admins.any?
    return tips
  end

  def get_matching_tips(program, user)
    tips = []
    tips << "feature.reports.content.matching_campaign_tip_html".translate(email_campaigns_link: link_to("feature.reports.content.email_campaigns".translate, campaign_management_user_campaigns_path), mentees: _mentees, mentoring: _mentoring) if program.campaign_management_enabled?
    tips << "feature.reports.content.mentor_request_reminder_tip_html".translate(email_campaigns_link: link_to("feature.reports.content.email_campaigns".translate, campaign_management_user_campaigns_path), configure_link_text: link_to("feature.reports.content.configure_link_text".translate, edit_program_path(tab: ProgramsController::SettingsTabs::MATCHING)), mentoring: _mentoring, mentors: _mentors) if program.ongoing_mentoring_enabled? && program.matching_by_mentee_alone? && user.can_manage_mentor_requests? && program.campaign_management_enabled?
    tips << "feature.reports.content.right_mix_tip_v1_html".translate(check_link_text: link_to("feature.reports.content.check_link_text".translate, match_reports_path(category: Report::Customization::Category::HEALTH, report: true, src: EngagementIndex::Src::MatchReport::DASHBOARD)), mentors: _mentors, mentees: _mentees, mentee: _mentee) if program.can_show_match_report?
    tips << "feature.reports.content.artificial_scarcity_tip".translate(mentoring: _mentoring, mentees: _mentees)
    return tips
  end

  def get_metric_tr_element(metric)
    content_tag(:tr, class: "cjs_metric_#{metric.id}") do
      get_metric_details(metric)
    end
  end

  def get_metric_details(metric)
    alert = metric.alert
    metric_count = metric.count
    metric_count_for_alert = metric.alert_specific_count_needed? ? metric.count(alert) : metric_count
    render(partial: "reports/management_report/metric", locals: {metric: metric, count: metric_count, alert: alert, metric_count_for_alert: metric_count_for_alert})
  end

  def get_dashboard_report_tile_title(tile, program)
    case tile
    when DashboardReportSubSection::Tile::ENROLLMENT
      "feature.reports.content.enrollment".translate
    when DashboardReportSubSection::Tile::ENGAGEMENTS
      get_engagements_health_report_tile_titile(program)
    when DashboardReportSubSection::Tile::MATCHING
      "feature.reports.content.matching".translate
    when DashboardReportSubSection::Tile::GROUPS_ACTIVITY
      "feature.reports.content.other_engagement_metrics".translate
    end
  end

  def get_dashboard_report_tile_settings(tile, options={})
    case tile
    when DashboardReportSubSection::Tile::ENROLLMENT
      render(partial: "reports/management_report/enrollment/tile_settings", locals: {tile: tile})
    when DashboardReportSubSection::Tile::ENGAGEMENTS
      render(partial: "reports/management_report/engagements/tile_settings", locals: {tile: tile, options: options})
    when DashboardReportSubSection::Tile::GROUPS_ACTIVITY
      render(partial: "reports/management_report/groups_activity/tile_settings", locals: {tile: tile, options: options})
    when DashboardReportSubSection::Tile::MATCHING
      render(partial: "reports/management_report/matching/tile_settings", locals: {tile: tile})
    end
  end

  def get_dashboard_report_name(report_type, program)
    case report_type
    when DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE
      "feature.reports.content.invitations_acceptance_rate_report".translate
    when DashboardReportSubSection::Type::Enrollment::APPLICATIONS_STATUS
      "feature.reports.content.applications_status_report".translate
    when DashboardReportSubSection::Type::Enrollment::PUBLISHED_PROFILES
      "feature.reports.content.published_profiles_report".translate
    when DashboardReportSubSection::Type::Engagements::ENGAGEMENTS_HEALTH
      get_engagements_health_report_name(program)
    when DashboardReportSubSection::Type::Engagements::ENGAGEMENTS_SURVEY_RESPONSES
      "feature.reports.content.survey_responses_report".translate
    when DashboardReportSubSection::Type::Matching::CONNECTED_USERS
      "feature.reports.content.connected_users".translate
    when DashboardReportSubSection::Type::Matching::CONNECTED_FLASH_USERS
      "feature.reports.content.connected_users".translate
    when DashboardReportSubSection::Type::Matching::MENTOR_REQUESTS
      "feature.reports.content.mentor_requests".translate(mentoring: _Mentoring)
    end
  end

  def get_engagements_health_report_name(program)
    engagement_type = program.get_engagement_type
    (engagement_type == Program::Dashboard::EngagementsReport::MEETINGS_ENGAGEMENT_TYPE ? "feature.reports.content.engagements_health_report".translate(Engagements: _Meetings) : "feature.reports.content.engagements_health_report".translate(Engagements: _Mentoring_Connections))
  end

  def get_engagements_health_report_tile_titile(program)
    engagement_type = program.get_engagement_type
    (engagement_type == Program::Dashboard::EngagementsReport::MEETINGS_ENGAGEMENT_TYPE ? "feature.reports.content.health_of_engagements".translate(engagements: _meetings) : "feature.reports.content.health_of_engagements".translate(engagements: _mentoring_connections))
  end

  def get_date_range_preset_translated(date_range_preset)
    date_range_preset == DateRangePresets::CUSTOM ? DateRangePresets.keys[date_range_preset].translate : DateRangePresets.keys[date_range_preset].first.translate(DateRangePresets.keys[date_range_preset].second)
  end

  def get_date_range_preset_translated_for_activity_tile(date_range_preset)
    date_range_preset == DateRangePresets::CUSTOM ? "feature.reports.content.selected_time".translate : get_date_range_preset_translated(date_range_preset)
  end

  def get_engagements_report_health_hash(good_engagements, not_good_engagements, empty_engagements, engagement_type)
    total_engagements = good_engagements + not_good_engagements + empty_engagements
    return nil if total_engagements == 0
    engagements_with_good_survey_responses_string, engagements_with_not_good_survey_responses_string, engagements_without_survey_responses_string = get_survey_responses_strings(engagement_type)
    
    engagements_report_health_stats = 
      [{
        name: engagements_with_good_survey_responses_string,
        y: ((good_engagements.to_f/total_engagements)*100).round(0),
        color: ENGAGEMENT_WITH_GOOD_SURVEY_RESPONSES_COLOR
      },
      {
        name: engagements_with_not_good_survey_responses_string,
        y: ((not_good_engagements.to_f/total_engagements)*100).round(0),
        color: ENGAGEMENT_WITH_NOT_GOOD_SURVEY_RESPONSES_COLOR
      },
      {
        name: engagements_without_survey_responses_string,
        y: ((empty_engagements.to_f/total_engagements)*100).round(0),
        color: ENGAGEMENT_WITHOUT_SURVEY_RESPONSES_COLOR
      }]
    engagements_report_health_stats
  end

  def get_survey_responses_strings(engagement_type)
    engagements_with_good_survey_responses_string = (engagement_type == Program::Dashboard::EngagementsReport::MEETINGS_ENGAGEMENT_TYPE ? "feature.reports.content.engagements_with_good_survey_responses".translate(Engagements: _Meetings) : "feature.reports.content.engagements_with_good_survey_responses".translate(Engagements: _Mentoring_Connections))
    engagements_with_not_good_survey_responses_string = (engagement_type == Program::Dashboard::EngagementsReport::MEETINGS_ENGAGEMENT_TYPE ? "feature.reports.content.engagements_with_not_good_survey_responses".translate(Engagements: _Meetings) : "feature.reports.content.engagements_with_not_good_survey_responses".translate(Engagements: _Mentoring_Connections))
    engagements_without_survey_responses_string = (engagement_type == Program::Dashboard::EngagementsReport::MEETINGS_ENGAGEMENT_TYPE ? "feature.reports.content.engagements_without_survey_responses".translate(Engagements: _Meetings) : "feature.reports.content.engagements_without_survey_responses".translate(Engagements: _Mentoring_Connections))

    return [engagements_with_good_survey_responses_string, engagements_with_not_good_survey_responses_string, engagements_without_survey_responses_string]
  end

  def get_dashboard_groups_activity_icon_for_key(key)
    GROUPS_ACTIVITY_REPORT_ICONS[key]
  end

  def get_dashboard_groups_activity_name(key)
    GROUPS_ACTIVITY_REPORT_TEXTS[key].call({Meetings: _Meetings, meetings: _meetings, Mentor: _Mentor, Mentee: _Mentee})
  end

  def group_report_activity_enabled?(program, key)
    Program::Dashboard::GroupsActivityReport::Activities.all.include?(key) ? GROUPS_ACTIVITY_REPORT_CONDITIONS[key].call(program) : true
  end

  def get_dashboard_report_sub_setting_name(report_sub_setting)
    case report_sub_setting
    when DashboardReportSubSection::Type::Matching::ConnectedUsers::ONLY_ONGOING
      "feature.reports.content.users_in_ongoing".translate(mentoring_connections: _mentoring_connections)
    when DashboardReportSubSection::Type::Matching::ConnectedUsers::ONGOING_AND_CLOSED
      "feature.reports.content.users_in_ongoing_closed".translate(mentoring_connections: _mentoring_connections)
    when DashboardReportSubSection::Type::Matching::ConnectedUsers::ONGOING_AND_DRAFTED
      "feature.reports.content.users_in_ongoing_draft".translate(mentoring_connections: _mentoring_connections)
    end
  end

  def get_announcement_title_class(display_expires_on)
    display_expires_on ? 'col-xs-6' : 'col-xs-9'
  end

  def get_dashboard_community_forums_articles_icon_for_key(key)
    COMMUNITY_FORUMS_AND_ARTICLES_ICONS[key]
  end

  def get_dashboard_community_forums_articles_text_for_key(key)
    COMMUNITY_FORUMS_AND_ARTICLES_TEXTS[key].call({Articles: _Articles, articles: _articles})
  end

  def get_matching_report_links(report_type)
    case report_type
    when DashboardReportSubSection::Type::Matching::PROJECT_REQUESTS
      manage_project_requests_path
    when DashboardReportSubSection::Type::Matching::MENTOR_REQUESTS
      manage_mentor_requests_path
    when DashboardReportSubSection::Type::Matching::MEETING_REQUESTS
      manage_meeting_requests_path
    end
  end

  def get_matching_report_link_text(report_type)
    case report_type
    when DashboardReportSubSection::Type::Matching::PROJECT_REQUESTS
      "feature.project_request.header.project_requests".translate(:Mentoring_Connection => _Mentoring_Connection)
    when DashboardReportSubSection::Type::Matching::MENTOR_REQUESTS
      "feature.mentor_request.header.mentor_requests_v1".translate(:Mentoring => _Mentoring)
    when DashboardReportSubSection::Type::Matching::MEETING_REQUESTS
      "feature.admin_view.label.meeting_request_status".translate(Meeting: _Meeting)
    end
  end

  def get_matching_report_tooltip_text(report_type)
    case report_type
    when DashboardReportSubSection::Type::Matching::PROJECT_REQUESTS
      "feature.project_request.header.project_requests_dropped".translate(:Mentoring_Connection => _Mentoring_Connection)
    when DashboardReportSubSection::Type::Matching::MENTOR_REQUESTS
      mentor_request_reject_tile_tooltip
    when DashboardReportSubSection::Type::Matching::MEETING_REQUESTS
      "feature.admin_view.program_defaults.title.meeting_requests_dropped".translate(Meeting: _Meeting)
    end
  end
end
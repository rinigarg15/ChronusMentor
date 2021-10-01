require_relative "./../../test_helper.rb"

class DashboardHelperTest < ActionView::TestCase
  def test_get_current_status_data
    program = programs(:albers)
    program.stubs(:current_status).returns("current_status")
    Role.stubs(:for_mentoring).returns("mentoring_roles")


    self.stubs(:get_current_status_user_details).with("current_status", "mentoring_roles", program, {}).returns("users")
    self.stubs(:get_current_status_connection_details).with("current_status", program, {}).returns("connections")
    self.stubs(:get_current_status_user_connection_details).with("current_status", "mentoring_roles", program, {}).returns("connected users")
    assert_equal ['users', 'connections', 'connected users'], get_current_status_data(program)
  end

  def test_get_current_status_user_details
    program = programs(:albers)
    roles = [program.roles.find_by(name: RoleConstants::MENTOR_NAME)]
    roles[0].customized_term.stubs(:pluralized_term).returns("Mentor pluralized_term")
    current_status = {users: {total: 7, "mentor" => "something", "student" => "nothing"}}
    self.stubs(:get_current_status_admin_view_link).with(7, {}).returns("seven")
    self.stubs(:get_current_status_admin_view_link).with("something", program: program, role: roles[0].name).returns("nothing")
    expected_result = {title: "feature.reports.content.active_users".translate, title_tooltip_id: "current_status_active_users", title_tooltip: "Users in the program with published profiles", icon_class: "fa-user", total: "seven", sub_sections: [{title: "Mentor pluralized_term", value: "nothing"}]}
    assert_equal_hash(expected_result, get_current_status_user_details(current_status, roles, program))
  end

  def test_get_current_status_connection_details
    program = programs(:albers)
    program.stubs(:only_one_time_mentoring_enabled?).returns(true)
    current_status = {connections: {total: 88, upcoming: "upcoming", past: "past", completed: "completed"}}
    sub_sections = [{title: "feature.meetings.header.upcoming".translate, value: link_to("upcoming", calendar_sessions_path(dashboard_filters: MeetingsController::CalendarSessionConstants::DashboardFilter::UPCOMING))},
                    {title: "feature.meetings.header.past".translate, value: link_to("past", calendar_sessions_path(dashboard_filters: MeetingsController::CalendarSessionConstants::DashboardFilter::PAST))},
                    {title: "feature.meetings.header.completed".translate, value: link_to("completed", calendar_sessions_path(dashboard_filters: MeetingsController::CalendarSessionConstants::DashboardFilter::COMPLETED))}]
    expected_result = {title: "All Meetings", icon_class: "fa-calendar", total: link_to(88, calendar_sessions_path(dashboard_filters: MeetingsController::CalendarSessionConstants::DashboardFilter::ALL)), sub_sections: sub_sections}
    assert_equal_hash(expected_result, get_current_status_connection_details(current_status, program))

    program.stubs(:only_one_time_mentoring_enabled?).returns(false)
    program.stubs(:project_based?).returns(false)
    current_status = {connections: {total: 99, available: "available", ongoing: "ongoing", closed: "closed"}}
    sub_sections = [{title: "All", value: link_to(99, groups_path)},
                    {title: "feature.connection.header.status.Closed".translate, value: link_to("closed", groups_path(tab: Group::Status::CLOSED))}]
    expected_result = {title: "Ongoing Mentoring Connections", icon_class: "fa-share-alt", total: link_to("ongoing", groups_path(tab: Group::Status::ACTIVE)), sub_sections: sub_sections}
    assert_equal_hash(expected_result, get_current_status_connection_details(current_status, program))

    program.stubs(:project_based?).returns(true)
    sub_sections[2] = sub_sections[1]
    sub_sections[1] = {title: "feature.connection.header.status.Available".translate, value: link_to(current_status[:connections][:available], groups_path(tab: Group::Status::PENDING))}
    expected_result = {title: "Ongoing Mentoring Connections", icon_class: "fa-share-alt", total: link_to("ongoing", groups_path(tab: Group::Status::ACTIVE)), sub_sections: sub_sections}
    assert_equal_hash(expected_result, get_current_status_connection_details(current_status, program))
  end

  def test_get_title_total_sub_sections_for_current_status_meeting_connection_details
    current_status = {connections: {total: 88, upcoming: "upcoming", past: "past", completed: "completed"}}
    sub_sections = [{title: "feature.meetings.header.upcoming".translate, value: link_to("upcoming", calendar_sessions_path(dashboard_filters: MeetingsController::CalendarSessionConstants::DashboardFilter::UPCOMING))},
                    {title: "feature.meetings.header.past".translate, value: link_to("past", calendar_sessions_path(dashboard_filters: MeetingsController::CalendarSessionConstants::DashboardFilter::PAST))},
                    {title: "feature.meetings.header.completed".translate, value: link_to("completed", calendar_sessions_path(dashboard_filters: MeetingsController::CalendarSessionConstants::DashboardFilter::COMPLETED))}]
    title = "All Meetings"
    total = link_to(88, calendar_sessions_path(dashboard_filters: MeetingsController::CalendarSessionConstants::DashboardFilter::ALL))
    assert_equal [title, total, sub_sections], get_title_total_sub_sections_for_current_status_meeting_connection_details(current_status)
  end

  def test_get_sub_sections_for_current_status_group_connection_details
    program = programs(:albers)
    current_status = {connections: {total: 99, available: "available", ongoing: "ongoing", closed: "closed"}}
    sub_sections = [{title: "All", value: link_to(99, groups_path)},
                       {title: "feature.connection.header.status.Closed".translate, value: link_to("closed", groups_path(tab: Group::Status::CLOSED))}]
    assert_equal sub_sections, get_sub_sections_for_current_status_group_connection_details(current_status, program)

    sub_sections[2] = sub_sections[1]
    sub_sections[1] = {title: "feature.connection.header.status.Available".translate, value: link_to(current_status[:connections][:available], groups_path(tab: Group::Status::PENDING))}
    program.stubs(:project_based?).returns(true)
    assert_equal sub_sections, get_sub_sections_for_current_status_group_connection_details(current_status, program)
  end

  def test_get_title_total_sub_sections_for_current_status_group_connection_details
    program = programs(:albers)
    current_status = {connections: {total: 99, available: "available", ongoing: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).pluralized_term, closed: "closed"}}
    self.stubs(:get_sub_sections_for_current_status_group_connection_details).with(current_status, program).returns("something")
    assert_equal ["Ongoing Mentoring Connections", link_to(program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).pluralized_term, groups_path(tab: Group::Status::ACTIVE)), "something"], get_title_total_sub_sections_for_current_status_group_connection_details(current_status, program)
  end

  def test_get_current_status_user_connection_details
    program = programs(:albers)
    roles = [program.roles.find_by(name: RoleConstants::MENTOR_NAME), program.roles.find_by(name: RoleConstants::ADMIN_NAME)]
    roles[0].customized_term.stubs(:pluralized_term).returns("Mentor pluralized_term")
    roles[1].customized_term.stubs(:pluralized_term).returns("Admin pluralized_term")
    self.stubs(:get_current_status_admin_view_link).with(666, connected: true).returns("sixsixsix")
    self.stubs(:get_current_status_admin_view_link).with("something", program: program, role: roles[0].name, connected: true).returns("something mentor")
    self.stubs(:get_current_status_admin_view_link).with("present", program: program, role: roles[1].name, connected: true).returns("admin present")

    current_status = {connected_users: {total: 666, "mentor" => "something", "student" => "nothing", "admin" => "present"}}
    expected_result = {title: "feature.reports.content.connected_users".translate, title_tooltip_id: "current_status_connected_users", title_tooltip: "Active users who are in one or more ongoing mentoring connections", icon_class: "fa-users", total: "sixsixsix", sub_sections: [{title: "Mentor pluralized_term", value: "something mentor"}, {title: "Admin pluralized_term", value: "admin present"}]}
    assert_equal_hash(expected_result, get_current_status_user_connection_details(current_status, roles, program))

    program.stubs(:only_one_time_mentoring_enabled?).returns(true)
    self.stubs(:get_current_status_admin_view_link).never
    expected_result = {title: "feature.reports.content.all_connected_users".translate, title_tooltip_id: "current_status_connected_users", title_tooltip: "Active users who have taken part in one or more meetings", icon_class: "fa-users", total: 666, sub_sections: [{title: "Mentor pluralized_term", value: "something"}, {title: "Admin pluralized_term", value: "present"}]}
    assert_equal_hash(expected_result, get_current_status_user_connection_details(current_status, roles, program))
  end

  def test_get_common_total_link_options_merged_path
    params = {a: 1, b: 2}
    assert_equal_hash({a: 1, b: 2, c: 3}, get_common_total_link_options_merged_path(params, common_total_link_options: {c: 3}))
    assert_equal_hash({a: 1, b: 2}, get_common_total_link_options_merged_path(params, other: {c: 3}))
  end

  def test_get_current_status_admin_view_link
    program = programs(:albers)
    assert_equal link_to("count", admin_view_all_users_path({dynamic_filters: {state: User::Status::ACTIVE}})), get_current_status_admin_view_link("count")
    assert_equal link_to("count", admin_view_all_users_path({dynamic_filters: {state: User::Status::ACTIVE, connected: true}})), get_current_status_admin_view_link("count", connected: true)
    role = program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    assert_equal link_to("count", admin_view_all_users_path({dynamic_filters: {state: User::Status::ACTIVE, connected: true, role: RoleConstants::MENTOR_NAME}})), get_current_status_admin_view_link("count", connected: true, role: role.name, program: program)
  end

  def test_get_dashboard_data_for
    program = programs(:albers)
    program.stubs(:get_invitation_acceptance_rate_data).returns('inv')
    assert_equal 'inv', get_dashboard_data_for(program, DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE)

    program.stubs(:get_applications_status_data).returns('app')
    assert_equal 'app', get_dashboard_data_for(program, DashboardReportSubSection::Type::Enrollment::APPLICATIONS_STATUS)

    program.stubs(:get_published_profiles_data).returns('pub')
    assert_equal 'pub', get_dashboard_data_for(program, DashboardReportSubSection::Type::Enrollment::PUBLISHED_PROFILES)
  end

  def test_get_dashboard_partial_for
    assert_equal "reports/management_report/enrollment/get_published_or_accepted_enrollment_data", get_dashboard_partial_for(DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE)
    assert_equal "reports/management_report/enrollment/application_status", get_dashboard_partial_for(DashboardReportSubSection::Type::Enrollment::APPLICATIONS_STATUS)
    assert_equal "reports/management_report/enrollment/get_published_or_accepted_enrollment_data", get_dashboard_partial_for(DashboardReportSubSection::Type::Enrollment::PUBLISHED_PROFILES)
    assert_equal "reports/management_report/matching/connected_users", get_dashboard_partial_for(DashboardReportSubSection::Type::Matching::CONNECTED_USERS)
    assert_equal "reports/management_report/matching/display_requests", get_dashboard_partial_for(DashboardReportSubSection::Type::Matching::MENTOR_REQUESTS)
  end

  def test_render_dashboard_report
    program = programs(:albers)
    self.stubs(:get_dashboard_data_for).with(program, DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE).returns('invitation')
    self.stubs(:render).with(partial: "reports/management_report/enrollment/get_published_or_accepted_enrollment_data", locals: {data: 'invitation'}).returns('inv')
    assert_equal 'inv', render_dashboard_report(program, DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE)

    self.stubs(:get_dashboard_data_for).with(program, DashboardReportSubSection::Type::Enrollment::APPLICATIONS_STATUS).returns('applications_status')
    self.stubs(:render).with(partial: "reports/management_report/enrollment/application_status", locals: {data: 'applications_status'}).returns('app')
    assert_equal 'app', render_dashboard_report(program, DashboardReportSubSection::Type::Enrollment::APPLICATIONS_STATUS)

    self.stubs(:get_dashboard_data_for).with(program, DashboardReportSubSection::Type::Enrollment::PUBLISHED_PROFILES).returns('published_profiles')
    self.stubs(:render).with(partial: "reports/management_report/enrollment/get_published_or_accepted_enrollment_data", locals: {data: 'published_profiles'}).returns('pub')
    assert_equal 'pub', render_dashboard_report(program, DashboardReportSubSection::Type::Enrollment::PUBLISHED_PROFILES)
  end

  def test_render_community_tile_report
    program = programs(:albers)
    program.stubs(:get_data_for).with(DashboardReportSubSection::Type::CommunityAnnouncementsEvents::ANNOUNCEMENTS_AND_EVENTS).returns('announcements_and_events')
    self.stubs(:render).with(partial: "reports/management_report/community_announcements_and_events/announcements_and_events", locals: {data: 'announcements_and_events'}).returns('announcements_and_events')
    assert_equal 'announcements_and_events', render_community_tile_report(program, DashboardReportSubSection::Type::CommunityAnnouncementsEvents::ANNOUNCEMENTS_AND_EVENTS)

    program.stubs(:get_data_for).with(DashboardReportSubSection::Type::CommunityResources::RESOURCES).returns('resources')
    self.stubs(:render).with(partial: "reports/management_report/community_resources/resources", locals: {data: 'resources'}).returns('resource')
    assert_equal 'resource', render_community_tile_report(program, DashboardReportSubSection::Type::CommunityResources::RESOURCES)

    date_range = program.created_at.beginning_of_day..Time.now.utc.end_of_day
    program.stubs(:get_data_in_date_range_for).with(DashboardReportSubSection::Type::CommunityForumsArticles::FORUMS_AND_ARTICLES, date_range).returns('forums_or_articles')
    self.stubs(:render).with(partial: "reports/management_report/community_forums_articles/forums_and_articles", locals: {data: 'forums_or_articles', date_range: date_range, date_range_preset: DateRangePresets::CUSTOM}).returns('forums_or_articles_report')
    assert_equal 'forums_or_articles_report', render_community_tile_report(program, DashboardReportSubSection::Type::CommunityForumsArticles::FORUMS_AND_ARTICLES, {date_range: date_range, date_range_preset: DateRangePresets::CUSTOM})
  end

  def test_get_lower_ibox_locals
    program = programs(:albers)
    date_range = Time.now.utc..Time.now.utc
    date_range_preset = DateRangePresets::LAST_30_DAYS
    options = {date_range_preset: date_range_preset, date_range: date_range, program: program}

    assert_equal_hash({show_date_filter: false, object_links: [{link: announcements_path, name: "feature.reports.content.view_all_announcements_html".translate}, {link: program_events_path, name: "feature.reports.content.view_all_events_html".translate}]}, get_lower_ibox_locals(DashboardReportSubSection::Type::CommunityAnnouncementsEvents::ANNOUNCEMENTS_AND_EVENTS, options))
    assert_equal_hash({show_date_filter: false, object_links: [{link: resources_path, name: "feature.reports.content.view_all_resources_html".translate(Resources: _Resources)}]}, get_lower_ibox_locals(DashboardReportSubSection::Type::CommunityResources::RESOURCES, options))
    assert_equal_hash({show_date_filter: true, object_links: [], date_range: options[:date_range], date_range_preset: options[:date_range_preset], tile: DashboardReportSubSection::Tile::COMMUNITY_FORUMS_AND_ARTICLES}, get_lower_ibox_locals(DashboardReportSubSection::Type::CommunityForumsArticles::FORUMS_AND_ARTICLES, options))
  end

  def test_get_community_tile_reports_to_display
    program = programs(:albers)
    program.stubs(:community_announcement_event_report_enabled?).returns(true)
    program.stubs(:community_resource_report_enabled?).returns(true)
    program.stubs(:community_forum_articles_report_enabled?).returns(true)

    assert_equal [DashboardReportSubSection::Type::CommunityAnnouncementsEvents::ANNOUNCEMENTS_AND_EVENTS, DashboardReportSubSection::Type::CommunityResources::RESOURCES, DashboardReportSubSection::Type::CommunityForumsArticles::FORUMS_AND_ARTICLES], get_community_tile_reports_to_display(program)

    program.stubs(:community_resource_report_enabled?).returns(false)
    program.stubs(:community_forum_articles_report_enabled?).returns(false)
    assert_equal [DashboardReportSubSection::Type::CommunityAnnouncementsEvents::ANNOUNCEMENTS_AND_EVENTS], get_community_tile_reports_to_display(program)

    program.stubs(:community_announcement_event_report_enabled?).returns(false)
    assert_equal [], get_community_tile_reports_to_display(program)
  end

  def test_get_management_report_locals
    program = programs(:albers)
    report_type = DashboardReportSubSection::Type::CommunityForumsArticles::FORUMS_AND_ARTICLES
    date_range = program.created_at.beginning_of_day..Time.now.utc.end_of_day
    program.expects(:get_data_in_date_range_for).with(report_type, date_range)
    assert_equal_hash({"data"=>nil, "date_range"=>date_range, "date_range_preset"=>nil}, get_management_report_locals(program, report_type, {date_range: date_range}))

    report_type = DashboardReportSubSection::Type::CommunityResources::RESOURCES
    program.expects(:get_data_for).with(report_type)
    assert_equal_hash({"data"=>nil}, get_management_report_locals(program, report_type))
  end

  def test_get_enrollment_tips
    program = programs(:albers)
    user = users(:f_admin)
    program.stubs(:campaign_management_enabled?).returns(true)
    program.stubs(:invitable_roles_by_admins).returns([])
    user.stubs(:can_manage_announcements?).returns(true)
    tip1 = "feature.reports.content.campaign_tip_html".translate(email_campaigns_link: link_to("feature.reports.content.email_campaigns".translate, campaign_management_user_campaigns_path))
    tip2 = "feature.reports.content.announcement_tip_html".translate(announcements_link: link_to("feature.reports.content.announcements".translate, announcements_path))
    tip3 = "feature.reports.content.invitations_tip_html".translate(invitation_emails_link: link_to("feature.reports.content.invitation_emails".translate, new_program_invitation_path))

    assert_equal [tip1, tip2], get_enrollment_tips(program, user)

    program.stubs(:invitable_roles_by_admins).returns(['something'])
    assert_equal [tip1, tip2, tip3], get_enrollment_tips(program, user)

    user.stubs(:can_manage_announcements?).returns(false)
    assert_equal [tip1, tip3], get_enrollment_tips(program, user)
  end

  def test_get_matching_tips
    tip1 = "feature.reports.content.matching_campaign_tip_html".translate(email_campaigns_link: link_to("feature.reports.content.email_campaigns".translate, campaign_management_user_campaigns_path), mentees: _mentees, mentoring: _mentoring)
    tip2 = "feature.reports.content.mentor_request_reminder_tip_html".translate(email_campaigns_link: link_to("feature.reports.content.email_campaigns".translate, campaign_management_user_campaigns_path), configure_link_text: link_to("feature.reports.content.configure_link_text".translate, edit_program_path(tab: ProgramsController::SettingsTabs::MATCHING)), mentoring: _mentoring, mentors: _mentors)
    tip3 = "feature.reports.content.right_mix_tip_v1_html".translate(check_link_text: link_to("feature.reports.content.check_link_text".translate, match_reports_path(category: Report::Customization::Category::HEALTH, report: true, src: EngagementIndex::Src::MatchReport::DASHBOARD)), mentors: _mentors, mentees: _mentees, mentee: _mentee)
    tip4 = "feature.reports.content.artificial_scarcity_tip".translate(mentoring: _mentoring, mentees: _mentees)
    program = programs(:albers)
    user = users(:f_admin)

    program.stubs(:campaign_management_enabled?).returns(true)
    program.stubs(:ongoing_mentoring_enabled?).returns(true)
    user.stubs(:can_manage_mentor_requests?).returns(true)
    program.stubs(:can_show_match_report?).returns(true)
    assert_equal [tip1, tip2, tip3, tip4], get_matching_tips(program, user)

    program.stubs(:campaign_management_enabled?).returns(false)
    user.stubs(:can_manage_mentor_requests?).returns(true)
    assert_equal [tip3, tip4], get_matching_tips(program, user)

    program.stubs(:ongoing_mentoring_enabled?).returns(false)
    assert_equal [tip3, tip4], get_matching_tips(program, user)
  end

  def test_get_metric_tr_element
    metric = Report::Metric.first
    self.stubs(:get_metric_details).with(metric).returns("something")
    html_content = to_html(get_metric_tr_element(metric))
    assert_select html_content, "tr.cjs_metric_#{metric.id}", text: "something"
  end

  def test_get_metric_details
    program = programs(:albers)
    member = members(:f_admin)
    view = program.abstract_views.first
    section = program.report_sections.create(title: "Users", description: "All users metrics")
    metric = section.metrics.create(title: "pending users", description: "see pending users counts", abstract_view_id: view.id)

    metric.stubs(:count).returns('metric_count')
    self.stubs(:render).with(partial: "reports/management_report/metric", locals: {metric: metric, count: 'metric_count', alert: nil, metric_count_for_alert: 'metric_count'}).returns('metric1')
    assert_equal 'metric1', get_metric_details(metric)

    alert = metric.alerts.create(description: "Some Description", filter_params: "", operator: Report::Alert::OperatorType::LESS_THAN, target: 10)
    metric.stubs(:count).with(alert).returns('metric_count_for_alert')
    self.stubs(:render).with(partial: "reports/management_report/metric", locals: {metric: metric, count: 'metric_count', alert: alert, metric_count_for_alert: 'metric_count_for_alert'}).returns('metric2')
    assert_equal 'metric2', get_metric_details(metric)
  end

  def test_get_dashboard_report_tile_title
    program = programs(:albers)
    assert_equal "feature.reports.content.enrollment".translate, get_dashboard_report_tile_title(DashboardReportSubSection::Tile::ENROLLMENT, program)
    assert_equal "feature.reports.content.health_of_engagements".translate(engagements: _mentoring_connections), get_dashboard_report_tile_title(DashboardReportSubSection::Tile::ENGAGEMENTS, program)
    assert_equal "feature.reports.content.matching".translate, get_dashboard_report_tile_title(DashboardReportSubSection::Tile::MATCHING, program)
  end

  def test_get_dashboard_report_tile_settings
    self.stubs(:render).with(partial: "reports/management_report/enrollment/tile_settings", locals: {tile: DashboardReportSubSection::Tile::ENROLLMENT}).returns('something')
    assert_equal 'something', get_dashboard_report_tile_settings(DashboardReportSubSection::Tile::ENROLLMENT)

    self.stubs(:render).with(partial: "reports/management_report/engagements/tile_settings", locals: {tile: DashboardReportSubSection::Tile::ENGAGEMENTS, options: {}}).returns('something')
    assert_equal 'something', get_dashboard_report_tile_settings(DashboardReportSubSection::Tile::ENGAGEMENTS)

    self.stubs(:render).with(partial: "reports/management_report/engagements/tile_settings", locals: {tile: DashboardReportSubSection::Tile::ENGAGEMENTS, options: {something: "nothing"}}).returns('something')
    assert_equal 'something', get_dashboard_report_tile_settings(DashboardReportSubSection::Tile::ENGAGEMENTS, {something: "nothing"})

    self.stubs(:render).with(partial: "reports/management_report/groups_activity/tile_settings", locals: {tile: DashboardReportSubSection::Tile::GROUPS_ACTIVITY, options: {}}).returns('something')
    assert_equal 'something', get_dashboard_report_tile_settings(DashboardReportSubSection::Tile::GROUPS_ACTIVITY)

    self.stubs(:render).with(partial: "reports/management_report/matching/tile_settings", locals: {tile: DashboardReportSubSection::Tile::MATCHING}).returns('something else')
    assert_equal 'something else', get_dashboard_report_tile_settings(DashboardReportSubSection::Tile::MATCHING)
  end

  def test_get_dashboard_report_name
    program = programs(:albers)
    assert_equal "feature.reports.content.invitations_acceptance_rate_report".translate, get_dashboard_report_name(DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE, program)
    assert_equal "feature.reports.content.applications_status_report".translate, get_dashboard_report_name(DashboardReportSubSection::Type::Enrollment::APPLICATIONS_STATUS, program)
    assert_equal "feature.reports.content.published_profiles_report".translate, get_dashboard_report_name(DashboardReportSubSection::Type::Enrollment::PUBLISHED_PROFILES, program)
    assert_equal "feature.reports.content.engagements_health_report".translate(Engagements: _Mentoring_Connections), get_dashboard_report_name(DashboardReportSubSection::Type::Engagements::ENGAGEMENTS_HEALTH, program)
    assert_equal "feature.reports.content.survey_responses_report".translate, get_dashboard_report_name(DashboardReportSubSection::Type::Engagements::ENGAGEMENTS_SURVEY_RESPONSES, program)
    assert_equal "feature.reports.content.connected_users".translate, get_dashboard_report_name(DashboardReportSubSection::Type::Matching::CONNECTED_USERS, program)
    assert_equal "feature.reports.content.connected_users".translate, get_dashboard_report_name(DashboardReportSubSection::Type::Matching::CONNECTED_FLASH_USERS, program)
    assert_equal "feature.reports.content.mentor_requests".translate(mentoring: _Mentoring), get_dashboard_report_name(DashboardReportSubSection::Type::Matching::MENTOR_REQUESTS, program)
  end

  def test_get_date_range_preset_translated
    date_range_preset = DateRangePresets::CUSTOM
    assert_equal "Custom", get_date_range_preset_translated(date_range_preset)

    date_range_preset = DateRangePresets::LAST_7_DAYS
    assert_equal "Last 7 days", get_date_range_preset_translated(date_range_preset)

    date_range_preset = DateRangePresets::LAST_30_DAYS
    assert_equal "Last 30 days", get_date_range_preset_translated(date_range_preset)
  end

  def test_render_engagements_report
    program = programs(:albers)
    date_range = program.created_at.beginning_of_day..Time.now.utc.end_of_day
    program.stubs(:get_data_in_date_range_for).with(DashboardReportSubSection::Type::Engagements::ENGAGEMENTS_HEALTH, date_range).returns('groups_health')
    self.stubs(:render).with(partial: "reports/management_report/engagements/engagements_health", locals: {data: 'groups_health', date_range: date_range, date_range_preset: DateRangePresets::CUSTOM, engagement_type: "_Mentoring_Connections"}).returns('groups_health_report')
    assert_equal 'groups_health_report', render_engagements_report(program, DashboardReportSubSection::Type::Engagements::ENGAGEMENTS_HEALTH, {date_range: date_range, date_range_preset: DateRangePresets::CUSTOM, engagement_type: "_Mentoring_Connections"})

    program.stubs(:get_data_in_date_range_for).with(DashboardReportSubSection::Type::Engagements::ENGAGEMENTS_SURVEY_RESPONSES, date_range).returns('group_survey_responses')
    self.stubs(:render).with(partial: "reports/management_report/engagements/engagement_survey_responses", locals: {data: 'group_survey_responses', date_range: date_range, date_range_preset: DateRangePresets::CUSTOM, engagement_type: "_Mentoring_Connections"}).returns('group_survey_responses_report')
    assert_equal 'group_survey_responses_report', render_engagements_report(program, DashboardReportSubSection::Type::Engagements::ENGAGEMENTS_SURVEY_RESPONSES, {date_range: date_range, date_range_preset: DateRangePresets::CUSTOM, engagement_type: "_Mentoring_Connections"})
  end

  def test_render_tiles_with_date_filter
    program = programs(:albers)
    date_range = program.created_at.beginning_of_day..Time.now.utc.end_of_day

    self.stubs(:render_groups_activity_report).with(program, {date_range: date_range, date_range_preset: DateRangePresets::CUSTOM}).returns('groups_health_report')
    assert_equal 'groups_health_report', render_tiles_with_date_filter(program, DashboardReportSubSection::Tile::GROUPS_ACTIVITY, {date_range: date_range, date_range_preset: DateRangePresets::CUSTOM})


    self.stubs(:render_engagements_report).with(program, DashboardReportSubSection::Type::Engagements::ENGAGEMENTS_HEALTH, {date_range: date_range, date_range_preset: DateRangePresets::CUSTOM, engagement_type: "_Mentoring_Connections"}).returns('group_survey_responses_report ')
    self.stubs(:render_engagements_report).with(program, DashboardReportSubSection::Type::Engagements::ENGAGEMENTS_SURVEY_RESPONSES, {date_range: date_range, date_range_preset: DateRangePresets::CUSTOM, engagement_type: "_Mentoring_Connections"}).returns('+ group_survey_responses_report2')
    assert_equal 'group_survey_responses_report + group_survey_responses_report2', render_tiles_with_date_filter(program, DashboardReportSubSection::Tile::ENGAGEMENTS, {date_range: date_range, date_range_preset: DateRangePresets::CUSTOM, engagement_type: "_Mentoring_Connections"})

    self.stubs(:render_community_tile_report).with(program, DashboardReportSubSection::Type::CommunityForumsArticles::FORUMS_AND_ARTICLES, {date_range: date_range, date_range_preset: DateRangePresets::CUSTOM}).returns('forums_or_articles_report')
    assert_equal 'forums_or_articles_report', render_tiles_with_date_filter(program, DashboardReportSubSection::Tile::COMMUNITY_FORUMS_AND_ARTICLES, {date_range: date_range, date_range_preset: DateRangePresets::CUSTOM})
  end

  def test_display_engagements_reports
    program = programs(:albers)
    date_range = program.created_at.beginning_of_day..Time.now.utc.end_of_day

    obj = program.dashboard_reports.create!(report_type: DashboardReportSubSection::Type::Engagements::ENGAGEMENTS_HEALTH, enabled: false)
    self.stubs(:render_engagements_report).with(program, DashboardReportSubSection::Type::Engagements::ENGAGEMENTS_HEALTH, {date_range: date_range, date_range_preset: DateRangePresets::CUSTOM, engagement_type: "_Mentoring_Connections"}).returns('group_survey_responses_report ')
    self.stubs(:render_engagements_report).with(program, DashboardReportSubSection::Type::Engagements::ENGAGEMENTS_SURVEY_RESPONSES, {date_range: date_range, date_range_preset: DateRangePresets::CUSTOM, engagement_type: "_Mentoring_Connections"}).returns('+ group_survey_responses_report2')
    assert_equal '+ group_survey_responses_report2', display_engagements_reports(program, {date_range: date_range, date_range_preset: DateRangePresets::CUSTOM, engagement_type: "_Mentoring_Connections"})

    obj.update_attributes!(enabled: true)
    assert_equal 'group_survey_responses_report + group_survey_responses_report2', display_engagements_reports(program, {date_range: date_range, date_range_preset: DateRangePresets::CUSTOM, engagement_type: "_Mentoring_Connections"})

    program.dashboard_reports.create!(report_type: DashboardReportSubSection::Type::Engagements::ENGAGEMENTS_SURVEY_RESPONSES, enabled: false)
    assert_equal 'group_survey_responses_report ', display_engagements_reports(program, {date_range: date_range, date_range_preset: DateRangePresets::CUSTOM, engagement_type: "_Mentoring_Connections"})
  end

  def test_get_engagements_report_health_hash
    engagements_with_good_survey_responses = 20
    engagements_with_not_good_survey_responses = 30
    engagements_without_survey_responses = 10

    engagements_report_health_stats =
      [{
        name: "feature.reports.content.engagements_with_good_survey_responses".translate(Engagements: _Mentoring_Connections),
        y: 33,
        color: DashboardHelper::ENGAGEMENT_WITH_GOOD_SURVEY_RESPONSES_COLOR
      },
      {
        name: "feature.reports.content.engagements_with_not_good_survey_responses".translate(Engagements: _Mentoring_Connections),
        y: 50,
        color: DashboardHelper::ENGAGEMENT_WITH_NOT_GOOD_SURVEY_RESPONSES_COLOR
      },
      {
        name: "feature.reports.content.engagements_without_survey_responses".translate(Engagements: _Mentoring_Connections),
        y: 17,
        color: DashboardHelper::ENGAGEMENT_WITHOUT_SURVEY_RESPONSES_COLOR
      }]
    assert_equal engagements_report_health_stats, get_engagements_report_health_hash(engagements_with_good_survey_responses, engagements_with_not_good_survey_responses, engagements_without_survey_responses, "_Mentoring_Connections")
  end

  def test_get_dashboard_engagements_activity_icon_for_key
    key = Program::Dashboard::GroupsActivityReport::Activities::MESSAGES_ACTIVITY
    assert_equal "fa-envelope", get_dashboard_groups_activity_icon_for_key(key)

    key = Program::Dashboard::GroupsActivityReport::Activities::TASKS_ACTIVITY
    assert_equal "fa-check-square-o", get_dashboard_groups_activity_icon_for_key(key)

    key = Program::Dashboard::GroupsActivityReport::Activities::MEETINGS_ACTIVITY
    assert_equal "fa-calendar", get_dashboard_groups_activity_icon_for_key(key)

    key = Program::Dashboard::GroupsActivityReport::Activities::SURVEYS_ACTIVITY
    assert_equal "fa-comments", get_dashboard_groups_activity_icon_for_key(key)

    key = Program::Dashboard::GroupsActivityReport::Activities::POSTS_ACTIVITY
    assert_equal "fa-comment", get_dashboard_groups_activity_icon_for_key(key)
  end

  def test_get_dashboard_groups_activity_name
    key = Program::Dashboard::GroupsActivityReport::Activities::MESSAGES_ACTIVITY
    assert_equal "feature.reports.content.messages_exchanged".translate , get_dashboard_groups_activity_name(key)

    key = Program::Dashboard::GroupsActivityReport::Activities::TASKS_ACTIVITY
    assert_equal "feature.reports.groups_report_columns.tasks_count_v1".translate, get_dashboard_groups_activity_name(key)

    key = Program::Dashboard::GroupsActivityReport::Activities::MEETINGS_ACTIVITY
    assert_equal "feature.reports.content.meetings_scheduled".translate(Meetings: _Meetings), get_dashboard_groups_activity_name(key)

    key = Program::Dashboard::GroupsActivityReport::Activities::SURVEYS_ACTIVITY
    assert_equal "feature.survey.label.survey_responses_v1".translate, get_dashboard_groups_activity_name(key)

    key = Program::Dashboard::GroupsActivityReport::Activities::POSTS_ACTIVITY
    assert_equal "feature.reports.groups_report_columns.posts_count".translate, get_dashboard_groups_activity_name(key)
  end

  def test_get_dashboard_community_forums_articles_icon_for_key
    key = Program::Dashboard::CommunityForumsArticlesReport::Features::FORUM_POSTS
    assert_equal "fa fa-comments", get_dashboard_community_forums_articles_icon_for_key(key)

    key = Program::Dashboard::CommunityForumsArticlesReport::Features::ARTICLES_SHARED
    assert_equal "fa fa-file-text", get_dashboard_community_forums_articles_icon_for_key(key)

    key = Program::Dashboard::CommunityForumsArticlesReport::Features::COMMENTS_ON_ARTICLES
    assert_equal "fa fa-comment", get_dashboard_community_forums_articles_icon_for_key(key)
  end

  def test_get_dashboard_community_forums_articles_text_for_key
    key = Program::Dashboard::CommunityForumsArticlesReport::Features::FORUM_POSTS
    assert_equal "feature.reports.label.forum_posts_v1".translate , get_dashboard_community_forums_articles_text_for_key(key)

    key = Program::Dashboard::CommunityForumsArticlesReport::Features::ARTICLES_SHARED
    assert_equal "feature.reports.content.articles_shared".translate(Articles: _Articles), get_dashboard_community_forums_articles_text_for_key(key)

    key = Program::Dashboard::CommunityForumsArticlesReport::Features::COMMENTS_ON_ARTICLES
    assert_equal "feature.reports.content.comments_on_articles".translate(articles: _articles), get_dashboard_community_forums_articles_text_for_key(key)
  end

  def test_render_groups_activity_report
    program = programs(:albers)
    date_range = program.created_at.beginning_of_day..Time.now.utc.end_of_day
    program.stubs(:get_data_in_date_range_for).with(DashboardReportSubSection::Type::GroupsActivity::GROUPS_ACTIVITY, date_range).returns('groups_activity')
    self.stubs(:render).with(partial: "reports/management_report/groups_activity/groups_activity_pie_chart", locals: {data: 'groups_activity', date_range: date_range, date_range_preset: DateRangePresets::CUSTOM}).returns('groups_activity_pie_chart')
    self.stubs(:render).with(partial: "reports/management_report/groups_activity/groups_activity_summary", locals: {data: 'groups_activity', date_range: date_range, date_range_preset: DateRangePresets::CUSTOM}).returns('groups_activity_summary')
    assert_equal 'groups_activity_pie_chartgroups_activity_summary', render_groups_activity_report(program, {date_range: date_range, date_range_preset: DateRangePresets::CUSTOM})

    program.stubs(:only_one_time_mentoring_enabled?).returns(true)
    program.stubs(:get_data_in_date_range_for).with(DashboardReportSubSection::Type::GroupsActivity::MEETING_ACTIVITY, date_range).returns('meeting_activity')
    self.stubs(:render).with(partial: "reports/management_report/groups_activity/meeting_activity", locals: {data: 'meeting_activity', date_range: date_range, date_range_preset: DateRangePresets::CUSTOM}).returns('meeting_activity_summary')
    assert_equal 'meeting_activity_summary', render_groups_activity_report(program, {date_range: date_range, date_range_preset: DateRangePresets::CUSTOM})
  end

  def test_get_dashboard_groups_activiy_report_lower_ibox_link_options
    program = programs(:albers)
    assert_equal [{link: groups_report_path, name: "feature.reports.content.view_activity_report_html".translate}], get_dashboard_groups_activiy_report_lower_ibox_link_options(program)
    program.stubs(:only_one_time_mentoring_enabled?).returns(true)
    assert_equal [{link: calendar_sessions_path, name: "feature.reports.content.view_recent_meetings_html".translate(Meetings: _Meetings)}], get_dashboard_groups_activiy_report_lower_ibox_link_options(program)
  end

  def test_get_dashboard_report_sub_setting_name
    assert_equal "feature.reports.content.users_in_ongoing".translate(mentoring_connections: _mentoring_connections), get_dashboard_report_sub_setting_name(DashboardReportSubSection::Type::Matching::ConnectedUsers::ONLY_ONGOING)
    assert_equal "feature.reports.content.users_in_ongoing_closed".translate(mentoring_connections: _mentoring_connections), get_dashboard_report_sub_setting_name(DashboardReportSubSection::Type::Matching::ConnectedUsers::ONGOING_AND_CLOSED)
    assert_equal "feature.reports.content.users_in_ongoing_draft".translate(mentoring_connections: _mentoring_connections), get_dashboard_report_sub_setting_name(DashboardReportSubSection::Type::Matching::ConnectedUsers::ONGOING_AND_DRAFTED)
  end

  def test_get_announcement_title_class
    display_expires_on = true
    assert_equal 'col-xs-6', get_announcement_title_class(display_expires_on)
    display_expires_on = false
    assert_equal 'col-xs-9', get_announcement_title_class(display_expires_on)
  end

  def test_get_matching_report_links
    report_type = DashboardReportSubSection::Type::Matching::PROJECT_REQUESTS
    assert_equal manage_project_requests_path, get_matching_report_links(report_type)
   
    report_type = DashboardReportSubSection::Type::Matching::MENTOR_REQUESTS
    assert_equal manage_mentor_requests_path, get_matching_report_links(report_type)

    report_type = DashboardReportSubSection::Type::Matching::MEETING_REQUESTS
    assert_equal manage_meeting_requests_path, get_matching_report_links(report_type)
  end

  def test_get_matching_report_link_text
    report_type = DashboardReportSubSection::Type::Matching::PROJECT_REQUESTS
    assert_equal "feature.project_request.header.project_requests".translate(:Mentoring_Connection => _Mentoring_Connection), get_matching_report_link_text(report_type)
   
    report_type = DashboardReportSubSection::Type::Matching::MENTOR_REQUESTS
    assert_equal "feature.mentor_request.header.mentor_requests_v1".translate(:Mentoring => _Mentoring), get_matching_report_link_text(report_type)

    report_type = DashboardReportSubSection::Type::Matching::MEETING_REQUESTS
    assert_equal "feature.admin_view.label.meeting_request_status".translate(Meeting: _Meeting), get_matching_report_link_text(report_type)
  end

  def test_get_matching_report_tooltip_text
    report_type = DashboardReportSubSection::Type::Matching::PROJECT_REQUESTS
    assert_equal "feature.project_request.header.project_requests_dropped".translate(:Mentoring_Connection => _Mentoring_Connection), get_matching_report_tooltip_text(report_type)
   
    report_type = DashboardReportSubSection::Type::Matching::MENTOR_REQUESTS
    self.stubs(:mentor_request_reject_tile_tooltip).returns("tooltip") 
    assert_equal "tooltip", get_matching_report_tooltip_text(report_type)

    report_type = DashboardReportSubSection::Type::Matching::MEETING_REQUESTS
    assert_equal "feature.admin_view.program_defaults.title.meeting_requests_dropped".translate(Meeting: _Meeting), get_matching_report_tooltip_text(report_type)
    end

  def test_group_report_activity_enabled
    program = programs(:albers)
    program.stubs(:group_messaging_enabled?).returns(false)
    key = Program::Dashboard::GroupsActivityReport::Activities::MESSAGES_ACTIVITY
    assert_false group_report_activity_enabled?(program, key)

    program.stubs(:group_messaging_enabled?).returns(true)
    key = Program::Dashboard::GroupsActivityReport::Activities::MESSAGES_ACTIVITY
    assert group_report_activity_enabled?(program, key)
    
    program.stubs(:mentoring_connections_v2_enabled?).returns(false)
    key = Program::Dashboard::GroupsActivityReport::Activities::TASKS_ACTIVITY
    assert_false group_report_activity_enabled?(program, key)

    program.stubs(:mentoring_connections_v2_enabled?).returns(true)
    key = Program::Dashboard::GroupsActivityReport::Activities::TASKS_ACTIVITY
    assert group_report_activity_enabled?(program, key)

    program.stubs(:mentoring_connection_meeting_enabled?).returns(false)
    key = Program::Dashboard::GroupsActivityReport::Activities::MEETINGS_ACTIVITY
    assert_false group_report_activity_enabled?(program, key)

    program.stubs(:mentoring_connection_meeting_enabled?).returns(true)
    key = Program::Dashboard::GroupsActivityReport::Activities::MEETINGS_ACTIVITY
    assert group_report_activity_enabled?(program, key)

    program.stubs(:group_forum_enabled?).returns(false)
    key = Program::Dashboard::GroupsActivityReport::Activities::POSTS_ACTIVITY
    assert_false group_report_activity_enabled?(program, key)

    program.stubs(:group_forum_enabled?).returns(true)
    key = Program::Dashboard::GroupsActivityReport::Activities::POSTS_ACTIVITY
    assert group_report_activity_enabled?(program, key)

    program.stubs(:mentoring_connections_v2_enabled?).returns(false)
    key = Program::Dashboard::GroupsActivityReport::Activities::SURVEYS_ACTIVITY
    assert_false group_report_activity_enabled?(program, key)

    program.stubs(:mentoring_connections_v2_enabled?).returns(true)
    key = Program::Dashboard::GroupsActivityReport::Activities::SURVEYS_ACTIVITY
    assert group_report_activity_enabled?(program, key)
  end

  private

  def _Meetings
    "Meetings"
  end

  def _Meeting
    "Meeting"
  end

  def _Mentoring_Connections
    "Mentoring Connections"
  end

  def _Mentoring_Connection
    "Mentoring Connection"
  end

  def _mentoring_connections
    "mentoring connections"
  end

  def _Resources
    "Resources"
  end

  def _mentors
    "mentors"
  end

  def _mentees
    "mentees"
  end

  def _mentoring
    "mentoring"
  end

  def _Mentoring
    "Mentoring"
  end

  def _meetings
    "meetings"
  end

  def _program
    "program"
  end

  def _Mentor
    "Mentor"
  end

  def _Mentee
    "Mentee"
  end

  def _Articles
    "Articles"
  end

  def _articles
    "articles"
  end

  def _mentee
    "mentee"
  end
end
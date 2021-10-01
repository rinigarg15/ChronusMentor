require_relative './../../test_helper.rb'

class GroupsReportHelperTest < ActionView::TestCase
  include TranslationsService
  include GroupsHelper

  def setup
    super
    @current_program = programs(:albers)
    @report_view_columns = @current_program.report_view_columns.for_groups_report
    @group = create_group(
      :name => "Report Group",
      :students => [users(:student_10)],
      :mentors => [users(:mentor_10), users(:mentor_11)]
    )
    @custom_term_options = {
      :Mentor => "Mentor",
      :Mentee => "Mentee",
      :Mentors => "Mentors",
      :Mentees => "Mentees",
      :Meetings => "Meetings",
      :Mentoring_Connection => "Mentoring Connection"
    }
    @role_name_id_hash = {}
    @current_program.roles.select(:id, :name).each { |role| @role_name_id_hash[role.name] = role.id }
  end

  def test_get_groups_report_table_header
    content = get_groups_report_table_header(@report_view_columns, ReportViewColumn::GroupsReport::Key::GROUP, "asc", 1.day.ago.to_date, Time.now.utc.to_date, @custom_term_options)
    assert_select_helper_function "th", content, count: 8
    assert_select_helper_function "th.text-center", content, count: 3
    assert_select_helper_function "th[data-start-date][data-end-date][data-url='#{groups_report_path(format: :js)}']", content, count: 7
    assert_select_helper_function "th.sort_asc[data-sort-param='group']", content, text: "Mentoring Connection"
    assert_select_helper_function "th.sort_both[data-sort-param='mentors']", content, text: "Mentors"
    assert_select_helper_function "th.sort_both[data-sort-param='mentees']", content, text: "Mentees"
    assert_select_helper_function "th.sort_both[data-sort-param='started_on']", content, text: "Started on"
    assert_select_helper_function "th.sort_both[data-sort-param='close_date']", content, text: "Close date"
    assert_select_helper_function "th.sort_both.text-center[data-sort-param='messages_count']", content, text: "Messages"
    assert_select_helper_function "th.sort_both.text-center[data-sort-param='current_status']", content, text: "Current Status"

    @report_view_columns.last.stubs(:is_sortable?).returns(false)
    content = get_groups_report_table_header(@report_view_columns, ReportViewColumn::GroupsReport::Key::MENTORS, "desc", 1.day.ago.to_date, Time.now.utc.to_date, @custom_term_options)
    assert_select_helper_function "th", content, count: 8
    assert_select_helper_function "th.sort_both.text-center[data-sort-param='current_status']", content, text: "Current Status", count: 0
    assert_select_helper_function "th.sort_desc[data-sort-param='mentors']", content, text: "Mentors"
    assert_select_helper_function "th", content, text: "Messages", count: 1
  end

  def test_get_groups_report_table_row_for_names
    GroupsReportHelperTest.any_instance.stubs(:super_console?).returns(false)
    column_keys = @report_view_columns.collect(&:column_key)
    groups_report = GroupsReport.new(@current_program, column_keys, {group_ids: @current_program.groups.pluck(:id), point_interval: 7, start_time: @current_program.created_at, end_time: Time.now.utc})
    groups_report.compute_data_for_table_row_or_csv

    content = get_groups_report_table_row(@group.reload, @report_view_columns, groups_report)
    assert_select_helper_function "a[href=\"/p/albers/groups/#{@group.id}\"]", content, text: "Report Group"
    assert_select_helper_function "a[title=\"mentor_k chronus\"]", content, text: "mentor_k chronus"
    assert_select_helper_function "a[title=\"mentor_l chronus\"]", content, text: "mentor_l chronus"
    assert_select_helper_function "a[title=\"student_k example\"]", content, content: "student_k example"
    assert_match "<td class=\"text-center\">0</td>", content
  end

  def test_get_groups_report_table_row_for_started_date
    GroupsReportHelperTest.any_instance.stubs(:super_console?).returns(false)
    report_view_columns = @report_view_columns.where(column_key: ReportViewColumn::GroupsReport::Key::STARTED_ON)
    GroupsReport.expects(:new).returns(mock)
    groups_report = GroupsReport.new
    content = get_groups_report_table_row(@group, report_view_columns, groups_report)
    assert_match format_date_for_view(@group.published_at), content
  end

  def test_get_groups_report_table_row_for_close_date
    GroupsReportHelperTest.any_instance.stubs(:super_console?).returns(false)
    GroupsReport.expects(:new).returns(mock)
    groups_report = GroupsReport.new
    report_view_columns = @report_view_columns.where(column_key: ReportViewColumn::GroupsReport::Key::CLOSE_DATE)

    content = get_groups_report_table_row(@group, report_view_columns, groups_report)
    assert_match format_date_for_view(@group.expiry_time), content

    @group.auto_terminate_due_to_inactivity!
    content = get_groups_report_table_row(@group, report_view_columns, groups_report)
    assert_match format_date_for_view(@group.closed_at), content
  end

  def test_get_groups_report_table_row_for_total_activity_and_status
    GroupsReportHelperTest.any_instance.stubs(:super_console?).returns(false)
    GroupsReport.expects(:new).returns(mock)
    groups_report = GroupsReport.new

    report_view_columns = @report_view_columns.where(column_key: ReportViewColumn::GroupsReport::Key::CURRENT_STATUS)
    content = get_groups_report_table_row(@group, report_view_columns, groups_report)
    assert_match "<td class=\"text-center\">active</td>", content

    report_view_columns = @report_view_columns.where(column_key: ReportViewColumn::GroupsReport::Key::TOTAL_ACTIVITIES)
    ReportViewColumn.any_instance.expects(:get_groups_report_column_data_for_table_row_or_csv).with(groups_report, @group).once.returns(1000)
    content = get_groups_report_table_row(@group, report_view_columns, groups_report)
    assert_match "<td class=\"text-center\">1000</td>", content
  end

  def test_get_groups_report_table_row_for_messages
    GroupsReportHelperTest.any_instance.stubs(:super_console?).returns(false)
    report_view_columns = []
    report_view_columns << create_groups_report_view_column(@current_program, ReportViewColumn::GroupsReport::Key::MENTOR_MESSAGES_COUNT)
    report_view_columns << create_groups_report_view_column(@current_program, ReportViewColumn::GroupsReport::Key::MENTEE_MESSAGES_COUNT)

    create_scrap(group: @group, sender: members(:student_10))
    create_scrap(group: @group, sender: members(:student_10))
    create_scrap(group: @group, sender: members(:mentor_11))

    column_keys = report_view_columns.map(&:column_key)

    groups_report = GroupsReport.new(@current_program, column_keys, {group_ids: @current_program.groups.pluck(:id), point_interval: 7, start_time: @current_program.created_at, end_time: Time.now.utc})
    groups_report.compute_data_for_table_row_or_csv
    content = get_groups_report_table_row(@group, report_view_columns, groups_report)
    assert_match "<td class=\"text-center\">1</td><td class=\"text-center\">2</td>", content
  end

  def test_get_groups_report_table_row_for_tasks
    GroupsReportHelperTest.any_instance.stubs(:super_console?).returns(false)
    report_view_columns = []
    report_view_columns << create_groups_report_view_column(@current_program, ReportViewColumn::GroupsReport::Key::TASKS_COUNT)
    report_view_columns << create_groups_report_view_column(@current_program, ReportViewColumn::GroupsReport::Key::MENTOR_TASKS_COUNT)
    report_view_columns << create_groups_report_view_column(@current_program, ReportViewColumn::GroupsReport::Key::MENTEE_TASKS_COUNT)

    create_mentoring_model_task(group: @group, status: MentoringModel::Task::Status::DONE, user: users(:mentor_10), completed_date: Time.now.utc.to_date)
    create_mentoring_model_task(group: @group, status: MentoringModel::Task::Status::DONE, user: users(:mentor_11), completed_date: Time.now.utc.to_date)
    create_mentoring_model_task(group: @group, status: MentoringModel::Task::Status::DONE, user: users(:student_10), completed_date: Time.now.utc.to_date)
    create_mentoring_model_task(group: @group, status: MentoringModel::Task::Status::TODO, user: users(:mentor_10))

    column_keys = report_view_columns.map(&:column_key)
    groups_report = GroupsReport.new(@current_program, column_keys, {group_ids: @current_program.groups.pluck(:id), point_interval: 7, start_time: @current_program.created_at, end_time: Time.now.utc})
    groups_report.compute_data_for_table_row_or_csv

    content = get_groups_report_table_row(@group, report_view_columns, groups_report)
    assert_match "<td class=\"text-center\">3</td><td class=\"text-center\">2</td><td class=\"text-center\">1</td>", content
  end

  def test_get_groups_report_table_row_for_meetings
    GroupsReportHelperTest.any_instance.stubs(:super_console?).returns(false)
    time = Time.now
    report_view_columns = []
    report_view_columns << create_groups_report_view_column(@current_program, ReportViewColumn::GroupsReport::Key::MEETINGS_COUNT)
    report_view_columns << create_groups_report_view_column(@current_program, ReportViewColumn::GroupsReport::Key::MENTOR_MEETINGS_COUNT)
    report_view_columns << create_groups_report_view_column(@current_program, ReportViewColumn::GroupsReport::Key::MENTEE_MEETINGS_COUNT)

    #Archived
    create_meeting(start_time: time - 50.minutes, end_time: time - 20.minutes, group_id: @group.id, members: [members(:student_10), members(:mentor_11)], owner_id: members(:mentor_11).id)
    create_meeting(start_time: time - 60.minutes, end_time: time - 10.minutes, group_id: @group.id, members: [members(:student_10), members(:mentor_10)], owner_id: members(:student_10).id)
    create_meeting(start_time: time - 50.minutes, end_time: time - 20.minutes, group_id: @group.id, members: [members(:mentor_10), members(:mentor_11)], owner_id: members(:mentor_10).id)
    #Archived no one attending
    m = create_meeting(start_time: time - 2.days, end_time: time - 1.day, group_id: @group.id, members: [members(:student_10), members(:mentor_11)], owner_id: members(:mentor_11).id)
    m.member_meetings.map{|mm| mm.update_column(:attending, MemberMeeting::ATTENDING::NO)}
    #Upcoming
    create_meeting(start_time: 20.minutes.from_now, end_time: 50.minutes.from_now, group_id: @group.id, members: [members(:mentor_10), members(:mentor_11)], owner_id: members(:mentor_11).id)
    create_meeting(start_time: 20.minutes.from_now, end_time: 50.minutes.from_now, group_id: @group.id, members: [members(:student_10), members(:mentor_10)], owner_id: members(:mentor_10).id)
    column_keys = report_view_columns.map(&:column_key)
    groups_report = GroupsReport.new(@current_program, column_keys, {group_ids: @current_program.groups.pluck(:id), point_interval: 7, start_time: @current_program.created_at, end_time: Time.now.utc})
    groups_report.compute_data_for_table_row_or_csv

    programs(:org_primary).enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)
    content = get_groups_report_table_row(@group.reload, report_view_columns, groups_report)

    assert_match "<td class=\"text-center\">3</td><td class=\"text-center\">3</td><td class=\"text-center\">2</td>", content
  end

  def test_get_groups_report_columns_for_multiselect
    selected_column_keys = @report_view_columns.collect(&:column_key)
    @current_program.stubs(:mentoring_connections_v2_enabled?).returns(true)
    content = get_groups_report_columns_for_multiselect(selected_column_keys, @custom_term_options)
    assert_select_helper_function "option", content, count: 16
    assert_select_helper_function "option[selected='selected']", content, count: 8
    assert_select_helper_function "option[selected='selected'][value='group']", content, text: "Mentoring Connection"
    assert_select_helper_function "option[selected='selected'][value='mentors']", content, text: "Mentors"
    assert_select_helper_function "option[selected='selected'][value='mentees']", content, text: "Mentees"
    assert_select_helper_function "option[selected='selected'][value='started_on']", content, text: "Started on"
    assert_select_helper_function "option[selected='selected'][value='close_date']", content, text: "Close date"
    assert_select_helper_function "option[selected='selected'][value='messages_count']", content, text: "Messages"
    assert_select_helper_function "option[selected='selected'][value='current_status']", content, text: "Current Status"
    assert_select_helper_function "option[selected='selected'][value='total_activities']", content, text: "Total Activities"
    assert_select_helper_function "option[value='mentor_messages_count']", content, text: "Mentor Messages"
    assert_select_helper_function "option[value='mentee_messages_count']", content, text: "Mentee Messages"

    ReportViewColumn.expects(:get_applicable_groups_report_columns).with(@current_program).once.returns(selected_column_keys - ['started_on'])
    content = get_groups_report_columns_for_multiselect(selected_column_keys - ['messages_count'], @custom_term_options)
    assert_select_helper_function "option", content, count: 7
    assert_select_helper_function "option[selected='selected']", content, count: 6
    assert_select_helper_function "option[selected='selected'][value='group']", content, text: "Mentoring Connection"
    assert_select_helper_function "option[selected='selected'][value='mentors']", content, text: "Mentors"
    assert_select_helper_function "option[selected='selected'][value='mentees']", content, text: "Mentees"
    assert_select_helper_function "option[selected='selected'][value='close_date']", content, text: "Close date"
    assert_select_helper_function "option[selected='selected'][value='current_status']", content, text: "Current Status"
    assert_select_helper_function "option[selected='selected'][value='total_activities']", content, text: "Total Activities"
    assert_select_helper_function "option[value='messages_count']", content, text: "Messages"
  end

  def test_get_groups_report_date_range_options
    content = get_groups_report_date_range_options(ReportsController::DateRangeOptions::CUSTOM)
    assert_match "<option value=\"program_to_date\">", content
    assert_match "<option value=\"month_to_date\">", content
    assert_match "<option value=\"quarter_to_date\">", content
    assert_match "<option value=\"year_to_date\">", content
    assert_match "<option value=\"last_month\">", content
    assert_match "<option value=\"last_quarter\">", content
    assert_match "<option value=\"last_year\">", content
    assert_match "<option selected=\"selected\" value=\"custom\">", content
  end

  def test_get_groups_report_trend_chart_hash
    groups_report = GroupsReport.new(@current_program, [], {group_ids: @current_program.groups.pluck(:id), point_interval: 7, start_time: Time.now.utc, end_time: Time.now.utc})
    groups_report.stubs(:messages_by_period).returns( { "Day 1" => 1, "Day 2" => 2 } )
    groups_report.stubs(:posts_by_period).returns( { "Day 1" => 3, "Day 2" => 4 } )
    groups_report.stubs(:tasks_by_period).returns( { "Day 1" => 5, "Day 2" => 6 } )
    groups_report.stubs(:meetings_by_period).returns( { "Day 1" => 7, "Day 2" => 8 } )
    groups_report.stubs(:survey_responses_by_period).returns( { "Day 1" => 3, "Day 2" => 8 } )

    assert @current_program.group_messaging_enabled?
    assert_false @current_program.group_forum_enabled?
    assert_false @current_program.mentoring_connections_v2_enabled?
    assert_false @current_program.mentoring_connection_meeting_enabled?
    content_1 = get_groups_report_trend_chart_hash(groups_report)
    assert_equal 1, content_1.size
    assert_equal_hash( {
      name: "Messages",
      data: [1, 2],
      visible: true,
      color: GroupsReportHelper::MESSAGES_COLOR
    }, content_1["messages"])

    @current_program.stubs(:group_messaging_enabled?).returns(false)
    @current_program.stubs(:group_forum_enabled?).returns(true)
    @current_program.stubs(:mentoring_connection_meeting_enabled?).returns(true)
    content_2 = get_groups_report_trend_chart_hash(groups_report)
    assert_equal 2, content_2.size
    assert_equal_hash( {
      name: "Posts",
      data: [3, 4],
      visible: true,
      color: GroupsReportHelper::POSTS_COLOR
    }, content_2["posts"])
    assert_equal_hash( {
      name: "Meetings",
      data: [7, 8],
      visible: true,
      color: GroupsReportHelper::MEETINGS_COLOR
    }, content_2["meetings"])

    @current_program.stubs(:mentoring_connections_v2_enabled?).returns(true)
    @current_program.stubs(:mentoring_connection_meeting_enabled?).returns(false)
    content_3 = get_groups_report_trend_chart_hash(groups_report)
    assert_equal 3, content_3.size
    assert_equal content_2["posts"], content_3["posts"]
    assert_equal_hash( {
      name: "Tasks Completed",
      data: [5, 6],
      visible: true,
      color: GroupsReportHelper::TASKS_COLOR
    }, content_3["tasks"])
    assert_equal_hash( {
      name: "Survey Responses",
      data: [3, 8],
      visible: true,
      color: GroupsReportHelper::SURVEY_RESPONSES_COLOR
    }, content_3["survey_responses"])
  end

  def test_get_groups_report_table_totals
    totals_hash = { "group" => 2, "mentors" => 1, "mentees" => 2, "messages_count" => 1 }
    content = get_groups_report_table_totals(@report_view_columns.where(column_key: totals_hash.keys), totals_hash)
    assert_match "<td class=\"font-600\">2</td><td class=\"font-600\">1</td>", content
    assert_match "<td class=\"font-600\">2</td><td class=\"font-600 text-center\">1</td>", content
    assert_match "<td class=\"font-600 text-center\">1</td>", content
  end

  def test_get_groups_status_hash
    assert_equal_hash({0=>"active", 1=>"inactive", 2=>"closed", 3=>"drafted", 4=>"pending", 5=>"proposed", 6=>"rejected", 7=>"withdrawn"}, get_groups_status_hash)
  end

  def test_get_groups_status_sorted
    order = "asc"
    assert_equal [0, 2, 3, 1, 4, 5, 6, 7], get_groups_status_sorted(order)

    order = "desc"
    assert_equal [7, 6, 5, 4, 1, 3, 2, 0], get_groups_status_sorted(order)
  end

  def test_get_groups_report_activity_stats
    groups_report = GroupsReport.new(@current_program, @current_program.get_groups_report_view_columns, {group_ids: [1,2,3,4,5], point_interval: 7, start_time: Time.now, end_time: Time.now.utc})
    groups_report.stubs(:activity_groups).returns(4)
    groups_report.stubs(:no_activity_groups).returns(1)
    groups_report_activity_stats =
      [{
        name: "feature.reports.content.connection_with_activity".translate(Mentoring_Connections: _Mentoring_Connections),
        y: 80,
        color: GroupsReportHelper::ACTIVITY_COLOR
      },
      {
        name: "feature.reports.content.connection_without_any_activity".translate(Mentoring_Connections: _Mentoring_Connections),
        y: 20,
        color: GroupsReportHelper::NO_ACTIVITY_COLOR
      }]
    assert_equal groups_report_activity_stats, get_groups_report_activity_stats(groups_report)
  end

  private

  def _Meetings
    "Meetings"
  end

  def _Mentoring_Connections
    "Mentoring_Connections"
  end
end
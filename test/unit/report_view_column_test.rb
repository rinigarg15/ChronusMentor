require_relative './../test_helper.rb'

class ReportViewColumnTest < ActiveSupport::TestCase
  def test_validate_program_presence
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :program do
      ReportViewColumn.create!(
        :report_type => ReportViewColumn::ReportType::GROUPS_REPORT,
        :column_key => ReportViewColumn::GroupsReport::Key::GROUP
      )
    end

    assert_raise_error_on_field ActiveRecord::RecordInvalid, :program do
      ReportViewColumn.create!(
        :report_type => ReportViewColumn::ReportType::DEMOGRAPHIC_REPORT,
        :column_key => ReportViewColumn::DemographicReport::Key::COUNTRY
      )
    end
  end

  def test_validate_report_type_presence
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :report_type do
      ReportViewColumn.create!(
        :program => programs(:albers),
        :column_key => ReportViewColumn::GroupsReport::Key::GROUP
      )
    end
  end

  def test_validate_column_key_presence
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :column_key do
      ReportViewColumn.create!(
        :program => programs(:albers),
        :report_type => ReportViewColumn::ReportType::GROUPS_REPORT
      )
    end
  end

  def test_validate_report_type_value
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :report_type do
      ReportViewColumn.create!(
        :program => programs(:albers),
        :report_type => "invalid_report_type",
        :column_key => ReportViewColumn::GroupsReport::Key::GROUP
      )
    end
  end

  def test_validate_column_key_value
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :column_key do
      ReportViewColumn.create!(
        :program => programs(:albers),
        :report_type => ReportViewColumn::ReportType::GROUPS_REPORT,
        :column_key => "invalid_column_key"
      )
    end
  end

  def test_column_key_uniqueness
    create_groups_report_view_column(programs(:albers), ReportViewColumn::GroupsReport::Key::MENTOR_MESSAGES_COUNT)

    assert_raise_error_on_field ActiveRecord::RecordInvalid, :column_key do
      create_groups_report_view_column(programs(:albers), ReportViewColumn::GroupsReport::Key::MENTOR_MESSAGES_COUNT)
    end
  end

  def test_belongs_to_program
    report_view_column = programs(:albers).report_view_columns.first
    assert_equal programs(:albers), report_view_column.program
  end

  def test_for_demographic_report
    report_view_column = programs(:albers).report_view_columns.for_demographic_report.first
    assert_equal ReportViewColumn::ReportType::DEMOGRAPHIC_REPORT, report_view_column.report_type
  end

  def test_get_title
    default_column = programs(:albers).report_view_columns.for_groups_report.first
    assert_equal "Engagement", default_column.get_title(ReportViewColumn::ReportType::GROUPS_REPORT, :Mentoring_Connection => "Engagement")

    non_default_column = create_groups_report_view_column(programs(:albers), ReportViewColumn::GroupsReport::Key::MENTOR_MESSAGES_COUNT)
    assert_equal "Expert Messages", non_default_column.get_title(ReportViewColumn::ReportType::GROUPS_REPORT, :Mentor => "Expert")

    default_column = programs(:albers).report_view_columns.for_demographic_report.last
    assert_equal "Mentees", default_column.get_title(ReportViewColumn::ReportType::DEMOGRAPHIC_REPORT, :Mentees => "Mentees")
  end

  def test_is_sortable
    meeting_column = create_groups_report_view_column(programs(:albers), ReportViewColumn::GroupsReport::Key::MENTOR_MEETINGS_COUNT)
    assert_false meeting_column.is_sortable?

    non_meeting_column = create_groups_report_view_column(programs(:albers), ReportViewColumn::GroupsReport::Key::MENTOR_MESSAGES_COUNT)
    assert non_meeting_column.is_sortable?

    activities_column = ReportViewColumn.where(column_key: ReportViewColumn::GroupsReport::Key::TOTAL_ACTIVITIES).first 
    assert_false activities_column.is_sortable?
  end

  def test_for_groups_report_scope
    assert_equal 8, programs(:albers).report_view_columns.for_groups_report.count
    create_groups_report_view_column(programs(:albers), ReportViewColumn::GroupsReport::Key::MENTOR_MESSAGES_COUNT)
    assert_equal 9, programs(:albers).report_view_columns.for_groups_report.count
  end

  def test_get_applicable_groups_report_columns
    program = programs(:albers)
    task_columns = ReportViewColumn::GroupsReport.mentoring_model_task_columns
    meeting_columns = ReportViewColumn::GroupsReport.meeting_columns
    message_columns = ReportViewColumn::GroupsReport.message_columns
    post_columns = ReportViewColumn::GroupsReport.post_columns
    role_based_columns = ReportViewColumn::GroupsReport.mentor_columns + ReportViewColumn::GroupsReport.mentee_columns
    role_based_activity_columns = role_based_columns & ReportViewColumn::GroupsReport.activity_columns
    survey_responses_columns = ReportViewColumn::GroupsReport.survey_responses_columns

    assert_false program.mentoring_connections_v2_enabled?
    assert_false program.mentoring_connection_meeting_enabled?
    assert program.group_messaging_enabled?
    assert_false program.group_forum_enabled?
    applicable_columns = ReportViewColumn.get_applicable_groups_report_columns(program)
    assert_false task_columns.any? { |column| column.in?(applicable_columns) }
    assert_false meeting_columns.any? { |column| column.in?(applicable_columns) }
    assert_false post_columns.any? { |column| column.in?(applicable_columns) }
    assert message_columns.all? { |column| column.in?(applicable_columns) }
    assert role_based_activity_columns.any? { |column| column.in?(applicable_columns) }
    assert_false survey_responses_columns.all? { |column| column.in?(applicable_columns) }

    program.stubs(:mentoring_connections_v2_enabled?).returns(true)
    program.stubs(:mentoring_connection_meeting_enabled?).returns(true)
    program.stubs(:group_messaging_enabled?).returns(false)
    applicable_columns = ReportViewColumn.get_applicable_groups_report_columns(program, ReportViewColumn::GroupsReport.all.keys)
    assert task_columns.all? { |column| column.in?(applicable_columns) }
    assert meeting_columns.all? { |column| column.in?(applicable_columns) }
    assert survey_responses_columns.all? { |column| column.in?(applicable_columns) }
    assert_false post_columns.any? { |column| column.in?(applicable_columns) }
    assert_false message_columns.any? { |column| column.in?(applicable_columns) }
    assert role_based_activity_columns.any? { |column| column.in?(applicable_columns) }

    program.stubs(:mentoring_connection_meeting_enabled?).returns(false)
    program.stubs(:group_forum_enabled?).returns(true)
    applicable_columns = ReportViewColumn.get_applicable_groups_report_columns(program, ReportViewColumn::GroupsReport.defaults)
    assert (task_columns - role_based_activity_columns).all? { |column| column.in?(applicable_columns) }
    assert_false meeting_columns.any? { |column| column.in?(applicable_columns) }
    assert (post_columns - role_based_activity_columns).all? { |column| column.in?(applicable_columns) }
    assert_false message_columns.any? { |column| column.in?(applicable_columns) }
    assert_false role_based_activity_columns.any? { |column| column.in?(applicable_columns) }
  end

  def test_get_default_groups_report_columns
    program = programs(:albers)
    ReportViewColumn.expects(:get_applicable_groups_report_columns).with(program, ReportViewColumn::GroupsReport.defaults).once
    ReportViewColumn.get_default_groups_report_columns(program)
  end

  def test_get_groups_report_column_data_for_table_row_or_csv_for_message_columns
    group = groups(:mygroup)
    group_id = group.id

    groups_report = mock
    GroupsReport.expects(:new).returns(groups_report)
    groups_report.expects(:messages_by_group).returns(group_id => 5).twice
    groups_report.expects(:mentor_messages_by_group).returns(group_id => 2).twice
    groups_report.expects(:mentee_messages_by_group).returns(group_id => 3).twice

    groups_report = GroupsReport.new
    report_view_column = ReportViewColumn.new(column_key: ReportViewColumn::GroupsReport::Key::MESSAGES_COUNT)
    assert_equal 5, report_view_column.get_groups_report_column_data_for_table_row_or_csv(groups_report, group)
    report_view_column.column_key = ReportViewColumn::GroupsReport::Key::MENTOR_MESSAGES_COUNT
    assert_equal 2, report_view_column.get_groups_report_column_data_for_table_row_or_csv(groups_report, group)
    report_view_column.column_key = ReportViewColumn::GroupsReport::Key::MENTEE_MESSAGES_COUNT
    assert_equal 3, report_view_column.get_groups_report_column_data_for_table_row_or_csv(groups_report, group)

    group.stubs(:scraps_enabled?).returns(false)
    assert_equal "-", report_view_column.get_groups_report_column_data_for_table_row_or_csv(groups_report, group)
    report_view_column = ReportViewColumn.new(column_key: ReportViewColumn::GroupsReport::Key::MESSAGES_COUNT)
    assert_equal "-", report_view_column.get_groups_report_column_data_for_table_row_or_csv(groups_report, group)
    report_view_column.column_key = ReportViewColumn::GroupsReport::Key::MENTOR_MESSAGES_COUNT
    assert_equal "-", report_view_column.get_groups_report_column_data_for_table_row_or_csv(groups_report, group)
  end

  def test_get_groups_report_column_data_for_table_row_or_csv_for_post_columns
    group = groups(:mygroup)
    group_id = group.id

    groups_report = mock
    GroupsReport.expects(:new).returns(groups_report)
    groups_report.expects(:posts_by_group).returns(group_id => 1).twice
    groups_report.expects(:mentor_posts_by_group).returns({}).twice
    groups_report.expects(:mentee_posts_by_group).returns(group_id => 1).twice

    groups_report = GroupsReport.new
    report_view_column = ReportViewColumn.new(column_key: ReportViewColumn::GroupsReport::Key::POSTS_COUNT)
    assert_equal "-", report_view_column.get_groups_report_column_data_for_table_row_or_csv(groups_report, group)
    report_view_column.column_key = ReportViewColumn::GroupsReport::Key::MENTOR_POSTS_COUNT
    assert_equal "-", report_view_column.get_groups_report_column_data_for_table_row_or_csv(groups_report, group)
    report_view_column.column_key = ReportViewColumn::GroupsReport::Key::MENTEE_POSTS_COUNT
    assert_equal "-", report_view_column.get_groups_report_column_data_for_table_row_or_csv(groups_report, group)

    group.stubs(:forum_enabled?).returns(true)
    assert_equal 1, report_view_column.get_groups_report_column_data_for_table_row_or_csv(groups_report, group)
    report_view_column = ReportViewColumn.new(column_key: ReportViewColumn::GroupsReport::Key::POSTS_COUNT)
    assert_equal 1, report_view_column.get_groups_report_column_data_for_table_row_or_csv(groups_report, group)
    report_view_column.column_key = ReportViewColumn::GroupsReport::Key::MENTOR_POSTS_COUNT
    assert_equal 0, report_view_column.get_groups_report_column_data_for_table_row_or_csv(groups_report, group)
  end

  def test_get_groups_report_column_data_for_table_row_or_csv_for_task_columns
    group = groups(:mygroup)
    group_id = group.id

    groups_report = mock
    GroupsReport.expects(:new).returns(groups_report)
    groups_report.expects(:tasks_by_group).returns(group_id => 10)
    groups_report.expects(:mentor_tasks_by_group).returns(group_id => 5)
    groups_report.expects(:mentee_tasks_by_group).returns(group_id => 5)

    groups_report = GroupsReport.new
    report_view_column = ReportViewColumn.new(column_key: ReportViewColumn::GroupsReport::Key::TASKS_COUNT)
    assert_equal 10, report_view_column.get_groups_report_column_data_for_table_row_or_csv(groups_report, group)
    report_view_column.column_key = ReportViewColumn::GroupsReport::Key::MENTOR_TASKS_COUNT
    assert_equal 5, report_view_column.get_groups_report_column_data_for_table_row_or_csv(groups_report, group)
    report_view_column.column_key = ReportViewColumn::GroupsReport::Key::MENTEE_TASKS_COUNT
    assert_equal 5, report_view_column.get_groups_report_column_data_for_table_row_or_csv(groups_report, group)
  end

  def test_get_groups_report_column_data_for_table_row_or_csv_for_meeting_columns
    group = groups(:mygroup)
    group_id = group.id

    groups_report = mock
    GroupsReport.expects(:new).returns(groups_report)
    groups_report.expects(:meetings_by_group).returns(group_id => 1).twice
    groups_report.expects(:mentor_meetings_by_group).returns(group_id => 0).twice
    groups_report.expects(:mentee_meetings_by_group).returns(group_id => 1).twice

    groups_report = GroupsReport.new
    report_view_column = ReportViewColumn.new
    report_view_column.column_key = ReportViewColumn::GroupsReport::Key::MEETINGS_COUNT
    assert_equal "-", report_view_column.get_groups_report_column_data_for_table_row_or_csv(groups_report, group)
    report_view_column.column_key = ReportViewColumn::GroupsReport::Key::MENTOR_MEETINGS_COUNT
    assert_equal "-", report_view_column.get_groups_report_column_data_for_table_row_or_csv(groups_report, group)
    report_view_column.column_key = ReportViewColumn::GroupsReport::Key::MENTEE_MEETINGS_COUNT
    assert_equal "-", report_view_column.get_groups_report_column_data_for_table_row_or_csv(groups_report, group)

    group.stubs(:meetings_enabled?).returns(true)
    assert_equal 1, report_view_column.get_groups_report_column_data_for_table_row_or_csv(groups_report, group)
    report_view_column.column_key = ReportViewColumn::GroupsReport::Key::MEETINGS_COUNT
    assert_equal 1, report_view_column.get_groups_report_column_data_for_table_row_or_csv(groups_report, group)
    report_view_column.column_key = ReportViewColumn::GroupsReport::Key::MENTOR_MEETINGS_COUNT
    assert_equal 0, report_view_column.get_groups_report_column_data_for_table_row_or_csv(groups_report, group)
  end

  def test_get_groups_report_column_data_for_table_row_or_csv_for_survey_response_columns
    group = groups(:mygroup)
    group_id = group.id

    groups_report = mock
    GroupsReport.expects(:new).returns(groups_report)
    groups_report.expects(:survey_responses_by_group).returns(group_id => 8).twice
    groups_report.expects(:mentor_survey_responses_by_group).returns(group_id => 4).twice
    groups_report.expects(:mentee_survey_responses_by_group).returns(group_id => 4).twice

    groups_report = GroupsReport.new
    report_view_column = ReportViewColumn.new(column_key: ReportViewColumn::GroupsReport::Key::SURVEY_RESPONSES_COUNT)
    assert_equal "-", report_view_column.get_groups_report_column_data_for_table_row_or_csv(groups_report, group)
    report_view_column.column_key = ReportViewColumn::GroupsReport::Key::MENTOR_SURVEY_RESPONSES_COUNT
    assert_equal "-", report_view_column.get_groups_report_column_data_for_table_row_or_csv(groups_report, group)
    report_view_column.column_key = ReportViewColumn::GroupsReport::Key::MENTEE_SURVEY_RESPONSES_COUNT
    assert_equal "-", report_view_column.get_groups_report_column_data_for_table_row_or_csv(groups_report, group)

    group.stubs(:can_manage_mm_engagement_surveys?).returns(true)
    assert_equal 4, report_view_column.get_groups_report_column_data_for_table_row_or_csv(groups_report, group)
    report_view_column = ReportViewColumn.new(column_key: ReportViewColumn::GroupsReport::Key::SURVEY_RESPONSES_COUNT)
    assert_equal 8, report_view_column.get_groups_report_column_data_for_table_row_or_csv(groups_report, group)
    report_view_column.column_key = ReportViewColumn::GroupsReport::Key::MENTOR_SURVEY_RESPONSES_COUNT
    assert_equal 4, report_view_column.get_groups_report_column_data_for_table_row_or_csv(groups_report, group)
  end

  def test_get_groups_report_column_data_for_table_row_or_csv_for_total_activities_column
    group = groups(:mygroup)
    group_id = group.id

    groups_report = mock
    GroupsReport.expects(:new).returns(groups_report)
    groups_report.expects(:messages_by_group).returns(group_id => 5)
    groups_report.expects(:posts_by_group).returns(group_id => 1)
    groups_report.expects(:tasks_by_group).returns({})
    groups_report.expects(:meetings_by_group).returns(group_id => 1)
    groups_report.expects(:survey_responses_by_group).returns(group_id => 8)

    groups_report = GroupsReport.new
    report_view_column = ReportViewColumn.new(column_key: ReportViewColumn::GroupsReport::Key::TOTAL_ACTIVITIES)
    assert_equal 15, report_view_column.get_groups_report_column_data_for_table_row_or_csv(groups_report, group)
  end
end
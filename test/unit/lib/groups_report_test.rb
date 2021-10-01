require_relative "./../../test_helper.rb"

class GroupsReportTest < ActiveSupport::TestCase

  def setup
    super
    Timecop.freeze(Time.current.beginning_of_day + 1.hour)
  end

  def test_compute_data_point_interval_seven
    @end_time = Time.current
    populate_data
    column_keys = @report_view_columns.pluck(:column_key)
    groups_report = GroupsReport.new(@program, column_keys, group_ids: @program.groups.pluck(:id), point_interval: 7, start_time: @program.created_at, end_time: (@end_time + 1.hour))
    groups_report.compute_data_for_view
    assert_equal @program, groups_report.program
    assert_equal @program.created_at, groups_report.start_time
    assert_equal (@end_time + 1.hour), groups_report.end_time
    assert_equal column_keys, groups_report.columns

    # Totals
    assert_equal 3, groups_report.totals["messages_count"]
    assert_equal 2, groups_report.totals["mentor_messages_count"]
    assert_equal 1, groups_report.totals["mentee_messages_count"]
    assert_equal 2, groups_report.totals["tasks_count"]
    assert_equal 0, groups_report.totals["mentor_tasks_count"]
    assert_equal 2, groups_report.totals["mentee_tasks_count"]
    assert_equal 4, groups_report.totals["posts_count"]
    assert_equal 2, groups_report.totals["mentor_posts_count"]
    assert_equal 2, groups_report.totals["mentee_posts_count"]
    assert_equal 1, groups_report.totals["meetings_count"]
    assert_equal 1, groups_report.totals["mentor_meetings_count"]
    assert_equal 1, groups_report.totals["mentee_meetings_count"]
    assert_equal 1, groups_report.totals["group"]
    assert_equal 3, groups_report.totals["mentors"]
    assert_equal 3, groups_report.totals["mentees"]
    assert_equal 1, groups_report.totals["mentor_survey_responses_count"]
    assert_equal 2, groups_report.totals["survey_responses_count"]
    assert_equal 1, groups_report.totals["mentee_survey_responses_count"]
    assert_equal 12, groups_report.totals["total_activities"]
    assert_equal 1, groups_report.activity_groups
    assert_equal 0, groups_report.no_activity_groups

    assert_equal 3, groups_report.messages_by_period[groups_report.send(:get_monday_of_the_week, @end_time.to_date)]
    assert_equal 2, groups_report.tasks_by_period[groups_report.send(:get_monday_of_the_week, @end_time.to_date)]
    assert_equal 4, groups_report.posts_by_period[groups_report.send(:get_monday_of_the_week, @end_time.to_date)]
    assert_equal 1, groups_report.meetings_by_period[groups_report.send(:get_monday_of_the_week, @end_time.to_date)]
    assert_equal 2, groups_report.survey_responses_by_period[groups_report.send(:get_monday_of_the_week, @end_time.to_date)]

    # Ordering should be preserved
    assert_equal groups_report.messages_by_period.keys.first, groups_report.send(:get_monday_of_the_week, @program.created_at.to_date)
    assert_equal groups_report.tasks_by_period.keys.first, groups_report.send(:get_monday_of_the_week, @program.created_at.to_date)
    assert_equal groups_report.posts_by_period.keys.first, groups_report.send(:get_monday_of_the_week, @program.created_at.to_date)
    assert_equal groups_report.meetings_by_period.keys.first, groups_report.send(:get_monday_of_the_week, @program.created_at.to_date)
    assert_equal groups_report.survey_responses_by_period.keys.first, groups_report.send(:get_monday_of_the_week, @program.created_at.to_date)

    groups_report.compute_data_for_table_row_or_csv
    assert_equal 3, groups_report.messages_by_group[@group.id]
    assert_equal 2, groups_report.tasks_by_group[@group.id]
    assert_equal 4, groups_report.posts_by_group[@group.id]
    assert_equal 0, groups_report.posts_by_group[groups(:mygroup).id].to_i
    assert_equal 1, groups_report.meetings_by_group[@group.id]
    assert_equal 2, groups_report.mentor_messages_by_group[@group.id]
    assert_equal 1, groups_report.mentee_messages_by_group[@group.id]
    assert_equal 0, groups_report.mentor_tasks_by_group[@group.id].to_i
    assert_equal 2, groups_report.mentee_tasks_by_group[@group.id]
    assert_equal 2, groups_report.mentor_posts_by_group[@group.id]
    assert_equal 2, groups_report.mentee_posts_by_group[@group.id]
    assert_equal 1, groups_report.mentor_meetings_by_group[@group.id]
    assert_equal 1, groups_report.mentee_meetings_by_group[@group.id]
    assert_equal 1, groups_report.mentee_survey_responses_by_group[@group.id]
    assert_equal 1, groups_report.mentor_survey_responses_by_group[@group.id]
    assert_equal 2, groups_report.survey_responses_by_group[@group.id]
  end

  def test_compute_data_with_false_conditions
    @end_time = Time.current
    populate_data
    column_keys = @report_view_columns.pluck(:column_key)
    groups_report = GroupsReport.new(@program, column_keys, group_ids: @program.groups.pluck(:id), point_interval: 7, start_time: @program.created_at, end_time: (@end_time + 1.hour))

    @program.stubs(:group_messaging_enabled?).returns(false)
    groups_report.compute_data_for_view
    assert_equal 0, groups_report.totals["messages_count"]
    assert_equal 0, groups_report.totals["mentor_messages_count"]
    assert_equal 0, groups_report.totals["mentee_messages_count"]
    assert_equal 9, groups_report.totals["total_activities"]
    assert_equal 0, groups_report.messages_by_period[groups_report.send(:get_monday_of_the_week, @end_time.to_date)]

    @program.stubs(:mentoring_connections_v2_enabled?).returns(false)
    @program.stubs(:group_messaging_enabled?).returns(true)
    groups_report.compute_data_for_view
    assert_equal 0, groups_report.totals["tasks_count"]
    assert_equal 0, groups_report.totals["mentor_tasks_count"]
    assert_equal 0, groups_report.totals["mentee_tasks_count"]
    assert_equal 8, groups_report.totals["total_activities"]
    assert_equal 0, groups_report.tasks_by_period[groups_report.send(:get_monday_of_the_week, @end_time.to_date)]

    @program.stubs(:mentoring_connections_v2_enabled?).returns(true)
    @program.stubs(:group_messaging_enabled?).returns(true)
    @program.stubs(:group_forum_enabled?).returns(false)
    groups_report.compute_data_for_view
    assert_equal 0, groups_report.totals["posts_count"]
    assert_equal 0, groups_report.totals["mentor_posts_count"]
    assert_equal 0, groups_report.totals["mentee_posts_count"]
    assert_equal 8, groups_report.totals["total_activities"]
    assert_equal 0, groups_report.posts_by_period[groups_report.send(:get_monday_of_the_week, @end_time.to_date)]

    @program.stubs(:group_messaging_enabled?).returns(true)
    @program.stubs(:group_forum_enabled?).returns(true)
    @program.stubs(:mentoring_connection_meeting_enabled?).returns(false)
    @program.stubs(:mentoring_connections_v2_enabled?).returns(true)
    groups_report.compute_data_for_view
    assert_equal 0, groups_report.totals["meetings_count"]
    assert_equal 0, groups_report.totals["mentor_meetings_count"]
    assert_equal 0, groups_report.totals["mentee_meetings_count"]
    assert_equal 11, groups_report.totals["total_activities"]
    assert_equal 0, groups_report.meetings_by_period[groups_report.send(:get_monday_of_the_week, @end_time.to_date)]

    @program.stubs(:group_messaging_enabled?).returns(true)
    @program.stubs(:group_forum_enabled?).returns(true)
    @program.stubs(:mentoring_connection_meeting_enabled?).returns(true)
    @program.stubs(:mentoring_connections_v2_enabled?).returns(false)
    groups_report.compute_data_for_view
    assert_equal 0, groups_report.totals["mentor_survey_responses_count"]
    assert_equal 0, groups_report.totals["survey_responses_count"]
    assert_equal 0, groups_report.totals["mentee_survey_responses_count"]
    assert_equal 8, groups_report.totals["total_activities"]
    assert_equal 0, groups_report.survey_responses_by_period[groups_report.send(:get_monday_of_the_week, @end_time.to_date)]
  end

  def test_compute_activity_data
    @end_time = Time.current
    populate_albers_program_data
    column_keys = @report_view_columns.pluck(:column_key)
    groups_report = GroupsReport.new(@program, column_keys, group_ids: @program.groups.pluck(:id), point_interval: 7, start_time: @program.created_at, end_time: (@end_time + 1.hour))
    groups_report.compute_data_for_view
    assert_equal 4, groups_report.activity_groups
    assert_equal 6, groups_report.no_activity_groups
  end

  def test_compute_data_point_interval_one
    @end_time = 2.days.from_now
    populate_data
    column_keys = @report_view_columns.pluck(:column_key)
    groups_report = GroupsReport.new(@program, column_keys, group_ids: @program.groups.pluck(:id), point_interval: 1, start_time: @program.created_at, end_time: (@end_time + 1.hour))
    groups_report.compute_data_for_view

    assert_equal 3, groups_report.messages_by_period[@end_time.to_date]
    assert_equal 2, groups_report.tasks_by_period[@end_time.to_date]
    assert_equal 4, groups_report.posts_by_period[@end_time.to_date]
    assert_equal 1, groups_report.meetings_by_period[@end_time.to_date]
    assert_equal 2, groups_report.survey_responses_by_period[@end_time.to_date]

    assert_equal groups_report.messages_by_period.keys.first, @program.created_at.to_date
    assert_equal groups_report.tasks_by_period.keys.first, @program.created_at.to_date
    assert_equal groups_report.posts_by_period.keys.first, @program.created_at.to_date
    assert_equal groups_report.meetings_by_period.keys.first, @program.created_at.to_date
    assert_equal groups_report.survey_responses_by_period.keys.first, @program.created_at.to_date
  end

  def test_compute_data_point_interval_month
    @end_time = Time.current
    populate_data
    column_keys = @report_view_columns.pluck(:column_key)
    groups_report = GroupsReport.new(@program, column_keys, group_ids: @program.groups.pluck(:id), point_interval: 30, start_time: @program.created_at, end_time: (@end_time + 1.hour))
    groups_report.compute_data_for_view

    assert_equal 3, groups_report.messages_by_period[@end_time.strftime('%Y%m')]
    assert_equal 2, groups_report.tasks_by_period[@end_time.strftime('%Y%m')]
    assert_equal 4, groups_report.posts_by_period[@end_time.strftime('%Y%m')]
    assert_equal 1, groups_report.meetings_by_period[@end_time.strftime('%Y%m')]
    assert_equal 2, groups_report.survey_responses_by_period[@end_time.strftime('%Y%m')]

    assert_equal groups_report.messages_by_period.keys.first, @program.created_at.strftime('%Y%m')
    assert_equal groups_report.tasks_by_period.keys.first, @program.created_at.strftime('%Y%m')
    assert_equal groups_report.posts_by_period.keys.first, @program.created_at.strftime('%Y%m')
    assert_equal groups_report.meetings_by_period.keys.first, @program.created_at.strftime('%Y%m')
    assert_equal groups_report.survey_responses_by_period.keys.first, @program.created_at.strftime('%Y%m')
  end

  def test_get_groups_with_activity
    @end_time = Time.current
    populate_data
    column_keys = @report_view_columns.pluck(:column_key)
    groups_report = GroupsReport.new(@program, column_keys, group_ids: @program.groups.pluck(:id), point_interval: 30, start_time: @program.created_at, end_time: (@end_time + 1.hour))
    GroupsReport.any_instance.stubs(:fetch_tasks).returns(@group.mentoring_model_tasks)
    GroupsReport.any_instance.stubs(:fetch_survey_responses).returns(@group.survey_answers)
    GroupsReport.any_instance.stubs(:fetch_meetings).returns(@group.meetings)
    GroupsReport.any_instance.stubs(:fetch_messages).returns(@group.scraps)
    GroupsReport.any_instance.stubs(:compute_group_ids_with_meetings).returns([groups(:group_2).id, groups(:group_3).id, groups(:group_4).id])
    assert_equal 4, groups_report.send(:get_groups_with_activity)
  end

  def test_compute_group_ids_with_meetings
    @end_time = Time.current
    populate_data
    column_keys = @report_view_columns.pluck(:column_key)
    groups_report = GroupsReport.new(@program, column_keys, group_ids: @program.groups.pluck(:id), point_interval: 30, start_time: @program.created_at, end_time: (@end_time + 1.hour))
    GroupsReport.any_instance.stubs(:group_meetings).returns(@group.meetings)
    assert_equal [@group.id], groups_report.send(:compute_group_ids_with_meetings)
  end

  private

  def populate_data
    @program = programs(:psg)
    @group = groups(:multi_group)
    mentor = users(:psg_mentor1)
    mentee = users(:psg_student1)
    Group.any_instance.stubs(:forum_enabled?).returns(true)
    forum = create_forum(name: "Group Forum", description: "Discussion Board", program: @program, group_id: @group.id)
    topic = create_topic(forum: forum, user: mentor)
    @group.meetings.destroy_all

    @program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    @program.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)
    @program.stubs(:group_messaging_enabled?).returns(true)
    @program.stubs(:group_forum_enabled?).returns(true)

    create_groups_report_view_column(@program, ReportViewColumn::GroupsReport::Key::TASKS_COUNT)
    create_groups_report_view_column(@program, ReportViewColumn::GroupsReport::Key::POSTS_COUNT)
    create_groups_report_view_column(@program, ReportViewColumn::GroupsReport::Key::MEETINGS_COUNT)
    create_groups_report_view_column(@program, ReportViewColumn::GroupsReport::Key::MENTOR_MESSAGES_COUNT)
    create_groups_report_view_column(@program, ReportViewColumn::GroupsReport::Key::MENTEE_MESSAGES_COUNT)
    create_groups_report_view_column(@program, ReportViewColumn::GroupsReport::Key::MENTOR_TASKS_COUNT)
    create_groups_report_view_column(@program, ReportViewColumn::GroupsReport::Key::MENTEE_TASKS_COUNT)
    create_groups_report_view_column(@program, ReportViewColumn::GroupsReport::Key::MENTOR_POSTS_COUNT)
    create_groups_report_view_column(@program, ReportViewColumn::GroupsReport::Key::MENTEE_POSTS_COUNT)
    create_groups_report_view_column(@program, ReportViewColumn::GroupsReport::Key::MENTOR_MEETINGS_COUNT)
    create_groups_report_view_column(@program, ReportViewColumn::GroupsReport::Key::MENTEE_MEETINGS_COUNT)
    create_groups_report_view_column(@program, ReportViewColumn::GroupsReport::Key::MENTOR_SURVEY_RESPONSES_COUNT)
    create_groups_report_view_column(@program, ReportViewColumn::GroupsReport::Key::MENTEE_SURVEY_RESPONSES_COUNT)
    create_groups_report_view_column(@program, ReportViewColumn::GroupsReport::Key::SURVEY_RESPONSES_COUNT)
    @report_view_columns = @program.report_view_columns.for_groups_report

    time_to_reset = Time.current
    Timecop.return
    time_traveller(@end_time) do
      @group.memberships.each do |membership|
        membership.update_attributes!(login_count: 2)
      end
      # Messages
      create_scrap(group: @group, program: @program, sender: mentor.member)
      create_scrap(group: @group, program: @program, sender: mentor.member)
      create_scrap(group: @group, program: @program, sender: mentee.member)
      # Mentoring Model Tasks
      create_mentoring_model_task(group: @group, status: MentoringModel::Task::Status::TODO, user: mentor, completed_date: Time.current.to_date)
      create_mentoring_model_task(group: @group, status: MentoringModel::Task::Status::DONE, user: mentee, completed_date: Time.current.to_date)
      create_mentoring_model_task(group: @group, status: MentoringModel::Task::Status::DONE, user: mentee, completed_date: Time.current.to_date)
      # Meetings
      @meeting = create_meeting(start_time: Time.current.beginning_of_day, end_time: Time.current.beginning_of_day + 30.minutes, group_id: @group.id, program_id: @program.id, members: [mentor.member, mentee.member], owner_id: mentor.member_id)
      m = create_meeting(start_time: @end_time - 20.minutes, end_time: @end_time - 10.minutes, group_id: @group.id, program_id: @program.id, members: [mentor.member, mentee.member], owner_id: mentee.member_id)
      m.member_meetings.map { |mm| mm.update_column(:attending, MemberMeeting::ATTENDING::NO) }
      # Posts
      create_post(topic: topic, user: mentor)
      create_post(topic: topic, user: mentee)
      create_post(topic: topic, user: mentee)
      create_post(topic: topic, user: mentor)

      survey = create_engagement_survey(name: "Test Survey", program: @program)
      create_matrix_survey_question(survey: survey, program: @program, required: true)
      q1 = create_survey_question(survey: survey, program: @program, required: true)

      response_id = SurveyAnswer.maximum(:response_id).to_i + 1
      user = @group.mentors.first
      student = @group.students.first
      task = create_mentoring_model_task(group: @group, status: MentoringModel::Task::Status::DONE, user: user, action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id)

      task.action_item.survey_questions_with_matrix_rating_questions.matrix_rating_questions.each do |ques|
        ans = task.survey_answers.new(user: user, response_id: response_id, answer_value: {answer_text: "Good", question: ques}, last_answered_at: Time.current)
        ans.survey_question = ques
        ans.save!
      end

      ans = SurveyAnswer.new(user: user, response_id: response_id, answer_value: {answer_text: "Good", question: q1}, last_answered_at: Time.current + 1.hour, survey_question: q1, task_id: task.id)
      ans.save!

      student_response_id = SurveyAnswer.maximum(:response_id).to_i + 1
      task.action_item.survey_questions_with_matrix_rating_questions.matrix_rating_questions.each do |ques|
        ans = task.survey_answers.new(user: student, response_id: student_response_id, answer_value: {answer_text: "Good", question: ques}, last_answered_at: Time.current)
        ans.survey_question = ques
        ans.save!
      end

      ans = SurveyAnswer.new(user: student, response_id: student_response_id, answer_value: {answer_text: "Good", question: q1}, last_answered_at: Time.current + 1.hour, survey_question: q1, task_id: task.id)
      ans.save!
    end
    Timecop.freeze(time_to_reset)
  end

  def populate_albers_program_data
    @program = programs(:albers)
    @group = groups(:group_5)
    @group1 = groups(:group_2)
    @group2 = groups(:group_3)
    mentor = users(:mentor_1)
    mentor1 = users(:not_requestable_mentor)

    @program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    @program.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)
    @program.stubs(:group_messaging_enabled?).returns(true)
    @program.stubs(:group_forum_enabled?).returns(true)

    @report_view_columns = @program.report_view_columns.for_groups_report
    create_scrap(group: @group, program: @program, sender: mentor.member)
    create_scrap(group: @group1, program: @program, sender: mentor1.member)
    create_scrap(group: @group2, program: @program, sender: mentor1.member)
  end
end
require_relative './../../../../test_helper'

class Program::Dashboard::GroupsActivityTest < ActiveSupport::TestCase
  def test_get_groups_activity_report_to_display
    program = programs(:albers)
    assert_equal DashboardReportSubSection::Type::GroupsActivity::GROUPS_ACTIVITY, program.get_groups_activity_report_to_display

    program.stubs(:ongoing_mentoring_enabled?).returns(false)
    assert_nil program.get_groups_activity_report_to_display

    program.stubs(:only_one_time_mentoring_enabled?).returns(true)
    assert_equal DashboardReportSubSection::Type::GroupsActivity::MEETING_ACTIVITY, program.get_groups_activity_report_to_display
  end

  def test_groups_activity_summary
    end_time = Time.current + 1.hour
    populate_data
    start_time = @program.created_at
    date_range = start_time..end_time
    assert_equal_hash( { groups: 1, total_activity: 12, messages_activity: 3, tasks_activity: 2, meetings_activity: 1, surveys_activity: 2, posts_activity: 4 }, @program.send(:groups_activity_summary, date_range))
  end

  def test_initialize_prev_period_activity_hash
    program = programs(:psg)
    previous_period_activity_hash = {messages_activity: nil, tasks_activity: nil, meetings_activity: nil, surveys_activity: nil, posts_activity: nil }
    assert_equal_hash(previous_period_activity_hash, program.send(:initialize_prev_period_activity_hash))
  end

  def test_get_groups_activity_data
    end_time = Time.current + 1.hour
    populate_data
    start_time = @program.created_at
    date_range = start_time..end_time
    current_period_activity_hash = {groups: 1, total_activity: 12, messages_activity: 3, tasks_activity: 2, meetings_activity: 1, surveys_activity: 2, posts_activity: 4}
    previous_period_activity_hash = {messages_activity: 0, tasks_activity: 0, meetings_activity: 0, surveys_activity: 0, posts_activity: 0}
    activity_hash = {groups_with_higher_activity: 1, groups_with_lower_activity: 0, groups_with_no_activity: 0}
    percentage_hash = {messages_activity: nil, tasks_activity: nil, meetings_activity: nil, surveys_activity: nil, posts_activity: nil}
    @program.stubs(:groups_activity).returns({groups_with_higher_activity: 1, groups_with_lower_activity: 0, groups_with_no_activity: 0})

    assert_equal_hash( { current_period_activity_hash: current_period_activity_hash, previous_period_activity_hash: previous_period_activity_hash, percentage_hash: percentage_hash }.merge!(activity_hash), @program.send(:get_groups_activity_data, date_range))
  end

  def test_get_previous_period_groups_activity_summary
    Timecop.freeze(Time.current.beginning_of_day) do
      end_time = Time.current + 1.hour
      populate_data
      start_time = @program.created_at
      date_range = start_time..end_time
      assert_nil @program.send(:get_previous_period_groups_activity_summary, date_range)

      start_time1 = Time.current
      date_range = start_time1..end_time
      @program.send(:initialize_prev_period_activity_hash)
      assert_equal_hash( { messages_activity: nil, tasks_activity: nil, meetings_activity: nil, surveys_activity: nil, posts_activity: nil }, @program.send(:get_previous_period_groups_activity_summary, date_range))
    end
  end

  def test_get_meetings_activity_data
    program = programs(:albers)
    program.stubs(:get_meetings_accepted_data).with("date_range").returns("get_meetings_accepted_data")
    program.stubs(:get_meetings_completed_data).with("date_range").returns("get_meetings_completed_data")
    program.stubs(:get_meetings_message_survey_data).with("date_range").returns("get_meetings_message_survey_data")
    assert_equal_hash( { accepted_data: "get_meetings_accepted_data", completed_data: "get_meetings_completed_data", activity: "get_meetings_message_survey_data" }, program.get_meetings_activity_data("date_range"))
  end

  private

  def populate_data
    @program = programs(:psg)
    @group = groups(:multi_group)
    mentor = users(:psg_mentor1)
    mentee = users(:psg_student1)
    end_time = Time.current
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
    create_groups_report_view_column(@program, ReportViewColumn::GroupsReport::Key::SURVEY_RESPONSES_COUNT)
    @report_view_columns = @program.report_view_columns.for_groups_report

    time_traveller(end_time) do
      @group.memberships.each do |membership|
        membership.update_attributes!(login_count: 2)
      end
      # Messages
      create_scrap(group: @group, program: @program, sender: mentor.member)
      create_scrap(group: @group, program: @program, sender: mentor.member)
      create_scrap(group: @group, program: @program, sender: mentee.member)
      # Mentoring Model Tasks
      create_mentoring_model_task(group: @group, status: MentoringModel::Task::Status::TODO, user: mentor, completed_date: Time.current.to_date)
      create_mentoring_model_task(group: @group, status: MentoringModel::Task::Status::DONE, user: mentee , completed_date: Time.current.to_date)
      create_mentoring_model_task(group: @group, status: MentoringModel::Task::Status::DONE, user: mentee , completed_date: Time.current.to_date)
      # Meetings
      create_meeting(start_time: end_time - 30.minutes, end_time: end_time - 20.minutes, group_id: @group.id, program_id: @program.id, members: [mentor.member, mentee.member], owner_id: mentor.member_id)
      m = create_meeting(start_time: end_time - 20.minutes, end_time: end_time - 10.minutes, group_id: @group.id, program_id: @program.id, members: [mentor.member, mentee.member], owner_id: mentee.member_id)
      m.member_meetings.map{|mm| mm.update_column(:attending, MemberMeeting::ATTENDING::NO)}
      # Posts
      create_post(topic: topic, user: mentor)
      create_post(topic: topic, user: mentee)
      create_post(topic: topic, user: mentee)
      create_post(topic: topic, user: mentor)

      survey = create_engagement_survey(name: "Test Survey", program: @program)
      create_matrix_survey_question({survey: survey, program: @program, required: true})
      q1 = create_survey_question({survey: survey, program: @program, required: true})

      response_id = SurveyAnswer.maximum(:response_id).to_i + 1
      user = @group.mentors.first
      student = @group.students.first
      task = create_mentoring_model_task(group: @group, status: MentoringModel::Task::Status::DONE, user: user, action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id)

      task.action_item.survey_questions_with_matrix_rating_questions.matrix_rating_questions.each do |ques|
        ans = task.survey_answers.new(user: user, response_id: response_id, answer_value: {answer_text: "Good", question: ques},last_answered_at: Time.current)
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
  end
end
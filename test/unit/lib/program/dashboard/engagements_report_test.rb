require_relative './../../../../test_helper'

class Program::Dashboard::EngagementsReportTest < ActiveSupport::TestCase
  def test_get_engagements_reports_to_display
    program = programs(:albers)
    assert_equal [DashboardReportSubSection::Type::Engagements::ENGAGEMENTS_HEALTH, DashboardReportSubSection::Type::Engagements::ENGAGEMENTS_SURVEY_RESPONSES], program.get_engagements_reports_to_display
  end

  def test_get_engagement_type
    program = programs(:albers)
    assert_equal Program::Dashboard::EngagementsReport::GROUPS_ENGAGEMENT_TYPE, program.get_engagement_type

    program.stubs(:only_one_time_mentoring_enabled?).returns(true)
    assert_equal Program::Dashboard::EngagementsReport::MEETINGS_ENGAGEMENT_TYPE, program.get_engagement_type
  end

  def test_get_engagements_survey_responses_data
    program = programs(:albers)
    program.stubs(:get_groups_survey_responses_data).with("date_range",1).once.returns('groups_data')
    assert_equal 'groups_data', program.get_engagements_survey_responses_data("date_range", 1)

    program.stubs(:only_one_time_mentoring_enabled?).returns(true)
    program.stubs(:get_meetings_survey_responses_data).with("date_range", 1).once.returns('meetings_data')
    assert_equal 'meetings_data', program.get_engagements_survey_responses_data("date_range", 1)
  end

  def test_get_engagements_health_data
    program = programs(:albers)
    program.stubs(:get_groups_health_data).with("date_range").once.returns('groups_data')
    assert_equal 'groups_data', program.get_engagements_health_data("date_range")

    program.stubs(:only_one_time_mentoring_enabled?).returns(true)
    program.stubs(:get_meetings_health_data).with("date_range").once.returns('meetings_data')
    assert_equal 'meetings_data', program.get_engagements_health_data("date_range")
  end

  def test_get_groups_survey_responses_data
    program = programs(:albers)
    program.stubs(:get_groups_survey_responses_count).with("date_range").once.returns('count')
    program.stubs(:get_groups_survey_responses_to_show).with("date_range", 1).once.returns('responses')
    assert_equal_hash({survey_responses_count: 'count', survey_responses: 'responses'}, program.send(:get_groups_survey_responses_data, "date_range", 1))
  end

  def test_get_meetings_survey_responses_data
    program = programs(:albers)
    program.stubs(:only_one_time_mentoring_enabled?).returns(true)
    program.stubs(:get_meetings_survey_responses_count).with("date_range").once.returns('count')
    program.stubs(:get_meetings_survey_responses_to_show).with("date_range", 1).once.returns('responses')
    assert_equal_hash({survey_responses_count: 'count', survey_responses: 'responses'}, program.send(:get_meetings_survey_responses_data, "date_range", 1))
  end

  def test_get_groups_survey_responses_count
    program = programs(:albers)
    program.stubs(:get_groups_survey_responses).with("date_range").returns([1,2,3,4,5,6])
    assert_equal 6, program.send(:get_groups_survey_responses_count, "date_range")

    program.stubs(:get_groups_survey_responses).with("date_range").returns([1,2,3,4,5,6,7,8,9,10,11,12,13])
    assert_equal 13, program.send(:get_groups_survey_responses_count, "date_range")
  end

  def test_get_groups_survey_responses_to_show
    program = programs(:albers)
    program.stubs(:get_groups_survey_responses).with("date_range").returns([1,2,3,4,5,6])
    assert_equal [1,2,3,4,5,6], program.send(:get_groups_survey_responses_to_show, "date_range", 1)

    program.stubs(:get_groups_survey_responses).with("date_range").returns([1,2,3,4,5,6,7,8,9,10,11,12,13])
    assert_equal [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], program.send(:get_groups_survey_responses_to_show, "date_range", 1)
  end

  def test_get_groups_survey_responses
    program = programs(:albers)
    date_range = 1.year.ago..Time.now
    assert_equal [], program.send(:get_groups_survey_responses, date_range)

    g1 = groups(:mygroup)
    u11 = g1.students.first
    u12 = g1.mentors.first
    g2 = groups(:group_4)
    u21 = g2.students.first

    q1 = create_survey_question
    sa1 = create_survey_answer({answer_text: "ans1", response_id: 555, user: u11, group: g1, last_answered_at: 1.month.from_now, survey_question: q1, survey_id: q1.survey_id})
    assert_equal [], program.send(:get_groups_survey_responses, date_range)

    sa1.update_attributes!(last_answered_at: 1.month.ago)
    assert_equal [[u11.id, g1.id, 555]], program.send(:get_groups_survey_responses, date_range).map{|a| [a.user_id, a.group_id, a.response_id]}

    q2 = create_survey_question
    sa2 = create_survey_answer({answer_text: "ans2", response_id: 556, user: u11, group: g1, last_answered_at: 1.month.ago - 1.second, survey_question: q2})
    assert_equal [[u11.id, g1.id, 555], [u11.id, g1.id, 556]], program.send(:get_groups_survey_responses, date_range).map{|a| [a.user_id, a.group_id, a.response_id]}

    sa2.update_attributes!(response_id: sa1.response_id)
    assert_equal [[u11.id, g1.id, 555]], program.send(:get_groups_survey_responses, date_range).map{|a| [a.user_id, a.group_id, a.response_id]}

    create_survey_answer({answer_text: "ans3", response_id: 555, user: u12, group: g1, last_answered_at: 1.month.ago - 1.minute, survey_question: q1, survey_id: q1.survey_id})
    create_survey_answer({answer_text: "ans4", response_id: 555, user: u12, group: g1, last_answered_at: 1.month.ago - 1.minute, survey_question: q2, survey_id: q2.survey_id})
    assert_equal [[u11.id, g1.id, 555], [u12.id, g1.id, 555]], program.reload.send(:get_groups_survey_responses, date_range).map{|a| [a.user_id, a.group_id, a.response_id]}

    create_survey_answer({answer_text: "ans3", response_id: 550, user: u21, group: g2, last_answered_at: 1.month.ago + 1.minute, survey_question: q1, survey_id: q1.survey_id})
    assert_equal [[u21.id, g2.id, 550], [u11.id, g1.id, 555], [u12.id, g1.id, 555]], program.send(:get_groups_survey_responses, date_range).map{|a| [a.user_id, a.group_id, a.response_id]}
  end

  def test_get_meetings_survey_responses_count
    program = programs(:albers)
    program.stubs(:get_meetings_survey_responses).with("date_range").returns([1,2,3,4,5,6])
    assert_equal 6, program.send(:get_meetings_survey_responses_count, "date_range")

    program.stubs(:get_meetings_survey_responses).with("date_range").returns([1,2,3,4,5,6,7,8,9,10,11,12,13])
    assert_equal 13, program.send(:get_meetings_survey_responses_count, "date_range")
  end

  def test_get_meetings_survey_responses_to_show
    program = programs(:albers)
    program.stubs(:get_meetings_survey_responses).with("date_range").returns([1,2,3,4,5,6])
    assert_equal [1,2,3,4,5,6], program.send(:get_meetings_survey_responses_to_show, "date_range", 1)

    program.stubs(:get_meetings_survey_responses).with("date_range").returns([1,2,3,4,5,6,7,8,9,10])
    assert_equal [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], program.send(:get_meetings_survey_responses_to_show, "date_range", 1)
  end

  def test_get_meetings_survey_responses
    program = programs(:albers)
    date_range = 1.year.ago..Time.now

    m1 = meetings(:completed_calendar_meeting)
    u11 = users(:f_mentor)
    mm11 = m1.get_member_meeting_for_role(RoleConstants::MENTOR_NAME)

    u12 = users(:mkr_student)
    mm12 = m1.get_member_meeting_for_role(RoleConstants::STUDENT_NAME)

    m2 = meetings(:cancelled_calendar_meeting)
    u21 = users(:f_mentor)
    mm21 = m2.get_member_meeting_for_role(RoleConstants::MENTOR_NAME)

    q1 = create_survey_question
    q2 = create_survey_question
    assert_equal [], program.send(:get_meetings_survey_responses, date_range)

    sa1 = create_survey_answer({answer_text: "ans1", response_id: 555, user: u11, member_meeting: mm11, last_answered_at: 1.month.from_now, survey_question: q1, survey_id: q1.survey_id})
    assert_equal [], program.send(:get_meetings_survey_responses, date_range)

    sa1.update_attributes!(last_answered_at: 1.month.ago)
    assert_equal [[u11.id, mm11.id, 555]], program.send(:get_meetings_survey_responses, date_range).map{|a| [a.user_id, a.member_meeting_id, a.response_id]}
    
    sa2 = create_survey_answer({answer_text: "ans2", response_id: 556, user: u11, member_meeting: mm11, last_answered_at: 1.month.ago - 1.second, survey_question: q2})
    assert_equal [[u11.id, mm11.id, 555], [u11.id, mm11.id, 556]], program.send(:get_meetings_survey_responses, date_range).map{|a| [a.user_id, a.member_meeting_id, a.response_id]}

    sa2.update_attributes!(response_id: sa1.response_id)
    assert_equal [[u11.id, mm11.id, 555]], program.send(:get_meetings_survey_responses, date_range).map{|a| [a.user_id, a.member_meeting_id, a.response_id]}

    create_survey_answer({answer_text: "ans3", response_id: 555, user: u12, member_meeting: mm12, last_answered_at: 1.month.ago - 1.minute, survey_question: q1, survey_id: q1.survey_id})
    create_survey_answer({answer_text: "ans4", response_id: 555, user: u12, member_meeting: mm12, last_answered_at: 1.month.ago - 1.minute, survey_question: q2, survey_id: q2.survey_id})
    assert_equal [[u11.id, mm11.id, 555], [u12.id, mm12.id, 555]], program.reload.send(:get_meetings_survey_responses, date_range).map{|a| [a.user_id, a.member_meeting_id, a.response_id]}

    create_survey_answer({answer_text: "ans3", response_id: 550, user: u21, member_meeting: mm21, last_answered_at: 1.month.ago + 1.minute, survey_question: q1, survey_id: q1.survey_id})
    assert_equal [[u21.id, mm21.id, 550], [u11.id, mm11.id, 555], [u12.id, mm12.id, 555]], program.send(:get_meetings_survey_responses, date_range).map{|a| [a.user_id, a.member_meeting_id, a.response_id]}
  end

  def test_get_groups_health_data
    program = programs(:albers)
    program.stubs(:get_group_data_for_positive_outcome_between).with("date_range").returns(1..100)
    program.stubs(:get_group_data_for_neutral_outcome_between).with("date_range").returns(1..22)
    program.stubs(:groups_with_overdue_survey_responses_and_active_within).with("date_range").returns(1..33)
    assert_equal_hash({engagements_with_good_survey_responses_count: 100, engagements_with_not_good_survey_responses_count: 22, engagements_without_survey_responses_count: 33}, program.send(:get_groups_health_data, "date_range"))
  end

  def test_get_meetings_health_data
    program = programs(:albers)
    program.stubs(:get_meeting_data_for_positive_outcome_completed_between).with("date_range").returns(1..100)
    program.stubs(:get_meeting_data_for_neutral_outcome_completed_between).with("date_range").returns(1..22)
    program.stubs(:meetings_with_no_survey_responses_and_completed_between).with("date_range").returns(1..33)
    assert_equal_hash({engagements_with_good_survey_responses_count: 100, engagements_with_not_good_survey_responses_count: 22, engagements_without_survey_responses_count: 33}, program.send(:get_meetings_health_data, "date_range"))
  end

  def test_get_group_data_for_positive_outcome_between
    program = programs(:albers)
    date_range = 1.year.ago..Time.now

    s1 = program.surveys.of_engagement_type.find_by(name: "Partnership Effectiveness")
    q11 = s1.survey_questions.find_by(question_text: "How effective is your partnership in helping to reach your goals")
    q12 = s1.survey_questions.find_by(question_text: "What is going well in your mentoring partnership?")
    c111 = q11.question_choices.find_by(text: "Very Good")
    c112 = q11.question_choices.find_by(text: "Good")

    g1 = groups(:mygroup)
    u11 = g1.students.first
    u12 = g1.mentors.first
    g2 = groups(:group_4)
    u21 = g2.students.first

    assert_equal [], program.send(:get_group_data_for_positive_outcome_between, date_range)

    sa1 = create_survey_answer({answer_value: {answer_text: "Good",  question: q11}, response_id: 555, user: u11, group: g1, last_answered_at: 1.month.from_now, survey_question: q11, survey_id: s1.id})
    create_survey_answer({answer_text: "Something", response_id: 555, user: u11, group: g1, last_answered_at: 1.month.ago, survey_question: q12, survey_id: s1.id})
    sa3 = create_survey_answer({answer_value: {answer_text: "Good",  question: q11}, response_id: 555, user: u12, group: g1, last_answered_at: 1.month.ago, survey_question: q11, survey_id: s1.id})
    assert_equal [], program.send(:get_group_data_for_positive_outcome_between, date_range)

    q11.update_attributes!(positive_outcome_options_management_report: [c111.id].join(","))
    assert_equal [], program.send(:get_group_data_for_positive_outcome_between, date_range)

    q11.update_attributes!(positive_outcome_options_management_report: [c111.id, c112.id].join(","))
    assert_equal [g1.id], program.send(:get_group_data_for_positive_outcome_between, date_range)

    sa3.destroy
    assert_equal [], program.send(:get_group_data_for_positive_outcome_between, date_range)

    sa1.update_attributes!(last_answered_at: 1.month.ago)
    assert_equal [g1.id], program.send(:get_group_data_for_positive_outcome_between, date_range)

    create_survey_answer({answer_value: {answer_text: "Very good",  question: q11}, response_id: 555, user: u21, group: g2, last_answered_at: 1.month.ago, survey_question: q11, survey_id: s1.id})
    assert_equal_unordered [g1.id, g2.id], program.send(:get_group_data_for_positive_outcome_between, date_range)
  end

  def test_get_group_data_for_neutral_outcome_between
    program = programs(:albers)
    date_range = 1.year.ago..Time.now

    s1 = program.surveys.of_engagement_type.find_by(name: "Partnership Effectiveness")
    q11 = s1.survey_questions.find_by(question_text: "How effective is your partnership in helping to reach your goals")
    q12 = s1.survey_questions.find_by(question_text: "What is going well in your mentoring partnership?")

    g1 = groups(:mygroup)
    u11 = g1.students.first
    g2 = groups(:group_4)
    u21 = g2.students.first
    u22 = g1.mentors.first

    program.stubs(:get_group_data_for_positive_outcome_between).with(date_range).returns([])

    program.stubs(:dashboard_positive_outcome_survey_ids).returns([])
    assert_equal_unordered [], program.send(:get_group_data_for_neutral_outcome_between, date_range)

    program.stubs(:dashboard_positive_outcome_survey_ids).returns([s1.id])    
    assert_equal_unordered [], program.send(:get_group_data_for_neutral_outcome_between, date_range)

    sa1 = create_survey_answer({answer_text: "Something", response_id: 555, user: u11, group: g1, last_answered_at: 1.month.ago, survey_question: q12, survey_id: s1.id})
    create_survey_answer({answer_value: {answer_text: "Very good",  question: q11}, response_id: 555, user: u21, group: g2, last_answered_at: 1.month.ago, survey_question: q11, survey_id: s1.id})
    create_survey_answer({answer_text: "Something", response_id: 555, user: u22, group: g2, last_answered_at: 1.month.ago, survey_question: q12, survey_id: s1.id})
    program.stubs(:dashboard_positive_outcome_survey_ids).returns([])
    assert_equal_unordered [], program.send(:get_group_data_for_neutral_outcome_between, date_range)

    program.stubs(:dashboard_positive_outcome_survey_ids).returns([s1.id])
    assert_equal_unordered [g1.id, g2.id], program.send(:get_group_data_for_neutral_outcome_between, date_range)

    program.stubs(:get_group_data_for_positive_outcome_between).with(date_range).returns([g2.id])
    assert_equal_unordered [g1.id], program.send(:get_group_data_for_neutral_outcome_between, date_range)

    sa1.update_attributes!(last_answered_at: 1.month.from_now)
    assert_equal_unordered [], program.send(:get_group_data_for_neutral_outcome_between, date_range)
  end

  def test_groups_with_overdue_survey_responses_and_active_within
    program = programs(:albers)
    date_range = 1.year.ago..Time.now

    s1 = program.surveys.of_engagement_type.find_by(name: "Partnership Effectiveness")
    q1 = s1.survey_questions.find_by(question_text: "How effective is your partnership in helping to reach your goals")

    g1 = groups(:mygroup)
    u11 = g1.students.first

    program.stubs(:dashboard_positive_outcome_survey_ids).returns([])
    assert_equal [], program.send(:groups_with_overdue_survey_responses_and_active_within, date_range)

    program.stubs(:dashboard_positive_outcome_survey_ids).returns([s1.id])
    assert_equal [], program.send(:groups_with_overdue_survey_responses_and_active_within, date_range)

    task = MentoringModel::Task.create!({
      connection_membership_id: Connection::Membership.where(group_id: g1.id, user_id: u11.id)[0].id,
      group_id: g1.id,
      title: "Survey Task",
      status: MentoringModel::Task::Status::TODO,
      action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY,
      action_item_id: s1.id,
      required: true,
      due_date: 1.day.from_now,
      template_version: 2
    })

    assert_equal [], program.send(:groups_with_overdue_survey_responses_and_active_within, date_range)

    task.update_attributes!(due_date: 1.week.ago)
    assert_equal [g1.id], program.send(:groups_with_overdue_survey_responses_and_active_within, date_range)

    ans = SurveyAnswer.create!({answer_value: {answer_text: "Very good",  question: q1}, response_id: 1111, user: u11, last_answered_at: 1.week.from_now, survey_question: q1, task_id: task.id, group_id: g1.id})
    assert_equal [g1.id], program.send(:groups_with_overdue_survey_responses_and_active_within, date_range)

    ans.update_attributes!(last_answered_at: 2.years.ago)
    assert_equal [], program.send(:groups_with_overdue_survey_responses_and_active_within, date_range)

    ans.update_attributes!(is_draft: true)
    assert_equal [g1.id], program.send(:groups_with_overdue_survey_responses_and_active_within, date_range)
  end

  def test_group_ids_with_survey_responses
    program = programs(:albers)
    date_range = 1.year.ago..Time.now

    s1 = program.surveys.of_engagement_type.find_by(name: "Partnership Effectiveness")
    q11 = s1.survey_questions.find_by(question_text: "How effective is your partnership in helping to reach your goals")
    q12 = s1.survey_questions.find_by(question_text: "What is going well in your mentoring partnership?")

    g1 = groups(:mygroup)
    u11 = g1.students.first
    g2 = groups(:group_4)
    u21 = g2.students.first
    u22 = g1.mentors.first

    program.stubs(:dashboard_positive_outcome_survey_ids).returns([])
    assert_equal_unordered [], program.send(:group_ids_with_survey_responses, date_range).collect(&:group_id)

    program.stubs(:dashboard_positive_outcome_survey_ids).returns([s1.id])
    assert_equal_unordered [], program.send(:group_ids_with_survey_responses, date_range).collect(&:group_id)

    sa1 = create_survey_answer({answer_text: "Something", response_id: 555, user: u11, group: g1, last_answered_at: 1.month.ago, survey_question: q12, survey_id: s1.id})
    create_survey_answer({answer_value: {answer_text: "Very good",  question: q11}, response_id: 555, user: u21, group: g2, last_answered_at: 1.month.ago, survey_question: q11, survey_id: s1.id})
    create_survey_answer({answer_text: "Something", response_id: 555, user: u22, group: g2, last_answered_at: 1.month.ago, survey_question: q12, survey_id: s1.id})

    program.stubs(:dashboard_positive_outcome_survey_ids).returns([])
    assert_equal_unordered [], program.send(:group_ids_with_survey_responses, date_range).collect(&:group_id)

    program.stubs(:dashboard_positive_outcome_survey_ids).returns([s1.id])
    assert_equal_unordered [g1.id, g2.id], program.send(:group_ids_with_survey_responses, date_range).collect(&:group_id)

    sa1.update_attributes!(last_answered_at: 1.month.from_now)
    assert_equal_unordered [g2.id], program.send(:group_ids_with_survey_responses, date_range).collect(&:group_id)
  end

  def test_get_meeting_data_for_positive_outcome_completed_between
    program = programs(:albers)
    date_range = 1.year.ago..Time.now
    s = program.surveys.of_meeting_feedback_type.last
    q = s.survey_questions.find_by(question_text: "How was your overall meeting experience?")
    u = users(:mkr_student)
    m1 = meetings(:completed_calendar_meeting)
    mm1 = m1.get_member_meeting_for_role(RoleConstants::STUDENT_NAME)
    m2 = meetings(:cancelled_calendar_meeting)
    mm2 = m2.get_member_meeting_for_role(RoleConstants::STUDENT_NAME)
    c1 = q.question_choices.find_by(text: "Extremely useful")
    c2 = q.question_choices.find_by(text: "Very useful")
    q.update_attributes!(positive_outcome_options_management_report: [c1.id].join(","))

    assert_equal [], program.send(:get_meeting_data_for_positive_outcome_completed_between, date_range).collect(&:id)

    SurveyAnswer.create!({answer_value: {answer_text: "Very useful",  question: q}, response_id: 555, user: u, member_meeting: mm1, last_answered_at: 1.month.from_now, survey_question: q, survey_id: s.id})
    SurveyAnswer.create!({answer_value: {answer_text: "Very useful",  question: q}, response_id: 556, user: u, member_meeting: mm2, last_answered_at: 1.month.from_now, survey_question: q, survey_id: s.id})
    assert_equal [], program.send(:get_meeting_data_for_positive_outcome_completed_between, date_range).collect(&:id)

    q.update_attributes!(positive_outcome_options_management_report: [c1.id, c2.id].join(","))
    assert_equal [m1.id], program.send(:get_meeting_data_for_positive_outcome_completed_between, date_range).collect(&:id)

    m1.update_attributes!(start_time: 2.years.ago, end_time: 2.years.ago + 1.hour)
    assert_equal [], program.send(:get_meeting_data_for_positive_outcome_completed_between, date_range).collect(&:id)
  end

  def test_get_meeting_data_for_neutral_outcome_completed_between
    program = programs(:albers)
    date_range = 1.year.ago..Time.now
    s = program.surveys.of_meeting_feedback_type.last
    q = s.survey_questions.find_by(question_text: "How was your overall meeting experience?")
    u = users(:mkr_student)
    m1 = meetings(:completed_calendar_meeting)
    mm1 = m1.get_member_meeting_for_role(RoleConstants::STUDENT_NAME)
    m2 = meetings(:cancelled_calendar_meeting)
    mm2 = m2.get_member_meeting_for_role(RoleConstants::STUDENT_NAME)

    program.stubs(:dashboard_positive_outcome_survey_ids).returns([])
    program.stubs(:get_meeting_data_for_positive_outcome_completed_between).with(date_range).returns([])

    assert_equal [], program.send(:get_meeting_data_for_neutral_outcome_completed_between, date_range).collect(&:id)

    SurveyAnswer.create!({answer_value: {answer_text: "Very useful",  question: q}, response_id: 555, user: u, member_meeting: mm1, last_answered_at: 1.month.from_now, survey_question: q, survey_id: s.id})
    SurveyAnswer.create!({answer_value: {answer_text: "Very useful",  question: q}, response_id: 556, user: u, member_meeting: mm2, last_answered_at: 1.month.from_now, survey_question: q, survey_id: s.id})
    assert_equal [], program.send(:get_meeting_data_for_neutral_outcome_completed_between, date_range).collect(&:id)

    program.stubs(:dashboard_positive_outcome_survey_ids).returns([s.id])
    assert_equal [m1.id], program.send(:get_meeting_data_for_neutral_outcome_completed_between, date_range).collect(&:id)

    m1.update_attributes!(start_time: 2.years.ago, end_time: 2.years.ago + 1.hour)
    assert_equal [], program.send(:get_meeting_data_for_neutral_outcome_completed_between, date_range).collect(&:id)

    m1.update_attributes!(start_time: 1.years.ago, end_time: 1.years.ago + 1.hour)
    assert_equal [m1.id], program.send(:get_meeting_data_for_neutral_outcome_completed_between, date_range).collect(&:id)

    program.stubs(:get_meeting_data_for_positive_outcome_completed_between).with(date_range).returns([m1.id])
    assert_equal [], program.send(:get_meeting_data_for_neutral_outcome_completed_between, date_range).collect(&:id)
  end

  def test_meetings_with_no_survey_responses_and_completed_between
    program = programs(:albers)
    date_range = 1.year.ago..Time.now
    s = program.surveys.of_meeting_feedback_type.last
    q = s.survey_questions.find_by(question_text: "How was your overall meeting experience?")
    u = users(:mkr_student)
    m1 = meetings(:completed_calendar_meeting)
    mm1 = m1.get_member_meeting_for_role(RoleConstants::STUDENT_NAME)
    m2 = meetings(:cancelled_calendar_meeting)
    mm2 = m2.get_member_meeting_for_role(RoleConstants::STUDENT_NAME)

    program.stubs(:dashboard_positive_outcome_survey_ids).returns([])
    assert_equal [], program.send(:meetings_with_no_survey_responses_and_completed_between, date_range).collect(&:id)

    program.stubs(:dashboard_positive_outcome_survey_ids).returns([s.id])
    assert_equal [m1.id], program.send(:meetings_with_no_survey_responses_and_completed_between, date_range).collect(&:id)

    m1.update_attributes!(start_time: 2.years.ago, end_time: 2.years.ago + 1.hour)
    assert_equal [], program.send(:meetings_with_no_survey_responses_and_completed_between, date_range).collect(&:id)

    m1.update_attributes!(start_time: 1.years.ago, end_time: 1.years.ago + 1.hour)
    assert_equal [m1.id], program.send(:meetings_with_no_survey_responses_and_completed_between, date_range).collect(&:id)

    SurveyAnswer.create!({answer_value: {answer_text: "Very useful",  question: q}, response_id: 555, user: u, member_meeting: mm1, last_answered_at: 1.month.from_now, survey_question: q, survey_id: s.id})
    SurveyAnswer.create!({answer_value: {answer_text: "Very useful",  question: q}, response_id: 556, user: u, member_meeting: mm2, last_answered_at: 1.month.from_now, survey_question: q, survey_id: s.id})
    assert_equal [], program.send(:meetings_with_no_survey_responses_and_completed_between, date_range).collect(&:id)
  end

  def test_dashboard_positive_outcome_survey_ids
    program = programs(:albers)
    ms = program.surveys.of_meeting_feedback_type.last
    mq = ms.survey_questions.find_by(question_text: "How was your overall meeting experience?")
    mc = mq.question_choices.find_by(text: "Extremely useful")

    es = program.surveys.of_engagement_type.find_by(name: "Partnership Effectiveness")
    eq = es.survey_questions.find_by(question_text: "How effective is your partnership in helping to reach your goals")
    ec = eq.question_choices.find_by(text: "Very Good")

    assert_equal [], program.send(:dashboard_positive_outcome_survey_ids)
    program.stubs(:only_one_time_mentoring_enabled?).returns(true)
    assert_equal [], program.send(:dashboard_positive_outcome_survey_ids)

    mq.update_attributes!(positive_outcome_options_management_report: [mc.id].join(","))
    eq.update_attributes!(positive_outcome_options_management_report: [ec.id].join(","))

    assert_equal [ms.id], program.send(:dashboard_positive_outcome_survey_ids)
    program.stubs(:only_one_time_mentoring_enabled?).returns(false)
    assert_equal [es.id], program.send(:dashboard_positive_outcome_survey_ids)
  end
end
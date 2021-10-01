require_relative './../../../test_helper'

class UserMeetingFeedbackWidgetTest < ActiveSupport::TestCase
  def test_can_render_meeting_feedback_widget
    user = users(:f_admin)
    assert_false user.can_render_meeting_feedback_widget?
    user.stubs(:member_meetings_with_pending_meeting_feedback).returns(['something'])
    assert_false user.can_render_meeting_feedback_widget?
    Program.any_instance.stubs(:calendar_enabled?).returns(true)
    assert user.can_render_meeting_feedback_widget?
    user.stubs(:member_meetings_with_pending_meeting_feedback).returns([])
    assert_false user.can_render_meeting_feedback_widget?
  end

  def test_member_meetings_with_pending_meeting_feedback
    user = users(:f_mentor)
    m1 = create_meeting(start_time: 1.hour.ago, end_time: 30.minutes.ago, force_non_group_meeting: true)
    m2 = create_meeting(start_time: 2.days.ago, end_time: 2.days.ago + 30.minutes, force_non_group_meeting: true)
    user.stubs(:meeting_ids_eligible_for_meeting_feedback_widget).returns([m1.id, m2.id])
    user.stubs(:member_meeting_ids_with_feedback_provided).returns([])
    mms = user.member_meetings_with_pending_meeting_feedback
    assert_equal 2, mms.count
    assert_equal_unordered [m1.id, m2.id], mms.collect(&:meeting_id)

    user.stubs(:member_meeting_ids_with_feedback_provided).returns(m1.member_meetings.pluck(:id))
    mms = user.member_meetings_with_pending_meeting_feedback
    assert_equal 1, mms.count
    assert_equal [m2.id], mms.collect(&:meeting_id)
  end

  def test_meeting_ids_eligible_for_meeting_feedback_widget
    user = users(:f_mentor)
    m1 = create_meeting(start_time: 1.hour.ago, end_time: 30.minutes.ago, force_non_group_meeting: true)
    m2 = create_meeting(start_time: 2.days.ago, end_time: 2.days.ago + 30.minutes, force_non_group_meeting: true)
    m3 = create_meeting(start_time: 40.days.ago, end_time: 40.days.ago + 30.minutes, force_non_group_meeting: true)
    m4 = create_meeting(start_time: 1.hour.ago, end_time: 30.minutes.ago)
    
    assert_equal [meetings(:past_calendar_meeting).id, meetings(:completed_calendar_meeting).id, meetings(:cancelled_calendar_meeting).id], user.send(:meeting_ids_eligible_for_meeting_feedback_widget)

    m1.meeting_request.update_status!(users(:f_mentor), AbstractRequest::Status::ACCEPTED, skip_meeting_update: true)
    m2.meeting_request.update_status!(users(:f_mentor), AbstractRequest::Status::ACCEPTED, skip_meeting_update: true)
    m3.meeting_request.update_status!(users(:f_mentor), AbstractRequest::Status::ACCEPTED, skip_meeting_update: true)
    assert_nil m4.meeting_request_id

    assert_equal_unordered [m1.id, m2.id, meetings(:past_calendar_meeting).id, meetings(:completed_calendar_meeting).id, meetings(:cancelled_calendar_meeting).id], user.send(:meeting_ids_eligible_for_meeting_feedback_widget)
  end

  def test_member_meeting_ids_with_feedback_provided
    user = users(:f_mentor)
    assert_equal [], user.send(:member_meeting_ids_with_feedback_provided)
    m1 = create_meeting(start_time: 1.hour.ago, end_time: 30.minutes.ago, force_non_group_meeting: true)

    mmid = user.member.member_meetings.first.id
    survey = user.program.get_meeting_feedback_survey_for_role(RoleConstants::MENTOR_NAME)
    create_survey_answer(user: user, survey: survey, survey_question: survey.survey_questions[0], answer_value: {answer_text: "Extremely satisfying", question: survey.survey_questions[0]}, member_meeting_id: mmid, meeting_occurrence_time: m1.first_occurrence)

    assert_equal [mmid], user.send(:member_meeting_ids_with_feedback_provided)
  end
end
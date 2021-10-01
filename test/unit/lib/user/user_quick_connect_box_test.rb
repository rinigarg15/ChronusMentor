require_relative './../../../test_helper'

class UserQuickConnectBoxTest < ActiveSupport::TestCase
  # Testing methods on user class directly

  def test_can_render_meetings_for_quick_connect_box
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR)
    user = users(:f_student)

    user.stubs(:can_view_mentoring_calendar?).returns(false)
    assert_false user.can_render_meetings_for_quick_connect_box?

    user.stubs(:can_view_mentoring_calendar?).returns(true)
    User.any_instance.stubs(:is_student_meeting_request_limit_reached?).returns(false)
    assert user.can_render_meetings_for_quick_connect_box?

    program.stubs(:calendar_enabled?).returns(false)
    assert_false user.can_render_meetings_for_quick_connect_box?(program)

    user.stubs(:can_view_mentors?).returns(false)
    assert_false user.can_render_meetings_for_quick_connect_box?

    user.stubs(:can_view_mentors?).returns(true)
    assert user.can_render_meetings_for_quick_connect_box?

    User.any_instance.stubs(:is_student_meeting_request_limit_reached?).returns(true)
    assert_false user.can_render_meetings_for_quick_connect_box?
  end

  def test_can_render_mentors_for_connection_in_quick_connect_box
    program = programs(:albers)
    program.stubs(:only_career_based_ongoing_mentoring_enabled?).returns(true)
    program.stubs(:matching_by_mentee_alone?).returns(true)
    user = users(:f_mentor)
    user.stubs(:can_send_mentor_request?).returns(true)
    assert user.can_render_mentors_for_connection_in_quick_connect_box?
    assert user.can_render_mentors_for_connection_in_quick_connect_box?(program)

    user.stubs(:can_send_mentor_request?).returns(false)
    assert_false user.can_render_mentors_for_connection_in_quick_connect_box?(program)

    user.stubs(:can_send_mentor_request?).returns(true)
    program.stubs(:only_career_based_ongoing_mentoring_enabled?).returns(false)
    assert_false user.can_render_mentors_for_connection_in_quick_connect_box?(program)

    program.stubs(:only_career_based_ongoing_mentoring_enabled?).returns(true)
    program.stubs(:matching_by_mentee_alone?).returns(false)
    assert_false user.can_render_mentors_for_connection_in_quick_connect_box?(program)
    program.stubs(:only_career_based_ongoing_mentoring_enabled?).returns(true)
    program.stubs(:matching_by_mentee_alone?).returns(false)
    program.stubs(:matching_by_mentee_and_admin_with_preference?).returns(true)
    user.stubs(:can_send_mentor_request?).returns(true)
    assert user.can_render_mentors_for_connection_in_quick_connect_box?(program)

    user.stubs(:can_view_mentors?).returns(false)
    assert_false user.can_render_mentors_for_connection_in_quick_connect_box?

    user.stubs(:can_view_mentors?).returns(true)
    assert user.can_render_mentors_for_connection_in_quick_connect_box?

    user.stubs(:connection_limit_as_mentee_reached?).returns(false)
    assert user.can_render_mentors_for_connection_in_quick_connect_box?

    user.stubs(:connection_limit_as_mentee_reached?).returns(true)
    assert_false user.can_render_mentors_for_connection_in_quick_connect_box?
  end

  def test_can_render_quick_connect_box
    Meeting.stubs(:upcoming_recurrent_meetings).returns(Meeting.all)
    Member.any_instance.stubs(:get_attending_recurring_meetings).returns([])
    Member.any_instance.stubs(:not_connected_for?).returns(true)
    program = programs(:albers)
    user1 = users(:mkr_student)
    user1.stubs(:can_render_meetings_for_quick_connect_box?).returns(true)
    user1.stubs(:can_render_mentors_for_connection_in_quick_connect_box?).returns(true)
    assert user1.can_render_quick_connect_box?

    user2 = users(:student_0)
    user2.stubs(:can_view_mentors?).returns(false)
    user2.stubs(:can_render_meetings_for_quick_connect_box?).returns(true)
    user2.stubs(:can_render_mentors_for_connection_in_quick_connect_box?).returns(true)
    assert_false user2.can_render_quick_connect_box?

    user2.stubs(:can_view_mentors?).returns(true)
    assert user2.can_render_quick_connect_box?

    user2.stubs(:can_render_meetings_for_quick_connect_box?).returns(false)
    assert user2.can_render_quick_connect_box?

    user2.stubs(:can_render_mentors_for_connection_in_quick_connect_box?).returns(false)
    assert_false user2.can_render_quick_connect_box?
  end
end
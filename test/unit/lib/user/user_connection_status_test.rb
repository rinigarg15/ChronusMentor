require_relative './../../../test_helper'

class UserConnectionStatusTest < ActiveSupport::TestCase
  def setup
    super
    @user = users(:f_mentor)
  end

  def test_current_connection_status
    @user.stubs(:connection_status).with(User::ConnectionStatus::TimeLine::ONGOING).returns("something")
    assert_equal "something", @user.current_connection_status
  end

  def test_past_connection_status
    @user.stubs(:connection_status).with(User::ConnectionStatus::TimeLine::PAST).returns("something")
    assert_equal "something", @user.past_connection_status
  end

  def test_connection_status
    @user.stubs(:has_groups?).with('timeline').returns(false)
    @user.stubs(:has_meetings?).with('timeline').returns(false)
    assert_equal User::ConnectionStatus::ConnectionStatus::NONE, @user.send(:connection_status, 'timeline')

    @user.stubs(:has_groups?).with('timeline').returns(true)
    assert_equal User::ConnectionStatus::ConnectionStatus::ONGOING, @user.send(:connection_status, 'timeline')

    @user.stubs(:has_groups?).with('timeline').returns(false)
    @user.stubs(:has_meetings?).with('timeline').returns(true)
    assert_equal User::ConnectionStatus::ConnectionStatus::FLASH, @user.send(:connection_status, 'timeline')

    @user.stubs(:has_groups?).with('timeline').returns(true)
    assert_equal User::ConnectionStatus::ConnectionStatus::BOTH, @user.send(:connection_status, 'timeline')
  end

  def test_has_groups
    @user.stubs(:has_completed_groups?).returns('past')
    @user.stubs(:has_ongoing_groups?).returns('future')

    assert_equal 'past', @user.send(:has_groups?)
    assert_equal 'future', @user.send(:has_groups?, User::ConnectionStatus::TimeLine::ONGOING)
  end

  def test_has_meetings
    @user.stubs(:has_completed_meetings?).returns('past')
    @user.stubs(:has_upcoming_meetings?).returns('future')

    assert_equal 'past', @user.send(:has_meetings?)
    assert_equal 'future', @user.send(:has_meetings?, User::ConnectionStatus::TimeLine::ONGOING)
  end

  def test_has_ongoing_groups
    assert @user.groups.active.any?
    assert @user.send(:has_ongoing_groups?)

    assert_false users(:f_admin).groups.active.any?
    assert_false users(:f_admin).send(:has_ongoing_groups?)
  end

  def test_has_completed_groups
    assert users(:student_4).groups.closed.any?
    assert users(:student_4).send(:has_completed_groups?)

    assert_false users(:f_admin).groups.active.any?
    assert_false users(:f_admin).send(:has_completed_groups?)
  end

  def test_has_upcoming_meetings
    # TODO test for truthy after fixtures are added
    assert_false users(:f_admin).member.meetings.of_program(users(:f_admin).program).non_group_meetings.accepted_meetings.upcoming.any?
    assert_false users(:f_admin).send(:has_upcoming_meetings?)
  end

  def test_has_completed_meetings
    # TODO test for truthy after fixtures are added
    assert_false users(:f_admin).member.meetings.of_program(users(:f_admin).program).non_group_meetings.accepted_meetings.past.any?
    assert_false users(:f_admin).send(:has_completed_meetings?)
  end
end
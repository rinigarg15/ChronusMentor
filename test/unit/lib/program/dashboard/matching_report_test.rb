require_relative './../../../../test_helper'

class Program::Dashboard::MatchingReportTest < ActiveSupport::TestCase
  # Testing methods on program class directly
  def test_get_matching_reports_to_display
    program = programs(:albers)
    assert_equal [DashboardReportSubSection::Type::Matching::CONNECTED_USERS, DashboardReportSubSection::Type::Matching::MENTOR_REQUESTS], program.get_matching_reports_to_display

    program.stubs(:is_report_enabled?).with(DashboardReportSubSection::Type::Matching::CONNECTED_USERS).returns(false)
    program.stubs(:is_report_enabled?).with(DashboardReportSubSection::Type::Matching::MENTOR_REQUESTS).returns(true)
    program.stubs(:is_report_enabled?).with(DashboardReportSubSection::Type::Matching::CONNECTED_FLASH_USERS).returns(true)
    program.stubs(:is_report_enabled?).with(DashboardReportSubSection::Type::Matching::MEETING_REQUESTS).returns(true)
    program.stubs(:is_report_enabled?).with(DashboardReportSubSection::Type::Matching::PROJECT_REQUESTS).returns(true)
    assert_equal [DashboardReportSubSection::Type::Matching::MENTOR_REQUESTS, DashboardReportSubSection::Type::Matching::CONNECTED_FLASH_USERS, DashboardReportSubSection::Type::Matching::PROJECT_REQUESTS, DashboardReportSubSection::Type::Matching::MEETING_REQUESTS], program.get_matching_reports_to_display
  end

  def test_get_connected_ongoing_users_data
    program = programs(:albers)

    connected_users_hash = {total: 'total connected'}
    user_status_hash = {total: 'total'}
    program.roles.for_mentoring.each do |role|
      connected_users_hash[role.name] = "connected #{role.name}"
      user_status_hash[role.name] = "total #{role.name}"
    end
    program.stubs(:user_status).returns(user_status_hash)
    program.stubs(:get_sub_setting).with(DashboardReportSubSection::Type::Matching::CONNECTED_USERS).returns("sub setting")
    program.stubs(:get_groups_scope_for_sub_setting).with("sub setting").returns("something")
    program.stubs(:get_users_connected_via_groups_status).with("something").returns(connected_users_hash)
    program.stubs(:rounded_percentage).with('total connected', 'total').returns('total')
    program.stubs(:rounded_percentage).with("connected mentor", 'total mentor').returns('mentor')
    program.stubs(:rounded_percentage).with("connected student", 'total student').returns('student')

    result = program.send(:get_connected_ongoing_users_data)
    assert_equal "total", result[:total]
    assert_equal "mentor", result["mentor"]
    assert_equal "student", result["student"]
  end

  def test_get_connected_users_data
    program = programs(:albers)
    connected_users_hash = {total: 'total connected'}
    user_status_hash = {total: 'total'}
    program.roles.for_mentoring.each do |role|
      connected_users_hash[role.name] = "connected #{role.name}"
      user_status_hash[role.name] = "total #{role.name}"
    end
    program.stubs(:rounded_percentage).with('total connected', 'total').returns('total')
    program.stubs(:rounded_percentage).with("connected mentor", 'total mentor').returns('mentor')
    program.stubs(:rounded_percentage).with("connected student", 'total student').returns('student')
    result = program.send(:get_connected_users_data, user_status_hash, connected_users_hash)
    assert_equal "total", result[:total]
    assert_equal "mentor", result["mentor"]
    assert_equal "student", result["student"]
  end

  def test_get_connected_flash_users_data
    program = programs(:albers)
    program.stubs(:user_status).returns("user_status")
    program.stubs(:get_users_connected_via_meeting_status).returns("get_users_connected_via_meeting_status")
    program.stubs(:get_connected_users_data).with("user_status", "get_users_connected_via_meeting_status").returns("something")
    assert_equal "something", program.send(:get_connected_flash_users_data)
  end

  def test_get_groups_scope_for_sub_setting
    program = programs(:albers)
    assert_equal :active, program.send(:get_groups_scope_for_sub_setting, DashboardReportSubSection::Type::Matching::ConnectedUsers::ONLY_ONGOING)
    assert_equal :active_or_closed, program.send(:get_groups_scope_for_sub_setting, DashboardReportSubSection::Type::Matching::ConnectedUsers::ONGOING_AND_CLOSED)
    assert_equal :active_or_drafted, program.send(:get_groups_scope_for_sub_setting, DashboardReportSubSection::Type::Matching::ConnectedUsers::ONGOING_AND_DRAFTED)
  end

  def test_get_mentor_requests_data
    program = programs(:albers)
    assert_equal_hash({sent: program.mentor_requests.count, accepted: program.mentor_requests.accepted.count, rejected: program.mentor_requests.with_status_in([MentorRequest::Status::REJECTED, MentorRequest::Status::WITHDRAWN, MentorRequest::Status::CLOSED]).count, report_type: DashboardReportSubSection::Type::Matching::MENTOR_REQUESTS}, program.send(:get_mentor_requests_data))
  end

  def test_get_project_requests_data
    program = programs(:pbe)
    assert_equal_hash({sent: 10, accepted: 0, rejected: 5, report_type: DashboardReportSubSection::Type::Matching::PROJECT_REQUESTS}, program.send(:get_project_requests_data))
  end

  def test_get_meeting_requests_data
    program = programs(:albers)
    assert_equal_hash({sent: 8, accepted: 4, rejected: 2, report_type: DashboardReportSubSection::Type::Matching::MEETING_REQUESTS}, program.send(:get_meeting_requests_data))
  end
end
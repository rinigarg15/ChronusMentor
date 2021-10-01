require_relative './../../../../test_helper'

class Program::Dashboard::CommunityReportTest < ActiveSupport::TestCase
  def test_community_announcement_event_report_enabled
    program = programs(:albers)
    assert program.community_announcement_event_report_enabled?

    program.stubs(:is_report_enabled?).with(DashboardReportSubSection::Type::CommunityAnnouncementsEvents::ANNOUNCEMENTS_AND_EVENTS).returns(false)
    assert_false program.community_announcement_event_report_enabled?
  end

  def test_get_announcements_and_events_data
    program = programs(:albers)
    assert_equal_hash({announcements: [{display_expires_on: false}, {:announcement=> announcements(:big_announcement), :for=>"Mentors and Students"}, {:announcement=>announcements(:assemble), :for=>"Mentors and Students"}], events: [{:program_event=>program_events(:birthday_party), :attending=>0}]}, program.send(:get_announcements_and_events_data))
  end

  def test_get_active_announcements_data
    program = programs(:albers)
    assert_equal 2, program.announcements.published.not_expired.count
    assert_equal [{display_expires_on: false}, {:announcement=> announcements(:big_announcement), :for=>"Mentors and Students"}, {:announcement=>announcements(:assemble), :for=>"Mentors and Students"}], program.send(:get_active_announcements_data)

    program.announcements.destroy_all
    assert_equal 0, program.announcements.published.not_expired.count
    assert_equal [], program.send(:get_active_announcements_data)
  end

  def test_get_upcoming_events_data
    program = programs(:albers)
    program.stubs(:program_events_enabled?).returns(false)
    assert_equal [], program.send(:get_upcoming_events_data)
    program_event = program_events(:birthday_party)

    assert_equal 1, program.program_events.published.upcoming.count
    program.stubs(:program_events_enabled?).returns(true)
    assert_equal [{:program_event=>program_event, :attending=>0}], program.send(:get_upcoming_events_data)

    program_event.event_invites.create!(:user => users(:f_mentor), :status => EventInvite::Status::YES)
    assert_equal [{:program_event=>program_events(:birthday_party), :attending=>1}], program.send(:get_upcoming_events_data)
  end
end
require_relative './../../../../test_helper'

class Program::Dashboard::ReportSubSectionSettingsTest < ActiveSupport::TestCase
  # Testing methods on program class directly

  def test_dashboard_report_objects
    program = Program.first
    assert_equal [], program.send(:dashboard_report_objects)

    DashboardReportSubSection.create!(program_id: program.id, report_type: DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE, enabled: true)
    assert_equal [], program.send(:dashboard_report_objects)
    assert_equal [DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE], Program.first.send(:dashboard_report_objects).collect(&:report_type)
  end

  def test_dashboard_report_object
    program = programs(:albers)
    obj = program.dashboard_reports.create!(report_type: DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE, enabled: true)

    assert_equal obj, program.send(:dashboard_report_object, DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE)
    assert_nil program.send(:dashboard_report_object, DashboardReportSubSection::Type::Enrollment::APPLICATIONS_STATUS)
  end

  def test_has_dashboard_report_object
    p = programs(:albers)
    p.stubs(:dashboard_report_object).with('something').returns('something else')
    assert p.send(:has_dashboard_report_object?, 'something')
    p.stubs(:dashboard_report_object).with('nothing').returns(nil)
    assert_false p.send(:has_dashboard_report_object?, 'nothing')
  end

  def test_is_enrollment_report_available
    p = programs(:albers)
    assert p.is_report_available? DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE
    assert p.is_report_available? DashboardReportSubSection::Type::Enrollment::APPLICATIONS_STATUS
    assert p.is_report_available? DashboardReportSubSection::Type::Enrollment::PUBLISHED_PROFILES

    p.stubs(:allow_join_now?).returns(false)
    assert_false p.is_report_available? DashboardReportSubSection::Type::Enrollment::APPLICATIONS_STATUS
  end

  def test_is_community_report_available
    p = programs(:albers)
    assert p.is_report_available? DashboardReportSubSection::Type::CommunityAnnouncementsEvents::ANNOUNCEMENTS_AND_EVENTS
    assert p.is_report_available? DashboardReportSubSection::Type::CommunityResources::RESOURCES
    assert p.is_report_available? DashboardReportSubSection::Type::CommunityForumsArticles::FORUMS_AND_ARTICLES

    p.stubs(:resources_enabled?).returns(false)
    assert_false p.is_report_available? DashboardReportSubSection::Type::CommunityResources::RESOURCES
  end

  def test_is_groups_report_available
    p = programs(:albers)
    assert p.is_report_available? DashboardReportSubSection::Type::Engagements::ENGAGEMENTS_HEALTH
    assert p.is_report_available? DashboardReportSubSection::Type::Engagements::ENGAGEMENTS_SURVEY_RESPONSES

    p.stubs(:ongoing_mentoring_enabled?).returns(false)
    assert_false p.is_report_available? DashboardReportSubSection::Type::Engagements::ENGAGEMENTS_HEALTH
    assert_false p.is_report_available? DashboardReportSubSection::Type::Engagements::ENGAGEMENTS_SURVEY_RESPONSES
  end

  def test_is_groups_activity_report_available
    p = programs(:albers)
    assert p.is_report_available? DashboardReportSubSection::Type::GroupsActivity::GROUPS_ACTIVITY

    p.stubs(:ongoing_mentoring_enabled?).returns(false)
    assert_false p.is_report_available? DashboardReportSubSection::Type::GroupsActivity::GROUPS_ACTIVITY
  end

  def test_is_report_enabled
    p = programs(:albers)
    p.stubs(:is_report_available?).with(DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE).returns(false)

    assert_false p.is_report_enabled? DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE

    p.stubs(:is_report_available?).with(DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE).returns(true)
    obj = p.dashboard_reports.create!(report_type: DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE, enabled: false)

    assert_false p.is_report_enabled? DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE
    p.stubs(:has_dashboard_report_object?).with(DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE).returns(false)
    assert p.is_report_enabled? DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE

    p.stubs(:has_dashboard_report_object?).with(DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE).returns(true)
    obj.enabled = true
    assert p.is_report_enabled? DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE
  end

  def test_get_reports_available_for_section
    p = programs(:albers)

    p.stubs(:is_report_available?).returns(false).times(3)
    assert_equal [], p.get_reports_available_for_section(DashboardReportSubSection::Tile::ENROLLMENT)

    p.stubs(:is_report_available?).with(DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE).returns(true)
    p.stubs(:is_report_available?).with(DashboardReportSubSection::Type::Enrollment::APPLICATIONS_STATUS).returns(false)
    p.stubs(:is_report_available?).with(DashboardReportSubSection::Type::Enrollment::PUBLISHED_PROFILES).returns(true)

    assert_equal [DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE, DashboardReportSubSection::Type::Enrollment::PUBLISHED_PROFILES], p.get_reports_available_for_section(DashboardReportSubSection::Tile::ENROLLMENT)
  end

  def test_get_groups_reports_available_for_section
    p = programs(:albers)

    p.stubs(:is_report_available?).returns(false).times(2)
    assert_equal [], p.get_reports_available_for_section(DashboardReportSubSection::Tile::ENGAGEMENTS)

    p.stubs(:is_report_available?).with(DashboardReportSubSection::Type::Engagements::ENGAGEMENTS_HEALTH).returns(true)
    p.stubs(:is_report_available?).with(DashboardReportSubSection::Type::Engagements::ENGAGEMENTS_SURVEY_RESPONSES).returns(false)

    assert_equal [DashboardReportSubSection::Type::Engagements::ENGAGEMENTS_HEALTH], p.get_reports_available_for_section(DashboardReportSubSection::Tile::ENGAGEMENTS )
  end

  def test_enable_dashboard_report
    p = programs(:albers)
    assert_difference "DashboardReportSubSection.count", 1 do
      p.enable_dashboard_report!(DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE)
    end
    assert p.dashboard_reports.last.enabled

    assert_no_difference "DashboardReportSubSection.count" do
      p.enable_dashboard_report!(DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE, false)
    end
    assert_false p.dashboard_reports.last.enabled

    assert_no_difference "DashboardReportSubSection.count" do
      p.enable_dashboard_report!(DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE, true, "apple")
    end
    assert p.dashboard_reports.last.enabled
    assert_equal "apple", p.dashboard_reports.last.setting
  end

  def test_get_sub_setting
    program = programs(:albers)
    report_type = DashboardReportSubSection::Type::Matching::CONNECTED_USERS
    assert_equal DashboardReportSubSection::Type::Matching::ConnectedUsers::ONLY_ONGOING, program.get_sub_setting(report_type)
    dr = DashboardReportSubSection.new
    dr.setting = "something"
    program.stubs(:has_dashboard_report_object?).with(report_type).returns(true)
    program.stubs(:dashboard_report_object).with(report_type).returns(dr)
    assert_equal "something", program.get_sub_setting(report_type)
  end

  def test_matching_report_settings
    p = programs(:albers)
    MentorRequestView.stubs(:is_accessible?).with(p).returns(false)
    assert_false p.is_report_enabled? DashboardReportSubSection::Type::Matching::MENTOR_REQUESTS

   p.stubs(:project_based?).returns(true)
    assert p.is_report_enabled? DashboardReportSubSection::Type::Matching::PROJECT_REQUESTS

    p.stubs(:only_one_time_mentoring_enabled?).returns(true)
    assert p.is_report_enabled? DashboardReportSubSection::Type::Matching::MEETING_REQUESTS
  end
end
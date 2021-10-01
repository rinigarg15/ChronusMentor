require_relative "./../test_helper.rb"

class DashboardReportSubSectionTest < ActiveSupport::TestCase
  def test_belongs_to_program
    program = programs(:albers)
    dr = DashboardReportSubSection.create!(program: program, report_type: DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE)
    assert_equal program, dr.program
  end

  def test_validates_program
    dr = DashboardReportSubSection.new(report_type: DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE)
    assert_false dr.save
    assert_equal ["can't be blank"], dr.errors[:program]
  end

  def test_validates_report_type
    program = programs(:albers)
    dr = DashboardReportSubSection.new(program: program)
    assert_false dr.save
    assert_equal ["can't be blank", "is not included in the list"], dr.errors[:report_type]

    dr.report_type = "blah"
    assert_false dr.save
    assert_equal ["is not included in the list"], dr.errors[:report_type]

    dr.report_type = DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE
    assert dr.save

    dr2 = DashboardReportSubSection.new(program: program, report_type: DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE)
    assert_false dr2.save
    assert_equal ["has already been taken"], dr2.errors[:report_type]

    dr2.program = programs(:pbe)
    assert dr.save
  end

  def test_all_report_types
    assert_equal [DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE, DashboardReportSubSection::Type::Enrollment::APPLICATIONS_STATUS, DashboardReportSubSection::Type::Enrollment::PUBLISHED_PROFILES, DashboardReportSubSection::Type::CommunityAnnouncementsEvents::ANNOUNCEMENTS_AND_EVENTS, DashboardReportSubSection::Type::CommunityResources::RESOURCES, DashboardReportSubSection::Type::CommunityForumsArticles::FORUMS_AND_ARTICLES, DashboardReportSubSection::Type::Engagements::ENGAGEMENTS_HEALTH, DashboardReportSubSection::Type::Engagements::ENGAGEMENTS_SURVEY_RESPONSES, DashboardReportSubSection::Type::GroupsActivity::GROUPS_ACTIVITY, DashboardReportSubSection::Type::GroupsActivity::MEETING_ACTIVITY, DashboardReportSubSection::Type::Matching::CONNECTED_USERS, DashboardReportSubSection::Type::Matching::MENTOR_REQUESTS, DashboardReportSubSection::Type::Matching::CONNECTED_FLASH_USERS, DashboardReportSubSection::Type::Matching::PROJECT_REQUESTS, DashboardReportSubSection::Type::Matching::MEETING_REQUESTS], DashboardReportSubSection::Type.all
  end
end
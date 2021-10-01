require_relative './../../../../test_helper'

class Program::Dashboard::EnrollmentReportTest < ActiveSupport::TestCase
  # Testing methods on program class directly
  def test_get_enrollment_reports_to_display
    program = programs(:albers)
    assert_equal [DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE, DashboardReportSubSection::Type::Enrollment::APPLICATIONS_STATUS, DashboardReportSubSection::Type::Enrollment::PUBLISHED_PROFILES], program.get_enrollment_reports_to_display

    program.stubs(:is_report_enabled?).with(DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE).returns(false)
    program.stubs(:is_report_enabled?).with(DashboardReportSubSection::Type::Enrollment::APPLICATIONS_STATUS).returns(true)
    program.stubs(:is_report_enabled?).with(DashboardReportSubSection::Type::Enrollment::PUBLISHED_PROFILES).returns(false)
    assert_equal [DashboardReportSubSection::Type::Enrollment::APPLICATIONS_STATUS], program.get_enrollment_reports_to_display
  end

  def test_get_invitation_acceptance_rate_data
    program = programs(:albers)
    assert_equal [], program.program_invitations.accepted
    GenericKendoPresenterConfigs::ProgramInvitationGrid.stubs(:get_invitations).with(program, true).returns(program.program_invitations.accepted)
    program.stubs(:invitable_roles_by_admins).returns([])

    assert_equal_hash({percentage: 0, report_type: DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE, roles: []}, program.send(:get_invitation_acceptance_rate_data))

    GenericKendoPresenterConfigs::ProgramInvitationGrid.stubs(:get_invitations).with(program, true).returns(program.program_invitations)
    assert_equal_hash({percentage: 0, report_type: DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE, roles: []}, program.send(:get_invitation_acceptance_rate_data))

    pi = program.program_invitations.first
    assert_equal [RoleConstants::MENTOR_NAME], pi.role_names
    mentor_role = program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    program.stubs(:invitable_roles_by_admins).returns([mentor_role])
    data = {percentage: 0, report_type: DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE, roles: program.invitable_roles_by_admins}
    data[RoleConstants::MENTOR_NAME] = {total: 1, accepted_or_published: 0}
    assert_equal_hash(data, program.send(:get_invitation_acceptance_rate_data))

    pi.update_attribute(:use_count, 1)
    GenericKendoPresenterConfigs::ProgramInvitationGrid.stubs(:get_invitations).with(program, true).returns(program.reload.program_invitations)
    data2 = {percentage: 50, report_type: DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE, roles: program.invitable_roles_by_admins}
    data2[RoleConstants::MENTOR_NAME] = {total: 1, accepted_or_published: 1}
    assert_equal_hash(data2, program.send(:get_invitation_acceptance_rate_data))
  end

  def test_get_applications_status_data
    program = programs(:albers)
    assert_equal_hash({received: program.membership_requests.not_joined_directly.count, accepted: program.membership_requests.not_joined_directly.accepted.count, rejected: program.membership_requests.not_joined_directly.rejected.count}, program.send(:get_applications_status_data))
  end

  def test_get_published_profiles_data
    program = programs(:albers)
    roles = program.roles_without_admin_role
    active_role_users = program.users.active.includes(:roles).select{|user| (user.roles.collect(&:name) & roles.collect(&:name)).any?}
    active_pending_role_users = program.users.active_or_pending.includes(:roles).select{|user| (user.roles.collect(&:name) & roles.collect(&:name)).any?}
    assert_equal 43, active_role_users.size
    assert_equal 44, active_pending_role_users.size
    program.stubs(:rounded_percentage).with(43, 44).returns(9999)
    data = program.send(:get_published_profiles_data)
    assert_equal 9999, data[:percentage]
    assert_equal roles, data[:roles]
    assert_equal DashboardReportSubSection::Type::Enrollment::PUBLISHED_PROFILES, data[:report_type]
    assert_equal_hash(data["mentor"], {total: 23, accepted_or_published: 22})
    assert_equal_hash(data["student"], {total: 21, accepted_or_published: 21})
    assert_equal_hash(data["user"], {total: 1, accepted_or_published: 1})
  end
end
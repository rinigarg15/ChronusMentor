module Program::Dashboard::EnrollmentReport
  extend ActiveSupport::Concern

  def get_enrollment_reports_to_display
    DashboardReportSubSection::Type::Enrollment.all.select{|report_type| self.is_report_enabled?(report_type)}
  end

  private

  def get_invitation_acceptance_rate_data
    roles = self.invitable_roles_by_admins
    data = {roles: roles, report_type: DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE}
    program_invitations = GenericKendoPresenterConfigs::ProgramInvitationGrid.get_invitations(self, true)
    total_program_invitations_sent = program_invitations.count
    data[:percentage] = rounded_percentage(program_invitations.accepted.count, total_program_invitations_sent)
    roles.each do |role|
      program_invitations_for_role = program_invitations.with_fixed_roles.for_roles([role.name])
      data[role.name] = {total: program_invitations_for_role.count, accepted_or_published: program_invitations_for_role.accepted.count}
    end
    return data
  end

  def get_applications_status_data
    membership_requests = self.membership_requests.not_joined_directly
    return {received: membership_requests.count, accepted: membership_requests.accepted.count, rejected: membership_requests.rejected.count}
  end

  def get_published_profiles_data
    roles = self.roles_without_admin_role
    total_active_count = User.where("roles.id IN (?)", roles.collect(&:id)).active.joins(:roles).distinct.count
    total_count = User.where("roles.id IN (?)", roles.collect(&:id)).active_or_pending.joins(:roles).distinct.count
    data = {percentage: rounded_percentage(total_active_count, total_count), roles: roles, report_type: DashboardReportSubSection::Type::Enrollment::PUBLISHED_PROFILES}
    roles.each do |role|
      data[role.name] = {total: self.send("#{role.name}_users").active_or_pending.distinct.count, accepted_or_published: self.send("#{role.name}_users").active.distinct.count}
    end
    return data
  end
end
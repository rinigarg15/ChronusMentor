class OrganizationDashboardService
  def initialize(organization)
    @organization = organization
  end

  def get_item_counts_for_admin
    program_ids = @organization.programs.pluck(:id)

    mentoring_program_ids = @organization.programs.collect{|p| p.id if p.engagement_enabled?}.compact

    items_count = {}
    items_count[:mentoring_connections] = get_mentoring_connection_items_count_for_admin(mentoring_program_ids)
    items_count[:users_per_role] = get_non_administrative_role_users_count(program_ids)
    items_count[:unread_admin_messages] = AdminMessages::Receiver.joins(:message).where("messages.program_id in (?)", program_ids).received.unread.group("messages.program_id").count
    items_count[:unresolved_flagged_content] = get_unresolved_flags_count(program_ids)
    items_count[:unpublished_posts] = Post.joins(:topic => :forum).where("forums.program_id in (?)", program_ids).unpublished.group("forums.program_id").count
    items_count[:pending_membership_requests] = MembershipRequest.not_joined_directly.pending.where(:program_id => program_ids).group(:program_id).count
    items_count[:pending_project_requests] = ProjectRequest.active.where(:program_id => mentoring_program_ids).group(:program_id).count
    items_count[:proposed_groups] = Group.proposed.where(:program_id => mentoring_program_ids).group(:program_id).count
    return items_count
  end

  private

  def get_mentoring_connection_items_count_for_admin(program_ids)
    mentoring_connections_count = {}
    mentoring_connections_count[:all] = Group.active.where(:program_id => program_ids).group(:program_id).count
    mentoring_connections_count[:overdue] = Group.active.with_overdue_tasks.where(:program_id => program_ids).group(:program_id).count
    mentoring_connections_count[:ontrack] = mentoring_connections_count[:all].merge(mentoring_connections_count[:overdue]){|program_id, all_count, overdue_count| all_count - overdue_count}
    return mentoring_connections_count
  end

  def get_non_administrative_role_users_count(program_ids)
    User.joins(:roles).select("count(*) as users_count, roles.program_id, roles.id as role_id").where(:program_id => program_ids).where("roles.administrative = false").group("roles.id").group_by(&:program_id)
  end

  def get_unresolved_flags_count(program_ids)
    unresolved_flagged_content = {}
    Program.where(id: program_ids).each {|program| unresolved_flagged_content[program.id] = program.unresolved_flagged_content_count }
    unresolved_flagged_content
  end
end
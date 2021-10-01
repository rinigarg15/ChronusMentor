class MembershipObserver < ActiveRecord::Observer
  observe Connection::Membership

  def after_create(membership)
    date_id = Time.now.utc.to_i/1.day.to_i
    group = membership.group
    user = membership.user
    if group.pending_or_active? && user.profile_pending?
      user.update_attribute(:state, User::Status::ACTIVE)
    end
    DelayedEsDocument.delayed_bulk_update_es_documents(Member, [user.member_id]) if group.active?
    membership.track_connection_membership_status_change(date_id, membership.group.status, membership.user.state, {from_state: nil, to_state: Connection::Membership::Status::ACTIVE})
    membership.create_user_state_change_on_connection_membership_change(date_id, user_group_membership_info_hash_for_state_changes(membership, nil, Connection::Membership::Status::ACTIVE))
    ProjectRequest.delay.close_pending_requests_if_required({ membership.user_id => membership.role_id }) if group.project_based? && !group.drafted?
  end

  def before_destroy(membership)
    date_id = Time.now.utc.to_i/1.day.to_i
    membership.create_user_state_change_on_connection_membership_change(date_id, user_group_membership_info_hash_for_state_changes(membership, Connection::Membership::Status::ACTIVE, nil)) unless membership._marked_for_destroy_
    membership._marked_for_destroy_ = true
  end

  def after_destroy(membership)
    date_id = Time.now.utc.to_i/1.day.to_i
    membership.track_connection_membership_status_change(date_id, membership.group.status, membership.user.state, {from_state: Connection::Membership::Status::ACTIVE, to_state: nil}) unless membership.group._marked_for_destroy_
    DelayedEsDocument.delayed_bulk_update_es_documents(Member, [membership.user.member_id])
    return if membership.skip_destroy_callback
    user = membership.user
    group = membership.group
    if membership.leave_connection_callback
      members_to_send = group.pending? ? group.owners : group.members
      members_to_send.each do |member|
        membership_to_send = group.membership_of(member)
        membership_to_send.send_email(user, RecentActivityConstants::Type::GROUP_MEMBER_LEAVING, nil, membership.leaving_reason)
      end
      ra_for_leave_connection(group, membership)
    end

    # Note that destroying a group will trigger a destroy on its memberships.
    # So checking for group's existence is needed to break the recursion
    if !membership.leave_connection_callback && group && !group._marked_for_destroy_ && (group.mentor_memberships.empty? || group.student_memberships.empty?)
      group._marked_for_destroy_ = true
      group.destroy
    end
  end

  def ra_for_leave_connection(group, membership)
    RecentActivity.create!(
    :programs => [group.program],
    :member => membership.user.member,
    :ref_obj => group,
    :action_type => RecentActivityConstants::Type::GROUP_MEMBER_LEAVING,
    :target => RecentActivityConstants::Target::ALL)
  end

  def user_group_membership_info_hash_for_state_changes(membership, membership_from_state, membership_to_state)
    user = membership.user
    return {
      user: {from_state: user.state, to_state: user.state, role_ids: user.role_ids, role_ids_in_active_groups: user.role_ids_in_active_groups},
      group: {state: membership.group.status},
      connection_membership: {from_state: membership_from_state, to_state: membership_to_state}
    }
  end
end
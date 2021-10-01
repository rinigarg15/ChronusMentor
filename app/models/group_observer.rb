class GroupObserver < ActiveRecord::Observer
  def after_update(group)
    program = group.program
    # Elasticsearch delta indexing should happen in es_reindex method so that indexing for update_column/update_all or delete/delete_all will be taken care.
    Group.es_reindex(group, reindex_project_request: true) if group.saved_change_to_name?
    Group.es_reindex(group, reindex_user: true) if group.saved_change_to_status? || group.saved_change_to_closed_at?

    track_group_status_change(group, Time.now.utc, group.status_before_last_save)
    if !group.skip_observer && group.pending?
      actor = group.actor
      if group.status_before_last_save == Group::Status::DRAFTED
        GroupObserver.delay(:queue => DjQueues::HIGH_PRIORITY).send_pending_state_emails(group.id, group.message, JobLog.generate_uuid, actor)
        ProjectRequest.delay.close_pending_requests_if_required(group.get_user_id_role_id_hash)
      elsif group.old_members_by_role
        GroupObserver.delay(:queue => DjQueues::HIGH_PRIORITY).handle_member_updates(group.id, group.message, group.old_members_by_role, JobLog.generate_uuid, actor)
      end
    end

    pending_to_withdrawn = group.status_before_last_save == Group::Status::PENDING && group.status == Group::Status::WITHDRAWN
    active_to_closed = group.status_before_last_save.in?(Group::Status::ACTIVE_CRITERIA) && group.status == Group::Status::CLOSED

    if pending_to_withdrawn || active_to_closed
      ProjectRequest.mark_rejected(group.active_project_requests.pluck(:id), group.closed_by, group.termination_reason)
    end

    return unless group.published?
    group.update_attribute_skipping_observer(:published_at, Time.now) if group.published_at.nil?
    return if group.skip_observer

    if group.status == Group::Status::CLOSED && group.status_before_last_save != Group::Status::CLOSED
      GroupObserver.create_ra(group, RecentActivityConstants::Type::GROUP_TERMINATING, RecentActivityConstants::Target::ALL) if group.closed_by_leaving?
      Group.delay.remove_upcoming_meetings_of_group(group.id)
      send_group_termination_mails(group)
      Matching.perform_users_delta_index_and_refresh_later(group.member_ids, program) if program.prevent_past_mentor_matching
    elsif group.status != Group::Status::CLOSED && group.status_before_last_save == Group::Status::CLOSED
      GroupObserver.create_ra(group, RecentActivityConstants::Type::GROUP_REACTIVATION, RecentActivityConstants::Target::ALL)
      group.students.each(&:withdraw_active_requests!)
      Group.delay.send_group_reactivation_mails(group.id, group.actor.id, group.member_ids, group.message, JobLog.generate_uuid)
      Matching.perform_users_delta_index_and_refresh_later(group.member_ids, program) if program.prevent_past_mentor_matching
    elsif group.saved_change_to_expiry_time?
      GroupObserver.create_ra(group, RecentActivityConstants::Type::GROUP_CHANGE_EXPIRY_DATE, RecentActivityConstants::Target::ALL)
      Group.delay.send_group_change_expiry_date_mails(group.id, group.member_ids)
    end

    if program.matching_by_mentee_and_admin? && group.all_old_students && (group.all_old_students != group.students)
      group.students.each(&:withdraw_active_requests!)
    end

    if group.offered_to
      if group.offered_to != group.actor
        group.create_ra_and_notify_mentee_about_mentoring_offer
        group.notify_group_members_about_member_update
      end
    elsif group.old_members_by_role
      # Handle member addition to the group
      # Mail should be sent if the admin has directly added a user to the group or
      # when a mentor accepts a mentor request sent by a student directly
      old_members_by_role = group.old_members_by_role
      actor = group.actor
      group.students.each(&:withdraw_active_requests!)
      if (group.members_by_role != old_members_by_role) && (group.assigned_from_match || !(program.matching_by_mentee_alone? && actor.nil?))
        Group.delay.create_ra_and_notify_members_about_member_update(group.id, old_members_by_role, JobLog.generate_uuid, actor, message: group.message)
      end
    end
  end

  def after_commit(group)
    group.touch_mentors
  end

  def after_create(group)
    track_group_status_change(group, Time.now.utc, nil)
    return if group.skip_observer

    program = group.program
    if program.mentoring_connections_v2_enabled? && group.mentoring_model.blank?
      group.update_attribute_skipping_observer(:mentoring_model_id, program.default_mentoring_model.id)
    end
    after_publish(group) if group.published?
    group.students.each(&:withdraw_active_requests!)
  end

  def after_publish(group)
    return if group.skip_observer
    group.update_attribute_skipping_observer(:published_at, group.created_at) if group.published_at.nil?
    group.students.each(&:withdraw_active_requests!)
    program = group.program

    program.mentor_requests.involving(group.member_ids).active.update_all(status:AbstractRequest::Status::WITHDRAWN)

    # TODO: Move this to groups controller
    if program.mentoring_connections_v2_enabled?
      mentoring_model = group.mentoring_model || program.default_mentoring_model
      Group::MentoringModelCloner.new(group, program, mentoring_model).copy_mentoring_model_objects
    end
    # Send email when a mentor adds a mentee
    # Do not send if an email when the mentee accepts a mentoring offer, in which case the actor of the group is the mentee
    if group.offered_to
      group.create_ra_and_notify_mentee_about_mentoring_offer if group.offered_to != group.actor
    else
      # Deliver group created notification to student and mentor
      if group.project_based?
        GroupObserver.delay.send_group_published_notification(group.id, group.message, JobLog.generate_uuid, group.actor)
        Push::Base.queued_notify(PushNotification::Type::PBE_PUBLISHED, group)
      else
        send_group_creation_mails_and_ra(group)
      end
    end
    GroupObserver.delay(:queue => DjQueues::HIGH_PRIORITY).send_facilitation_messages_on_group_publish(group.id)
  end

  def before_validation(group)
    return if group.skip_observer
    group.pending_at = Time.now.utc if group.pending? && group.pending_at.blank?

    return unless group.new_record?
    if group.name.blank?
      members = group.mentors + group.students
      group.name = members.collect(&:last_name).to_sentence(last_word_connector: LAST_WORD_CONNECTOR, two_words_connector: TWO_WORDS_CONNECTOR)
    end

    return unless group.published?
    group.expiry_time = group.get_group_expiry_time if group.expiry_time.blank?
    return nil
  end

  def self.send_facilitation_messages_on_group_publish(group_id)
    group = Group.find_by(id: group_id)
    return if group.nil?

    program = group.program
    if program.mentoring_connections_v2_enabled? && group.mentoring_model.can_manage_mm_messages?(program.get_roles(RoleConstants::ADMIN_NAME)) && group.active?
      immediate_facilitation_templates = group.mentoring_model.mentoring_model_facilitation_templates.send_immediately
      admin_member = group.program.admin_users.first.member
      immediate_facilitation_templates.each do |facilitation_template|
        facilitation_template.deliver_to_eligible_recipients(group, admin_member)
      end
    end
  end

  ## Passing message as an argumrnt as message is an attr_accessor of group :(
  def self.send_pending_state_emails(group_id, message, job_uuid, actor = nil)
    group = Group.find_by(id: group_id)
    return if group.nil?
    group.message = message
    JobLog.compute_with_uuid(group.members, job_uuid, "Sending mails to members in Pending state or Draft -> Pending State") do |user|
      ChronusMailer.pending_group_added_notification(user, group, actor).deliver_now
    end

    if group.members.present?
      GroupObserver.create_ra(group, RecentActivityConstants::Type::GROUP_MEMBER_ADDITION_REMOVAL)
    end
  end

  def self.handle_member_updates(group_id, message, old_members_hash, job_uuid, actor = nil)
    group = Group.find_by(id: group_id)
    return if group.nil?
    group.message = message
    old_users = old_members_hash.values.flatten
    added_users = group.members - old_users
    removed_users = old_users - group.members

    JobLog.compute_with_uuid(added_users, job_uuid, "New members added to group in pending_state") do |user|
      ChronusMailer.pending_group_added_notification(user, group, actor).deliver_now
    end

    JobLog.compute_with_uuid(removed_users, job_uuid, "Members removed from group in pending state") do |user|
      ChronusMailer.pending_group_removed_notification(user, group, actor).deliver_now
    end

    if added_users.present? || removed_users.present?
      GroupObserver.create_ra(group, RecentActivityConstants::Type::GROUP_MEMBER_ADDITION_REMOVAL)
    end
  end

  def self.send_group_published_notification(group_id, message, job_uuid, actor)
    group = Group.find_by(id: group_id)
    return if group.nil?
    group.message = message

    JobLog.compute_with_uuid(group.members, job_uuid, "Group published notification to project based engagements") do |user|
      ChronusMailer.group_published_notification(user, group, actor).deliver_now
    end
  end

  def self.create_ra(group, action_type, target = RecentActivityConstants::Target::NONE)
    RecentActivity.create!(
      :programs => [group.program],
      :member => (group.actor && group.actor.member),
      :ref_obj => group,
      :action_type => action_type,
      :target => target,
      :message => group.message
    )
  end

  def after_save(group)
    group.create_group_forum
  end

  private

  def send_group_creation_mails_and_ra(group)
    program = group.program

    if program.matching_by_mentee_alone? && group.actor.nil?
      # This is handled in mentor_request observer
    else
      mentor_request = program.mentor_requests.find_by(group_id: group.id)
      # The mail is not sent to mentor in case group is created when mentor accepts the forwarded request
      Group.delay(queue: DjQueues::HIGH_PRIORITY).send_group_creation_notification_to_members(group.id, group.get_role_id_user_ids_map, group.message, JobLog.generate_uuid)
      # This connection is created by admin using "create new connection" action
      if group.actor
        GroupObserver.create_ra(group, RecentActivityConstants::Type::GROUP_CREATION)
      end
    end
  end

  def track_group_status_change(group, timestamp, from_state, to_state = nil)
    publish_pending_members(group) if group.saved_change_to_status? && group.pending_or_active?
    Group.es_reindex(group, reindex_member: true) if group.saved_change_to_status? && (group.closed? || group.active?)

    if from_state.nil? || group.saved_change_to_status?
      to_state ||= group.status
      if from_state.nil? || (group.last_status_change != group.saved_changes[:status])
        group_info = { from_state: from_state, to_state: to_state }
        membership_users_info = {}
        memberships = group.memberships.select(:id, :user_id)
        user_ids = memberships.map(&:user_id)
        user_id_connection_memberships_map = Connection::Membership.of_active_criteria_groups.where(user_id: user_ids).select("connection_memberships.user_id AS user_id, GROUP_CONCAT(connection_memberships.role_id) AS role_ids").group("connection_memberships.user_id").index_by(&:user_id)
        user_id_state_roles_map = User.where(id: user_ids).joins(:roles).select("users.id, users.state, GROUP_CONCAT(roles.id) AS role_ids").group("users.id").index_by(&:id)

        memberships.each do |membership|
          user_id = membership.user_id
          role_ids_in_active_groups = user_id_connection_memberships_map.include?(user_id) ? user_id_connection_memberships_map[user_id][:role_ids].split(",").collect(&:to_i) : []
          # Do not change role_ids_in_active_groups to only unique elements as it will affect create_user_state_change_on_group_state_change
          membership_users_info[membership.id] = {
            from_state: user_id_state_roles_map[user_id][:state],
            to_state: user_id_state_roles_map[user_id][:state],
            role_ids: user_id_state_roles_map[user_id][:role_ids].split(",").collect(&:to_i),
            role_ids_in_active_groups: role_ids_in_active_groups
          }
        end
        Group.delay.create_group_and_membership_state_changes(group.id, timestamp, group_info, membership_users_info)
      end
      group.last_status_change = group.saved_changes[:status]
    end
  end

  def publish_pending_members(group)
    pending_users = group.members.pending
    pending_users.each do |user|
      user.update_attribute(:state, User::Status::ACTIVE)
    end
  end

  def send_group_termination_mails(group)
    Group.delay.send_coach_rating_notification(group.id, JobLog.generate_uuid) if group.program.coach_rating_enabled?
    if Group::TerminationMode.termination_modes_for_notification.include?(group.termination_mode)
      Group.delay.send_group_termination_notification(group.id, group.actor.try(:id), JobLog.generate_uuid)
    else
      raise "Termination mode not present"
    end
  end

end
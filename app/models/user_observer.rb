class UserObserver < ActiveRecord::Observer
  # Notify the mentor about his profile being added by the admin.
  class << self
    def notify_new_user(user, creator)
      user.program.notify_added_user(user, creator)
    end
  end

  def before_validation(user)
    return if user.skip_observer
    if user.is_mentor? && user.max_connections_limit.nil?
      user.max_connections_limit = user.program.default_max_connections_limit
    end
  end

  def before_create(user)
    return if user.skip_observer
    user.program_notification_setting = user.program.notification_setting.messages_notification
  end

  def after_create(user)
    user.is_pending_user_creation_case = user.profile_incomplete_roles.any? & !user.skip_observer
    track_user_state_transition(user, user.created_at, from_create: true)
    return if user.skip_observer

    if user.is_mentor_or_student?
      Matching.perform_users_delta_index_and_refresh_later([user.id], user.program)
    end

    # If the user is a mentor/mentee/admin added by the admin, notify
    # the user about the same.
    #
    # Note that we are creating RA at this point. We create
    # RA only for mentors who have their profiles complete.
    if user.created_by
      if user.imported_from_other_program
        if user.program.is_career_developement_program?
          user.program.delay.send_welcome_email(user, user.created_by)
        else
          UserObserver.delay(queue: DjQueues::HIGH_PRIORITY).notify_new_user(user, user.created_by)
        end
      elsif (user.is_admin? && !user.existing_member_as_admin) || !user.is_admin_only?
        UserObserver.delay(queue: DjQueues::HIGH_PRIORITY).notify_new_user(user, user.created_by)
      end
    elsif user.is_admin_only?
      handle_admin_creation(user)
    end

    member = user.member
    if member.dormant?
      member.activate_from_dormant
      member.save!
    end
    if user.program.standalone? && user.is_admin?
      member.promote_as_admin!
    end

    if user.profile_incomplete_roles.any?
      # There are some required question that the user
      # has to answer. Mark the profile as PENDING.
      user.update_attribute(:state, User::Status::PENDING)
    elsif user.is_mentor?
      # Ok, now we know the profile is complete.
      # Create an RA about the new mentor.
      create_new_mentor_recent_activity(user)
    end
    # CM_TODO - should add a delayed job to update the adminviewcounts
  end

  def after_update(user)
    track_user_state_transition(user, user.updated_at)
    return if user.skip_observer
    handle_program_notification_setting_changes(user) if user.saved_change_to_program_notification_setting?
    handle_state_changes(user) if user.saved_change_to_state?
  end

  # We call handle_destroy from target_deletion script to run the callbacks.
  # Please add any new changes in user.handle_destroy to maintain integrity.
  def after_destroy(user)
    user.handle_destroy
  end

  protected

  def handle_admin_creation(user)
    ra = RecentActivity.create(
      :member => user.member,
      :ref_obj => user,
      :action_type => RecentActivityConstants::Type::ADMIN_CREATION,
      :target => RecentActivityConstants::Target::ADMINS
    )
    ra.programs = [user.program]
    ra.save!
  end

  def create_new_mentor_recent_activity(user)
    ra = RecentActivity.create(
      :member => user.member,
      :ref_obj => user,
      :action_type => user.created_by ? RecentActivityConstants::Type::ADMIN_ADD_MENTOR : RecentActivityConstants::Type::MENTOR_JOIN_PROGRAM,
      :target => RecentActivityConstants::Target::ADMINS
    )
    ra.programs = [user.program]
    ra.save!
  end

  def handle_program_notification_setting_changes(user)
    user.pending_notifications.destroy_all if user.program_notification_setting.in?([UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE, UserConstants::DigestV2Setting::ProgramUpdates::NONE]) && user.program_notification_setting_before_last_save.in?([UserConstants::DigestV2Setting::ProgramUpdates::DAILY, UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY])
  end

  def handle_state_changes(user)
    # A unpublished user completed his profile and hence became ACTIVE and visible to others
    create_new_mentor_recent_activity(user) if user.active? && user.is_mentor? && user.state_before_last_save == User::Status::PENDING

    handle_user_activation(user) if user.state_before_last_save == User::Status::SUSPENDED
    handle_user_suspension(user) if user.suspended?
  end

  def handle_user_activation(user)
    UserObserver.recent_activity_for_user_state_change(user, RecentActivityConstants::Type::USER_ACTIVATION, RecentActivityConstants::Target::ADMINS)
  end

  # Create Recent activity to all about the user suspension
  # Send emails
  def handle_user_suspension(user)
    UserObserver.send_later(:recent_activity_for_user_state_change_by_id, user.id, RecentActivityConstants::Type::USER_SUSPENSION, RecentActivityConstants::Target::ADMINS)
    user.recommendation_preferences.destroy_all
    user.close_pending_received_requests_and_offers
  end

  def self.send_user_suspension_emails_by_id(user_id, job_uuid = nil)
    user = User.find_by(id: user_id)
    send_user_suspension_emails(user,job_uuid) if user.present?
  end

  def self.send_user_suspension_emails(user, job_uuid = nil)
    JobLog.compute_with_uuid(user, job_uuid, "Suspension Notification") do |user_object|
      ChronusMailer.user_suspension_notification(user_object, force_send: true).deliver_now
    end

    connected_memberships = Connection::Membership.where(group_id: user.active_group_ids).where.not(user_id: user.id)
    JobLog.compute_with_uuid(connected_memberships, job_uuid, "Suspension notification for connected memberships") do |connected_membership|
      connected_membership.send_email(user, RecentActivityConstants::Type::USER_SUSPENSION)
    end
  end

  def self.recent_activity_for_user_state_change_by_id(user_id, action_type, target)
    user = User.find_by(id: user_id)
    recent_activity_for_user_state_change(user, action_type, target) if user.present?
  end

  # Creates a recent activity for all about state change of a user
  def self.recent_activity_for_user_state_change(user, action_type, target)
    ra = RecentActivity.create!(
      :ref_obj => user,
      :action_type => action_type,
      :target => target,
      :member => (user.state_changer && user.state_changer.member)
    )
    ra.programs = [user.program]
    ra.save!
  end

  private

  def track_user_state_transition(user, timestamp, options = {})
    return if user.created_for_sales_demo
    options.reverse_merge!(from_create: false)
    if (options[:from_create] && !user.is_pending_user_creation_case) || user.saved_change_to_state?
      user_info = {state: {}, role: {}}
      user_info[:state][:from] = options[:from_create] || user.is_pending_user_creation_case ? nil : user.state_before_last_save
      user_info[:state][:to] = user.state
      if user_info[:state][:from].nil? || (user.last_state_change != user.saved_changes[:state])
        user_info[:role][:from] = options[:from_create] || user.is_pending_user_creation_case ? nil : user.role_ids
        user_info[:role][:to] = user.role_ids
        date_id = timestamp.utc.to_i/1.day.to_i
        group_info = User.get_active_roles_and_membership_info([user.id])
        User.delay.create_user_and_membership_state_changes(user.id, date_id, user_info, group_info[user.id])
        user.last_state_change = user.saved_changes[:state]
      end
      user.is_pending_user_creation_case = false
    end
  end
end
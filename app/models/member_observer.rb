class MemberObserver < ActiveRecord::Observer
  #
  # When a non admin becomes an admin, promote all users of the member to admins
  # in programs the member belongs to, and create new admin users in other programs.
  #
  def before_validation(member)
    member.strip_whitespace_from(member.email)
    if member.new_record?
      member.set_calendar_api_key
    end
  end

  def before_update(member)
    if member.admin? && !member.admin_was
      member.activate_from_dormant
      # Add admin role to existing non-admin users.
      member.users.reject(&:is_admin?).each do |user|
        user.add_role(RoleConstants::ADMIN_NAME)
      end
      # Create a new admin user for the programs the member does not
      # belong to.
      (member.organization.programs - member.programs).each do |program|
        build_admin_for_program(member, program)
      end
    end
  end

  def before_save(member)
    if member.crypted_password_changed?
      member.password_updated_at = Time.now.utc
      member.login_identifiers.find_or_initialize_by(auth_config_id: member.organization.chronus_auth(true).id)
    end
  end

  def after_save(member)
    if member.saved_change_to_email?
      MemberObserver.delay.modify_manager_entries(member.id, member.email, member.organization_id)
    end
    if can_reindex_user?(member)
      Member.es_reindex(member, reindex_user: true)
    end
    if is_name_changed?(member)
      Member.es_reindex(member, reindex_member_meeting: true, reindex_mentor_request: true, reindex_project_request: true, reindex_group: true, reindex_article: true, reindex_survey_assessee: true, reindex_qa_question: true, reindex_topic: true)
    end
  end

  def after_update(member)
    return if member.skip_observer
    Member.delay(queue: DjQueues::HIGH_PRIORITY).send_email_change_notification(member.id, member.email, member.email_before_last_save, member.email_changer.id) if member.saved_change_to_email? && member.email_changer
    member.membership_requests.pending.destroy_all if member.saved_change_to_state? && member.suspended?
  end

  def after_destroy(member)
    messages = AbstractMessage.where(sender_id: member.id)
    # Change sent messages behaviour as if some offline user has sent them
    messages.each do |m|
      m.update_attributes!(sender_name: "feature.messaging.content.message_receiver_removed_user".translate, sender_id: nil)
    end
    MemberObserver.delay.modify_manager_entries(member.id, member.email, member.organization_id, true)
    DelayedEsDocument.delayed_bulk_update_es_documents(Meeting, member.meetings.pluck(:id))
    group_ids = Group.where(created_by: member.user_ids).pluck(:id)
    DelayedEsDocument.delayed_bulk_update_es_documents(Group, group_ids)
  end

  def self.modify_manager_entries(member_id, email, organization_id, member_destroyed=false)
    # Nullify all manager_entries which are previously mapped to current user
    Manager.with_managee.in_organization(organization_id).
                  where(:managers => {:member_id => member_id}).readonly(false).each do |manager|
                    manager.update_attributes!(:member_id => nil)
                  end
    # Check for manager_entries which have the new email as manager's email and update them
    Manager.with_managee.in_organization(organization_id).
                  where(:managers => {:email => email}).readonly(false).each do |manager|
                    manager.update_attributes!(:member_id => member_id)
                  end unless member_destroyed
  end

  private

  #
  # Builds a new admin user for the member in the given program.
  #
  def build_admin_for_program(member, program)
    user = member.users.build
    user.program = program
    user.role_names = [RoleConstants::ADMIN_NAME]
    return user
  end

  def can_reindex_user?(member)
    is_name_changed?(member) || member.saved_change_to_email? || member.saved_change_to_state? || member.saved_change_to_terms_and_conditions_accepted? || member.saved_change_to_organization_id?
  end

  def is_name_changed?(member)
    member.saved_change_to_first_name? || member.saved_change_to_last_name?
  end
end
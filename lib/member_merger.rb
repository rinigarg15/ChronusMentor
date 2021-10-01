# BETA: Not a full fledged implementation

class MemberMerger

  attr_accessor :member_to_discard, :member_to_retain, :admin_member,
    :users_of_member_to_discard, :users_of_member_to_retain, :users_of_admin_member

  module WhitelistedAssociations
    def self.all
      [
        :profile_picture, :one_time_flags, :users, :sent_messages, :message_receivers,
        :articles, :activities, :member_meetings, :mentoring_slots, :profile_answers, :answer_choice_versions,
        :membership_requests, :member_language, :three_sixty_survey_assessees, :manager_entries, :mobile_devices,
        :push_notifications, :vulnerable_content_logs, :dismissed_rollout_emails, :content_updated_emails,
        :ratings, :owned_meetings, :mentoring_model_activities, :invited_three_sixty_survey_reviewers, :user_csv_imports,
        :mentoring_model_task_comments, :mentee_meetings, :user_activities, :login_identifiers, :login_tokens
      ]
    end

    def self.uniqueness_scope_map
      {
        profile_answers: :profile_question_id,
        one_time_flags: :message_tag,
        login_identifiers: :auth_config_id
      }
    end
  end

  def initialize(member_to_discard, member_to_retain, admin_member = nil)
    self.member_to_discard = member_to_discard
    self.member_to_retain = member_to_retain
    self.admin_member = admin_member
    self.admin_member ||= member_to_discard.organization.chronus_admin if member_to_discard.present?

    if [self.member_to_discard, self.member_to_retain, self.admin_member].all?(&:present?)
      self.users_of_member_to_discard = self.member_to_discard.users.includes(:accepted_rejected_membership_requests)
      self.users_of_member_to_retain = self.member_to_retain.users
      self.users_of_admin_member = self.admin_member.users
    end
  end

  def merge
    return false unless can_be_merged?

    ActiveRecord::Base.transaction do
      handle_accepted_rejected_membership_requests
      handle_associations
      self.member_to_discard.reload.destroy
    end
    return true
  end

  private

  def can_be_merged?
    return false if [self.member_to_discard, self.member_to_retain, self.admin_member].any?(&:blank?)
    return false if [self.member_to_discard, self.member_to_retain, self.admin_member].collect(&:organization_id).uniq.size != 1
    return false if (self.users_of_member_to_discard.pluck(:program_id) & self.users_of_member_to_retain.pluck(:program_id)).any?
    return false if (self.users_of_member_to_discard.pluck(:program_id) - self.users_of_admin_member.pluck(:program_id)).any?
    return true
  end

  def handle_accepted_rejected_membership_requests
    program_id_admin_user_map = self.users_of_admin_member.index_by(&:program_id)
    self.users_of_member_to_discard.each do |user|
      user.accepted_rejected_membership_requests.update_all(admin_id: program_id_admin_user_map[user.program_id].id)
    end
  end

  def handle_associations
    assoc_name_foreign_key_map = Member.get_assoc_name_foreign_key_map

    WhitelistedAssociations.all.each do |assoc_name|
      foreign_key = assoc_name_foreign_key_map[assoc_name]
      associated_objects = self.member_to_discard.send(assoc_name)
      next if associated_objects.blank?

      if associated_objects.is_a?(ActiveRecord::Relation)
        uniqueness_scope_column = WhitelistedAssociations.uniqueness_scope_map[assoc_name]
        if uniqueness_scope_column.present?
          uniqueness_scope_ids = self.member_to_retain.send(assoc_name).pluck(uniqueness_scope_column)
          associated_objects = associated_objects.where.not(uniqueness_scope_column => uniqueness_scope_ids)
        end
        associated_objects.each { |associated_object| associated_object.update_attributes!(foreign_key => self.member_to_retain.id) }
      elsif self.member_to_retain.send(assoc_name).blank?
        associated_objects.update_attributes!(foreign_key => self.member_to_retain.id)
      end
    end
  end
end
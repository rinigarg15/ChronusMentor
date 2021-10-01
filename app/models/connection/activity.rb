# == Schema Information
#
# Table name: connection_activities
#
#  id                 :integer          not null, primary key
#  group_id           :integer          not null
#  recent_activity_id :integer          not null
#  created_at         :datetime
#  updated_at         :datetime
#

# Mapping table from RecentActivity to Group
class Connection::Activity < ActiveRecord::Base
  self.table_name = "connection_activities"

  # RecentActivityConstants::Type that are relevant to connections. 
  SUPPORTED_ACTIVITIES = [
    RecentActivityConstants::Type::SCRAP_CREATION,
    RecentActivityConstants::Type::VISIT_MENTORING_AREA,
    RecentActivityConstants::Type::GROUP_REACTIVATION,
    RecentActivityConstants::Type::GROUP_CHANGE_EXPIRY_DATE,
    RecentActivityConstants::Type::GROUP_PRIVATE_NOTE_CREATION,
    RecentActivityConstants::Type::GROUP_MEMBER_ADDITION,
    RecentActivityConstants::Type::GROUP_MEMBER_REMOVAL,
    RecentActivityConstants::Type::MENTORING_OFFER_DIRECT_ADDITION,
    RecentActivityConstants::Type::MENTORING_OFFER_ACCEPTANCE,
    RecentActivityConstants::Type::MEETING_CREATED,
    RecentActivityConstants::Type::MEETING_UPDATED,
    RecentActivityConstants::Type::MEETING_DECLINED,
    RecentActivityConstants::Type::MEETING_ACCEPTED,    
    RecentActivityConstants::Type::GROUP_MEMBER_LEAVING,
    RecentActivityConstants::Type::GROUP_TERMINATING,
    RecentActivityConstants::Type::COACHING_GOAL_CREATION,
    RecentActivityConstants::Type::COACHING_GOAL_UPDATED,
    RecentActivityConstants::Type::COACHING_GOAL_ACTIVITY_CREATION,
    RecentActivityConstants::Type::PROJECT_REQUEST_ACCEPTED,
    RecentActivityConstants::Type::PROJECT_REQUEST_REJECTED,
    RecentActivityConstants::Type::PROJECT_REQUEST_SENT,
    RecentActivityConstants::Type::GROUP_MEMBER_ADDITION_REMOVAL,
    RecentActivityConstants::Type::GROUP_RELATED_ACTIVITY
  ]

  # RecentActivityConstants::Type that are relevant to connections
  # but those don't contribute to the activity of the group.
  SUPPORTED_NON_MEMBER_ACTIVITIES = [
    RecentActivityConstants::Type::GROUP_REACTIVATION,
    RecentActivityConstants::Type::GROUP_CHANGE_EXPIRY_DATE,
    RecentActivityConstants::Type::GROUP_MEMBER_ADDITION,
    RecentActivityConstants::Type::GROUP_MEMBER_REMOVAL
  ]

  ##############################################################################
  # ASSOCIATIONS
  ##############################################################################

  belongs_to :group
  belongs_to :recent_activity

  ##############################################################################
  # VALIDATIONS
  ##############################################################################

  validates_presence_of :group, :recent_activity
  validate :check_activity_is_supported
  
  ##############################################################################
  # CALLBACKS
  ##############################################################################

  after_create :update_member_and_connection_status, :update_group_last_activity_at, :es_reindex_group
  after_destroy :es_reindex_group

  private
  
  # Checks whether the activity type represented by the recent_activity is one
  # amont the supported types in SUPPORTED_ACTIVITIES
  def check_activity_is_supported
    return unless self.recent_activity

    unless SUPPORTED_ACTIVITIES.include?(self.recent_activity.action_type)
      errors.add(:recent_activity, "activerecord.custom_errors.activity.not_supported".translate)
    end
  end

  # Marks the connection and the membership active.
  def update_member_and_connection_status
    # Do nothing on a closed connection.
    return if SUPPORTED_NON_MEMBER_ACTIVITIES.include?(self.recent_activity.action_type)
    ra_user_group = self.group
    ra_user = self.recent_activity.get_user(self.group.program)
    return if ra_user.nil? || ra_user_group.closed? || (ra_membership = ra_user_group.membership_of(ra_user)).blank?
    ra_user_group.mark_active!
    ra_user_group.set_member_status(ra_membership, Connection::Membership::Status::ACTIVE)
  end

  # Update the last_activity_at attribute of the group
  def update_group_last_activity_at
    group = self.group
    return if group.closed?
    # For Perf, skipping check_only_one_group_for_a_student_mentor_pair validation
    Group.update(group.id, last_activity_at: Time.now, skip_student_mentor_validation: true)
    return if SUPPORTED_NON_MEMBER_ACTIVITIES.include?(self.recent_activity.action_type)
    Group.update(group.id, last_member_activity_at: Time.now, skip_student_mentor_validation: true)
  end

  # This is to make sure the group is re-indexed after activities are removed. Group has an option to sort based on activity count.

  def self.es_reindex(activity)
    DelayedEsDocument.do_delta_indexing(Group, Array(activity), :group_id)
  end

  def es_reindex_group
    self.class.es_reindex(self)
  end
end

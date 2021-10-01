# == Schema Information
#
# Table name: forums
#
#  id           :integer          not null, primary key
#  program_id   :integer
#  description  :text(65535)
#  topics_count :integer          default(0)
#  name         :string(255)
#

class Forum < ActiveRecord::Base
  acts_as_subscribable

  MASS_UPDATE_ATTRIBUTES = {
    create: [:name, :description],
    update: [:name, :description]
  }

  module For
    ALL = "all"
  end

  acts_as_role_based role_association: 'access_role', validate_if: Proc.new { |forum| forum.is_program_forum? }

  has_many :topics, dependent: :destroy
  has_many :posts, through: :topics
  has_many :recent_activities, as: :ref_obj, dependent: :destroy

  belongs_to_program
  belongs_to :group

  validates :program, :name, presence: true
  validates :name, uniqueness: { scope: :program_id }
  validates :group_id, uniqueness: true, allow_nil: true

  after_create :create_recent_activity

  scope :program_forums, -> { where(group_id: nil) }

  def recent_post
    self.posts.order(id: :desc).first
  end

  # Program Forum: Admin/users of access_roles can CRUD
  # Group Forum: Admin can only read; group members can CRUD
  def can_be_accessed_by?(user, mode = :crud)
    if self.is_program_forum?
      self.can_access_program_forum?(user)
    else
      self.can_access_group_forum?(user, mode == :read_only)
    end
  end

  def available_for_student?
    self.access_role_names.include?(RoleConstants::STUDENT_NAME)
  end

  def posts_count
    self.posts.count
  end

  def total_views
    self.topics.sum(:hits)
  end

  def is_program_forum?
    self.group.blank?
  end

  def is_group_forum?
    self.group.present?
  end

  def allow_moderation?
    self.is_program_forum? && self.program.moderation_enabled?
  end

  def allow_flagging?
    self.is_program_forum? && self.program.flagging_enabled?
  end

  # can_access_*_methods are public as topic and post use these methods via delegation
  def can_access_program_forum?(user)
    return false unless self.is_program_forum?
    self.program.forums_enabled? && (user.has_any_role?(self.access_roles) || user.can_manage_forums?)
  end

  def can_access_group_forum?(user, read_only)
    return false unless self.is_group_forum?
    self.group.forum_enabled? && (
      (read_only && (self.group.has_member?(user) || user.can_manage_connections?)) ||
      (self.group.open? && self.group.has_member?(user))
    )
  end

  def create_recent_activity(action_type = nil, ref_obj = nil)
    target = self.recent_activity_target
    return if target.blank?

    RecentActivity.create!(
      programs: [self.program],
      action_type: action_type || RecentActivityConstants::Type::FORUM_CREATION,
      target: target,
      ref_obj: ref_obj || self,
      member: ref_obj.try(:user).try(:member)
    )
  end

  def self.deliver_notifications(topic_or_post)
    klass = topic_or_post.class
    recent_activity_type = klass.recent_activity_type
    users_list = topic_or_post.notification_list.compact
    forum = topic_or_post.forum
    user_id_membership_map = forum.group.memberships.index_by(&:user_id) if forum.is_group_forum?

    JobLog.compute_with_historical_data(users_list, topic_or_post, recent_activity_type) do |subscriber|
      Push::Base.queued_notify(klass.push_notification_type, topic_or_post, queue: :default, user_id: subscriber.id)
      if topic_or_post.forum.is_program_forum?
        subscriber.send_email(topic_or_post, recent_activity_type, sender: topic_or_post.user)
      elsif topic_or_post.forum.is_group_forum?
        user_id_membership_map[subscriber.id].send_email(topic_or_post, recent_activity_type, topic_or_post.user) if user_id_membership_map[subscriber.id]
      end
    end
  end
end
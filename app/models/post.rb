# == Schema Information
#
# Table name: posts
#
#  id                      :integer          not null, primary key
#  user_id                 :integer
#  topic_id                :integer
#  body                    :text(4294967295)
#  created_at              :datetime
#  updated_at              :datetime
#  attachment_file_name    :string(255)
#  attachment_content_type :string(255)
#  attachment_file_size    :integer
#  attachment_updated_at   :datetime
#  ancestry                :string(255)
#  published               :boolean          default(TRUE)
#  main_content            :boolean          default(FALSE)
#

class Post < ActiveRecord::Base
  has_ancestry
  has_attached_file :attachment, POST_STORAGE_OPTIONS

  MASS_UPDATE_ATTRIBUTES = {
    create: [:body, :parent_id, :user_id, :attachment]
  }

  has_many :recent_activities, as: :ref_obj, dependent: :destroy
  has_many :flags, as: :content, dependent: :nullify
  has_many :job_logs, as: :loggable_object, dependent: :destroy
  has_many :pending_notifications, as: :ref_obj, dependent: :destroy
  has_many :push_notifications, :as => :ref_obj
  has_many :vulnerable_content_logs, :as => :ref_obj
  has_many :viewed_objects, as: :ref_obj, dependent: :destroy

  belongs_to :user
  belongs_to :topic

  counter_culture :topic

  validates :user, :body, :topic, presence: true
  validate :check_user_has_permission, on: :create
  validate :check_moderation_and_flagging
  validates_attachment_content_type :attachment, content_type: DEFAULT_ALLOWED_FILE_UPLOAD_TYPES, message: Proc.new { "flash_message.message.file_attachment_invalid".translate }
  validates_attachment_size :attachment, less_than: AttachmentSize::END_USER_ATTACHMENT_SIZE, message: Proc.new { "flash_message.message.file_attachment_too_big".translate(file_size: AttachmentSize::END_USER_ATTACHMENT_SIZE/ONE_MEGABYTE) }
  validates_format_of :attachment_file_name, without: DISALLOWED_FILE_EXTENSIONS, message: Proc.new { "flash_message.general_file_attachment.file_attachment_name_invalid".translate }

  scope :unpublished, -> { where(published: false) }
  scope :published, -> { where(published: true) }
  scope :created_in_date_range, Proc.new { |date_range| where(created_at: date_range) }

  delegate :forum, :program, :can_be_accessed_by?, to: :topic

  def self.notify_admins_for_moderation(program, post, action)
    return if post.published?

    admins = program.admin_users
    JobLog.compute_with_historical_data(admins, post, action) do |user|
      ChronusMailer.content_moderation_admin_notification(user, post, sender: post.user).deliver_now
    end
  end

  def self.es_reindex(post)
    forums = Array(post).collect(&:forum).compact
    group_ids = forums.collect(&:group_id).compact
    reindex_group(group_ids)
    DelayedEsDocument.do_delta_indexing(Topic, Array(post), :topic_id)
  end

  def self.reindex_group(group_ids)
    DelayedEsDocument.delayed_bulk_update_es_documents(Group, group_ids)
  end

  def can_be_deleted?(user)
    return false unless self.can_be_accessed_by?(user)
    return true if (self.user == user) && self.published?
    return (self.forum.is_program_forum? && user.can_manage_forums?)
  end

  def fetch_children_and_unmoderated_children_count(user)
    if user.can_manage_forums?
      [self.children, self.children.unpublished.size]
    else
      [self.children.published, 0]
    end
  end

  def self.recent_activity_type
    RecentActivityConstants::Type::POST_CREATION
  end

  def self.push_notification_type
    PushNotification::Type::FORUM_POST_CREATED
  end

  def notification_list
    post_user = self.user
    post_subscribers = self.topic.subscribers - [post_user]
    post_subscribers.select { |post_subscriber| post_user.visible_to?(post_subscriber) }
  end

  protected

  def check_user_has_permission
    if self.topic.present? && !self.can_be_accessed_by?(self.user)
      self.errors.add(:user, "feature.forum.content.not_permitted".translate)
    end
  end

  def check_moderation_and_flagging
    # Moderation and Flagging are restricted for group forums (discussion boards).
    if self.topic.present? && self.forum.is_group_forum?
      self.errors.add(:base, "feature.forum.content.moderation_not_for_discusion_board".translate) unless self.published?
      self.errors.add(:base, "feature.forum.content.flagging_not_for_discussion_board".translate) if self.flags.exists?
    end
  end
end
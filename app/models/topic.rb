# == Schema Information
#
# Table name: topics
#
#  id              :integer          not null, primary key
#  forum_id        :integer
#  user_id         :integer
#  title           :string(255)
#  created_at      :datetime
#  updated_at      :datetime
#  hits            :integer          default(0)
#  posts_count     :integer          default(0)
#  sticky_position :integer          default(0)
#

class Topic < ActiveRecord::Base
  sanitize_attributes_content :body
  include TopicElasticsearchSettings

  MASS_UPDATE_ATTRIBUTES = {
    create: [:title, :body]
  }
  VIEWABLE_CUTOFF_DATE = "2018-01-07 00:00:00 UTC"
  DESCRIPTION_TRUNCATE_LENGTH = 300

  acts_as_subscribable

  belongs_to :forum
  counter_culture :forum
  belongs_to :user

  has_many :posts, dependent: :destroy
  has_many :published_posts, -> { where(published: true) }, class_name: Post.name
  has_one :recent_post, -> { order(id: :desc) }, class_name: Post.name
  has_many :recent_activities, as: :ref_obj, dependent: :destroy
  has_many :job_logs, as: :loggable_object, dependent: :destroy
  has_many :pending_notifications, as: :ref_obj, dependent: :destroy
  has_many :push_notifications, as: :ref_obj

  validates :forum, :user, :title, :body, presence: true
  validate :check_for_user_permission, on: :create

  delegate :program, :can_be_accessed_by?, to: :forum

  def hit!
    Topic.increment_counter(:hits, self.id)
  end

  def program_id
    program.id
  end
  
  def topic_role_ids
    forum.access_roles.collect(&:id)
  end

  def replied_at(user)
    return if self.posts.blank?

    if user.can_manage_forums?
      self.recent_post.updated_at
    else
      self.posts.published.last.try(:updated_at)
    end
  end

  def get_posts_count(user)
    if user.can_manage_forums?
      self.posts_count
    else
      self.posts.published.size
    end
  end

  def get_last_touched_time
    return [self.updated_at, self.posts.maximum(:updated_at)].compact.max
  end

  def self.notify_subscribers(topic_id)
    topic = Topic.find_by(id: topic_id)
    return if topic.blank?

    Forum.deliver_notifications(topic)
  end

  def sticky?
    self.sticky_position.to_i > 0
  end

  def can_be_deleted?(user)
    return false unless self.can_be_accessed_by?(user)
    return true if (self.user == user)
    return (self.forum.is_program_forum? && user.can_manage_forums?)
  end

  def self.recent_activity_type
    RecentActivityConstants::Type::TOPIC_CREATION
  end

  def self.push_notification_type
    PushNotification::Type::FORUM_TOPIC_CREATED
  end

  def notification_list
    topic_user = self.user
    forum_subscribers = self.forum.subscribers
    (forum_subscribers - [topic_user]).select { |forum_subscriber| topic_user.visible_to?(forum_subscriber) }
  end

  def mark_posts_viewability_for_user(user_id)
    return if self.forum.is_program_forum?
    posts = self.posts
    viewed_objects_posts_ids = ViewedObject.where(ref_obj_id: posts.pluck(:id), ref_obj_type: "Post", user_id: user_id).pluck(:ref_obj_id)
    posts.each do |post|
      next if post.user_id == user_id || viewed_objects_posts_ids.include?(post.id)
      ViewedObject.create!(ref_obj: post, user_id: user_id)
    end
  end

  protected

  def check_for_user_permission
    if self.forum.present? && !self.can_be_accessed_by?(self.user)
      self.errors.add(:user, "activerecord.custom_errors.topic.not_permitted".translate)
    end
  end
end
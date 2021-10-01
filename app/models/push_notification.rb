# == Schema Information
#
# Table name: push_notifications
#
#  id                  :integer          not null, primary key
#  member_id           :integer          not null
#  notification_params :text(65535)
#  unread              :boolean          default(TRUE)
#  ref_obj_id          :integer
#  ref_obj_type        :string(255)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  notification_type   :integer
#

class PushNotification < ActiveRecord::Base
  module Type
    MESSAGE_SENT_NON_ADMIN = 0
    MESSAGE_SENT_ADMIN = 1

    MENTOR_REQUEST_CREATE = 5
    MENTOR_REQUEST_ACCEPT = 6
    MENTOR_REQUEST_REJECT = 7

    ANNOUNCEMENT_NEW = 11
    ANNOUNCEMENT_UPDATE = 12
    MENTOR_RECOMMENDATION_PUBLISH = 13
    MEETING_REQUEST_CREATED = 14
    MEETING_REQUEST_ACCEPTED = 15
    MEETING_REQUEST_REJECTED = 16
    MEETING_REQUEST_REMINDER = 17
    MEETING_CREATED = 18
    MEETING_UPDATED = 19
    MEETING_REMINDER = 20
    MEETING_FEEDBACK_REQUEST = 21
    MENTOR_REQUEST_REMINDER = 22
    GROUP_MEMBER_ADDED = 23
    GROUP_INACTIVITY = 24
    PBE_PROPOSAL_ACCEPTED = 25
    PBE_PROPOSAL_REJECTED = 26
    PBE_PUBLISHED = 27
    PBE_CONNECTION_REQUEST_ACCEPT = 28
    PBE_CONNECTION_REQUEST_REJECT = 29
    MENTOR_OFFER = 30
    MENTOR_OFFER_ACCEPTED = 31
    MENTOR_OFFER_REJECTED = 32
    PROGRAM_EVENT_REMINDER = 33
    PROGRAM_EVENT_CREATED = 34
    ARTICLE_COMMENT_CREATED = 35
    QA_ANSWER_CREATED = 36
    FORUM_POST_CREATED = 37
    FORUM_TOPIC_CREATED = 38

    def self.all
      constants.collect{|c| const_get(c)}
    end
  end

  module Level
    PROGRAM      = 100
    ORGANIZATION = 200
  end

  belongs_to :member
  belongs_to :ref_obj, :polymorphic => true

  validates :member_id, :notification_params, :ref_obj_id, :ref_obj_type, :notification_type, presence: true
  validates :notification_type, inclusion: {in: Type.all}
  serialize :notification_params

  scope :unread, -> { where( :unread => true )}
  scope :read, -> { where( :unread => false )}

  default_scope -> { order('created_at DESC') }

  def ref_obj_type=(type)
     super(type.to_s.classify.constantize.base_class.name)
  end

  def mark_as_read!
  	self.update_attributes!(unread: false)
  end

  def notification_params_with_message_for_member(member)
    return self.notification_params.merge(alert: self.generate_message_for(Language.for_member(member)))
  end

  def self.mark_notification_read!(member, notification_object)
  	notifications = member.push_notifications.where("ref_obj_id = ? and ref_obj_type = ?", notification_object.id, notification_object.class.base_class.name).unread
  	# in group scraps(chat), there can be many unread messages under a single scrap
  	# so mark as read all the unread messages in the group (chat) scraps.
  	notifications.each do |notification|
  		if notification.unread
  			notification.mark_as_read! 
  		end
    end
  end
end

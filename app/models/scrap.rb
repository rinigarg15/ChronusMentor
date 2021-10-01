# == Schema Information
#
# Table name: messages
#
#  id                      :integer          not null, primary key
#  program_id              :integer
#  sender_id               :integer
#  sender_name             :string(255)
#  sender_email            :string(255)
#  subject                 :string(255)
#  content                 :text(65535)
#  created_at              :datetime
#  updated_at              :datetime
#  group_id                :integer
#  parent_id               :integer
#  type                    :string(255)
#  auto_email              :boolean          default(FALSE)
#  root_id                 :integer          default(0), not null
#  posted_via_email        :boolean          default(FALSE)
#  attachment_file_name    :string(255)
#  attachment_content_type :string(255)
#  attachment_file_size    :integer
#  attachment_updated_at   :datetime
#  delta                   :boolean          default(FALSE)
#  campaign_message_id     :integer
#  context_program_id      :integer
#  ref_obj_id              :integer
#  ref_obj_type            :string(255)
#

class Scrap < AbstractMessage
  include AttachmentUtils

  UNREAD_MESSAGE_LIMIT = 2
  HOME_LATEST_MESSAGE_LIMIT = 3
  MASS_UPDATE_ATTRIBUTES = {
    :create => [:subject, :content, :attachment, :reply_within]
  }

  ##### Associations #####
  belongs_to_program
  belongs_to :group,
             :foreign_key => "ref_obj_id",
             :class_name => "Group"
  belongs_to :ref_obj, polymorphic: true
  has_many :message_receivers,
           :dependent => :destroy,
           :class_name => "Scraps::Receiver",
           :foreign_key => "message_id",
           :inverse_of => :message
  has_many :receivers,
           :through => :message_receivers,
           :source => :member

  has_many :recent_activities, :as => :ref_obj, :dependent => :destroy
  has_one :mentoring_model_task_comment_scrap, :dependent => :destroy
  has_one :comment, through: :mentoring_model_task_comment_scrap, class_name: MentoringModel::Task::Comment.name

  ##### Validations #####
  validates_presence_of :program
  validates_presence_of :ref_obj, :sender, :on => :create
  validate :check_group_allows_scraps, on: :create, if: Proc.new { |scrap| scrap.is_group_message? }
  validate :check_sender_from_same_group, :on => :create, if: Proc.new { |scrap| scrap.is_group_message? }
  validate :check_sender_from_same_meeting, :on => :create, if: Proc.new { |scrap| scrap.is_meeting_message? }

  ##### Scope #####
  scope :of_member_in_ref_obj, ->(member_id, ref_obj_id, ref_obj_type) { joins("LEFT OUTER JOIN abstract_message_receivers ON abstract_message_receivers.message_id = messages.id").where("ref_obj_id = ? AND ref_obj_type = ? AND (sender_id = ? OR (member_id = ? AND status != ?))", ref_obj_id, ref_obj_type, member_id, member_id, AbstractMessageReceiver::Status::DELETED)}

  scope :created_in_date_range, Proc.new { |date_range| where(:created_at => date_range) }

  ##### Instance Methods #####

  def is_group_message?
    self.ref_obj.is_a?(Group)
  end

  def is_meeting_message?
    self.ref_obj.is_a?(Meeting)
  end

  # Returns other users of the group than the sender
  def receiving_users(user_to_ignore = nil)
    return [] if self.ref_obj.blank?

    user_to_ignore ||= self.sender_user
    all_users = self.is_group_message? ? self.ref_obj.members.active_or_pending.includes(:member) : self.ref_obj.participant_users
    all_users - [user_to_ignore]
  end

  def receiver_names(user)
    receiver_users = is_group_message? ? ref_obj.get_groupees(user) : ref_obj.get_coparticipants(user)
    receiver_users.collect(&:name).to_sentence
  end

  # Replying to a scrap that belongs to a non-active group is restricted
  def has_group_access?(member)
    user = get_user(member)
    is_group_message? && ref_obj && (ref_obj.scraps_enabled? && ref_obj.open?) && ref_obj.has_member?(user) && !user.suspended?
  end

  def has_meeting_access?(member)
    user = get_user(member)
    user && is_meeting_message? && ref_obj && ref_obj.state.nil? && ref_obj.active? && ref_obj.has_member?(member) && !user.suspended?
  end

  def is_admin_viewing?(member)
    user = get_user(member)
    participant_user_or_member = is_group_message? ? user : member
    user && user.is_admin? && (!ref_obj || !ref_obj.has_member?(participant_user_or_member))
  end

  # Admin / Sender / Receiver who has not deleted the scrap can view the scrap
  def can_be_viewed?(member, _options = {})
    super || is_admin_viewing?(member)
  end

  def can_be_replied?(member, options = {})
    user = self.get_user(member)

    user.try(:active_or_pending?) &&
      self.can_be_viewed?(member, options) &&
      self.receiving_users(user).present? &&
      (self.has_group_access?(member) || self.has_meeting_access?(member)) &&
      (!self.is_meeting_message? || self.ref_obj.member_can_send_new_message?(member))
  end

  def can_be_deleted?(member, options = {})
    if options[:preloaded].present?
      options[:has_receiver].present? && options[:is_deleted].blank?
    else
      self.sent_to?(member) && !self.deleted?(member)
    end
  end

  def create_receivers!
    self.receiving_users.each do |receiving_user|
      self.receivers << receiving_user.member
    end
  end

  # Reply - create receiver objects for all the other members of group
  def build_reply(member, _options = {})
    reply = ref_obj.scraps.build(sender: member, parent_id: id, subject: subject, program_id: ref_obj.program_id)
    reply.receivers = reply.receiving_users.collect(&:member)
    reply
  end

  def add_to_activity_log
    ActivityLog.log_mentoring_visit(self.sender_user) if is_group_message?
  end

  def create_comment_from_scrap
    if is_group_message?
      comment_attributes = {sender: self.sender, program_id: self.program_id, content: self.content}
      task = self.root.comment.mentoring_model_task
      comment = task.comments.new
      comment.attributes = comment_attributes
      AttachmentUtils.copy_attachment(self, comment) if self.attachment.exists?
      comment.scrap = self
      comment.save!
    end
  end

  private

  def check_group_allows_scraps
    group = self.ref_obj
    if group.present? && !group.scraps_enabled?
      mentoring_connection_term = self.program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase
      errors.add(:base, "activerecord.custom_errors.scrap.messaging_not_allowed_in_connection".translate(mentoring_connection: mentoring_connection_term))
    end
  end

  def check_sender_from_same_group
    group = self.ref_obj
    if group.present? && sender.present?
      return true if group.has_member?(sender_user)
      errors.add(:sender, "activerecord.custom_errors.scrap.not_member".translate)
    end
  end

  def check_sender_from_same_meeting
    meeting = self.ref_obj
    if meeting.present? && sender.present?
      return true if meeting.has_member?(sender)
      errors.add(:sender, "activerecord.custom_errors.scrap.not_meeting_member".translate(meeting: self.program.term_for(CustomizedTerm::TermType::MEETING_TERM).term_downcase))
    end
  end
end
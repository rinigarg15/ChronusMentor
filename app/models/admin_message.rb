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

#
# Represents a message exchanged through the 'Contact Admin' link. Following
# are the scenarios and how this model behaves w.r.t them
#
#   * Logged in user to Admin
#     ** sender_id                        - YES
#     ** receiver_id                      - NO
#     ** sender_name and sender_email     - NO
#     ** receiver_name and receiver_email - NO
#
#   * Unlogged in user to Admin
#     ** sender_id                        - YES
#     ** receiver_id                      - NO
#     ** sender_name and sender_email     - YES
#     ** receiver_name and receiver_email - NO

#   * Admin replying to logged in user
#     ** sender_id                        - YES
#     ** receiver_id                      - YES
#     ** sender_name and sender_email     - NO
#     ** receiver_name and receiver_email - NO
#
#   * Admin replying to Unlogged in user
#     ** sender_id                        - YES
#     ** receiver_id                      - NO
#     ** sender_name and sender_email     - NO
#     ** receiver_name and receiver_email - YES
#

class AdminMessage < AbstractMessage
  MESSAGES_PER_HOUR = 10
  sanitize_attributes_content :content, { if: Proc.new{ |admin_message| admin_message.has_rich_text_content? } }
  #-----------------------------------------------------------------------------
  # ASSOCIATIONS
  #-----------------------------------------------------------------------------

  belongs_to_program_or_organization
  belongs_to :group
  belongs_to :campaign_message, foreign_key: "campaign_message_id", class_name: "CampaignManagement::AbstractCampaignMessage"

  has_many  :message_receivers,
            :dependent => :destroy,
            :class_name => "AdminMessages::Receiver",
            :foreign_key => "message_id",
            :inverse_of => :message
  has_many :receivers,
           :through => :message_receivers,
           :source => :member

  has_many  :event_logs,
            :dependent => :destroy,
            :class_name => "CampaignManagement::EmailEventLog",
            :foreign_key => "message_id",
            :as => :message

  #-----------------------------------------------------------------------------
  # VALIDATIONS
  #-----------------------------------------------------------------------------

  # The following two validations are required as setting one will not set the other
  validates_presence_of :message_receivers, :on => :create, :if => Proc.new{|message| message.receivers.blank? }
  validates_presence_of :receivers, :on => :create, :if => Proc.new{|message| message.message_receivers.blank? }

  validates_presence_of :sender_name, :sender_email, :on => :create, :if => Proc.new{|message| !message.auto_email? && message.sender_id.nil? }
  validates :sender_email, :email_format => {:generate_message => true, :check_mx => false}, :on => :create, :if => Proc.new{|message| !message.auto_email? && message.sender_id.nil? }

  validate :sender_should_be_a_member_of_the_group, if: ->(admin_message){ !admin_message.auto_email? && admin_message.group.present? }
  validate :check_messages_created_per_time, if: :logged_in_user_to_admin_new_thread?
  validate :check_admin_to_user_messages, on: :create

  attr_accessor :connection_send_message_type_or_role

  MASS_UPDATE_ATTRIBUTES = {
   :create => [:parent_id, :subject, :content, :sender_name, :connection_send_message_type_or_role, :group_id, :attachment]
  }


  def self.created_after(time)
    where("messages.created_at > ?", time)
  end

  #-----------------------------------------------------------------------------
  # INSTANCE METHODS
  #-----------------------------------------------------------------------------

  # This method is used to set receivers when the member_ids are passed as string
  # This is used in Multi autocomplete while sending message
  def receiver_ids=(ids)
    receiver_ids = ids.split(",")
    if program
      self.receivers = for_program? ? program.organization.members.where(id: receiver_ids) : program.members.where(id: receiver_ids)
    end
  end

  # This method is used to set receivers when the group/connection ids are passed as string
  # This is used in Multi autocomplete of connections while sending message
  def connection_ids=(ids)
    connection_ids = ids.split(",")
    self.receivers = program.members_in_connections(connection_ids, self.connection_send_message_type_or_role) if program && for_program?
  end

  def only_receiver
    self.message_receivers.first
  end

  alias_method :admin_receiver, :only_receiver
  alias_method :offline_receiver, :only_receiver

  def sent_by_admin?
    if for_program?
      sender_user && sender_user.is_admin?
    else
      sender && sender.admin?
    end
  end

  def is_member_admin_for_this_msg?(member)
    if for_program?
      get_user(member) && get_user(member).is_admin?
    else
      member.admin?
    end
  end

  def sent_to?(member)
    return true if (user_to_admin? && is_member_admin_for_this_msg?(member))
    message_receivers.collect(&:member_id).include?(member.id)
  end

  def sent_by?(member)
    return sender_id == member.id if user_to_admin?
    sender_id && sent_by_admin? && is_member_admin_for_this_msg?(member)
  end

  def admin_to_registered_user?
    sent_by_admin? && (message_receivers.empty? || message_receivers.collect(&:member_id).compact.any?)
  end

  def admin_to_offline_user?
    sent_by_admin? && message_receivers.size == 1 && only_receiver.email && only_receiver.member_id.nil?
  end

  def admin_to_user?
    !user_to_admin?
  end

  def user_to_admin?
    message_receivers.size == 1 && only_receiver.member_id.nil? && only_receiver.email.nil?
  end

  def logged_in_user_to_admin_new_thread?
    user_to_admin? && sender_id.present? && parent_id.nil?
  end

  def deleted?(member)
    if self.sent_to?(member)
      user_to_admin? ? only_receiver.deleted? : get_message_receiver(member).deleted?
    elsif self.sent_by?(member)
      false
    end
  end

  ## The following users can reply:
  # Receivers of auto-email message (facilitation messages, campaigns)
  # Sender & Admins (if sender data exists) of user_to_admin message
  # Actual sender & receivers of admin_to_user non auto-email message
  def can_be_replied?(member, options = {})
    self.can_be_viewed?(member, options) &&
      if self.auto_email?
        self.sent_to?(member) && !self.deleted?(member)
      elsif self.sent_by?(member)
        self.user_to_admin? || self.message_receivers.exists?
      elsif self.user_to_admin?
        self.sender_email.present? || self.sender.present?
      else
        true
      end
  end

  def build_reply(member, options = {})
    reply = program.admin_messages.build(parent_id: id, subject: subject, sender: member)

    if !self.auto_email? && member.present? && self.sent_by?(member)
      if self.user_to_admin? || (self.sent_to?(member) && options[:from_inbox].to_s.to_boolean)
        reply.message_receivers.build
      else
        reply.message_receivers = self.message_receivers.map do |message_receiver|
          new_message_receiver = message_receiver.dup
          new_message_receiver.message = reply
          new_message_receiver
        end
      end
    elsif self.admin_to_user?
      reply.message_receivers.build
    else
      # In the case of offline sender, using read_attribute method inorder to fetch the sender_name from the admin_message object than instead of the sender member object.
      reply.message_receivers.build(email: sender_email, name: self.read_attribute(:sender_name), member: sender)
    end
    reply
  end

  def read?(member)
    if sent_to?(member)
      user_to_admin? ? only_receiver.read? : get_message_receiver(member).read?
    elsif sent_by?(member)
      true
    end
  end

  def unread?(member)
    if sent_to?(member)
      user_to_admin? ? only_receiver.unread? : get_message_receiver(member).unread?
    elsif sent_by?(member)
      false
    end
  end

  def mark_as_read!(member)
    return unless sent_to?(member)
    user_to_admin? ? only_receiver.mark_as_read! : get_message_receiver(member).mark_as_read!
  end

  def mark_deleted!(member)
    return unless sent_to?(member)
    user_to_admin? ? only_receiver.mark_deleted! : get_message_receiver(member).mark_deleted!
  end

  #TODO: Used only in API; should get rid of this.
  def member_admin_filtered_tree(member)
    return tree if is_member_admin_for_this_msg?(member)
    filtered_tree = []
    tree.map do |message|
      filtered_tree << message if (message.sent_by?(member) || message.sent_to?(member))
    end
    filtered_tree
  end

  #-----------------------------------------------------------------------------
  # CLASS METHODS
  #-----------------------------------------------------------------------------

  def self.create_for_facilitation_message(facilitation_message, recipient_user, admin_member, group)
    content, no_email_notifications, subject = nil, nil, nil
    locale = Language.for_member(recipient_user.member, recipient_user.program)
    Globalize.with_locale(locale) do
      subject = facilitation_message.subject
      content, no_email_notifications = facilitation_message.prepare_message(recipient_user, group)
    end

    group.program.admin_messages.create!(
      sender: admin_member,
      subject: subject,
      content: content,
      group: group,
      receivers: [recipient_user.member],
      auto_email: true,
      no_email_notifications: no_email_notifications
    )
  end

  def self.send_new_message_to_offline_user_notification(admin_message_id)
    admin_message = AdminMessage.find_by(id: admin_message_id)
    return if admin_message.nil?

    ChronusMailer.new_message_to_offline_user_notification(admin_message, sender: admin_message.sender).deliver_now
  end

  private

  def sender_should_be_a_member_of_the_group
    if sender.nil? || sender_user.nil?
      self.errors.add(:sender, "activerecord.custom_errors.message.sender_blank".translate)
    elsif (!sender_user.belongs_to_group?(group))
      self.errors[:base] << "activerecord.custom_errors.message.user_not_in_group".translate
    end
  end

  def check_messages_created_per_time
    self.errors[:base] << "activerecord.custom_errors.message.limit_exceeded".translate(self.program.return_custom_term_hash) if self.program.admin_messages.joins(:message_receivers).where(:abstract_message_receivers => {:member_id => nil}, :created_at => 1.hour.ago.utc..Time.now.utc, :sender_id => self.sender_id, :parent_id => nil, :auto_email => false).count >= MESSAGES_PER_HOUR
  end

  def check_admin_to_user_messages
    # Presence of receivers or message_receiver with email present indicates admin-to-user messages
    if self.program.present? && (self.receivers.any? || (self.message_receivers.any? && self.only_receiver.email.present?))
      if self.sender.blank? || !self.is_member_admin_for_this_msg?(self.sender)
        self.errors.add(:sender, "activerecord.custom_errors.message.sender_invalid".translate)
      end
    end
  end
end

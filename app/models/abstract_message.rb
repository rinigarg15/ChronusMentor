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

class AbstractMessage < ActiveRecord::Base
  include AbstractMessageElasticsearchQueries
  include AbstractMessageElasticsearchSettings

  READ_MESSAGE_THRESOLD = 3
  PER_PAGE = 20
  self.table_name = "messages"

  belongs_to_program_or_organization
  belongs_to :sender, class_name: 'Member'
  belongs_to :root, class_name: 'AbstractMessage'
  belongs_to :parent, class_name: 'AbstractMessage', inverse_of: :children
  belongs_to :context_program, class_name: 'Program'

  has_many :root_message_receivers, class_name: "AbstractMessageReceiver", foreign_key: "message_root_id"
  has_many :message_receivers,
           dependent: :destroy,
           class_name: "AbstractMessageReceiver",
           foreign_key: "message_id",
           inverse_of: :message
  has_many :receivers,
           through: :message_receivers,
           source: :member
  has_many :push_notifications, as: :ref_obj, dependent: :destroy
  has_many  :event_logs,
            dependent: :destroy,
            class_name: "CampaignManagement::EmailEventLog",
            foreign_key: "message_id",
            as: :message
  has_many :job_logs, as: :loggable_object

  has_attached_file :attachment, MESSAGE_STORAGE_OPTIONS

  # Scope included for performance reasons - to force mysql use index on parent_id column
  # TODO-PERF: See if this default includes in causing perf issues elsewhere
  scope :with_a_parent, -> { where("parent_id IS NOT NULL")}
  has_many :children, -> {where("id IN (#{AbstractMessage.with_a_parent.select(:id).to_sql})").includes([:program, :message_receivers, sender: { users: [:roles] }])}, class_name: 'AbstractMessage', foreign_key: :parent_id,
    inverse_of: :parent
  has_many :root_children, foreign_key: "root_id", class_name: "AbstractMessage"

  before_post_process :transliterate_file_name
  attr_accessor :no_email_notifications
  before_save :set_context_program

  #-----------------------------------------------------------------------------
  # VALIDATIONS
  #-----------------------------------------------------------------------------


  validates_presence_of :subject, :content, :program_id
  validates_attachment_content_type :attachment, content_type: DEFAULT_ALLOWED_FILE_UPLOAD_TYPES, message: Proc.new { "flash_message.message.file_attachment_invalid".translate }, if: Proc.new {|obj| obj.changes[:attachment_content_type].present?}
  validates_attachment_size :attachment, less_than: AttachmentSize::END_USER_ATTACHMENT_SIZE, message: Proc.new { "flash_message.message.file_attachment_too_big".translate(file_size: (AttachmentSize::END_USER_ATTACHMENT_SIZE/ONE_MEGABYTE)) }
  validates_format_of :attachment_file_name, without: DISALLOWED_FILE_EXTENSIONS, message: Proc.new { "flash_message.general_file_attachment.file_attachment_name_invalid".translate }, if: Proc.new {|obj| obj.changes[:attachment_file_name].present?}

  #-----------------------------------------------------------------------------
  # Elasticsearch indexed methods
  #-----------------------------------------------------------------------------

  def html_stripped_content
    self.content.try(:strip_html)
  end

  #-----------------------------------------------------------------------------
  #-----------------------------------------------------------------------------
  # INSTANCE METHODS
  #-----------------------------------------------------------------------------

  def get_user(member)
    if member
      @users ||= {}
      @users[member.id] ||= member.users.find{ |user| user.program_id == program_id }
    end
  end

  def sender_user
    @sender_user ||= get_user(sender) if sender
  end

  def context_program_for_email
    for_program? ? program : get_context_program
  end

  def get_context_program
    all_members_are_present_in_program?(context_program) ? context_program : nil
  end

  def all_members_are_present_in_program?(program)
    member_ids = self.message_receivers.pluck(:member_id) + [sender_id]
    program.present? && program.users.where(member_id: member_ids).count == member_ids.count
  end

  def send_progam_level_email?
    context_program_for_email.present?
  end

  def inbox_message_notification_type
    send_progam_level_email? ? RecentActivityConstants::Type::INBOX_MESSAGE_NOTIFICATION_FOR_TRACK : RecentActivityConstants::Type::INBOX_MESSAGE_NOTIFICATION
  end

  def for_program?
    program.is_a?(Program)
  end

  def for_organization?
    program.is_a?(Organization)
  end

  def formatted_subject
    self.subject
  end

  def has_rich_text_content?
    self.is_a?(AdminMessage) && self.root? && self.admin_to_user?
  end

  def formatted_content
    if self.has_rich_text_content?
      self.content.html_safe
    else
      chronus_format_text_area(self.content)
    end
  end

  def get_root
    self.root
  end

  # Returns all the abstract_messages that belong to the same thread
  def siblings
    AbstractMessage.where(root_id: self.root_id)
  end

  def subtree
    self.class.subtree(self)
  end

  def tree
    [self] + self.subtree
  end

  def reply?
    self.parent.present?
  end

  def root?
    !reply?
  end

  def sender_name
    sender ? sender.name : super
  end

  def get_message_receiver(member)
    return nil unless member
    if self.message_receivers.loaded?
      self.message_receivers.find { |message_receiver| message_receiver.member_id == member.id }
    else
      self.message_receivers.find_by(member_id: member.id)
    end
  end

  def sent_by?(member)
    (sender_id == member.id)
  end

  def sent_to?(member)
    get_message_receiver(member).present?
  end

  def read?(member)
    if sent_to?(member)
      get_message_receiver(member).read?
    elsif sent_by?(member)
      true
    end
  end

  def unread?(member)
    if sent_to?(member)
      get_message_receiver(member).unread?
    elsif sent_by?(member)
      false
    end
  end

  def deleted?(member)
    if sent_to?(member)
      get_message_receiver(member).deleted?
    elsif sent_by?(member)
      false
    end
  end

  def mark_as_read!(member)
    return unless sent_to?(member)
    get_message_receiver(member).mark_as_read!
  end

  def mark_tree_as_read!(member)
    tree.each do |message|
      message.mark_as_read!(member) if message.unread?(member)
    end
    true
  end

  def mark_siblings_as_read(member)
    member.message_receivers.where(message_id: siblings.collect(&:id)).unread.update_all(status: AbstractMessageReceiver::Status::READ)
    true
  end

  def mark_deleted!(member)
    return unless sent_to?(member)
    get_message_receiver(member).mark_deleted!
  end

  def can_be_viewed?(member, options = {})
    can_view_as_receiver = if options[:preloaded].present?
      options[:has_receiver].present? && options[:is_deleted].blank?
    else
      self.sent_to?(member) && !self.deleted?(member)
    end
    can_view_as_receiver || self.sent_by?(member)
  end

  # prevent showing delete action when sender and receiver are same
  def can_be_deleted?(member, options = {})
    self.can_be_viewed?(member, options) && !self.sent_by?(member)
  end

  def last_message_can_be_viewed(member)
    tree.reverse_each do |message|
      return message if message.can_be_viewed?(member)
    end
    nil
  end

  def thread_can_be_viewed?(member)
    tree.any? do |message|
      message.can_be_viewed?(member)
    end
  end

  def sibling_has_attachment?(member, options={})
    siblings_arr = options[:preloaded].present? ? Array(options[:siblings_index][self.root_id]) : siblings
    siblings_arr.any? do |message|
      preloaded_options = {}
      if options[:preloaded].present?
        preloaded_options.merge!({
          preloaded: true,
          has_receiver: options[:viewable_scraps_hash][message.id].present?,
          is_deleted: options[:deleted_scraps_hash][message.id].present?
        })
      end
      message.attachment? && message.can_be_viewed?(member, preloaded_options)
    end
  end

  def thread_members_and_size(member)
    messages = self.tree
    messages = messages.select{|message| message.can_be_viewed?(member)}
    members = []
    unread = {}
    messages.each do |message|
      sender = message.sender.nil? ? message.sender_name : message.sender
      members << sender
      unread[sender] ||= message.unread?(member)
    end
    { members: members.uniq, unread: unread, size: messages.size }
  end

  def thread_receivers_details(member, options = {})
    messages = options[:messages_scope].present? && !member.is_admin? ? options[:messages_scope].where(root_id: self.id) : self.tree
    messages = messages.select{|message| message.can_be_viewed?(member)}
    first_sent_message = nil
    unread = false
    messages.each do |message|
      first_sent_message ||= message if message.sent_by?(member)
      unread ||= message.unread?(member)
      return { first_sent_message: first_sent_message, unread: unread, size: messages.size } if first_sent_message && unread
    end
    { first_sent_message: first_sent_message, unread: unread, size: messages.size }
  end

  def tree_contains_unread_for_member?(member)
    tree.any? do |message|
      message.can_be_viewed?(member) && message.unread?(member)
    end
  end

  # TODO: Used only in API; should get rid of this.
  def get_next_not_marked_as_deleted(member)
    tree.each do |message|
      return message unless message.deleted?(member)
    end
  end

  def self.send_email_notifications(message_id, notif_type, opts = {}, processing_opts = {})
    message = AbstractMessage.find_by(id: message_id)
    return if message.blank?

    JobLog.compute_with_historical_data(message.receivers, message, notif_type, nil, { base_klass_name: AbstractMessage.name }.merge!(processing_opts)) do |receiver|
      opts.merge!(sender: (message.sender || message.sender_email))
      context_program = message.context_program_for_email
      if context_program.present?
        if [RecentActivityConstants::Type::AUTO_EMAIL_NOTIFICATION, RecentActivityConstants::Type::USER_CAMPAIGN_EMAIL_NOTIFICATION].include?(notif_type)
          receiver_user = receiver.user_in_program(context_program)
          receiver_user.send_email(message, notif_type, opts) if receiver_user.present?
        elsif notif_type == RecentActivityConstants::Type::INBOX_MESSAGE_NOTIFICATION_FOR_TRACK
          # Members without users can also send/receive program-level admin-messages
          ChronusMailer.inbox_message_notification_for_track(receiver, context_program, message, opts).deliver_now
        end
      elsif notif_type == RecentActivityConstants::Type::INBOX_MESSAGE_NOTIFICATION
        receiver.send_email(message, notif_type, opts)
      end
    end
  end

  def get_sender
    if self.sender.present?
      self.for_program? ? self.sender_user : self.sender
    else
      self.sender_email
    end
  end

  def viewer_and_receiver_from_same_program?(receiver_member, viewer_member)
    self.for_organization? || (receiver_member.user_in_program(self.program).present? && viewer_member.user_in_program(self.program).present?)
  end

  def viewer_and_sender_from_same_program?(viewer_member)
    self.for_organization? || (self.sender_user.present? && viewer_member.user_in_program(self.program).present?)
  end

  private

  def self.subtree(node)
    node.children.inject([]) { |res, child|
      res << child
      res += subtree(child)
      res
    }.sort_by(&:id)
  end

  def set_context_program
    return if context_program.present?
    self.context_program = root.context_program if root.present?
  end
end

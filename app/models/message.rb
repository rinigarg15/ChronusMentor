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

class Message < AbstractMessage

  MASS_UPDATE_ATTRIBUTES = {
    create: [:subject, :content, :sender_id, :receiver_ids]
  }

  belongs_to_organization

  has_many :message_receivers,
           dependent: :destroy,
           class_name: "Messages::Receiver",
           foreign_key: "message_id",
           inverse_of: :message
  has_many :receivers,
           through: :message_receivers,
           source: :member

  validates_presence_of :organization
  validates_presence_of :receivers, on: :create
  validates_presence_of :sender_id, on: :create
  validates_presence_of :sender_name, if: Proc.new { |message| message.sender_id.nil? }
  validate :check_sender_from_same_organization

  #-----------------------------------------------------------------------------
  # INSTANCE METHODS
  #-----------------------------------------------------------------------------

  def receiver_ids=(ids)
    receiver_ids = ids.split(",")
    self.receivers = self.organization.members.where(id: receiver_ids)
  end

  def build_reply(member, _options = {})
    reply = self.organization.messages.build(sender: member, parent_id: self.id, subject: self.subject)
    reply.receivers = self.sent_by?(member) ? self.receivers : [self.sender]
    reply
  end

  def can_be_replied?(member, options = {})
    self.can_be_viewed?(member, options) &&
      (self.sent_by?(member) ? self.receivers.present? : self.sender.present?)
  end

  ### The following methods are used for messages to scraps conversion ###
  def participant_member_ids
    @participant_member_ids ||= [self.sender_id, self.receiver_ids].flatten
  end

  def relavant_meetings
    return [] if self.receivers.count > 1

    programs = self.send_progam_level_email? ? [self.context_program_for_email] : self.organization.programs
    participants = [self.sender] + self.receivers
    return [] if participants.include?(nil)

    meetings = []
    programs.each do |program|
      meetings << program.meetings.accepted_meetings.involving(self.sender_id, self.receivers.first.id).non_group_meetings
    end
    meetings = Meeting.upcoming_recurrent_meetings(meetings.flatten)
    meetings = meetings.map{|m| m[:meeting]}
    return meetings
  end

  def relavant_groups
    programs = self.send_progam_level_email? ? [self.context_program_for_email] : self.organization.programs
    relavant_groups = []
    programs.each do |program|
      next unless program.engagement_enabled?

      member_ids = self.participant_member_ids
      next if member_ids.include?(nil)

      users = program.all_users.where(member_id: member_ids)
      next if users.count != participant_member_ids.count

      relavant_groups << Group.active_involving_users(users).select(&:scraps_enabled?)
    end
    relavant_groups.flatten
  end

  def convert_to_scrap(ref_obj)
    ref_obj_type = (ref_obj.is_a?(Group) ? Group : Meeting).name
    self.type = Scrap.name
    self.ref_obj_id = ref_obj.id
    self.ref_obj_type = ref_obj_type
    self.save!
  end

  def attach_to_related_group
    # TODO: Create scraps for all related groups, instead of the first group alone
    group = self.relavant_groups.first
    self.siblings.each do |message|
      message.convert_to_scrap(group)
      # Type is changed, reload will not work
      scrap = AbstractMessage.find(message.id)
      scrap.program_id = group.program_id
      scrap.save!
    end
  end

  def attach_to_related_meetings
    # TODO: Create scraps for all related meetings, instead of the first meeting alone
    meeting = self.relavant_meetings.first
    self.siblings.each do |message|
      message.convert_to_scrap(meeting)
      # Type is changed, reload will not work
      scrap = AbstractMessage.find(message.id)
      scrap.program_id = meeting.program_id
      scrap.save!
    end
  end

  private

  def check_sender_from_same_organization
    if self.organization && self.sender
      if self.organization != self.sender.organization
        self.errors.add(:sender, "activerecord.custom_errors.message.sender_not_program_member".translate)
      end
    end
  end
end
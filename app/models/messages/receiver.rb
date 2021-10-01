# == Schema Information
#
# Table name: abstract_message_receivers
#
#  id              :integer          not null, primary key
#  member_id       :integer
#  message_id      :integer          not null
#  name            :string(255)
#  email           :string(255)
#  status          :integer          default(0)
#  created_at      :datetime
#  updated_at      :datetime
#  api_token       :string(255)
#  message_root_id :integer          default(0), not null
#

class Messages::Receiver < AbstractMessageReceiver
  validates_presence_of :member, :message
  validate :check_receiver_from_same_organization
  validate :check_sender_can_contact_receiver

  def handle_reply_via_email(email_params)
    if !self.deleted? && self.message.present? && self.member.present? && self.member.active?
      self.mark_as_read!
      reply = self.message.build_reply(self.member)
      reply.content = email_params[:content] 
      reply.no_email_notifications = true if email_params[:no_email_notifications]
      reply.save!
      return true
    end
    return false
  end
  
  private

  def check_receiver_from_same_organization
    return unless self.message

    if self.member && self.message.organization != self.member.organization
      self.errors.add(:member, "activerecord.custom_errors.receiver.not_organization_member".translate)
    end
  end

  def check_sender_can_contact_receiver
    # Ignore if sender and receiver are not set.
    return unless self.message && self.message.sender && self.member && self.member.organization

    # A user can reply to a message when the message was sent by mentor.
    return if self.message.reply?

    if !self.message.sender.allowed_to_send_message?(self.member)
      self.errors[:base] << "activerecord.custom_errors.receiver.not_allowed_to_message".translate(member: self.member.name)
    end
  end
end

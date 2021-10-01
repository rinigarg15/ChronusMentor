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

class AdminMessages::Receiver < AbstractMessageReceiver
  scope :sent,      -> { where("email IS NOT NULL OR member_id IS NOT NULL") }
  scope :received,  -> { where("email IS NULL AND member_id IS NULL AND status != ?", AbstractMessageReceiver::Status::DELETED) }

  validates :message, presence: true
  validates :name, :email, presence: true, if: :check_for_presence_of_name_email?
  validates :email, email_format: { generate_message: true, check_mx: false }, if: :check_for_presence_of_name_email?

  def check_for_presence_of_name_email?
    self.member_id.nil? &&
      self.message.present? &&
      self.message.parent.present? &&
      self.message.parent.sender.blank? &&
      self.message.parent.user_to_admin?
  end

  def handle_reply_via_email(email_params)
    parent_message = self.message
    organization = parent_message.for_program? ? parent_message.program.organization : parent_message.program

    replying_member = if parent_message.user_to_admin?
      organization.members.find_by(email: email_params[:sender_email])
    else
      self.member
    end

    # admin -> user replies should have sender_id set
    is_reply_valid = parent_message.admin_to_user? || replying_member.present?
    is_reply_valid &&= (replying_member.blank? || parent_message.can_be_replied?(replying_member))

    if is_reply_valid
      reply = parent_message.build_reply(replying_member, from_inbox: true)
      reply.attributes = { content: email_params[:content], sender_name: self.name, sender_email: self.email }
      reply.no_email_notifications = true if email_params[:no_email_notifications]
      self.mark_as_read!
      reply.save!
      return true
    elsif parent_message.for_program?
      ChronusMailer.reply_to_admin_message_failure_notification(parent_message, email_params[:sender_email], email_params[:subject], email_params[:content]).deliver_now
    end
    return false
  end
end

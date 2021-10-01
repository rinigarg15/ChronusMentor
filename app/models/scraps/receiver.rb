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

class Scraps::Receiver < AbstractMessageReceiver
  ##### Associations #####

  ##### Validations #####
  validates :message, presence: true
  validates :member, presence: true, :on => :create
  validate :check_receiver_from_same_group, :on => :create, if: Proc.new { |receiver| receiver.message.present? && receiver.message.is_group_message? }
  validate :check_receiver_from_same_meeting, :on => :create, if: Proc.new { |receiver| receiver.message.present? && receiver.message.is_meeting_message? }
  
  ##### Instance Methods #####
  def receiver_user
    @receiver_user ||= member.users.find { |user| user.program_id == message.ref_obj.program_id }
  end

  def handle_reply_via_email(email_params)
    if !self.deleted? && self.message.present? && self.member.present? && self.member.active?
      self.mark_as_read!
      if self.message.can_be_replied?(self.member)
        reply = self.message.build_reply(self.member)
        reply.content = email_params[:content]
        reply.no_email_notifications = true if email_params[:no_email_notifications]
        reply.posted_via_email = true
        reply.save!
        return true
      else
        user = self.message.get_user(self.member)
        if user && !user.suspended?
          if self.message.is_group_message?
            ChronusMailer.posting_in_mentoring_area_failure(user, self.message.ref_obj, email_params[:subject], email_params[:content]).deliver_now
          elsif self.message.ref_obj.present?
            ChronusMailer.posting_in_meeting_area_failure(user, self.message.ref_obj, email_params[:subject], email_params[:content]).deliver_now
          end
        end
      end
    end
    return false
  end

private

  def check_receiver_from_same_group
    if member.present?
      return if message.ref_obj.has_member?(receiver_user)
      errors.add(:receiver, "activerecord.custom_errors.scrap.not_member".translate)
    end
  end

  def check_receiver_from_same_meeting
    if member.present?
      return if message.ref_obj.has_member?(member)
      errors.add(:receiver, "activerecord.custom_errors.scrap.not_meeting_member".translate(meeting: self.message.program.term_for(CustomizedTerm::TermType::MEETING_TERM).term_downcase))
    end
  end

end

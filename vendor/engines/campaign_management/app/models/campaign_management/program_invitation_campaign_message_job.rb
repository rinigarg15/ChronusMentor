class CampaignManagement::ProgramInvitationCampaignMessageJob < CampaignManagement::AbstractCampaignMessageJob
 
  belongs_to :campaign_message,
             :foreign_key => "campaign_message_id",
             :class_name => "CampaignManagement::ProgramInvitationCampaignMessage",
             :inverse_of => :jobs

  belongs_to :program_invitation, foreign_key: "abstract_object_id"
  validates :campaign_message, :program_invitation, :run_at, presence: true

  class << self
    def deliver_email(mail_locale, program_invitation_id, campaign_email_id)
      GlobalizationUtils.run_in_locale(mail_locale) do
        program_invitation = ProgramInvitation.find(program_invitation_id)
        campaign_email = CampaignManagement::CampaignEmail.find(campaign_email_id)
        ProgramInvitationCampaignEmailNotification.program_invitation_campaign_email_notification(program_invitation, campaign_email).deliver_now
      end
    end
  end

  # This function doesn't destroy the userjob nor it updates the failed status nor it updates the campaign user status to finished. It is upto the caller to take care of those!
  def create_personalized_message
    begin
      if !self.program_invitation.invitee_already_member?
        email_template = campaign_message.email_template

        email = self.program_invitation.sent_to
        member = self.program_invitation.program.organization.members.find_by(email: email)
        mail_locale = member.present? && !member.dormant? ? Language.for_member(member, self.program_invitation.program) : (program_invitation.locale.try(:to_sym) || I18n.default_locale)

        GlobalizationUtils.run_in_locale(mail_locale) do
          mail = ProgramInvitationCampaignEmailNotification.replace_tags(program_invitation, email_template)
          campaign_email = CampaignManagement::CampaignEmail.create!(:subject => mail[:subject].to_s, :source => mail.body.raw_source.to_s, :campaign_message => campaign_message, :abstract_object_id => program_invitation.id)
          CampaignManagement::ProgramInvitationCampaignMessageJob.delay(queue: DjQueues::HIGH_PRIORITY).deliver_email(mail_locale, program_invitation.id, campaign_email.id)
        end
      else
        program_invitation.update_use_count
      end
     return true

    rescue Exception => e
      Airbrake.notify(e)
      return false
    end
  end

  # We don't need to have validations like whether the program exists or not or whether the template is not valid. They are being taken care of as part of model validations or associations
  private

  def set_abstract_object_type
    self.abstract_object_type = ProgramInvitation.name
  end
end

class CampaignManagement::SurveyCampaignMessageJob < CampaignManagement::AbstractCampaignMessageJob
  belongs_to :campaign_message,
             :foreign_key => "campaign_message_id",
             :class_name => "CampaignManagement::SurveyCampaignMessage",
             :inverse_of => :jobs

  validates :campaign_message, :run_at, presence: true

  def create_personalized_message
    begin
      if can_send_email?
        email_template = campaign_message.email_template
        mail_locale = Language.for_member(abstract_object.user.member, abstract_object.user.program)

        GlobalizationUtils.run_in_locale(mail_locale) do
          mail = SurveyCampaignEmailNotification.replace_tags(abstract_object, email_template)
          campaign_email = CampaignManagement::CampaignEmail.create!(:subject => mail[:subject].to_s, :source => mail.body.raw_source.to_s, :campaign_message => campaign_message, :abstract_object_id => abstract_object.id)
          CampaignManagement::SurveyCampaignMessageJob.delay.deliver_email(abstract_object.id, abstract_object.user.id, campaign_email.id, campaign_message.campaign.survey)
        end
      end
    rescue Exception => e
      Airbrake.notify(e)
      return false
    end
  end

  def can_send_email?
    abstract_object && abstract_object.can_send_campaign_email?
  end

  class << self
    def deliver_email(abstract_object_id, user_id, campaign_email_id, survey)
      abstract_object = survey.campaign.abstract_object_klass.find(abstract_object_id)
      user = User.find(user_id)
      campaign_email = CampaignManagement::CampaignEmail.find(campaign_email_id)
      ChronusMailer.survey_campaign_email_notification(user, abstract_object, campaign_email, survey).deliver_now
      if abstract_object.is_a?(MemberMeeting)
        Push::Base.queued_notify(PushNotification::Type::MEETING_FEEDBACK_REQUEST, abstract_object, user_id: user.id, current_occurrence_time: abstract_object.meeting.occurrences.first, content: campaign_email.subject)
      end
    end
  end

  private

  def set_abstract_object_type
    self.abstract_object_type ||= campaign_message.campaign.abstract_object_klass.name
  end
end
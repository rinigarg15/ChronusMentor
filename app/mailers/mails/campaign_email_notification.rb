class CampaignEmailNotification < ChronusActionMailer::Base
  @mailer_attributes = {
    :uid          => "uf3pz64l", # rand(36**8).to_s(36)
    :title        => Proc.new{"email_translations.campaign_email_notification.title".translate},
    :description  => Proc.new{"email_translations.campaign_email_notification.description".translate},
    :donot_list => true,
    :campaign_id  => CampaignConstants::CAMPAIGN_EMAIL_NOTIFICATION_MAIL_ID
    # Add custom headers here
  }

  include CampaignManagement::CampaignsHelper

  # The caller has to fetch the subject and message like mail[:subject], mail.body.raw_source
  def replace_tags(obj, template)
    set_variables_required_for_mustache_rendering(obj, template)
    subject_content, message_content, template_tags = render_tags(template, options_for_mustache_rendering(template))
    # Longer texts should be passed in body and should not be part of headers
    mail(subject: subject_content, body: message_content, from: "test@example.com", sender: "test@example.com")
  end

  private

  # Inherited classes shoudl implement campaign_management_message_info and set @subject and @content before calling super
  def init_mail
    set_email_subject_and_message_internal_attributes(get_subject_and_content)
    set_custom_data({:campaign => campaign_management_message_info})
  end

end


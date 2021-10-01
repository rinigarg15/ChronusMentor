class SurveyCampaignEmailNotification < CampaignEmailNotification
  @mailer_attributes = {
    :uid          => "hrrsw820", # rand(36**8).to_s(36)
    :title        => Proc.new{"email_translations.campaign_email_notification.title".translate},
    :subject      => Proc.new{"email_translations.campaign_email_notification.subject".translate},
    :description  => Proc.new{"email_translations.campaign_email_notification.description".translate},
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :donot_list   => true,
    :level        => EmailCustomization::Level::PROGRAM
  }

  def survey_campaign_email_notification(user, abstract_object, campaign_email, survey)
    @user = user
    @abstract_object = abstract_object
    @survey = survey
    @campaign_email = campaign_email

    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@user.program)
    set_username(@user, :name_only => true)
    setup_email(@user, :from => :admin)
    super
  end

  def get_subject_and_content
    {:subject => @campaign_email.subject, :content => @campaign_email.source}
  end

  def campaign_management_message_info
    {:message_id => @campaign_email.id, :message_type => "CampaignManagement::CampaignEmail"}
  end

  def set_variables_required_for_mustache_rendering(obj, email_template)
    @abstract_object = obj
    @survey = email_template.campaign_message.campaign.survey
    @email_template = email_template
    @user = @survey.get_user_for_campaign(@abstract_object)
    set_program(@user.program)
    set_username(@user, :name_only => true)
  end

  def options_for_mustache_rendering(email_template)
    {:additional_tags => email_template.campaign_message.campaign.campaign_email_tags.keys}
  end

  self.register!

end


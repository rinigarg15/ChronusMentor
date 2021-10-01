class GroupMentoringOfferNotificationToNewMentee < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'bijcxmrw', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::MENTORING_OFFERS,
    :title        => Proc.new{|program| "email_translations.group_mentoring_offer_notification_to_new_mentee.title_v3".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.group_mentoring_offer_notification_to_new_mentee.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.group_mentoring_offer_notification_to_new_mentee.subject_v1".translate},
    :campaign_id  => CampaignConstants::MENTORING_REQUESTS_OFFERS_MAIL_ID,
    :campaign_id_2  => CampaignConstants::GROUP_MENTORING_OFFER_NOTIFICATION_TO_NEW_MENTEE_MAIL_ID,
    :feature      => FeatureName::OFFER_MENTORING,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :program_settings => Proc.new{|program| program.only_career_based_ongoing_mentoring_enabled? && program.mentor_offer_needs_acceptance?},
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 1
  }

  def group_mentoring_offer_notification_to_new_mentee(mentee, mentor_offer, mentor,  options={})
    @mentor_offer = mentor_offer
    @mentee = mentee
    @mentor = mentor
    @options = options
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@mentor_offer.program)
    set_sender(@options)
    set_username(@mentee)
    setup_email(@mentee, :from => @mentor, :sender_name => @mentor.visible_to?(@mentee) ? mentor_name : nil, message_type: EmailCustomization::MessageType::COMMUNICATION)
    super
    set_layout_options(:program => @program)
  end

  register_tags do
    tag :mentor_name, :description => Proc.new{'email_translations.group_mentoring_offer_notification_to_new_mentee.tags.mentor_name.description'.translate},  :example => Proc.new{'William Smith'} do
      @mentor.name
    end

    tag :url_mentoring_offers, :description => Proc.new{'email_translations.group_mentoring_offer_notification_to_new_mentee.tags.url_mentoring_offers.description'.translate},  :example => Proc.new{'http://www.chronus.com'} do
      mentor_offers_url(:subdomain => @organization.subdomain, :src => 'mail')
    end

    tag :message_content, :description => Proc.new{'email_translations.group_mentoring_offer_notification_to_new_mentee.tags.message_content.description'.translate},  :example => Proc.new{'feature.email.tags.message_from_user_v2_html'.translate(:message => 'email_translations.group_mentoring_offer_notification_to_new_mentee.tags.message_content.example'.translate, :name => 'William Smith')} do
      @mentor_offer.message.present? ? 'feature.email.tags.message_from_user_v2_html'.translate(:message => @mentor_offer.message, :name => mentor_name) : ""
    end

    tag :message_content_as_quote, :description => Proc.new{'email_translations.group_mentoring_offer_notification_to_new_mentee.tags.message_content_as_quote.description'.translate},  :example => Proc.new{'feature.email.tags.message_from_user_v3_html'.translate(:message => 'email_translations.group_mentoring_offer_notification_to_new_mentee.tags.message_content.example'.translate, :name => 'feature.email.tags.mentor_name.example'.translate)} do
      @mentor_offer.message.present? ? 'feature.email.tags.message_from_user_v3_html'.translate(:message => @mentor_offer.message, :name => mentor_name) : ""
    end

    tag :view_offer_button, :description => Proc.new{'email_translations.group_mentoring_offer_notification_to_new_mentee.tags.view_offer_button.description'.translate},  :example => Proc.new{ call_to_action_example('email_translations.group_mentoring_offer_notification_to_new_mentee.button_text'.translate) } do
      call_to_action('email_translations.group_mentoring_offer_notification_to_new_mentee.button_text'.translate, mentor_offers_url(:subdomain => @organization.subdomain, :src => 'mail'))
    end

    tag :mentor_url,  description: Proc.new { "email_translations.group_mentoring_offer_notification_to_new_mentee.tags.mentor_url.description".translate }, example: Proc.new {"http://www.chronus.com"} do
      user_url(@mentor, subdomain: @organization.subdomain, root: @program.root)
    end
  end

  self.register!

end

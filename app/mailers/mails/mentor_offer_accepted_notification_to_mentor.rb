class MentorOfferAcceptedNotificationToMentor < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'iefrbyir', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::MENTORING_OFFERS,
    :title        => Proc.new{|program| "email_translations.mentor_offer_accepted_notification_to_mentor.title_v2".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.mentor_offer_accepted_notification_to_mentor.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.mentor_offer_accepted_notification_to_mentor.subject_v1".translate},
    :campaign_id  => CampaignConstants::MENTORING_REQUESTS_OFFERS_MAIL_ID,
    :campaign_id_2  => CampaignConstants::MENTOR_OFFER_ACCEPTED_NOTIFICATION_TO_MENTOR_MAIL_ID,
    :feature      => FeatureName::OFFER_MENTORING,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :program_settings => Proc.new{|program| program.only_career_based_ongoing_mentoring_enabled? && program.mentor_offer_needs_acceptance?},
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 2
  }

  def mentor_offer_accepted_notification_to_mentor(mentor, mentor_offer, options={})
    @mentor = mentor
    @mentor_offer = mentor_offer
    @group = @mentor_offer.group
    @mentee = @mentor_offer.student
    @options = options
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@mentor_offer.program)
    set_sender(@options)
    set_username(@mentor)
    setup_email(@mentor, :sender_name => @mentor_offer.student.visible_to?(@mentor) ? mentee_name : nil, message_type: EmailCustomization::MessageType::COMMUNICATION)
    super
  end

  register_tags do
    tag :mentee_name, :description => Proc.new{'email_translations.mentor_offer_accepted_notification_to_mentor.tags.mentee_name.description'.translate}, :example => Proc.new{'John Doe'}  do
      @mentor_offer.student.name(:name_only => true)
    end

    tag :url_mentoring_connection, :description => Proc.new{|program| 'email_translations.mentor_offer_accepted_notification_to_mentor.tags.url_mentoring_connection.description_v1'.translate(program.return_custom_term_hash)},  :example => Proc.new{'http://www.chronus.com'} do
      group_url(@group, :subdomain => @organization.subdomain, :src => 'mail')
    end

    tag :url_mentee, :description => Proc.new{"email_translations.mentor_offer_accepted_notification_to_mentor.tags.url_mentee.description".translate}, :example => Proc.new{'http://www.chronus.com'} do
      user_url(@mentee, :subdomain => @organization.subdomain, :root => @program.root)
    end

    tag :mentoring_connection_expiry_date, :description => Proc.new{|program| 'email_translations.mentor_offer_accepted_notification_to_mentor.tags.mentoring_connection_expiry_date.description_v2'.translate(program.return_custom_term_hash)},  :example => Proc.new{'email_translations.mentor_offer_accepted_notification_to_mentor.tags.mentoring_connection_expiry_date.example'.translate} do
      formatted_time_in_words(@group.expiry_time, :no_ago => true, :no_time => true)
    end

    tag :group_name, :description => Proc.new{'email_translations.mentor_offer_accepted_notification_to_mentor.tags.group_name.description'.translate}, :example => Proc.new{'email_translations.mentor_offer_accepted_notification_to_mentor.tags.group_name.example'.translate} do
      @group.name
    end

    tag :visit_mentoring_area_button, :description => Proc.new{'email_translations.mentor_offer_accepted_notification_to_mentor.tags.visit_mentoring_area_button.description'.translate}, :example => Proc.new{|program| call_to_action_example('email_translations.mentor_offer_accepted_notification_to_mentor.button_text'.translate(mentoring_connection: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase)) } do
      call_to_action('email_translations.mentor_offer_accepted_notification_to_mentor.button_text'.translate(mentoring_connection: @_mentoring_connection_string), group_url(@group, :subdomain => @organization.subdomain, :src => 'mail'))
    end
  end

  self.register!

end

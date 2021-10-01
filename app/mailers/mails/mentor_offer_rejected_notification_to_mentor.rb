class MentorOfferRejectedNotificationToMentor < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'fbtnsqk9', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::MENTORING_OFFERS,
    :title        => Proc.new{|program| "email_translations.mentor_offer_rejected_notification_to_mentor.title_v4".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.mentor_offer_rejected_notification_to_mentor.description_v3".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.mentor_offer_rejected_notification_to_mentor.subject_v1".translate},
    :campaign_id  => CampaignConstants::MENTORING_REQUESTS_OFFERS_MAIL_ID,
    :campaign_id_2  => CampaignConstants::MENTOR_OFFER_REJECTED_NOTIFICATION_TO_MENTOR_MAIL_ID,
    :feature      => FeatureName::OFFER_MENTORING,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :program_settings => Proc.new{|program| program.only_career_based_ongoing_mentoring_enabled? && program.mentor_offer_needs_acceptance?},
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 3
  }

  def mentor_offer_rejected_notification_to_mentor(mentor, mentor_offer, options={})
    @mentor = mentor
    @mentor_offer = mentor_offer
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
    tag :mentee_name, :description => Proc.new{'email_translations.mentor_offer_rejected_notification_to_mentor.tags.mentee_name.description'.translate}, :example => Proc.new{'John Doe'} do
      @mentor_offer.student.name
    end

    tag :url_mentees_list, :description => Proc.new{'email_translations.mentor_offer_rejected_notification_to_mentor.tags.url_mentees_list.description'.translate},  :example => Proc.new{'http://www.chronus.com'} do
      users_url(:view => RoleConstants::STUDENT_NAME, :subdomain => @organization.subdomain)
    end

    tag :rejection_response, :description => Proc.new{'email_translations.mentor_offer_rejected_notification_to_mentor.tags.rejection_response.description'.translate},  :example => Proc.new{'feature.email.tags.message_from_user_v3_html'.translate(:message => 'email_translations.mentor_offer_rejected_notification_to_mentor.tags.rejection_response.example'.translate, :name => 'John Doe')} do
      @mentor_offer.response.present? ? 'feature.email.tags.message_from_user_v3_html'.translate(:message => @mentor_offer.response, :name => mentee_name) : ""
    end

    tag :view_mentees_button, :description => Proc.new{'email_translations.mentor_offer_rejected_notification_to_mentor.tags.view_mentees_button.description'.translate}, :example => Proc.new{ |program| call_to_action_example('email_translations.mentor_offer_rejected_notification_to_mentor.button_text'.translate(mentees: program.find_role(RoleConstants::STUDENT_NAME).customized_term.pluralized_term_downcase)) } do
     call_to_action('email_translations.mentor_offer_rejected_notification_to_mentor.button_text'.translate(mentees: @_mentees_string), users_url(:view => RoleConstants::STUDENT_NAME, :subdomain => @organization.subdomain))
    end

    tag :url_contact_admin, :description => Proc.new{'email_translations.mentor_offer_rejected_notification_to_mentor.tags.url_contact_admin.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      get_contact_admin_path(@user.program, url_params: { subdomain: @organization.subdomain, root: @user.program.root }, only_url: true)
    end

    tag :mentee_url, :description => Proc.new{'email_translations.mentor_offer_rejected_notification_to_mentor.tags.mentee_url.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      user_url(@mentor_offer.student, subdomain: @organization.subdomain, :root => @program.root)
    end        
  end
  
  self.register!

end

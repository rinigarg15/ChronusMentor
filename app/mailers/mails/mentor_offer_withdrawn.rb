class MentorOfferWithdrawn < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'y6kt8uri', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::MENTORING_OFFERS,
    :title        => Proc.new{|program| "email_translations.mentor_offer_withdrawn.title_v2".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.mentor_offer_withdrawn.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.mentor_offer_withdrawn.subject_v1".translate},
    :campaign_id  => CampaignConstants::MENTORING_REQUESTS_OFFERS_MAIL_ID,
    :feature      => FeatureName::OFFER_MENTORING,
    :program_settings => Proc.new{|program| program.only_career_based_ongoing_mentoring_enabled? && program.mentor_offer_needs_acceptance?},
    :campaign_id_2  => CampaignConstants::MENTOR_OFFER_WITHDRAWN_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 4
  }

  def mentor_offer_withdrawn(receiver, mentor_offer, options={})
    @receiver = receiver
    @mentor_offer = mentor_offer
    @mentor = mentor_offer.mentor
    @options = options
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@mentor_offer.program)
    set_sender(@options)
    set_username(@receiver, :name_only => true)
    setup_email(@receiver, :from => @mentor.name, :sender_name => @mentor.visible_to?(@receiver) ? mentor_name : nil, message_type: EmailCustomization::MessageType::COMMUNICATION)
    super
    set_layout_options(:show_change_notif_link => true)
  end

  register_tags do
    tag :mentor_name, :description => Proc.new{'email_translations.mentor_offer_withdrawn.tags.mentor_name.description'.translate}, :example => Proc.new{'John Doe'} do
      @mentor.name
    end

    tag :message_from_mentor, :description => Proc.new{'email_translations.mentor_offer_withdrawn.tags.message_from_mentor.description'.translate}, :example => Proc.new{'feature.email.tags.message_from_user_v3_html'.translate(:message => 'email_translations.mentor_offer_withdrawn.tags.message_from_mentor.example'.translate, :name => 'feature.email.tags.mentor_name.example'.translate)} do
      @mentor_offer.response.present? ? 'feature.email.tags.message_from_user_v3_html'.translate(:message => @mentor_offer.response, :name => mentor_name) : ""
    end

    tag :view_mentors_button, :description => Proc.new{'email_translations.mentor_offer_withdrawn.tags.view_mentors_button.description'.translate}, :example => Proc.new{ |program| call_to_action_example("email_translations.mentor_offer_withdrawn.tags.view_mentors_button.view_mentors".translate(Mentors: program.find_role(RoleConstants::MENTOR_NAME).customized_term.pluralized_term)) } do
      call_to_action("email_translations.mentor_offer_withdrawn.tags.view_mentors_button.view_mentors".translate(Mentors: @_Mentors_string), users_url(:subdomain => @organization.subdomain, src: EngagementIndex::Src::BrowseMentors::EMAIL))
    end

    tag :mentor_url, :description => Proc.new{'email_translations.mentor_offer_withdrawn.tags.mentor_url.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      user_url(@mentor, subdomain: @organization.subdomain, root: @program.root)
    end

    tag :url_contact_admin, :description => Proc.new{'email_translations.mentor_offer_withdrawn.tags.url_contact_admin.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      get_contact_admin_path(@user.program, url_params: { subdomain: @organization.subdomain, root: @user.program.root }, only_url: true)
    end    
  end

  self.register!

end

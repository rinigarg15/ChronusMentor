class GroupMentoringOfferAddedNotificationToNewMentee < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'm09w0a8a', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::MENTORING_OFFERS,
    :title        => Proc.new{|program| "email_translations.group_mentoring_offer_added_notification_to_new_mentee.title_v2".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.group_mentoring_offer_added_notification_to_new_mentee.description_v1".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.group_mentoring_offer_added_notification_to_new_mentee.subject_v1".translate},
    :campaign_id  => CampaignConstants::MENTORING_CONNECTION_MAIL_ID,
    :campaign_id_2  => CampaignConstants::GROUP_MENTORING_OFFER_ADDED_NOTIFICATION_TO_NEW_MENTEE_MAIL_ID,
    :feature      => FeatureName::OFFER_MENTORING,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :program_settings => Proc.new{|program| program.only_career_based_ongoing_mentoring_enabled? && !program.mentor_offer_needs_acceptance?},
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 7
  }

  def group_mentoring_offer_added_notification_to_new_mentee(mentee, group, mentor, options={})
    @group = group
    @mentors = group.mentors
    @mentee = mentee
    @mentor = mentor
    @options = options
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@group.program)
    set_sender(@options)
    set_username(@mentee)
    setup_email(@mentee, :from => @mentor, :sender_name => @mentor.visible_to?(@mentee) ? mentor_name : nil, message_type: EmailCustomization::MessageType::COMMUNICATION)
    super
    set_layout_options(:program => @program)
  end

  register_tags do
    tag :mentor_name, :description => Proc.new{'email_translations.group_mentoring_offer_added_notification_to_new_mentee.tags.mentor_name.description'.translate}, :example => Proc.new{'William Smith'} do
      @mentor.name
    end

    tag :url_mentoring_connection, :description => Proc.new{|program| 'email_translations.group_mentoring_offer_added_notification_to_new_mentee.tags.url_mentoring_connection.description_v1'.translate(program.return_custom_term_hash)}, :example => Proc.new{'http://www.chronus.com'} do
      @group_url = group_url(@group, :subdomain => @organization.subdomain, :src => 'mail')
    end

    tag :message_content, :description => Proc.new{'email_translations.group_mentoring_offer_added_notification_to_new_mentee.tags.message_content.description'.translate}, :example => Proc.new{|program| 'feature.email.tags.message_from_user_v3_html'.translate(:message => 'email_translations.group_mentoring_offer_added_notification_to_new_mentee.tags.message_content.example_v1'.translate(program.return_custom_term_hash), :name => 'William Smith')} do
      @group.message.present? ? 'feature.email.tags.message_from_user_v3_html'.translate(:message => @group.message, :name => mentor_name) : ""
    end

    tag :mentoring_connection_expiry_date, :description => Proc.new{|program| 'email_translations.group_mentoring_offer_added_notification_to_new_mentee.tags.mentoring_connection_expiry_date.description_v2'.translate(program.return_custom_term_hash)}, :example => Proc.new{'email_translations.group_mentoring_offer_added_notification_to_new_mentee.tags.mentoring_connection_expiry_date.example'.translate} do
      formatted_time_in_words(@group.expiry_time, :no_ago => true, :no_time => true)
    end

    tag :group_name, :description => Proc.new{'email_translations.group_mentoring_offer_added_notification_to_new_mentee.tags.group_name.description'.translate}, :example => Proc.new{'email_translations.group_mentoring_offer_added_notification_to_new_mentee.tags.group_name.example'.translate} do
      @group.name
    end

    tag :mentor_or_mentors_term, :description => Proc.new{'email_translations.group_mentoring_offer_added_notification_to_new_mentee.tags.mentor_or_mentors_term.description'.translate}, :example => Proc.new{'email_translations.group_mentoring_offer_added_notification_to_new_mentee.tags.mentor_or_mentors_term.example'.translate} do
      @mentors.size > 1 ? customized_mentors_term : customized_mentor_term
    end

    tag :visit_mentoring_area_button, :description => Proc.new{'email_translations.group_mentoring_offer_added_notification_to_new_mentee.tags.visit_mentoring_area_button.description'.translate}, :example => Proc.new{|program| call_to_action_example('email_translations.group_mentoring_offer_added_notification_to_new_mentee.button_text'.translate(mentoring_connection: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase)) } do
       call_to_action('email_translations.group_mentoring_offer_added_notification_to_new_mentee.button_text'.translate(mentoring_connection: @_mentoring_connection_string), group_url(@group, :subdomain => @organization.subdomain, :src => 'mail'))
    end   

    tag :url_contact_admin, description: Proc.new { "email_translations.group_mentoring_offer_added_notification_to_new_mentee.tags.url_contact_admin.description".translate }, example: Proc.new { "http://www.chronus.com" } do
      get_contact_admin_path(@program, url_params: { subdomain: @organization.subdomain, root: @program.root }, only_url: true)
    end

    tag :mentor_url,  description: Proc.new { "email_translations.group_mentoring_offer_added_notification_to_new_mentee.tags.mentor_url.description".translate }, example: Proc.new {"http://www.chronus.com"} do
      user_url(@mentor, subdomain: @organization.subdomain, root: @program.root)
    end      
  end

  self.register!

end

class MentorRequestClosedForSender < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'jdy6ndzb', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::MENTOR_REQUEST_RELATED,
    :title        => Proc.new{|program| "email_translations.mentor_request_closed_for_sender.title_v2".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.mentor_request_closed_for_sender.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.mentor_request_closed_for_sender.subject_v2".translate},
    :campaign_id  => CampaignConstants::MENTORING_REQUESTS_OFFERS_MAIL_ID,
    :program_settings => Proc.new{|program| program.only_career_based_ongoing_mentoring_enabled? && program.matching_by_mentee_alone?},
    :campaign_id_2  => CampaignConstants::MENTOR_REQUEST_CLOSED_FOR_SENDER_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :level        => EmailCustomization::Level::PROGRAM,
    :for_role_names => [RoleConstants::STUDENT_NAME],
    :listing_order => 9
  }

  def mentor_request_closed_for_sender(student, mentor_request, options = {})
    @student = student
    @mentor_request = mentor_request
    @program = mentor_request.program
    @mentor = mentor_request.mentor
    @closed_by = @mentor_request.closed_by
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@program)
    set_username(@student, :name_only => true)
    setup_email(@student, :from => :admin, :sender_name => @closed_by && @closed_by.visible_to?(@student) ? @closed_by.name(:name_only => true) : nil)
    super
    set_layout_options(:show_change_notif_link => true)
  end

  register_tags do
    tag :recipient_name, :description => Proc.new{'email_translations.mentor_request_closed_for_sender.tags.recipient_name.description'.translate}, :example => Proc.new{'email_translations.mentor_request_closed_for_sender.tags.recipient_name.example'.translate} do
      @mentor.name
    end

    tag :url_mentors_listing, :description => Proc.new{'email_translations.mentor_request_closed_for_sender.tags.url_mentors_listing.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      users_url(:subdomain => @organization.subdomain, src: EngagementIndex::Src::BrowseMentors::EMAIL)
    end

    tag :message_from_admin, :description => Proc.new{'email_translations.mentor_request_closed_for_sender.tags.message_from_admin.description'.translate}, :example => Proc.new{'email_translations.mentor_request_closed_for_sender.tags.message_from_admin.example_v1'.translate} do
      @mentor_request.response_text.presence || ""
    end

    tag :message_from_admin_as_quote, :description => Proc.new{'email_translations.mentor_request_closed_for_sender.tags.message_from_admin_as_quote.description'.translate}, :example => Proc.new{'feature.email.tags.message_from_user_v3_html'.translate(:message => 'email_translations.mentor_request_closed_for_sender.tags.message_from_admin.example_v1'.translate, :name => 'email_translations.mentor_request_closed_for_sender.tags.admin_name.example'.translate)} do
      @mentor_request.response_text.present? ? 'feature.email.tags.message_from_user_v3_html'.translate( :message => @mentor_request.response_text, :name => @closed_by.present? ? @closed_by.name : @organization.admin_custom_term.term ) : ""
    end

    tag :admin_name, :description => Proc.new{'email_translations.mentor_request_closed_for_sender.tags.admin_name.description'.translate}, :example => Proc.new{'email_translations.mentor_request_closed_for_recipient.tags.admin_name.example'.translate} do
      @closed_by.name(:name_only => true)
    end

    tag :view_mentors_button, :description => Proc.new{'email_translations.mentor_request_closed_for_sender.tags.view_mentors_button.description'.translate}, :example => Proc.new{ |program| call_to_action_example("email_translations.mentor_request_closed_for_sender.tags.view_mentors_button.view_mentors".translate(Mentors: program.find_role(RoleConstants::MENTOR_NAME).customized_term.pluralized_term)) } do
      call_to_action("email_translations.mentor_request_closed_for_sender.tags.view_mentors_button.view_mentors".translate(Mentors: @_Mentors_string), users_url(:subdomain => @organization.subdomain, src: EngagementIndex::Src::BrowseMentors::EMAIL))
    end

    tag :mentor_url,  description: Proc.new { "email_translations.mentor_request_closed_for_sender.tags.mentor_url.description".translate }, example: Proc.new {"http://www.chronus.com"} do
      user_url(@mentor, subdomain: @organization.subdomain, root: @program.root)
    end

    tag :url_contact_admin, :description => Proc.new{'email_translations.mentor_request_closed_for_sender.tags.url_contact_admin.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      get_contact_admin_path(@user.program, url_params: { subdomain: @organization.subdomain, root: @user.program.root }, only_url: true)
    end    
  end

  self.register!

end

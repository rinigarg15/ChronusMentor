class MeetingRequestClosedForSender < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => '4sj7apa8', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::MEETING_REQUEST_RELATED,
    :title        => Proc.new{|program| "email_translations.meeting_request_closed_for_sender.title_v2".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.meeting_request_closed_for_sender.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.meeting_request_closed_for_sender.subject_v2".translate},
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :feature      => FeatureName::CALENDAR,
    :campaign_id  => CampaignConstants::MEETING_REQUEST_CLOSED_FOR_SENDER_MAIL_ID,
    :level        => EmailCustomization::Level::PROGRAM,
    :for_role_names => [RoleConstants::STUDENT_NAME],
    :listing_order => 12
  }

  def meeting_request_closed_for_sender(student, meeting_request, options = {})
    @student = student
    @meeting_request = meeting_request
    @program = meeting_request.program
    @mentor = meeting_request.mentor
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@program)
    set_username(@student, :name_only => true)
    setup_email(@student, :from => :admin)
    super
    set_layout_options(:show_change_notif_link => true)
  end

  register_tags do
    tag :recipient_name, :description => Proc.new{'email_translations.meeting_request_closed_for_sender.tags.recipient_name.description'.translate}, :example => Proc.new{'William Smith'} do
      @mentor.name
    end

    tag :url_mentors_listing, :description => Proc.new{'email_translations.meeting_request_closed_for_sender.tags.url_mentors_listing.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      users_url(:subdomain => @organization.subdomain, src: EngagementIndex::Src::BrowseMentors::EMAIL)
    end

    tag :message_from_admin, :description => Proc.new{'email_translations.meeting_request_closed_for_sender.tags.message_from_admin.description'.translate}, :example => Proc.new{'email_translations.meeting_request_closed_for_sender.tags.message_from_admin.example'.translate} do
      @meeting_request.response_text || ""
    end

    tag :message_from_admin_as_quote, :description => Proc.new{'email_translations.meeting_request_closed_for_sender.tags.message_from_admin_as_quote.description'.translate}, :example => Proc.new{'feature.email.tags.message_from_user_v3_html'.translate(:message => 'email_translations.meeting_request_closed_for_sender.tags.message_from_admin.example'.translate, :name => 'feature.email.tags.mentor_name.example'.translate)} do
      word_wrap(@meeting_request.response_text.present? ? 'feature.email.tags.message_from_user_v3_html'.translate( :message => @meeting_request.response_text, :name => @meeting_request.closed_by.present? ? @meeting_request.closed_by.name : @organization.admin_custom_term.term ) : "").html_safe
    end

    tag :url_contact_admin, :description => Proc.new{'email_translations.meeting_request_closed_for_sender.tags.url_contact_admin.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      get_contact_admin_path(@mentor.program, url_params: { subdomain: @organization.subdomain, root: @mentor.program.root }, only_url: true)
    end
  end

  self.register!

end

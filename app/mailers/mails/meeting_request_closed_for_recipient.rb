class MeetingRequestClosedForRecipient < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'pn12h6i5', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::MEETING_REQUEST_RELATED,
    :title        => Proc.new{|program| "email_translations.meeting_request_closed_for_recipient.title_v2".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.meeting_request_closed_for_recipient.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.meeting_request_closed_for_recipient.subject_v2".translate},
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :feature      => FeatureName::CALENDAR,
    :campaign_id  => CampaignConstants::MEETING_REQUEST_CLOSED_FOR_RECIPIENT_MAIL_ID,
    :level        => EmailCustomization::Level::PROGRAM,
    :for_role_names => [RoleConstants::MENTOR_NAME],
    :listing_order => 13
  }

  def meeting_request_closed_for_recipient(mentor, meeting_request, options = {})
    @mentor = mentor
    @meeting_request = meeting_request
    @program = meeting_request.program
    @sender = meeting_request.student
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@program)
    set_username(@mentor, :name_only => true)
    setup_email(@mentor, :from => :admin)
    super
    set_layout_options(:show_change_notif_link => true)
  end

  register_tags do
    tag :sender_name, :description => Proc.new{'email_translations.meeting_request_closed_for_recipient.tags.sender_name.description'.translate}, :example => Proc.new{'William Smith'} do
      @sender.name
    end

    tag :message_from_admin, :description => Proc.new{'email_translations.meeting_request_closed_for_recipient.tags.message_from_admin.description'.translate}, :example => Proc.new{'email_translations.meeting_request_closed_for_recipient.tags.message_from_admin.example'.translate} do
      @meeting_request.response_text || ""
    end

    tag :message_from_admin_as_quote, :description => Proc.new{'email_translations.meeting_request_closed_for_recipient.tags.message_from_admin_as_quote.description'.translate}, :example => Proc.new{'feature.email.tags.message_from_user_v3_html'.translate(:message => 'email_translations.meeting_request_closed_for_recipient.tags.message_from_admin.example'.translate, :name => 'feature.email.tags.mentor_name.example'.translate)} do
      word_wrap(@meeting_request.response_text.present? ? 'feature.email.tags.message_from_user_v3_html'.translate(:message => @meeting_request.response_text, :name => @meeting_request.closed_by.name) : "").html_safe
    end

    tag :url_contact_admin, :description => Proc.new{'email_translations.meeting_request_closed_for_recipient.tags.url_contact_admin.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      get_contact_admin_path(@mentor.program, url_params: { subdomain: @organization.subdomain, root: @mentor.program.root }, only_url: true)
    end
  end

  self.register!

end

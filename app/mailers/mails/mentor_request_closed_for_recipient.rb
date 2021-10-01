class MentorRequestClosedForRecipient < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'qfeyv0or', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::MENTOR_REQUEST_RELATED,
    :title        => Proc.new{|program| "email_translations.mentor_request_closed_for_recipient.title_v2".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.mentor_request_closed_for_recipient.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.mentor_request_closed_for_recipient.subject_v2".translate},
    :campaign_id  => CampaignConstants::MENTORING_REQUESTS_OFFERS_MAIL_ID,
    :program_settings => Proc.new{|program| program.only_career_based_ongoing_mentoring_enabled? && program.matching_by_mentee_alone?},
    :campaign_id_2  => CampaignConstants::MENTOR_REQUEST_CLOSED_FOR_RECIPIENT_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :level        => EmailCustomization::Level::PROGRAM,
    :for_role_names => [RoleConstants::MENTOR_NAME],
    :listing_order => 8
  }

  def mentor_request_closed_for_recipient(mentor, mentor_request, options = {})
    @mentor = mentor
    @mentor_request = mentor_request
    @program = mentor_request.program
    @sender = mentor_request.student
    @closed_by = @mentor_request.closed_by
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@program)
    set_username(@mentor, :name_only => true)
    setup_email(@mentor, :from => :admin, :sender_name => @closed_by && @closed_by.visible_to?(@mentor) ? @closed_by.name(:name_only => true) : nil)
    super
    set_layout_options(:show_change_notif_link => true)
  end

  register_tags do
    tag :sender_name, :description => Proc.new{'email_translations.mentor_request_closed_for_recipient.tags.sender_name.description'.translate}, :example => Proc.new{'email_translations.mentor_request_closed_for_recipient.tags.sender_name.example'.translate} do
      @sender.name
    end

    tag :message_from_admin, :description => Proc.new{'email_translations.mentor_request_closed_for_recipient.tags.message_from_admin.description'.translate}, :example => Proc.new{'email_translations.mentor_request_closed_for_recipient.tags.message_from_admin.example_v1'.translate} do
      @mentor_request.response_text.presence || ""
    end

    tag :message_from_admin_as_quote, :description => Proc.new{'email_translations.mentor_request_closed_for_recipient.tags.message_from_admin_as_quote.description'.translate}, :example => Proc.new{'feature.email.tags.message_from_user_v3_html'.translate(:message => 'email_translations.mentor_request_closed_for_recipient.tags.message_from_admin.example_v1'.translate, :name => 'email_translations.mentor_request_closed_for_recipient.tags.admin_name.example'.translate)} do
      @mentor_request.response_text.present? ? 'feature.email.tags.message_from_user_v3_html'.translate(:message => @mentor_request.response_text, :name => @closed_by.name) : ""
    end

    tag :url_contact_admin, :description => Proc.new{'email_translations.mentor_request_closed_for_recipient.tags.url_contact_admin.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      get_contact_admin_path(@mentor.program, {:only_url => true, :url_params => {:subdomain => @organization.subdomain, :root => @mentor.program.root}})
    end

    tag :sender_url, :description => Proc.new{'email_translations.mentor_request_closed_for_recipient.tags.sender_name.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      user_url(@sender, subdomain: @organization.subdomain, root: @program.root)
    end    
  end

  self.register!

end

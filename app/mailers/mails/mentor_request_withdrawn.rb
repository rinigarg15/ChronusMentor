class MentorRequestWithdrawn < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => '9g6rmlz', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::MENTOR_REQUEST_RELATED,
    :title        => Proc.new{|program| "email_translations.mentor_request_withdrawn.title_v3".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.mentor_request_withdrawn.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.mentor_request_withdrawn.subject_v2".translate},
    :campaign_id  => CampaignConstants::MENTORING_REQUESTS_OFFERS_MAIL_ID,
    :program_settings => Proc.new{|program| program.only_career_based_ongoing_mentoring_enabled? && program.matching_by_mentee_alone? && program.allow_mentee_withdraw_mentor_request?},
    :campaign_id_2  => CampaignConstants::MENTOR_REQUEST_WITHDRAWN_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 7
  }

  def mentor_request_withdrawn(receiver, mentor_request, options)
    @receiver = receiver
    @mentor_request = mentor_request
    @student = mentor_request.student
    @options = options
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@mentor_request.program)
    set_sender(@options)
    set_username(@receiver, :name_only => true)
    setup_email(@receiver, :from => @student.name, :sender_name => @student.visible_to?(@receiver) ? mentee_name : nil, message_type: EmailCustomization::MessageType::COMMUNICATION)
    super
    set_layout_options(:show_change_notif_link => true)
  end

  register_tags do
    tag :mentee_name, :description => Proc.new{'email_translations.mentor_request_withdrawn.tags.mentee_name.description'.translate}, :example => Proc.new{'email_translations.mentor_request_withdrawn.tags.mentee_name.example'.translate} do
      @student.name
    end

    tag :message_from_mentee, :description => Proc.new{'email_translations.mentor_request_withdrawn.tags.message_from_mentee.description_v1'.translate}, :example => Proc.new{'feature.email.tags.message_from_user_v3_html'.translate(:message => 'email_translations.mentor_request_withdrawn.tags.message_from_mentee.example'.translate, :name => 'email_translations.mentor_request_withdrawn.tags.mentee_name.example'.translate)} do
      @mentor_request.response_text.present? ? 'feature.email.tags.message_from_user_v3_html'.translate(:message => @mentor_request.response_text, :name => mentee_name) : ""
    end

    tag :url_contact_admin, :description => Proc.new{'email_translations.mentor_request_withdrawn.tags.url_contact_admin.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      get_contact_admin_path(@program, url_params: { subdomain: @organization.subdomain, root: @program.root }, only_url: true)
    end
  end

  self.register!

end

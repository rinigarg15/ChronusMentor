class NewMentorRequestToAdmin < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'aysy1t7x', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::MENTOR_REQUEST_RELATED,
    :title        => Proc.new{|program| "email_translations.new_mentor_request_to_admin.title_v3".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.new_mentor_request_to_admin.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.new_mentor_request_to_admin.subject_v1".translate},
    :campaign_id  => CampaignConstants::MENTORING_REQUESTS_OFFERS_MAIL_ID,
    :program_settings => Proc.new{|program| program.only_career_based_ongoing_mentoring_enabled? && program.allow_mentoring_requests? && program.matching_by_mentee_and_admin?},
    :campaign_id_2  => CampaignConstants::NEW_MENTOR_REQUEST_TO_ADMIN_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 4,
    :notification_setting => UserNotificationSetting::SettingNames::PROGRAM_MANAGEMENT
  }

  def new_mentor_request_to_admin(receiver, mentor_request, options)
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
  end

  register_tags do
    tag :message_to_admin, :description => Proc.new{ 'email_translations.new_mentor_request_to_admin.tags.message_to_admin.description'.translate }, :example => Proc.new{ 'feature.email.tags.message_from_user_v3_html'.translate(:message => 'email_translations.new_mentor_request_to_admin.tags.message_to_admin.example'.translate, :name => 'email_translations.new_mentor_request_to_admin.tags.mentee_name.example'.translate) } do
      word_wrap(@mentor_request.message.present? ? 'feature.email.tags.message_from_user_v3_html'.translate(:message => @mentor_request.message, :name => @student.name) : "").html_safe
    end

    tag :mentee_name, :description => Proc.new{'email_translations.new_mentor_request_to_admin.tags.mentee_name.description'.translate}, :example => Proc.new{'email_translations.new_mentor_request_to_admin.tags.mentee_name.example'.translate} do
      @student.name
    end

    tag :url_mentor_requests_listing, :description => Proc.new{'email_translations.new_mentor_request_to_admin.tags.url_mentor_requests_listing.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      mentor_requests_url(:subdomain => @organization.subdomain, :src => "email", :mentor_request_id => @mentor_request.id)
    end
  end

  self.register!

end

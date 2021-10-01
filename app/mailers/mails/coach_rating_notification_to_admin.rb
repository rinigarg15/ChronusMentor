class CoachRatingNotificationToAdmin < ChronusActionMailer::Base
  @mailer_attributes = {
    :uid          => 'i74nspv0', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::MENTORING_CONNECTIONS_NOTIFICATION,
    :title        => Proc.new{|program| "email_translations.coach_rating_notification_to_admin.title_v1".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.coach_rating_notification_to_admin.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.coach_rating_notification_to_admin.subject".translate},
    :feature      => FeatureName::COACH_RATING,
    :user_states  => [User::Status::ACTIVE],
    :program_settings => Proc.new{|program| program.only_career_based_ongoing_mentoring_enabled? || program.project_based?},
    :campaign_id  => CampaignConstants::COACH_RATING_NOTIFICATION_TO_ADMIN_MAIL_ID,
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 6,
    :notification_setting => UserNotificationSetting::SettingNames::PROGRAM_MANAGEMENT
  }  


  def coach_rating_notification_to_admin(admin, response, options={})
    @admin = admin
    @response = response
    @mentee = @response.rating_giver
    @mentor = @response.rating_receiver
    @program = @admin.program
    @options = options
    init_mail
    render_mail
  end

  def init_mail
    set_program(@program)
    set_sender(@options)
    set_username(@admin)
    setup_email(@admin, message_type: EmailCustomization::MessageType::COMMUNICATION)
    super
  end

  register_tags do
    tag :mentor_name, :description => Proc.new{"email_translations.coach_rating_notification_to_admin.tags.mentor_name.description".translate}, :example => Proc.new{"feature.email.tags.mentor_name.example".translate} do
      @mentor.first_name
    end

    tag :mentee_name, :description => Proc.new{"email_translations.coach_rating_notification_to_admin.tags.mentee_name.description".translate}, :example => Proc.new{"feature.email.tags.mentee_name.example".translate} do
      @mentee.first_name
    end

    tag :url_mentor, :description => Proc.new{"email_translations.coach_rating_notification_to_admin.tags.url_mentor.description".translate}, :example => Proc.new{"email_translations.coach_rating_notification_to_admin.tags.url_mentor.example".translate} do
      member_url(@mentor.member, :subdomain => @organization.subdomain, :root => @program.root)
    end

    tag :url_mentee, :description => Proc.new{"email_translations.coach_rating_notification_to_admin.tags.url_mentee.description".translate}, :example => Proc.new{"email_translations.coach_rating_notification_to_admin.tags.url_mentee.example".translate} do
      member_url(@mentee.member, :subdomain => @organization.subdomain, :root => @program.root)
    end

    tag :url_mentor_review, :description => Proc.new{"email_translations.coach_rating_notification_to_admin.tags.url_mentor_review.description".translate}, :example => Proc.new{"email_translations.coach_rating_notification_to_admin.tags.url_mentor_review.example".translate} do
      member_url(@mentor.member, :subdomain => @organization.subdomain, :root => @program.root, :show_reviews => true)
    end

    tag :rating, :description => Proc.new{"email_translations.coach_rating_notification_to_admin.tags.rating.description".translate}, :example => Proc.new{'3.5'} do
      @response.rating
    end

    # not handling configurable answers here.. that needs to be handle if required in future.
    tag :comments, :description => Proc.new{"email_translations.coach_rating_notification_to_admin.tags.comments.description".translate}, :example => Proc.new{"email_translations.coach_rating_notification_to_admin.tags.comments.example".translate} do
      @response.answers.first.present? ? @response.answers.first.answer_text : '-'
    end

    tag :view_rating_button, :description => Proc.new{"email_translations.coach_rating_notification_to_admin.tags.view_rating_button.description".translate}, :example => Proc.new{ call_to_action_example('email_translations.coach_rating_notification_to_admin.button_text'.translate) } do
      call_to_action('email_translations.coach_rating_notification_to_admin.button_text'.translate, member_url(@mentor.member, :subdomain => @organization.subdomain, :root => @program.root, :show_reviews => true))
    end
  end

  self.register!

end
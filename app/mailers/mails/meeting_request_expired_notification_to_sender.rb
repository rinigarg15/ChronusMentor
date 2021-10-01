class MeetingRequestExpiredNotificationToSender < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => '2e8w4uhi', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::MEETING_REQUEST_RELATED,
    :title        => Proc.new{|program| "email_translations.meeting_request_expired_notification_to_sender.title_v2".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.meeting_request_expired_notification_to_sender.description_v3".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.meeting_request_expired_notification_to_sender.subject_v3".translate},
    :feature      => FeatureName::CALENDAR,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :program_settings => Proc.new{ |program| program.meeting_request_auto_expiration_days.present? },
    :campaign_id  => CampaignConstants::MEETING_REQUEST_EXPIRED_NOTIFICATION_TO_SENDER_MAIL_ID,
    :level        => EmailCustomization::Level::PROGRAM,
    :other_registered_tags => [:recommended_mentors_tag, :admin_and_mentor_url_tags],
    :listing_order => 14
  }

  def meeting_request_expired_notification_to_sender(sender, meeting_request)
    @sender = sender
    @mentee = sender
    @request = meeting_request
    @meeting_request = meeting_request
    @mentor = @meeting_request.mentor
    @program = @meeting_request.program
    @max_pending_duration = @program.meeting_request_auto_expiration_days
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@program)
    set_username(@sender, :name_only => true)
    setup_email(@sender, :from => :admin)
    super
    set_layout_options(:show_change_notif_link => true)
  end

  register_tags do
    tag :recipient_name, :description => Proc.new{'email_translations.meeting_request_expired_notification_to_sender.tags.recipient_name.description'.translate}, :example => Proc.new{'William Smith'} do
      @mentor.name
    end

    tag :url_mentors_listing, :description => Proc.new{'email_translations.meeting_request_expired_notification_to_sender.tags.url_mentors_listing.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      users_url(:subdomain => @organization.subdomain, src: EngagementIndex::Src::BrowseMentors::EMAIL)
    end

    tag :auto_close_message, :description => Proc.new{'email_translations.meeting_request_expired_notification_to_sender.tags.auto_close_message.description'.translate},
        :example => Proc.new{'feature.meeting_request.auto_expire_message'.translate(mentor: 'mentor', expiration_days: 10)} do
      @meeting_request.response_text
    end

    tag :view_mentors_button, :description => Proc.new{'email_translations.meeting_request_expired_notification_to_sender.tags.view_mentors_button.description'.translate }, :example => Proc.new{ call_to_action_example("email_translations.meeting_request_expired_notification_to_sender.tags.view_mentors_button.view_mentors".translate(Mentors:  "feature.custom_terms.pluralize.mentor".translate)) } do
      call_to_action("email_translations.meeting_request_expired_notification_to_sender.tags.view_mentors_button.view_mentors".translate(Mentors:  @_Mentors_string), users_url(:subdomain => @organization.subdomain, src: EngagementIndex::Src::BrowseMentors::EMAIL))
    end

    tag :max_pending_duration, :description => Proc.new{'email_translations.meeting_request_expired_notification_to_sender.tags.max_pending_duration.description'.translate}, :example => Proc.new{'email_translations.meeting_request_expired_notification_to_sender.tags.max_pending_duration.example'.translate} do
      'email_translations.meeting_request_expired_notification_to_sender.pending_duration'.translate(:count => @max_pending_duration)
    end
  end

  self.register!

end

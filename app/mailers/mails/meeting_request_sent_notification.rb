class MeetingRequestSentNotification < ChronusActionMailer::Base
  
  @mailer_attributes = {
    :uid          => '6pdpjnao', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::MEETING_REQUEST_RELATED,
    :title        => Proc.new{|program| "email_translations.meeting_request_sent_notification.title_v4".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.meeting_request_sent_notification.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.meeting_request_sent_notification.subject_v2".translate},
    :campaign_id  => CampaignConstants::MENTORING_REQUESTS_OFFERS_MAIL_ID,
    :campaign_id_2  => CampaignConstants::MEETING_REQUEST_SENT_NOTIFICATION_MAIL_ID,
    :feature      => FeatureName::CALENDAR,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :program_settings => Proc.new{ |program| program.calendar_setting.allow_mentor_to_configure_availability_slots? },
    :level        => EmailCustomization::Level::PROGRAM,
    :other_registered_tags => [:meeting_request_tags, :meeting_attachment_tag, :meeting_tags],
    :listing_order => 3
  }

  def meeting_request_sent_notification(user, meeting_request, ics_attachment)
    @receiver = user
    @meeting_request = meeting_request
    @member = user.member
    @meeting = @meeting_request.meeting
    @attachment = ics_attachment
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@meeting_request.program)
    set_username(@receiver, :name_only => true)
    setup_email(@receiver, :sender_name => @meeting_request.student.visible_to?(@receiver) ? meeting_request_creator_name : nil)
    super
    set_layout_options(:show_change_notif_link => true)
  end

  register_tags do
    tag :meeting_request_creator_email, :description => Proc.new{'email_translations.meeting_request_sent_notification.tags.meeting_request_creator_email.description'.translate}, :example => Proc.new{'john@gmail.com'} do
      @meeting_request.student.email
    end

    tag :meeting_request_recepient_email, :description => Proc.new{'email_translations.meeting_request_sent_notification.tags.meeting_request_recepient_email.description'.translate}, :example => Proc.new{'john@gmail.com'} do
      @meeting_request.mentor.email
    end
  end

  self.register!
end

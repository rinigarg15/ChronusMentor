class MeetingRequestReminderNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'gbxfo7rl', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::MEETING_REQUEST_RELATED,
    :title        => Proc.new{|program| "email_translations.meeting_request_reminder_notification.title_v4".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.meeting_request_reminder_notification.description_v3".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.meeting_request_reminder_notification.subject_v1".translate},
    :campaign_id  => CampaignConstants::MENTORING_REQUESTS_OFFERS_MAIL_ID,
    :campaign_id_2 => CampaignConstants::MEETING_REQUEST_REMINDER_NOTIFICATION_ID,
    :feature      => FeatureName::CALENDAR,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :program_settings => Proc.new{ |program| program.needs_meeting_request_reminder? },
    :level        => EmailCustomization::Level::PROGRAM,
    :other_registered_tags => [:meeting_request_tags],
    :listing_order => 4
  }

  def meeting_request_reminder_notification(user, meeting_request)
    @receiver = user
    @member = user.member
    @meeting_request = meeting_request
    @meeting = @meeting_request.get_meeting
    @description = wrap_url_with_space_before_urls_in_message(@meeting.description) if @meeting.description.present?
    @program = meeting_request.program
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@program)
    set_username(@receiver, :name_only => true)
    setup_email(@receiver)
    super
    set_layout_options(:show_change_notif_link => false)
  end

  def wrap_url_with_space_before_urls_in_message(message)
    URI.extract(message).each do |url|
      message = message.gsub("\n#{url}", "\n #{url}")
    end
    return message
  end

  register_tags do
    tag :meeting_request_reminder_notification_content, :description => Proc.new{'email_translations.meeting_request_reminder_notification.tags.meeting_request_reminder_notification_content.description'.translate}, :example => Proc.new{'email_translations.meeting_request_reminder_notification.tags.meeting_request_reminder_notification_content.example_v2_html'.translate} do
      render(:partial => '/meeting_request_reminder_notification_email').html_safe
    end

    tag :pending_meeting_request, description: Proc.new{'email_translations.meeting_request_reminder_notification.tags.pending_meeting_request.description'.translate}, example: Proc.new { |program| 'email_translations.meeting_request_reminder_notification.tags.pending_meeting_request.example_v1_html'.translate(meeting: program.term_for(CustomizedTerm::TermType::MEETING_TERM).term_downcase) } do
      'email_translations.meeting_request_reminder_notification.pending_content_html'.translate(:count =>  [@receiver.received_meeting_requests.active.count - 1, 0].max, :url_meeting_request_pending_link => meeting_requests_url(subdomain: @program.organization.subdomain, root: @program.root), :meeting => customized_meeting_term)
    end

    tag :sent_time, description: Proc.new{'email_translations.meeting_request_reminder_notification.tags.sent_time.description'.translate}, example: Proc.new{'email_translations.meeting_request_reminder_notification.tags.sent_time.example'.translate} do
      DateTime.localize(@meeting_request.created_at.in_time_zone(@member.get_valid_time_zone), format: :abbr_short_with_time)
    end

    tag :mentee_name, :description => Proc.new{'email_translations.meeting_request_reminder_notification.tags.mentee_name.description'.translate}, :example => Proc.new{'email_translations.meeting_request_reminder_notification.tags.mentee_name.example'.translate} do
      @meeting_request.student.name(:name_only => true)
    end

    tag :mentee_url, :description => Proc.new{'email_translations.meeting_request_reminder_notification.tags.mentee_url.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      user_url(@meeting_request.student, subdomain: @organization.subdomain, :root => @program.root)
    end

    tag :view_request_button, :description => Proc.new{'email_translations.meeting_request_reminder_notification.tags.view_request_button.description'.translate }, :example => Proc.new{ call_to_action_example("email_translations.meeting_request_reminder_notification.tags.view_request_button.view_request".translate) } do
      call_to_action("email_translations.meeting_request_reminder_notification.tags.view_request_button.view_request".translate, meeting_requests_url(:root => @program.root, :subdomain => @program.organization.subdomain))
    end

    tag :meeting_description_as_quote, :description => Proc.new{"email_translations.meeting_request_reminder_notification.tags.meeting_description_as_quote.description".translate}, :example => Proc.new{"feature.email.tags.message_from_user_v3_html".translate(message: "email_translations.meeting_request_reminder_notification.tags.meeting_description_as_quote.example".translate, name: 'feature.email.tags.mentor_name.example'.translate)} do
      word_wrap(@meeting.description.present? ? "feature.email.tags.message_from_user_v3_html".translate(message: @description, name: mentee_name) : "").html_safe
    end
  end
  self.register!
end

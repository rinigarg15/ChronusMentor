class MentorRequestReminderNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'i8e2kysg', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::MENTOR_REQUEST_RELATED,
    :title        => Proc.new{|program| "email_translations.mentor_request_reminder_notification.title_v4".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.mentor_request_reminder_notification.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.mentor_request_reminder_notification.subject_v1".translate},
    :campaign_id  => CampaignConstants::MENTOR_REQUEST_REMINDER_NOTIFICATION_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :program_settings => Proc.new{|program| program.only_career_based_ongoing_mentoring_enabled? && program.matching_by_mentee_alone? && program.needs_mentoring_request_reminder?},
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 2
  }

  def mentor_request_reminder_notification(user, mentor_request)
    @receiver = user
    @member = user.member
    @mentor_request = mentor_request
    @program = user.program
    @organization = @program.organization
    @message = wrap_url_with_space_before_urls_in_message(@mentor_request.message) if @mentor_request.message.present?
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@program)
    set_username(@receiver, :name_only => true)
    setup_email(@receiver)
    super
  end

  def wrap_url_with_space_before_urls_in_message(message)
    URI.extract(message).each do |url|
      message = message.gsub("\n#{url}", "\n #{url}")
    end
    return message
  end

  register_tags do
    tag :mentor_request_reminder_notification_content, :description => Proc.new{'email_translations.mentor_request_reminder_notification.tags.mentor_request_reminder_notification_content.description'.translate}, :example => Proc.new{'email_translations.mentor_request_reminder_notification.tags.mentor_request_reminder_notification_content.example_v3_html'.translate} do
      render(:partial => '/mentor_request_reminder_notification_email').html_safe
    end

    tag :sent_time, description: Proc.new{'email_translations.mentor_request_reminder_notification.tags.sent_time.description'.translate(:mentoring => @_mentoring_string)}, example: Proc.new{'email_translations.mentor_request_reminder_notification.tags.sent_time.example'.translate} do
      DateTime.localize(@mentor_request.created_at.in_time_zone(@member.get_valid_time_zone), format: :abbr_short_with_time)
    end

    tag :mentor_request_creator_name, description: Proc.new{'email_translations.mentor_request_reminder_notification.tags.mentor_request_creator_name.description'.translate(:mentoring => @_mentoring_string)}, example: Proc.new{'email_translations.mentor_request_reminder_notification.tags.mentor_request_creator_name.example_v1'.translate} do
      @mentor_request.student.name(name_only: true)
    end

    tag :mentee_url, description: Proc.new{'email_translations.mentor_request_reminder_notification.tags.mentee_url.description'.translate(:mentoring => @_mentoring_string)}, example: Proc.new{'http://www.chronus.com/'} do
      user_url(@mentor_request.student, :subdomain => @organization.subdomain, :root => @program.root)
    end

    tag :url_mentor_request_list, :description => Proc.new{'email_translations.new_mentor_request.tags.url_mentor_request_list.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      mentor_requests_url(:subdomain => @organization.subdomain, :src => "email_rem", :mentor_request_id => @mentor_request.id)
    end

    tag :view_request_button, :description => Proc.new{'email_translations.mentor_request_reminder_notification.tags.view_request_button.description'.translate}, :example => Proc.new{ call_to_action_example("email_translations.mentor_request_reminder_notification.tags.view_request_button.view_request".translate) } do
      call_to_action("email_translations.mentor_request_reminder_notification.tags.view_request_button.view_request".translate, mentor_requests_url(:subdomain => @organization.subdomain, :src => "email_rem", :mentor_request_id => @mentor_request.id, filter: AbstractRequest::Filter::TO_ME))
    end

    tag :message_from_mentee, :description => Proc.new{"email_translations.mentor_request_reminder_notification.tags.message_from_mentee.description".translate}, :example => Proc.new{"feature.email.tags.message_from_user_v3_html".translate(message: "email_translations.mentor_request_reminder_notification.tags.message_from_mentee.example".translate, name: 'email_translations.mentor_request_reminder_notification.tags.mentor_request_creator_name.example_v1'.translate)} do
      word_wrap(@mentor_request.message.present? ? "feature.email.tags.message_from_user_v3_html".translate(message: @message, name: mentor_request_creator_name) : "").html_safe
    end
  end
  self.register!
end

class ProjectRequestReminderNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'f15adlh3', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::CIRCLE_REQUEST_RELATED,
    :title        => Proc.new{|program| "email_translations.project_request_reminder_notification.title_v3".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.project_request_reminder_notification.description_v3".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.project_request_reminder_notification.subject_v1".translate},
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :campaign_id  => CampaignConstants::PROJECT_REQUESTS_MAIL_ID,
    :campaign_id_2  => CampaignConstants::PROJECT_REQUEST_REMINDER_ID,
    :program_settings => Proc.new{ |program| program.project_based? && program.needs_project_request_reminder? },
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 2
  }

  def project_request_reminder_notification(user, request)
    @receiver = user
    @member = user.member
    @program = user.program
    @organization = @program.organization
    @request = request
    @group = @request.group
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

  register_tags do
    tag :project_requester_name, :description => Proc.new{'email_translations.project_request_reminder_notification.tags.project_requester_name.description'.translate}, :example => Proc.new{'email_translations.project_request_reminder_notification.tags.project_requester_name.example'.translate} do
      @request.sender.name(name_only: true)
    end

    tag :url_project_requester, :description => Proc.new{"email_translations.project_request_reminder_notification.tags.url_project_requester.description".translate}, :example => Proc.new{'http://www.chronus.com'} do
      user_url(@request.sender, :subdomain => @organization.subdomain, :root => @program.root)
    end

    tag :url_project_request_list, :description => Proc.new{'email_translations.project_request_reminder_notification.tags.url_project_request_list.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      project_requests_url(:subdomain => @organization.subdomain, :src => "email_rem")
    end

    tag :sent_time, description: Proc.new{'email_translations.project_request_reminder_notification.tags.sent_time.description'.translate}, example: Proc.new{'email_translations.project_request_reminder_notification.tags.sent_time.example'.translate} do
      DateTime.localize(@request.created_at.in_time_zone(@member.get_valid_time_zone), format: :abbr_short)
    end

    tag :url_project, description: Proc.new{'email_translations.project_request_reminder_notification.tags.url_project.description'.translate}, example: Proc.new{'http://www.chronus.com'} do
      profile_group_url(@group, subdomain: @organization.subdomain)
    end

    tag :project_name, description: Proc.new{"email_translations.project_request_reminder_notification.tags.project_name.description".translate}, example: Proc.new{"email_translations.project_request_reminder_notification.tags.project_name.example".translate} do
      @group.name
    end

    tag :date_of_sending, description: Proc.new{'email_translations.project_request_reminder_notification.tags.date_of_sending.description'.translate}, example: Proc.new{'email_translations.project_request_reminder_notification.tags.date_of_sending.example'.translate} do
      DateTime.localize(@request.created_at.in_time_zone(@member.get_valid_time_zone), format: :abbr_short)
    end

    tag :view_request_button,  description: Proc.new{'email_translations.project_request_reminder_notification.tags.view_request_button.description'.translate}, example: Proc.new{ call_to_action_example('email_translations.project_request_reminder_notification.button_text'.translate) } do
      call_to_action('email_translations.project_request_reminder_notification.button_text'.translate,  project_requests_url(:subdomain => @organization.subdomain, :src => "email_rem"))
    end  
  end
  self.register!
end
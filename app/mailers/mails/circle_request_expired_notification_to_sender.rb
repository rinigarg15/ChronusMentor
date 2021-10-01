class CircleRequestExpiredNotificationToSender < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'mndlgafj', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::CIRCLE_REQUEST_RELATED,
    :title        => Proc.new{|program| "email_translations.circle_request_expired_notification_to_sender.title".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.circle_request_expired_notification_to_sender.description".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.circle_request_expired_notification_to_sender.subject".translate},
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :campaign_id  => CampaignConstants::PROJECT_REQUESTS_MAIL_ID,
    :program_settings => Proc.new{ |program| program.project_based? && program.circle_request_auto_expiration_days.present? },
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 3
  }

  def circle_request_expired_notification_to_sender(sender, project_request)
    @sender = sender
    @member = @sender.member
    @project_request = project_request
    @group = @project_request.group
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@group.program)
    set_username(@sender, :name_only => true)
    setup_email(@sender, :from => :admin)
    super
    set_layout_options(:show_change_notif_link => true)
  end

  register_tags do
    tag :project_name, description: Proc.new{"email_translations.circle_request_expired_notification_to_sender.tags.project_name.description".translate}, example: Proc.new{"email_translations.circle_request_expired_notification_to_sender.tags.project_name.example".translate} do
      @group.name
    end

    tag :visit_other_connections_button, description: Proc.new{|program| 'email_translations.circle_request_expired_notification_to_sender.tags.visit_other_connections_button.description'.translate(program.return_custom_term_hash)}, example: Proc.new{|program| call_to_action_example("email_translations.circle_request_expired_notification_to_sender.visit_other_connections_html".translate(:mentoring_connection_term => program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).pluralized_term_downcase)) } do
      call_to_action("email_translations.circle_request_expired_notification_to_sender.visit_other_connections_html".translate(:mentoring_connection_term => @_mentoring_connections_string), find_new_groups_url(subdomain: @organization.subdomain))
    end

    tag :url_contact_admin, :description => Proc.new{'email_translations.not_eligible_to_join_notification.tags.url_contact_admin.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      get_contact_admin_path(@program, url_params: { subdomain: @organization.subdomain, root: @program.root, src: 'mail' }, only_url: true)
    end
  end
  self.register!
end
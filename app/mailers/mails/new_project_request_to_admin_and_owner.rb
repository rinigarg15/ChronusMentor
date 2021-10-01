class NewProjectRequestToAdminAndOwner < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'i8wbodpx', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::CIRCLE_REQUEST_RELATED,
    :title        => Proc.new{|program| "email_translations.new_project_request_to_admin_and_owner.title_v3".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.new_project_request_to_admin_and_owner.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.new_project_request_to_admin_and_owner.subject_v1".translate},
    :campaign_id  => CampaignConstants::PROJECT_REQUESTS_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :program_settings => Proc.new{ |program| program.project_based? && program.allows_users_to_apply_to_join_in_project?},
    :campaign_id_2  => CampaignConstants::NEW_PROJECT_REQUEST_TO_ADMIN_AND_OWNER_MAIL_ID,
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 1,
    :notification_setting => UserNotificationSetting::SettingNames::PROGRAM_MANAGEMENT
  }

  def new_project_request_to_admin_and_owner(admin_user, project_request, options={})
    @admin_user = admin_user
    @project_request = project_request
    @group = project_request.group
    @options = options
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@project_request.program)
    set_sender(@options)
    set_username(@admin_user, name_only: true)
    setup_email(@admin_user, :from => @admin_user.name, :sender_name => @sender.visible_to?(@admin_user) ? student_name : nil, message_type: EmailCustomization::MessageType::COMMUNICATION)
    super
  end

  register_tags do
    tag :student_name, :description => Proc.new{'email_translations.new_project_request_to_admin_and_owner.tags.student_name.description'.translate}, :example => Proc.new{'feature.email.tags.mentor_name.example'.translate} do
      @sender.name(name_only: true)
    end

    tag :url_project_requests_listing, :description => Proc.new{'email_translations.new_project_request_to_admin_and_owner.tags.url_project_requests_listing.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      project_requests_url(:subdomain => @organization.subdomain, :src => "email")
    end

    tag :url_project, description: Proc.new{'email_translations.new_project_request_to_admin_and_owner.tags.url_project.description'.translate}, example: Proc.new{'http://www.chronus.com'} do
      profile_group_url(@group, subdomain: @organization.subdomain)
    end

    tag :project_name, description: Proc.new{"email_translations.new_project_request_to_admin_and_owner.tags.project_name.description".translate}, example: Proc.new{"email_translations.new_project_request_to_admin_and_owner.tags.project_name.example".translate} do
      @group.name
    end

    tag :project_requester_name, :description => Proc.new{'email_translations.new_project_request_to_admin_and_owner.tags.project_requester_name.description'.translate}, :example => Proc.new{'feature.email.tags.mentor_name.example_with_url'.translate} do
      link_to(@sender.name(name_only: true), user_url(@sender, :subdomain => @organization.subdomain, :root => @program.root))
    end

    tag :view_request_button, :description => Proc.new{'email_translations.new_project_request_to_admin_and_owner.tags.view_request_button.description'.translate}, :example => Proc.new{ call_to_action_example('email_translations.new_project_request_to_admin_and_owner.view_request'.translate) } do
      call_to_action('email_translations.new_project_request_to_admin_and_owner.view_request'.translate, ProjectRequest.get_project_request_path_for_privileged_users(@admin_user, src: "email"))
    end
  end

  self.register!

end

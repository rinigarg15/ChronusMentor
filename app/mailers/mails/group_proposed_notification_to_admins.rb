class GroupProposedNotificationToAdmins < ChronusActionMailer::Base
  @mailer_attributes = {
    :uid          => 'tvygykre', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::NEW_CIRCLES_CREATION,
    :title        => Proc.new{|program| "email_translations.group_proposed_notification_to_admins.title_v2".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.group_proposed_notification_to_admins.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.group_proposed_notification_to_admins.subject".translate},
    :campaign_id  => CampaignConstants::PROJECT_REQUESTS_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :program_settings => Proc.new{ |program| program.project_based? && program.should_display_proposed_projects_emails? },
    :campaign_id_2  => CampaignConstants::GROUP_PROPOSED_NOTIFICATION_TO_ADMINS_MAIL_ID,
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 1,
    :notification_setting => UserNotificationSetting::SettingNames::PROGRAM_MANAGEMENT

  }

  def group_proposed_notification_to_admins(user, group, options={})
    @group = group
    @user = user
    @proposer = @group.created_by
    @options = options
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@group.program)
    set_sender(@options)
    set_username(@user)
    setup_email(@user, :sender_name => @proposer.visible_to?(@user) ? proposer_name : nil, message_type: EmailCustomization::MessageType::COMMUNICATION)
    super
  end

  register_tags do

    tag :project_name, :description => Proc.new{"email_translations.group_proposed_notification_to_admins.tags.project_name.description".translate}, :example => Proc.new{"email_translations.group_proposed_notification_to_admins.tags.project_name.example".translate} do
      @group.name
    end

    tag :project_url, :description => Proc.new{"email_translations.group_proposed_notification_to_admins.tags.project_url.description".translate},  :example => Proc.new{'http://www.chronus.com'} do
      profile_group_url(@group, :subdomain => @organization.subdomain, :src => 'mail')
    end

    tag :proposer_name, :description => Proc.new{"email_translations.group_proposed_notification_to_admins.tags.proposer_name.description".translate}, :example => Proc.new{"email_translations.group_proposed_notification_to_admins.tags.proposer_name.example".translate} do
      @proposer.name
    end

    tag :proposer_url, :description => Proc.new{"email_translations.group_proposed_notification_to_admins.tags.proposer_url.description".translate},  :example => Proc.new{'http://www.chronus.com'} do
      user_url(@proposer, subdomain: @organization.subdomain, root: @program.root)
    end

    tag :view_project_button, :description => Proc.new{"email_translations.group_proposed_notification_to_admins.tags.view_project_button.description".translate},  :example => Proc.new{|program| call_to_action_example("email_translations.group_proposed_notification_to_admins.view_project_text_html".translate(:mentoring_connection_term => program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase)) } do
      call_to_action("email_translations.group_proposed_notification_to_admins.view_project_text_html".translate(:mentoring_connection_term => @_mentoring_connection_string), profile_group_url(@group, :subdomain => @organization.subdomain, :src => 'mail'))
    end
  end
  self.register!
end
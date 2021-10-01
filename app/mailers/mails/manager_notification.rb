class ManagerNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'mjf6kl9l', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::ENROLLMENT_AND_USER_MANAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::APPLY_TO_JOIN,
    :title        => Proc.new{|program| "email_translations.manager_notification.title_v2".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.manager_notification.description_v3".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.manager_notification.subject_v2".translate},
    :campaign_id  => CampaignConstants::MEMBERSHIP_MAIL_ID,
    :feature      => FeatureName::MANAGER,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :campaign_id_2  => CampaignConstants::MANAGER_NOTIFICATION_MAIL_ID,
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 6
  }

  def manager_notification(manager, membership_request)
    @membership_request = membership_request
    @manager = manager
    init_mail
    render_mail
  end

  def self.mailer_locale(manager, membership_request)
    manager.member.present? ? Language.for_member(manager.member, membership_request.program) : I18n.default_locale
  end

  private

  def init_mail
    set_program(@membership_request.program)
    set_username(@manager.member, name: @manager.full_name, first_name: @manager.first_name, last_name: @manager.last_name, name_only: true)
    setup_email(nil, :email => @manager.email)
    super
  end

  register_tags do
    tag :member_role, :description => Proc.new{'email_translations.manager_notification.tags.member_role.description'.translate}, :example => Proc.new{'email_translations.manager_notification.tags.member_role.example_v1'.translate} do
      RoleConstants.human_role_string(@membership_request.role_names, :program => @program, :articleize => true, :no_capitalize => true)
    end

    tag :user_name, :description => Proc.new{'email_translations.manager_notification.tags.user_name.description'.translate}, :example => Proc.new{'John Doe'} do
      @membership_request.name
    end

    tag :url_contact_admin, :description => Proc.new{'email_translations.manager_notification.tags.url_contact_admin.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      get_contact_admin_path(@membership_request.program, {:only_url => true, :url_params => {:subdomain => @organization.subdomain, :root => @membership_request.program.root, :subject => 'email_translations.manager_notification.tags.url_contact_admin.subject'.translate(:user_name => user_name)}})
    end
  end

  self.register!

end

class EmailChangeNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'toyjg5tc', # rand(36**8).to_s(36)
    :title        => Proc.new{"email_translations.email_change_notification.title_v1".translate},
    :description  => Proc.new{"email_translations.email_change_notification.description_v1".translate},
    :subject      => Proc.new{"email_translations.email_change_notification.subject_v1".translate},
    :campaign_id  => CampaignConstants::USER_SETTINGS_ROLES_MAIL_ID,
    :campaign_id_2  => CampaignConstants::EMAIL_CHANGE_NOTIFICATION_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :level        => EmailCustomization::Level::ORGANIZATION,
    :donot_list   => true
  }

  def email_change_notification(member, old_email)
    @member = member
    @old_email = old_email
    @email_changer = member.email_changer
    init_mail
    render_mail
  end

  private

  def init_mail
    setup_recipient_and_organization(@member, @member.organization)
    set_username(@member, :name_only => true)
    setup_email(nil, :email => @old_email)
    super
  end

  register_tags do
    tag :url_contact_admin, :description => Proc.new{'email_translations.email_change_notification.tags.url_contact_admin.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      get_contact_admin_path(@member.users.first.program, url_params: { subdomain: @organization.subdomain, root: @member.users.first.program.root }, only_url: true)
    end

    tag :old_email_address, :description => Proc.new{'email_translations.email_change_notification.tags.old_email_address.description'.translate}, :example => Proc.new{'old_mail@gmail.com'} do
      @old_email
    end

    tag :current_email_address, :description => Proc.new{'email_translations.email_change_notification.tags.current_email_address.description'.translate}, :example => Proc.new{'new_mail@gmail.com'} do
      @member.email
    end
  end

  self.register!

end

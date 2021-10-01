class MemberActivationNotification < ChronusActionMailer::Base
  @mailer_attributes = {
    :uid          => 'qeppp2p0', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::ENROLLMENT_AND_USER_MANAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::USER_MANAGEMENT,
    :title        => Proc.new{|program| "email_translations.member_activation_notification.title_v1".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.member_activation_notification.description_v3".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.member_activation_notification.subject_v1".translate},
    :campaign_id  => CampaignConstants::MEMBERSHIP_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :campaign_id_2  => CampaignConstants::MEMBER_ACTIVATION_NOTIFICATION_MAIL_ID,
    :skip_default_salutation => true,
    :level        => EmailCustomization::Level::ORGANIZATION,
    :listing_order => 6
  }

  def member_activation_notification(member)
    @member = member
    @organization = member.organization
    init_mail
    render_mail
  end

  private

  def init_mail
    set_username(@member)
    setup_recipient_and_organization(@member, @organization)
    setup_email(@member)
    super
    set_layout_options(:show_change_notif_link => false)
  end

  register_tags do
    tag :url_organization_login, :description => Proc.new{'email_translations.member_activation_notification.tags.url_organization_login.description'.translate}, :example => Proc.new{"http://www.chronus.com/login"} do
      login_url(:subdomain => @organization.subdomain)
    end

    tag :login_button, :description => Proc.new{'email_translations.member_activation_notification.tags.login_button.description'.translate}, :example => Proc.new{ call_to_action_example("email_translations.member_activation_notification.tags.login_button.login".translate) } do
      call_to_action("email_translations.member_activation_notification.tags.login_button.login".translate, edit_member_url(@member, :subdomain => @organization.subdomain))
    end

    tag :url_subprogram_or_program, :description => Proc.new{'feature.email.tags.subprogram_tags.url_subprogram_or_program.description'.translate}, :example => Proc.new{"http://www.chronus.com"} do
      url_program
    end
  end

  self.register!

end

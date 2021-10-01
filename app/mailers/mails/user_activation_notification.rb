class UserActivationNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => '55x3ndfp', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::ENROLLMENT_AND_USER_MANAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::USER_MANAGEMENT,
    :title        => Proc.new{|program| "email_translations.user_activation_notification.title_v2".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.user_activation_notification.description_v3".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.user_activation_notification.subject_v1".translate},
    :campaign_id  => CampaignConstants::MEMBERSHIP_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :campaign_id_2  => CampaignConstants::USER_ACTIVATION_NOTIFICATION_MAIL_ID,
    :skip_default_salutation => true,
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 4
  }

  def user_activation_notification(user)
    @user = user
    init_mail
    render_mail
  end

  private

  def init_mail
    set_username(@user)
    set_program(@user.program)
    setup_email(@user, :from => :admin)
    super
    set_layout_options(:program => @program)
  end

  register_tags do
    tag :administrator_name, :description => Proc.new{'email_translations.user_activation_notification.tags.administrator_name.description'.translate}, :example => Proc.new{'feature.email.tags.mentor_name.example'.translate} do
      @user.state_changer.name
    end

    tag :login_button, :description => Proc.new{'email_translations.user_activation_notification.tags.login_button.description'.translate}, :example => Proc.new{ call_to_action_example('email_translations.user_activation_notification.login_text'.translate) } do
      call_to_action('email_translations.user_activation_notification.login_text'.translate, login_url(:subdomain => @organization.subdomain, :root => @user.program.root))
    end
  end

  self.register!

end

class UserSuspensionNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'x04nhnim', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::ENROLLMENT_AND_USER_MANAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::USER_MANAGEMENT,
    :title        => Proc.new{|program| "email_translations.user_suspension_notification.title_v3".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.user_suspension_notification.description_v3".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.user_suspension_notification.subject_v1".translate},
    :campaign_id  => CampaignConstants::MEMBERSHIP_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING, User::Status::SUSPENDED],
    :campaign_id_2  => CampaignConstants::USER_SUSPENSION_NOTIFICATION_MAIL_ID,
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 3
  }

  def user_suspension_notification(user)
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
    tag :administrator_name, :description => Proc.new{'email_translations.user_suspension_notification.tags.administrator_name.description'.translate}, :example => Proc.new{'feature.email.tags.mentor_name.example'.translate} do
      @user.state_changer.name
    end

    tag :reason, :description => Proc.new{'email_translations.user_suspension_notification.tags.reason.description'.translate}, :example => Proc.new{'email_translations.user_suspension_notification.tags.reason.example'.translate} do
      wrap_and_break(@user.state_change_reason)
    end

    tag :url_contact_admin, :description => Proc.new{'email_translations.user_suspension_notification.tags.url_contact_admin.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      get_contact_admin_path(@user.program, {:only_url => true, :url_params => {:subdomain => @organization.subdomain, :root => @user.program.root}})
    end

    tag :reason_as_quote, :description => Proc.new{'email_translations.user_suspension_notification.tags.reason_as_quote.description'.translate}, :example => Proc.new{'feature.email.tags.message_from_user_v3_html'.translate(:message => 'email_translations.user_suspension_notification.tags.reason.example'.translate, :name => 'feature.email.tags.mentor_name.example'.translate)} do
      word_wrap(@user.state_change_reason.present? ? 'feature.email.tags.message_from_user_v3_html'.translate(:message => @user.state_change_reason, :name => @user.state_changer.name) : "").html_safe
    end
  end
  
  self.register!

end

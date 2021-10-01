class ReplyToAdminMessageFailureNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'z9biu0ho', # rand(36**8).to_s(36)
    :title        => Proc.new{"email_translations.reply_to_admin_message_failure_notification.title".translate},
    :description  => Proc.new{"email_translations.reply_to_admin_message_failure_notification.description_v1".translate},
    :subject      => Proc.new{"email_translations.reply_to_admin_message_failure_notification.subject".translate},
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :campaign_id  => CampaignConstants::REPLY_TO_ADMIN_MESSAGE_FAILURE_NOTIFICATION_MAIL_ID,
    :level        => EmailCustomization::Level::PROGRAM,
    :donot_list   => true
  }

  def reply_to_admin_message_failure_notification(admin_message, user_email, old_subject, old_body)
    @admin_message = admin_message
    @user_email = user_email
    @old_subject = old_subject
    @old_content = old_body
    @program = @admin_message.program
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@program)
    name = @user_email.split('@').first.capitalize
    set_username(nil, :name => name)
    setup_email(nil, :email => @user_email)
    super
  end

  register_tags do
    tag :sender_email, :description => Proc.new{'email_translations.reply_to_admin_message_failure_notification.tags.sender_email.description'.translate}, :example => Proc.new{'xyz@example.com'} do
      @user_email
    end

    tag :subject, :description => Proc.new{'email_translations.reply_to_admin_message_failure_notification.tags.subject.description'.translate}, :example => Proc.new{'email_translations.reply_to_admin_message_failure_notification.tags.subject.example'.translate} do
      @old_subject
    end

    tag :content, :description => Proc.new{'email_translations.reply_to_admin_message_failure_notification.tags.content.description'.translate}, :example => Proc.new{'email_translations.reply_to_admin_message_failure_notification.tags.content.example_v1'.translate} do
      wrap_and_break(@old_content)
    end

    tag :url_contact_admin, :description => Proc.new{'email_translations.reply_to_admin_message_failure_notification.tags.url_contact_admin.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      get_contact_admin_path(@program, {:only_url => true, :url_params => {:subdomain => @organization.subdomain, :src => 'email'}})
    end
  end

  self.register!

end
class AnnouncementUpdateNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'fjgdr9n4', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::ADMINISTRATION_EMAILS,
    :title        => Proc.new{|program| "email_translations.announcement_update_notification.title_v1".translate},
    :description  => Proc.new{|program| "email_translations.announcement_update_notification.description_v3".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.announcement_update_notification.subject".translate},
    :campaign_id  => CampaignConstants::MESSAGE_MAIL_ID,
    :campaign_id_2  => CampaignConstants::ANNOUNCEMENT_UPDATE_NOTIFICATION_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :always_enabled => true,
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 2
  }

  def announcement_update_notification(user, announcement, options = {})
    @announcement = announcement
    @user = user
    if @announcement.attachment?
      attachments[@announcement.attachment_file_name] = @announcement.attachment.content
    end
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@announcement.program)
    set_username(@user)
    setup_email(@user, :from => :admin)
    super
    set_layout_options(:show_change_notif_link => true)
  end

  register_tags do
    tag :announcement_title, :description => Proc.new{'email_translations.announcement_notification.tags.announcement_title.description'.translate}, :example => Proc.new{'email_translations.announcement_notification.tags.announcement_title.example'.translate} do
      @announcement.title
    end

    tag :announcement_body, :description => Proc.new{'email_translations.announcement_notification.tags.announcement_body.description'.translate}, :example => Proc.new{'email_translations.announcement_notification.tags.announcement_body.example_v1'.translate} do
      (@announcement.body.presence || "").html_safe
    end

    tag :url_announcement, :description => Proc.new{'email_translations.announcement_notification.tags.url_announcement.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      announcement_url(@announcement, :subdomain => @organization.subdomain)
    end

    tag :view_announcement_button, :description => Proc.new{'email_translations.announcement_update_notification.tags.view_announcement_button.description'.translate}, :example => Proc.new{ call_to_action_example('email_translations.announcement_update_notification.view_announcement'.translate) } do
      call_to_action('email_translations.announcement_update_notification.view_announcement'.translate, announcement_url(@announcement, :subdomain => @organization.subdomain))
    end
  end

  self.register!

end

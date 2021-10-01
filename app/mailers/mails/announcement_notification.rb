class AnnouncementNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'qkak4psq', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::ADMINISTRATION_EMAILS,
    :title        => Proc.new{|program| "email_translations.announcement_notification.title_v2".translate},
    :description  => Proc.new{|program| "email_translations.announcement_notification.description_v3".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.announcement_notification.subject".translate},
    :campaign_id  => CampaignConstants::MESSAGE_MAIL_ID,
    :campaign_id_2  => CampaignConstants::ANNOUNCEMENT_NOTIFICATION_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :always_enabled => true,
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 1
  }

  def announcement_notification(user_or_member, announcement, options = {})
    @announcement = announcement
    @test_mail = options[:is_test_mail]
    @non_system_email = options[:non_system_email] if options[:non_system_email].present?
    @user_or_member = user_or_member
    if @announcement.attachment?
      attachments[@announcement.attachment_file_name] = @announcement.attachment.content
    end
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@announcement.program)
    @test_mail && @non_system_email ? set_username(nil, :name => 'feature.email.content.user_name_html'.translate) : set_username(@user_or_member)
    @test_mail && @non_system_email ? setup_email(nil, :from => :admin, :email => @non_system_email) : setup_email(@user_or_member, :from => :admin)
    super
    set_layout_options(:show_change_notif_link => !@test_mail)
  end

  register_tags do
    tag :announcement_title, :description => Proc.new{'email_translations.announcement_notification.tags.announcement_title.description'.translate}, :example => Proc.new{'email_translations.announcement_notification.tags.announcement_title.example'.translate} do
      @announcement.title
    end

    tag :announcement_body, :description => Proc.new{'email_translations.announcement_notification.tags.announcement_body.description'.translate}, :example => Proc.new{'email_translations.announcement_notification.tags.announcement_body.example_v1'.translate} do
      (@announcement.body.presence || "").html_safe
    end

    tag :url_announcement, :description => Proc.new{'email_translations.announcement_notification.tags.url_announcement.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      @test_mail ? "http://www.chronus.com" : announcement_url(@announcement, :subdomain => @organization.subdomain)
    end

    tag :view_announcement_button, :description => Proc.new{'email_translations.announcement_notification.tags.view_announcement_button.description'.translate}, :example => Proc.new{ call_to_action_example('email_translations.announcement_notification.view_announcement'.translate) } do
      button_url = @test_mail ? "http://www.chronus.com" : announcement_url(@announcement, :subdomain => @organization.subdomain)
      call_to_action('email_translations.announcement_notification.view_announcement'.translate, button_url)
    end
  end

  self.register!

end

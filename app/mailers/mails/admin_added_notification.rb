class AdminAddedNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'c4z0i1w9', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::ENROLLMENT_AND_USER_MANAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::INVITATION,
    :title        => Proc.new{|program| "email_translations.admin_added_notification.title_v3".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.admin_added_notification.description_v3".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.admin_added_notification.subject_v1".translate},
    :campaign_id  => CampaignConstants::MEMBERSHIP_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :campaign_id_2 => CampaignConstants::ADMIN_ADDED_NOTIFICATION_MAIL_ID,
    :level        => EmailCustomization::Level::ORGANIZATION,
    :listing_order => 2
  }

  def admin_added_notification(member, added_by, invite_text, reset_password)
    @member = member
    @reset_password = reset_password
    @added_by = added_by
    @invite_text = invite_text
    init_mail
    render_mail
  end

  private

  def init_mail
    setup_recipient_and_organization(@member, @member.organization)
    set_username(@member, :name_only => true)
    setup_email(@member, :sender_name => @added_by.visible_to?(@member) ? sender_name : nil)
    super
  end

  register_tags do
    tag :url_invite, :description => Proc.new{'email_translations.admin_added_notification.tags.url_invite.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      new_user_followup_users_url(:subdomain => @organization.subdomain, :reset_code => @reset_password.reset_code)
    end

    tag :sender_name, :description => Proc.new{'email_translations.admin_added_notification.tags.sender_name.description'.translate}, :example => Proc.new{'Alice Green'} do
      @added_by.name
    end

    tag :invite_message, :description => Proc.new{'email_translations.admin_added_notification.tags.invite_message.description'.translate}, :example => Proc.new{'email_translations.admin_added_notification.tags.invite_message.example'.translate} do
      word_wrap(@invite_text || "")
    end

    tag :invite_message_as_quote, :description => Proc.new{'email_translations.admin_added_notification.tags.invite_message_as_quote.description'.translate}, :example => Proc.new{'feature.email.tags.message_from_user_v3_html'.translate(:message => 'email_translations.admin_added_notification.tags.invite_message.example'.translate, :name => 'feature.email.tags.mentor_name.example'.translate)} do
      word_wrap(@invite_text.present? ? 'feature.email.tags.message_from_user_v3_html'.translate(:message => @invite_text, :name => sender_name) : "").html_safe
    end

    tag :accept_and_signup_button, :description => Proc.new{'email_translations.admin_added_notification.tags.accept_and_signup_button.description'.translate}, :example => Proc.new{ call_to_action_example('email_translations.admin_added_notification.accept_and_signup_text_html'.translate) } do
      call_to_action('email_translations.admin_added_notification.accept_and_signup_text_html'.translate, new_user_followup_users_url(:subdomain => @organization.subdomain, :reset_code => @reset_password.reset_code))
    end
  end

  self.register!

end

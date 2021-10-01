class MemberSuspensionNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'csxj4suk', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::ENROLLMENT_AND_USER_MANAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::USER_MANAGEMENT,
    :title        => Proc.new{|program| "email_translations.member_suspension_notification.title_v1".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.member_suspension_notification.description_v3".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.member_suspension_notification.subject".translate},
    :campaign_id  => CampaignConstants::MEMBERSHIP_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :program_settings => Proc.new{|program| !program.standalone? || program.organization.org_profiles_enabled?},
    :campaign_id_2  => CampaignConstants::MEMBER_SUSPENSION_NOTIFICATION_MAIL_ID,
    :level        => EmailCustomization::Level::ORGANIZATION,
    :listing_order => 5
  }

  def member_suspension_notification(member, reason, admin)
    @member = member
    @reason = reason
    @organization = member.organization
    @admin = admin
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

    tag :reason, :description => Proc.new{'email_translations.member_suspension_notification.tags.reason.description'.translate}, :example => Proc.new{'email_translations.member_suspension_notification.tags.reason.example'.translate} do
      wrap_and_break(@reason)
    end

    tag :url_contact_admin, :description => Proc.new{'email_translations.member_suspension_notification.tags.url_contact_admin.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      get_contact_admin_path(nil, url_params: { subdomain: @organization.subdomain }, organization: @organization, only_url: true)
    end

    tag :reason_as_quote, :description => Proc.new{'email_translations.member_suspension_notification.tags.reason_as_quote.description'.translate}, :example => Proc.new{"feature.email.tags.message_from_user_v3_html".translate(message: 'email_translations.member_suspension_notification.tags.reason.example'.translate, name: 'feature.email.tags.mentor_name.example'.translate)} do
      word_wrap(@reason.present? ? "feature.email.tags.message_from_user_v3_html".translate(message: @reason, name: @admin.name) : "").html_safe
    end
  end

  self.register!

end

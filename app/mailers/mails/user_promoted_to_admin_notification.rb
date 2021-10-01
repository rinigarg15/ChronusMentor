class UserPromotedToAdminNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'wnws3nva', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::ENROLLMENT_AND_USER_MANAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::ADMIN_ADDING_USERS,
    :title        => Proc.new{|program| "email_translations.user_promoted_to_admin_notification.title_v2".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.user_promoted_to_admin_notification.description".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.user_promoted_to_admin_notification.subject".translate},
    :campaign_id  => CampaignConstants::PROMOTED_TO_ADMIN_MAIL_ID,
    :level        => EmailCustomization::Level::ORGANIZATION,
    :listing_order => 11
  }

  def user_promoted_to_admin_notification(member, added_by)
    @member = member
    @added_by = added_by
    init_mail
    render_mail
  end

  private

  def init_mail
    setup_recipient_and_organization(@member, @member.organization)
    set_username(@member, :name_only => true)
    setup_email(@member, :sender_name => @added_by.visible_to?(@member) ? invitor_name : nil)
    super
  end

  register_tags do
    tag :receiver_name, :description => Proc.new{'email_translations.user_promoted_to_admin_notification.tags.receiver_name.description'.translate}, :example => Proc.new{'Alice Green'} do
      @member.name
    end

    tag :invitor_name, :description => Proc.new{'email_translations.user_promoted_to_admin_notification.tags.invitor_name.description'.translate(admin: @_admin_string)}, :example => Proc.new{'John Doe'} do
      get_sender_name(@added_by)
    end

    tag :organization_login_url, :description => Proc.new{'email_translations.user_promoted_to_admin_notification.tags.organization_login_url.description'.translate}, :example => Proc.new{'http://www.chronus.com/login'} do
      login_url(:subdomain => @organization.subdomain)
    end

    tag :visit_organization_button, :description => Proc.new{'email_translations.user_promoted_to_admin_notification.tags.visit_organization_button.description'.translate}, :example => Proc.new{ call_to_action_example("email_translations.user_promoted_to_admin_notification.tags.visit_organization_button.example".translate) } do
      call_to_action("email_translations.user_promoted_to_admin_notification.tags.visit_organization_button.visit_org".translate(subprogram_or_program_name: @organization.name), login_url(:subdomain => @organization.subdomain))
    end
  end

  self.register!

end

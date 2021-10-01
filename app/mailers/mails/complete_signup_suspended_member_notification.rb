class CompleteSignupSuspendedMemberNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => "v957q1as", # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::ENROLLMENT_AND_USER_MANAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::APPLY_TO_JOIN,
    :title        => Proc.new{|program| "email_translations.complete_signup_suspended_member_notification.title".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.complete_signup_suspended_member_notification.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.complete_signup_suspended_member_notification.subject".translate},
    :program_settings => Proc.new{|program| program.can_show_apply_to_join_mailer_templates? },
    :campaign_id  => CampaignConstants::MEMBERSHIP_MAIL_ID,
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 4
  }

  def complete_signup_suspended_member_notification(program, member)
    mail_locale = Language.for_member(member, program)
    GlobalizationUtils.run_in_locale(mail_locale) do
      @member = member
      @program = program
      init_mail
      render_mail
    end
  end

  private

  def init_mail
    set_program(@program)
    set_username(@member)
    setup_email(@member)
    super
  end

  register_tags do
    tag :url_contact_admin, description: Proc.new { "email_translations.complete_signup_suspended_member_notification.tags.url_contact_admin.description".translate }, example: Proc.new { "http://www.chronus.com" } do
      get_contact_admin_path(@program, { only_url: true, url_params: { subdomain: @program.organization.subdomain, root: @program.root } } )
    end
  end
  self.register!
end
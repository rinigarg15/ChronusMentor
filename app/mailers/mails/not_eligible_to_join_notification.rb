class NotEligibleToJoinNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'f72i4420', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::ENROLLMENT_AND_USER_MANAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::APPLY_TO_JOIN,
    :title        => Proc.new{|program| "email_translations.not_eligible_to_join_notification.title_v1".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.not_eligible_to_join_notification.description_v1".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.not_eligible_to_join_notification.subject".translate},
    :campaign_id  => CampaignConstants::NOT_ELIGIBLE_TO_JOIN,
    :program_settings => Proc.new{ |program| (program.has_allowing_join_with_criteria?)},
    :level        => EmailCustomization::Level::PROGRAM,
    :skip_rollout => true,
    :listing_order => 3
  }

  def not_eligible_to_join_notification(program, member, role_names)
    @program = program
    @member = member
    @role_names = role_names

    mail_locale = Language.for_member(member, program)
    GlobalizationUtils.run_in_locale(mail_locale) do
      init_mail
      render_mail
    end
  end

  private

  def init_mail
    set_program(@program)
    set_username(@member, :name_only => true)
    setup_email(@member)
    super
  end

  register_tags do
    tag :roles_applied_for, :description => Proc.new{'email_translations.not_eligible_to_join_notification.tags.roles_applied_for.description'.translate}, :example => Proc.new{|program| 'email_translations.not_eligible_to_join_notification.tags.roles_applied_for.example_v1'.translate(:role => program.get_first_role_term(:articleized_term_downcase))} do
      RoleConstants.human_role_string(@role_names, :program => @program, :articleize => true, :no_capitalize => true)
    end

    tag :url_contact_admin, :description => Proc.new{'email_translations.not_eligible_to_join_notification.tags.url_contact_admin.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      get_contact_admin_path(@program, url_params: { subdomain: @organization.subdomain, root: @program.root }, only_url: true)
    end
  end
  self.register!
end
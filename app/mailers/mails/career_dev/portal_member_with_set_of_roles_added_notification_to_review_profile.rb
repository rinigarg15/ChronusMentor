class PortalMemberWithSetOfRolesAddedNotificationToReviewProfile < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'ri9smoxk', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::ENROLLMENT_AND_USER_MANAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::ADMIN_ADDING_USERS,
    :title        => Proc.new{|program| "email_translations.portal_member_with_set_of_roles_added_notification_to_review_profile.title".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.portal_member_with_set_of_roles_added_notification_to_review_profile.description".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.portal_member_with_set_of_roles_added_notification_to_review_profile.subject".translate},
    :campaign_id  => CampaignConstants::MEMBERSHIP_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :program_settings => Proc.new{ |program| program.is_career_developement_program? },
    :campaign_id_2  => CampaignConstants::PORTAL_MEMBER_WITH_SET_OF_ROLES_ADDED_NOTIFICATION_TO_REVIEW_PROFILE_MAIL_ID,
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 9
  }

  def portal_member_with_set_of_roles_added_notification_to_review_profile(user, added_by, reset_password)
    @user = user
    @role_str = RoleConstants.human_role_string(@user.roles.collect(&:name), program: @user.program, articleize: true)
    @added_by = added_by
    @reset_password = reset_password
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@user.program)
    set_username(@user, :name_only => true)
    setup_email(@user, :from => :admin)
    super
  end

  register_tags do
    tag :url_invite, :description => Proc.new{'email_translations.portal_member_with_set_of_roles_added_notification_to_review_profile.tags.url_invite.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      new_user_followup_users_url(:subdomain => @organization.subdomain, :reset_code => @reset_password.reset_code)
    end

    tag :invitor_name, :description => Proc.new{'email_translations.portal_member_with_set_of_roles_added_notification_to_review_profile.tags.invitor_name.description'.translate}, :example => Proc.new{'Alice Green'} do
      @added_by.name(:name_only => true)
    end

    tag :role_names, :description => Proc.new{'email_translations.portal_member_with_set_of_roles_added_notification_to_review_profile.tags.role_names.description'.translate}, :example => Proc.new{|program| 'email_translations.portal_member_with_set_of_roles_added_notification_to_review_profile.tags.role_names.example'.translate(:role => program.get_first_role_term(:articleized_term))} do
      @role_str
    end

    tag :accept_sign_up, :description => Proc.new{'email_translations.portal_member_with_set_of_roles_added_notification_to_review_profile.tags.accept_sign_up.description'.translate}, :example => Proc.new{ call_to_action_example("email_translations.portal_member_with_set_of_roles_added_notification_to_review_profile.tags.accept_sign_up.accept".translate) } do
      call_to_action("email_translations.portal_member_with_set_of_roles_added_notification_to_review_profile.tags.accept_sign_up.accept".translate, new_user_followup_users_url(:subdomain => @organization.subdomain, :reset_code => @reset_password.reset_code))
    end

    tag :url_contact_admin, :description => Proc.new{'email_translations.portal_member_with_set_of_roles_added_notification_to_review_profile.tags.url_contact_admin.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      get_contact_admin_path(@program, url_params: { subdomain: @organization.subdomain, root: @program.root }, only_url: true)
    end
  end

  self.register!

end

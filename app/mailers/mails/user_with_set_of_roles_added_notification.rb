class UserWithSetOfRolesAddedNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => '24vvapdy', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::ENROLLMENT_AND_USER_MANAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::ADMIN_ADDING_USERS,
    :title        => Proc.new{|program| "email_translations.user_with_set_of_roles_added_notification.title_v5".translate(program.return_custom_term_hash_with_third_role)},
    :description  => Proc.new{|program| "email_translations.user_with_set_of_roles_added_notification.description_v5".translate(program.return_custom_term_hash_with_third_role)},
    :subject      => Proc.new{"email_translations.user_with_set_of_roles_added_notification.subject_v1".translate},
    :campaign_id  => CampaignConstants::MEMBERSHIP_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :program_settings => Proc.new{ |program| !program.is_career_developement_program? },
    :campaign_id_2  => CampaignConstants::USER_WITH_SET_OF_ROLES_ADDED_NOTIFICATION_MAIL_ID,
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 5
  }

  def user_with_set_of_roles_added_notification(user, added_by, reset_password)
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
    tag :url_invite, :description => Proc.new{'email_translations.user_with_set_of_roles_added_notification.tags.url_invite.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      if @user.member.can_signin?
        edit_member_url(@user.member, :subdomain => @organization.subdomain)
      else
        new_user_followup_users_url(:subdomain => @organization.subdomain, :reset_code => @reset_password.reset_code)
      end
    end

    tag :invitor_name, :description => Proc.new{'email_translations.user_with_set_of_roles_added_notification.tags.invitor_name.description'.translate}, :example => Proc.new{'Alice Green'} do
      get_sender_name(@added_by)
    end

    tag :role_names, :description => Proc.new{'email_translations.user_with_set_of_roles_added_notification.tags.role_names.description_v1'.translate}, :example => Proc.new{'email_translations.user_with_set_of_roles_added_notification.tags.role_names.example_v1'.translate} do
      @role_str
    end

    tag :accept_and_sign_up_button, :description => Proc.new{'email_translations.user_with_set_of_roles_added_notification.tags.accept_and_sign_up_button.description'.translate}, :example => Proc.new{ call_to_action_example('email_translations.user_with_set_of_roles_added_notification.accept_and_signup_text'.translate) } do
      call_to_action('email_translations.user_with_set_of_roles_added_notification.accept_and_signup_text'.translate, url_invite)
    end

    tag :url_contact_admin, :description => Proc.new{'email_translations.user_with_set_of_roles_added_notification.tags.url_contact_admin.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      get_contact_admin_path(@program, url_params: { subdomain: @organization.subdomain, root: @program.root }, only_url: true)
    end
  end

  self.register!
end

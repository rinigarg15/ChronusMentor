class WelcomeMessageToPortalUser < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'rcgoo1xh', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::ENROLLMENT_AND_USER_MANAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::WELCOME_MESSAGES,
    :title        => Proc.new{|program| "email_translations.welcome_message_to_portal_user.title_v1".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.welcome_message_to_portal_user.description".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.welcome_message_to_portal_user.subject".translate},
    :campaign_id  => CampaignConstants::WELCOME_MESSAGE_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :program_settings => Proc.new{|program| program.is_career_developement_program?},
    :campaign_id_2  => CampaignConstants::WELCOME_MESSAGE_TO_PORTAL_USER_MAIL_ID,
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 4
  }

  def welcome_message_to_portal_user(user, added_by)
    @user = user
    @added_by = added_by
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@user.program)
    set_username(@user, :name_only => true)
    setup_email(@user)
    super
  end

  register_tags do
    tag :user_role, :description => Proc.new{'email_translations.welcome_message_to_portal_user.tags.user_role.description'.translate}, :example => Proc.new{|program| 'email_translations.welcome_message_to_portal_user.tags.user_role.example_v1'.translate(:role => program.get_first_role_term(:articleized_term))} do
      RoleConstants.human_role_string(@user.role_names, :program => @program, :articleize => true)
    end

    tag :administrator_name, :description => Proc.new{'email_translations.welcome_message_to_portal_user.tags.administrator_name.description'.translate}, :example => Proc.new{'Alice Green'} do
      @added_by.name
    end

    tag :url_edit_profile, :description => Proc.new{'email_translations.welcome_message_to_portal_user.tags.url_edit_profile.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      if @user.member.can_signin?
        edit_member_url(@user.member, :subdomain => @organization.subdomain, :root => @program.root)
      else
        reset_password = Password.create!(:member => @user.member)
        new_user_followup_users_url(:subdomain => @organization.subdomain, :reset_code => reset_password.reset_code)
      end
    end

    tag :visit_program_button, :description => Proc.new{'email_translations.welcome_message_to_portal_user.tags.visit_program_button.description'.translate}, :example => Proc.new{ call_to_action_example("email_translations.welcome_message_to_portal_user.tags.visit_program_button.visit".translate(program_name: "feature.custom_terms.program".translate)) } do
      call_to_action("email_translations.welcome_message_to_portal_user.tags.visit_program_button.visit".translate(program_name: @program.name), login_url(:subdomain => @program.organization.subdomain, :root => @program.root, :src => :mail))
    end

    tag :url_contact_admin, :description => Proc.new{'email_translations.welcome_message_to_portal_user.tags.url_contact_admin.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      get_contact_admin_path(@user.program, {:only_url => true, :url_params => {:subdomain => @organization.subdomain, :root => @user.program.root}})
    end

    tag :url_visit_program, :description => Proc.new{'email_translations.welcome_message_to_portal_user.tags.url_visit_program.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      if @user.member.can_signin?
        url_program_login
      else
        reset_password = Password.create!(:member => @user.member)
        new_user_followup_users_url(:subdomain => @organization.subdomain, :reset_code => reset_password.reset_code)
      end
    end
  end

  self.register!

end

class WelcomeMessageToAdmin < ChronusActionMailer::Base

  @mailer_attributes = {
    uid:          'ug4s9un2', # rand(36**8).to_s(36)
    category:     EmailCustomization::NewCategories::Type::ENROLLMENT_AND_USER_MANAGEMENT,
    subcategory:  EmailCustomization::NewCategories::SubCategories::WELCOME_MESSAGES,
    title:        Proc.new{|program| "email_translations.welcome_message_to_admin.title_v3".translate(program.return_custom_term_hash)},
    description:  Proc.new{|program| "email_translations.welcome_message_to_admin.description_v2".translate(program.return_custom_term_hash)},
    subject:      Proc.new{"email_translations.welcome_message_to_admin.subject_v1".translate},
    campaign_id:  CampaignConstants::WELCOME_MESSAGE_MAIL_ID,
    user_states:  [User::Status::ACTIVE, User::Status::PENDING],
    campaign_id_2:  CampaignConstants::WELCOME_MESSAGE_TO_ADMIN_MAIL_ID,
    level:        EmailCustomization::Level::PROGRAM,
    listing_order: 3
  }

  def welcome_message_to_admin(user)
    @user = user

    init_mail
    render_mail
  end


  private

  def init_mail
    set_program(@user.program)
    set_username(@user, name_only: true)
    setup_email(@user)
    super
  end

  register_tags do
    tag :url_invite_mentors, description: Proc.new{'email_translations.welcome_message_to_admin.tags.url_invite_mentors.description'.translate}, example: Proc.new{'http://www.chronus.com'} do
      invite_users_url(role: :mentors, subdomain: @organization.subdomain, from: @user.role_names)
    end

    tag :url_add_mentor, description: Proc.new{'email_translations.welcome_message_to_admin.tags.url_add_mentor.description'.translate}, example: Proc.new{'http://www.chronus.com'} do
      new_user_url(role: RoleConstants::MENTOR_NAME, subdomain: @organization.subdomain)
    end

    tag :url_invite_mentees, description: Proc.new{'email_translations.welcome_message_to_admin.tags.url_invite_mentees.description'.translate}, example: Proc.new{'http://www.chronus.com'} do
      invite_users_url(role: :students, subdomain: @organization.subdomain, from: @user.role_names)
    end

    tag :url_customize_profile_form, description: Proc.new{'email_translations.welcome_message_to_admin.tags.url_customize_profile_form.description'.translate}, example: Proc.new{'http://www.chronus.com'} do
      role_questions_url(subdomain: @organization.subdomain)
    end

    tag :url_customize_program, description: Proc.new{'email_translations.welcome_message_to_admin.tags.url_customize_program.description'.translate}, example: Proc.new{'http://www.chronus.com'} do
      edit_program_url(subdomain: @organization.subdomain)
    end

    tag :url_customer_support, description: Proc.new{'email_translations.welcome_message_to_admin.tags.url_customer_support.description'.translate}, example: Proc.new{'http://www.chronus.com'} do
      get_support_url(subdomain: @organization.subdomain, url: true)
    end

    tag :url_program_health, description: Proc.new{'email_translations.welcome_message_to_admin.tags.url_program_health.description'.translate}, example: Proc.new{'http://www.chronus.com'} do
      @user.program.get_program_health_url
    end
  end
  self.register!
end
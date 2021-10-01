class ResendSignupInstructions < ChronusActionMailer::Base
  @mailer_attributes = {
    :uid          => 'loj9oida', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::ENROLLMENT_AND_USER_MANAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::ADMIN_ADDING_USERS,
    :title        => Proc.new{|program| "email_translations.resend_signup_instructions.title_v4".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.resend_signup_instructions.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.resend_signup_instructions.subject_v1".translate},
    :campaign_id  => CampaignConstants::ENGAGEMENT_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :campaign_id_2  => CampaignConstants::RESEND_SIGNUP_INSTRUCTIONS_MAIL_ID,
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 8
  }

  def resend_signup_instructions(user, reset_password)
    @user = user
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
    tag :url_invite, :description => Proc.new{'email_translations.resend_signup_instructions.tags.url_invite.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      new_user_followup_users_url(:subdomain => @organization.subdomain, :reset_code => @reset_password.reset_code)
    end

    tag :sign_up_button, :description => Proc.new{'email_translations.resend_signup_instructions.tags.sign_up_button.description'.translate}, :example => Proc.new{ call_to_action_example("email_translations.resend_signup_instructions.tags.sign_up_button.signup".translate) } do
      call_to_action("email_translations.resend_signup_instructions.tags.sign_up_button.signup".translate, new_user_followup_users_url(:subdomain => @organization.subdomain, :reset_code => @reset_password.reset_code))
    end

  end  

  self.register!
end
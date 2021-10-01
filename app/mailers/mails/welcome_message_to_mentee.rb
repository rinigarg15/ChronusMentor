class WelcomeMessageToMentee < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => '1rz1ude3', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::ENROLLMENT_AND_USER_MANAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::WELCOME_MESSAGES,
    :title        => Proc.new{|program| "email_translations.welcome_message_to_mentee.title_v3".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.welcome_message_to_mentee.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.welcome_message_to_mentee.subject_v1".translate},
    :campaign_id  => CampaignConstants::WELCOME_MESSAGE_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :program_settings => Proc.new{ |program| program.has_role?(RoleConstants::STUDENT_NAME)},
    :campaign_id_2  => CampaignConstants::WELCOME_MESSAGE_TO_MENTEE_MAIL_ID,
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 2
  }

  def welcome_message_to_mentee(user, options = {})
    @user = user
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
    tag :url_edit_profile, :description => Proc.new{'email_translations.welcome_message_to_mentee.tags.url_edit_profile.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      edit_member_url(@user.member, :subdomain => @organization.subdomain, :root => @program.root, :prof_c => true)
    end

    tag :login_to_program_button, :description => Proc.new{'email_translations.welcome_message_to_mentee.tags.login_to_program_button.description'.translate}, :example => Proc.new{ call_to_action_example("email_translations.welcome_message_to_mentee.tags.login_to_program_button.visit".translate(program_name: "feature.custom_terms.program".translate)) } do
      call_to_action("email_translations.welcome_message_to_mentee.tags.login_to_program_button.visit".translate(program_name: @program.name), login_url(:subdomain => @program.organization.subdomain, :root => @program.root, :src => :mail))
    end

    tag :url_contact_admin, :description => Proc.new{'email_translations.welcome_message_to_mentee.tags.url_contact_admin.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      get_contact_admin_path(@user.program, {:only_url => true, :url_params => {:subdomain => @organization.subdomain, :root => @user.program.root}})
    end    
  end

  self.register!

end

class MenteeAddedNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'jvak8hbo', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::ENROLLMENT_AND_USER_MANAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::ADMIN_ADDING_USERS,
    :title        => Proc.new{|program| "email_translations.mentee_added_notification.title_v3".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.mentee_added_notification.description_v3".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.mentee_added_notification.subject_v1".translate},
    :campaign_id  => CampaignConstants::MEMBERSHIP_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :program_settings => Proc.new{ |program| program.has_role?(RoleConstants::STUDENT_NAME)},
    :campaign_id_2  => CampaignConstants::MENTEE_ADDED_NOTIFICATION_MAIL_ID,
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 3
  }

  def mentee_added_notification(mentee, added_by, reset_password)
    @user = mentee
    @added_by = added_by
    @reset_password = reset_password
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@user.program)
    set_username(@user)
    setup_email(@user, :from => :admin, :sender_name => @added_by.visible_to?(@user) ? invitor_name : nil)
    super
  end

  register_tags do
    tag :url_invite, :description => Proc.new{'email_translations.mentee_added_notification.tags.url_invite.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      if @user.member.can_signin?
        edit_member_url(@user.member, :subdomain => @organization.subdomain)
      else
        new_user_followup_users_url(:subdomain => @organization.subdomain, :reset_code => @reset_password.reset_code)
      end
    end

    tag :invitor_name, :description => Proc.new{'email_translations.mentee_added_notification.tags.invitor_name.description'.translate}, :example => Proc.new{'Alice Green'} do
      get_sender_name(@added_by)
    end

    tag :accept_and_signup_button, :description => Proc.new{'email_translations.mentee_added_notification.tags.accept_and_signup_button.description'.translate}, :example => Proc.new{ call_to_action_example('email_translations.mentee_added_notification.accept_and_signup_text_html'.translate) } do
      call_to_action('email_translations.mentee_added_notification.accept_and_signup_text_html'.translate, url_invite)
    end

    tag :url_contact_admin, :description => Proc.new{'email_translations.mentee_added_notification.tags.url_contact_admin.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      get_contact_admin_path(@user.program, url_params: { subdomain: @organization.subdomain, root: @user.program.root }, only_url: true)
    end
  end

  self.register!

end

class InviteNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => '7as01het', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::ENROLLMENT_AND_USER_MANAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::INVITATION,
    :title        => Proc.new{|program| "email_translations.invite_notification.title_v3".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.invite_notification.description_v3".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.invite_notification.subject_v1".translate},
    :campaign_id  => CampaignConstants::MEMBERSHIP_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :skip_default_salutation => true,
    :program_settings => Proc.new{ |program| program.has_roles_that_can_invite? },
    :campaign_id_2  => CampaignConstants::INVITE_NOTIFICATION_MAIL_ID,
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 1
  }

  def invite_notification(invite, options={})
    @invite = invite
    @options = options
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@invite.program)
    set_sender(@options)
    # If there's a membership_request, use the name from the membership request.
    # Else, use the first part of the email address.
    member = @invite.sent_to_member
    set_username(member, name: @invite.sent_to.split('@').first.capitalize, name_only: true)
    setup_email(nil, email: @invite.sent_to, from: :admin, sender_name: invitor_name, message_type: EmailCustomization::MessageType::COMMUNICATION)
    super
  end

  register_tags do
    tag :invitor_name, :description => Proc.new{'email_translations.invite_notification.tags.invitor_name.description'.translate}, :example => Proc.new{"John Doe"} do
      get_sender_name(@invite.user)
    end

    tag :invited_as, :description => Proc.new{'email_translations.invite_notification.tags.invited_as.description'.translate}, :example => Proc.new{|program| 'email_translations.invite_notification.tags.invited_as.example_v1'.translate(:role => program.get_first_role_term(:articleized_term_downcase))} do
      RoleConstants.human_role_string(@invite.role_names, :program => @program, :no_capitalize => true, :articleize => true)
    end

    tag :url_invitation, :description => Proc.new{'email_translations.invite_notification.tags.url_invitation.description'.translate}, :example => Proc.new{"http://www.chronus.com"} do
      new_registration_url(invite_code: @invite.code, subdomain: @organization.subdomain)
    end

    tag :invitation_message, :description => Proc.new{'email_translations.invite_notification.tags.invitation_message.description'.translate}, :example => Proc.new{'feature.email.tags.message_from_user_v3_html'.translate(:message => 'email_translations.invite_notification.tags.invitation_message.example'.translate, :name => "feature.email.tags.mentor_name.example".translate)} do
      word_wrap(@invite.message.present? ? 'feature.email.tags.message_from_user_v3_html'.translate(:message => @invite.message.html_safe, :name => invitor_name) : "").html_safe
    end

    tag :accept_sign_up_button, :description => Proc.new{'email_translations.invite_notification.tags.accept_sign_up_button.description'.translate}, :example => Proc.new{ call_to_action_example("email_translations.invite_notification.tags.accept_sign_up_button.accept_sign_up".translate) } do
      call_to_action("email_translations.invite_notification.tags.accept_sign_up_button.accept_sign_up".translate, new_registration_url(invite_code: @invite.code, subdomain: @organization.subdomain))
    end

    tag :as_role_name_articleized, :description => Proc.new{'email_translations.invite_notification.tags.as_role_name_articleized.description'.translate}, :example => Proc.new{|program| 'email_translations.invite_notification.tags.as_role_name_articleized.example_v1'.translate(:role => program.get_first_role_term(:articleized_term_downcase))} do
      @invite.role_names.present? ? RoleConstants.human_role_string(@invite.role_names, :program => @program, :no_capitalize => true, :articleize => true, :as => true) : ""
    end

    tag :url_contact_admin, :description => Proc.new{'email_translations.invite_notification.tags.url_contact_admin.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      get_contact_admin_path(@program, url_params: { subdomain: @organization.subdomain, root: @program.root }, only_url: true)
    end
  end

  self.register!

end

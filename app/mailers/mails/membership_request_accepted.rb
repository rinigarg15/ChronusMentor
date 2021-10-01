class MembershipRequestAccepted < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'z6g2m5of', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::ENROLLMENT_AND_USER_MANAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::APPLY_TO_JOIN,
    :title        => Proc.new{|program| "email_translations.membership_request_accepted.title_v2".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.membership_request_accepted.description_v3".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.membership_request_accepted.subject_v1".translate},
    :campaign_id  => CampaignConstants::MEMBERSHIP_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :program_settings => Proc.new{ |program| program.role_names_allowing_membership_request.present? || program.membership_requests.pending.present? },
    :campaign_id_2  => CampaignConstants::MEMBERSHIP_REQUEST_ACCEPTED_MAIL_ID,
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 7
  }

  def membership_request_accepted(user, membership_request)
    @user = user

    # We're sending the mail to the requestor
    @membership_request = membership_request
    @reset_password = Password.create!(member: user.member)
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@membership_request.program)
    set_username(@user)
    setup_email(@user, {:from => :admin, :sender_name => @membership_request.admin.visible_to?(@user) ? accepted_admin_name : nil})
    super
  end

  register_tags do
    tag :member_role, :description => Proc.new{'email_translations.membership_request_accepted.tags.member_role.description'.translate}, :example => Proc.new { |program| 'email_translations.membership_request_accepted.tags.member_role.example_v1'.translate(role: program.get_first_role_term(:articleized_term_downcase)) } do
      RoleConstants.human_role_string(@membership_request.accepted_role_names, :program => @program, :no_capitalize => true, :articleize => true)
    end

    tag :url_signup, :description => Proc.new{'email_translations.membership_request_accepted.tags.url_signup.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      if @user.member.can_signin?
        edit_member_url(@user.member, :subdomain => @organization.subdomain, :root => @program.root, :first_visit => true)
      else
        new_user_followup_users_url(:subdomain => @organization.subdomain, :reset_code => @reset_password.reset_code)
      end
    end

    tag :accepted_admin_name, :description => Proc.new{'email_translations.membership_request_accepted.tags.accepted_admin_name.description'.translate}, :example => Proc.new{'Alice Green'} do
      @membership_request.admin.name(:name_only => true)
    end

    tag :message_from_admin, :description => Proc.new{'email_translations.membership_request_accepted.tags.message_from_admin.description'.translate}, :example => Proc.new{'feature.email.tags.message_from_user_v3_html'.translate(:message => 'email_translations.membership_request_accepted.tags.message_from_admin.example'.translate, :name => 'feature.email.tags.mentor_name.example'.translate)} do
      word_wrap(@membership_request.response_text.present? ? 'feature.email.tags.message_from_user_v3_html'.translate(:message => @membership_request.response_text, :name => accepted_admin_name) : "").html_safe
    end

    tag :admin_name, :description => Proc.new{'email_translations.membership_request_accepted.tags.admin_name.description'.translate}, :example => Proc.new{'feature.email.tags.mentor_name.example'.translate} do
      @membership_request.admin.name(:name_only => true)
    end

    tag :login_button, :description => Proc.new{'email_translations.membership_request_accepted.tags.login_button.description'.translate}, :example => Proc.new{ call_to_action_example('email_translations.membership_request_accepted.login_text'.translate) } do
      if @user.member.can_signin?
        call_to_action('email_translations.membership_request_accepted.login_text'.translate, edit_member_url(@user.member, :subdomain => @organization.subdomain, :root => @program.root))
      else
        call_to_action('email_translations.membership_request_accepted.login_text'.translate, new_user_followup_users_url(:subdomain => @organization.subdomain, :reset_code => @reset_password.reset_code))
      end
    end
  end

  self.register!

end

class PromotionNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'd7msk4vv', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::ENROLLMENT_AND_USER_MANAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::USER_MANAGEMENT,
    :title        => Proc.new{|program| "email_translations.promotion_notification.title_v2".translate},
    :description  => Proc.new{|program| "email_translations.promotion_notification.description_v4".translate(program.return_custom_term_hash.merge(a_non_admin_role_term: program.get_first_role_term(:articleized_term_downcase)))},
    :subject      => Proc.new{"email_translations.promotion_notification.subject_v1".translate},
    :campaign_id  => CampaignConstants::USER_SETTINGS_ROLES_MAIL_ID,
    :campaign_id_2  => CampaignConstants::PROMOTION_NOTIFICATION_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 1
  }

  def promotion_notification(user, promoted_roles, promoted_by, promotion_reason = '')
    @user = user
    @promoted_roles = promoted_roles
    @promoted_by = promoted_by
    @promotion_reason = promotion_reason

    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@user.program)
    set_username(@user)
    setup_email(@user, :from => @promoted_by.name)
    super
    set_layout_options(:program => @program)
  end

  register_tags do
    tag :administrator_name, :description => Proc.new{'email_translations.promotion_notification.tags.administrator_name.description'.translate}, :example => Proc.new{'Alice Green'} do
      @promoted_by.name
    end

    tag :promoted_role_articleized, :description => Proc.new{'email_translations.promotion_notification.tags.promoted_role_articleized.description'.translate}, :example => Proc.new{ |program| program.get_first_role_term(:articleized_term_downcase) } do
      RoleConstants.human_role_string(@promoted_roles, :program => @program, :articleize => true, :no_capitalize => true)
    end

    tag :promoted_role, :description => Proc.new{'email_translations.promotion_notification.tags.promoted_role.description'.translate}, :example => Proc.new{|program| 'email_translations.promotion_notification.tags.promoted_role.example_v1'.translate(role: program.get_first_role_term(:term_downcase))} do
      RoleConstants.human_role_string(@promoted_roles, :program => @program, :articleize => false, :no_capitalize => true)
    end

    tag :administrator_message, :description => Proc.new{'email_translations.promotion_notification.tags.administrator_message.description'.translate}, :example => Proc.new{'feature.email.tags.message_from_user_v3_html'.translate(:message => 'email_translations.promotion_notification.tags.administrator_message.example'.translate, :name => 'feature.email.tags.mentor_name.example'.translate)} do
      word_wrap(@promotion_reason.present? ? 'feature.email.tags.message_from_user_v3_html'.translate(:message => @promotion_reason, :name => role_changer_name) : "").html_safe
    end

    tag :url_profile_completion, :description => Proc.new{'email_translations.promotion_notification.tags.url_profile_completion.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      if @user.member.can_signin?
        edit_member_url(@user.member, :subdomain => @program.organization.subdomain, :first_visit => true)
      else
        reset_password = Password.create!(:member => @user.member)
        new_user_followup_users_url(:subdomain => @program.organization.subdomain, :reset_code => reset_password.reset_code)
      end
    end

    tag :role_changer_name, :description => Proc.new{'email_translations.promotion_notification.tags.role_changer_name.description'.translate}, :example => Proc.new{'feature.email.tags.mentor_name.example'.translate} do
      @promoted_by.name(:name_only => true)
    end

    tag :update_profile_button, :description => Proc.new{'email_translations.promotion_notification.tags.update_profile_button.description'.translate}, :example => Proc.new{ call_to_action_example('email_translations.promotion_notification.update_your_profile'.translate) } do
      if @user.member.can_signin?
        call_to_action('email_translations.promotion_notification.update_your_profile'.translate, edit_member_url(@user.member, subdomain: @program.organization.subdomain, first_visit: true))
      else
        reset_password = Password.create!(:member => @user.member)
        call_to_action('email_translations.promotion_notification.update_your_profile'.translate, new_user_followup_users_url(:subdomain => @program.organization.subdomain, :reset_code => reset_password.reset_code))
      end
    end

    tag :url_contact_admin, :description => Proc.new{'email_translations.promotion_notification.tags.url_contact_admin.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      get_contact_admin_path(@program, url_params: { subdomain: @program.organization.subdomain, root: @program.root }, only_url: true)
    end

  end

  self.register!

end

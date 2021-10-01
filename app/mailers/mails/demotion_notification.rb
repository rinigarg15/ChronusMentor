class DemotionNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'mif2l74o', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::ENROLLMENT_AND_USER_MANAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::USER_MANAGEMENT,
    :title        => Proc.new{|program| "email_translations.demotion_notification.title_v3".translate},
    :description  => Proc.new{|program| "email_translations.demotion_notification.description_v3".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.demotion_notification.subject_v1".translate},
    :campaign_id  => CampaignConstants::USER_SETTINGS_ROLES_MAIL_ID,
    :campaign_id_2  => CampaignConstants::DEMOTION_NOTIFICATION_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 2
  }

  def demotion_notification(user, demoted_roles, demoted_by, reason)
    @user = user
    @demoted_roles = demoted_roles
    @demoted_by = demoted_by
    @reason = reason
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@user.program)
    set_username(@user)
    setup_email(@user, :from => @demoted_by.name, :sender_name => @demoted_by.visible_to?(@user) ? role_changer_name : nil)
    super
    set_layout_options(:program => @program)
  end

  register_tags do
    tag :role_name, :description => Proc.new{'email_translations.demotion_notification.tags.role_name.description_v2'.translate}, :example => Proc.new { |program| program.get_first_role_term(:articleized_term_downcase) } do
      RoleConstants.human_role_string(@demoted_roles, :program => @program, :articleize => true, :no_capitalize => true)
    end

    tag :role_changer_name, :description => Proc.new{'email_translations.demotion_notification.tags.role_changer_name.description'.translate}, :example => Proc.new{'Alice Green'} do
      @demoted_by.name
    end

    tag :url_contact_admin, :description => Proc.new{'email_translations.demotion_notification.tags.url_contact_admin.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      get_contact_admin_path(@user.program, {:only_url => true, :url_params => {:subdomain => @organization.subdomain, :root => @user.program.root}})
    end

    tag :administrator_message, :description => Proc.new{'email_translations.demotion_notification.tags.administrator_message.description'.translate}, :example => Proc.new{'email_translations.demotion_notification.tags.administrator_message.example'.translate} do
      @reason.present? ? ("<br/><br/>".html_safe + 'email_translations.demotion_notification.tags.administrator_message.content'.translate(Admin: @_Admin_string, message: @reason) ): ''
    end

    tag :message_content, :description => Proc.new{'email_translations.demotion_notification.tags.message_content.description'.translate},  :example => Proc.new{'feature.email.tags.message_from_user_v3_html'.translate(:message => 'email_translations.demotion_notification.tags.message_content.example'.translate, :name => 'feature.email.tags.mentor_name.example'.translate)} do
      @reason.present? ? 'feature.email.tags.message_from_user_v3_html'.translate(:message => @reason, :name => @demoted_by.name) : ""
    end
  end

  self.register!

end

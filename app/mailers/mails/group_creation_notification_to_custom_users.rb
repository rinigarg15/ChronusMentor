class GroupCreationNotificationToCustomUsers < ChronusActionMailer::Base
  @mailer_attributes = {
    :uid          => 'nhss6a93', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::ADMIN_INITIATED_MATCHING,
    :title        => Proc.new{|program| "email_translations.group_creation_notification_to_custom_users.title_v3".translate(program.return_custom_term_hash_with_third_role)},
    :description  => Proc.new{|program| "email_translations.group_creation_notification_to_custom_users.description_v3".translate(program.return_custom_term_hash_with_third_role)},
    :subject      => Proc.new{"email_translations.group_creation_notification_to_custom_users.subject_v1".translate},
    :campaign_id  => CampaignConstants::MENTORING_CONNECTION_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :program_settings => Proc.new{|program| program.only_career_based_ongoing_mentoring_enabled? && program.has_custom_role?},
    :campaign_id_2  => CampaignConstants::GROUP_CREATION_NOTIFICATION_TO_CUSTOM_USERS_MAIL_ID,
    :level        => EmailCustomization::Level::PROGRAM,
    :for_role_names => Proc.new{ |program| program.roles.for_mentoring.non_default.pluck(:name) },
    :listing_order => 4
  }

  def group_creation_notification_to_custom_users(user, group)
    @group = group
    @user = user
    @role = @group.memberships.of(user).first.role
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@group.program)
    set_username(@user)
    setup_email(@user, :from => :admin)
    super
  end

  register_tags do

    tag :role_name_articleized, :description => Proc.new{ |program| "email_translations.group_creation_notification_to_custom_users.tags.role_name_articleized.description_v1".translate(program.return_custom_term_hash) }, :example => Proc.new{ |program| program.custom_roles.first.customized_term.articleized_term_downcase } do
      @role.customized_term.articleized_term_downcase
    end

    tag :group_name, :description => Proc.new{"email_translations.group_creation_notification_to_custom_users.tags.group_name.description".translate}, :example => Proc.new{"email_translations.group_creation_notification_to_custom_users.tags.group_name.example".translate} do
      @group.name
    end

    tag :url_mentoring_connection, :description => Proc.new{|program| "email_translations.group_creation_notification_to_custom_users.tags.url_mentoring_connection.description_v1".translate(program.return_custom_term_hash)},  :example => Proc.new{'http://www.chronus.com'} do
      group_url(@group, :subdomain => @organization.subdomain, :first_visit => 1, :src => 'mail')
    end

    tag :mentoring_connection_expiry_date, :description => Proc.new{|program| "email_translations.group_creation_notification_to_custom_users.tags.mentoring_connection_expiry_date.description_v2".translate(program.return_custom_term_hash)}, :example => Proc.new{"email_translations.group_creation_notification_to_custom_users.tags.mentoring_connection_expiry_date.example".translate} do
      formatted_time_in_words(@group.expiry_time, :no_ago => true, :no_time => true)
    end

    tag :message_from_admin, :description => Proc.new{"email_translations.group_creation_notification_to_custom_users.tags.message_from_admin.description".translate}, :example => Proc.new{'feature.email.tags.message_from_administrator_v2_html'.translate(:message_from_admin => "email_translations.group_creation_notification_to_custom_users.tags.message_from_admin.example".translate, :admin => "feature.custom_terms.downcase.admin".translate)} do
      @group.message.present? ? 'feature.email.tags.message_from_administrator_v2_html'.translate(:message_from_admin => @group.message, :admin => @_admin_string) : ""
    end

    tag :url_signup, :description => Proc.new{'email_translations.group_creation_notification_to_custom_users.tags.url_signup.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      reset_password = Password.create!(:member => @user.member)
      new_user_followup_users_url(:subdomain => @organization.subdomain, :reset_code => reset_password.reset_code)
    end

    tag :mentoring_area_button, :description => Proc.new{|program| 'email_translations.group_creation_notification_to_custom_users.tags.mentoring_area_button.description_v1'.translate(program.return_custom_term_hash)}, :example => Proc.new{|program| call_to_action_example("email_translations.group_creation_notification_to_custom_users.visit_your_connection".translate(mentoring_connection: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase)) } do
      call_to_action("email_translations.group_creation_notification_to_custom_users.visit_your_connection".translate(mentoring_connection: @_mentoring_connection_string), group_url(@group, :subdomain => @organization.subdomain, :root => @program.root, :src => :mail))
    end

    tag :url_contact_admin, :description => Proc.new{'email_translations.group_creation_notification_to_custom_users.tags.url_contact_admin.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      get_contact_admin_path(@user.program, url_params: { subdomain: @organization.subdomain, root: @user.program.root }, only_url: true)
    end
  end

  self.register!
end
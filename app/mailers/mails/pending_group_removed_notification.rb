class PendingGroupRemovedNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => "8ubp3fro", # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::NEW_CIRCLES_CREATION,
    :title        => Proc.new{|program| "email_translations.pending_group_removed_notification.title_v2".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.pending_group_removed_notification.description_v3".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.pending_group_removed_notification.subject_v1".translate},
    :campaign_id  => CampaignConstants::PROJECT_REQUESTS_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :program_settings => Proc.new{ |program| program.project_based? },
    :campaign_id_2  => CampaignConstants::PENDING_GROUP_REMOVED_NOTIFICATION_MAIL_ID,
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 5
  }

  def pending_group_removed_notification(user, group, actor)
    @group = group
    @user = user
    @actor = actor
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
    tag :url_find_new_projects, :description => Proc.new{|program| "email_translations.pending_group_removed_notification.tags.url_find_new_projects.description_v1".translate(program.return_custom_term_hash)}, :example => Proc.new{'http://www.chronus.com'} do
      find_new_groups_url(:subdomain => @organization.subdomain, :src => 'mail')
    end

    tag :group_name, :description => Proc.new{"email_translations.pending_group_removed_notification.tags.group_name.description".translate}, :example => Proc.new{"email_translations.pending_group_removed_notification.tags.group_name.example".translate} do
      @group.name
    end

    tag :administrator_or_owner_name, :description => Proc.new{"email_translations.pending_group_removed_notification.tags.administrator_or_owner_name.description".translate}, :example => Proc.new{ |program| "email_translations.pending_group_removed_notification.tags.administrator_or_owner_name.content".translate(program: program.organization.term_for(CustomizedTerm::TermType::PROGRAM_TERM).term_downcase, administrator: program.organization.admin_custom_term.term_downcase) } do
      (@actor.present? && @actor.is_owner_of?(@group)) ? @actor.name(name_only: true) : "email_translations.pending_group_removed_notification.tags.administrator_or_owner_name.content".translate(program: customized_subprogram_term, administrator: customized_admin_term)
    end

    tag :administrator_or_owner_name_capitalized, :description => Proc.new {"email_translations.pending_group_removed_notification.tags.administrator_or_owner_name_capitalized.description".translate}, :example => Proc.new{ |program| "email_translations.pending_group_removed_notification.tags.administrator_or_owner_name_capitalized.content".translate(program: program.organization.term_for(CustomizedTerm::TermType::PROGRAM_TERM).term, administrator: program.organization.admin_custom_term.term) } do
      (@actor.present? && @actor.is_owner_of?(@group)) ? @actor.name(name_only: true) : "email_translations.pending_group_removed_notification.tags.administrator_or_owner_name_capitalized.content".translate(program: customized_subprogram_term_capitalized, administrator: customized_admin_term_capitalized)
    end

    tag :message_from_admin, :description => Proc.new{"email_translations.pending_group_removed_notification.tags.message_from_admin.description".translate}, :example => Proc.new{"feature.email.tags.message_from_user_v3_html".translate(message: "email_translations.pending_group_removed_notification.tags.message_from_admin.example".translate, name: 'feature.email.tags.mentor_name.example'.translate)} do
      word_wrap(@group.message.present? ? "feature.email.tags.message_from_user_v3_html".translate(message: @group.message, name: administrator_or_owner_name) : "").html_safe
    end

    tag :visit_other_connections_button, :description => Proc.new{|program| "email_translations.pending_group_removed_notification.tags.visit_other_connections_button.description_v1".translate(program.return_custom_term_hash)}, :example => Proc.new{|program| call_to_action_example("email_translations.pending_group_removed_notification.visit_other_connections_html".translate(:mentoring_connection_term => program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).pluralized_term_downcase)) } do
      call_to_action("email_translations.pending_group_removed_notification.visit_other_connections_html".translate(:mentoring_connection_term => @_mentoring_connections_string), find_new_groups_url(:subdomain => @organization.subdomain, :src => 'mail'))
    end

    tag :url_contact_admin, :description => Proc.new{'email_translations.pending_group_removed_notification.tags.url_contact_admin.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      get_contact_admin_path(@user.program, url_params: { subdomain: @organization.subdomain, root: @user.program.root }, only_url: true)
    end
  end

  self.register!

end

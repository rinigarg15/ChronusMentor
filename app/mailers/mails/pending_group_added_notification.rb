class PendingGroupAddedNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => '47rwrwbi', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::NEW_CIRCLES_CREATION,
    :title        => Proc.new{|program| "email_translations.pending_group_added_notification.title_v2".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.pending_group_added_notification.description_v3".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.pending_group_added_notification.subject_v1".translate},
    :campaign_id  => CampaignConstants::PROJECT_REQUESTS_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :program_settings => Proc.new{ |program| program.project_based? },
    :campaign_id_2  => CampaignConstants::PENDING_GROUP_ADDED_NOTIFICATION_MAIL_ID,
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 4
  }

  def pending_group_added_notification(user, group, actor)
    @group = group
    @role = @group.memberships.of(user).first.role
    @user = user
    @actor = actor
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@group.program)
    set_username(@user)
    setup_email(@user, :from => :admin, :sender_name => @actor && @actor.visible_to?(@user) ? @actor.try(:name, :name_only => true) : nil)
    super
  end

  register_tags do
    tag :url_mentoring_connection, :description => Proc.new{|program| "email_translations.pending_group_added_notification.tags.url_mentoring_connection.description_v1".translate(program.return_custom_term_hash)}, :example => Proc.new{'http://www.chronus.com'} do
      profile_group_url(@group, :subdomain => @organization.subdomain, :src => 'mail')
    end

    tag :role_name_articleized, :description => Proc.new{|program| "email_translations.pending_group_added_notification.tags.role_name_articleized.description_v1".translate(program.return_custom_term_hash)}, :example => Proc.new{ |program| program.get_first_role_term(:articleized_term_downcase) } do
      @role.customized_term.articleized_term_downcase
    end

    tag :group_name, :description => Proc.new{"email_translations.pending_group_added_notification.tags.group_name.description".translate}, :example => Proc.new{"email_translations.pending_group_added_notification.tags.group_name.example".translate} do
      @group.name
    end

    tag :message_from_admin, :description => Proc.new{"email_translations.pending_group_added_notification.tags.message_from_admin.description".translate}, :example => Proc.new{"email_translations.pending_group_added_notification.tags.message_from_admin.example".translate} do
      @group.message.presence || "-"
    end

    tag :message_from_admin_as_quote, :description => Proc.new{"email_translations.pending_group_added_notification.tags.message_from_admin.description".translate}, :example => Proc.new{"feature.email.tags.message_from_user_v3_html".translate(message: "email_translations.pending_group_added_notification.tags.message_from_admin_as_quote.example".translate, name: 'feature.email.tags.mentor_name.example'.translate)} do
      word_wrap(@group.message.present? ? "feature.email.tags.message_from_user_v3_html".translate(message: @group.message, name: administrator_or_owner_name) : "").html_safe
    end

    tag :administrator_or_owner_name, :description => Proc.new{"email_translations.pending_group_added_notification.tags.administrator_or_owner_name.description".translate}, :example => Proc.new { |program| "email_translations.pending_group_added_notification.tags.administrator_or_owner_name.content".translate(program: program.organization.term_for(CustomizedTerm::TermType::PROGRAM_TERM).term_downcase, administrator: program.organization.admin_custom_term.term_downcase) } do
      (@actor.present? && @actor.is_owner_of?(@group)) ? @actor.name(name_only: true) : "email_translations.pending_group_added_notification.tags.administrator_or_owner_name.content".translate(program: customized_subprogram_term, administrator: customized_admin_term)
    end

    tag :mentoring_connection_button, :description => Proc.new{|program| "email_translations.pending_group_added_notification.tags.mentoring_connection_button.description_v1".translate(program.return_custom_term_hash)}, :example => Proc.new{|program| call_to_action_example("email_translations.pending_group_added_notification.visit_your_connection_text_html".translate(:mentoring_connection_term => program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase)) } do
      call_to_action("email_translations.pending_group_added_notification.visit_your_connection_text_html".translate(:mentoring_connection_term => @_mentoring_connection_string), profile_group_url(@group, :subdomain => @organization.subdomain, :src => 'mail'))
    end
  end

  self.register!

end

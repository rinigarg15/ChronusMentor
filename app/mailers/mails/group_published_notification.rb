class GroupPublishedNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'i7ym9e12', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::NEW_CIRCLES_CREATION,
    :title        => Proc.new{|program| "email_translations.group_published_notification.title_v2".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.group_published_notification.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.group_published_notification.subject_v1".translate},
    :campaign_id  => CampaignConstants::PROJECT_REQUESTS_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :program_settings => Proc.new{ |program| program.project_based? },
    :campaign_id_2  => CampaignConstants::GROUP_PUBLISHED_NOTIFICATION_MAIL_ID,
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 7
  }

  def group_published_notification(user, group, actor)
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
    tag :url_mentoring_connection, :description => Proc.new{|program| "email_translations.group_published_notification.tags.url_mentoring_connection.description_v1".translate(program.return_custom_term_hash)}, :example => Proc.new{'http://www.chronus.com'} do
      group_url(@group, :subdomain => @organization.subdomain, :src => 'mail')
    end

    tag :group_name, :description => Proc.new{"email_translations.group_published_notification.tags.group_name.description".translate}, :example => Proc.new{"email_translations.group_published_notification.tags.group_name.example".translate} do
      @group.name
    end

    tag :message_from_admin, :description => Proc.new{"email_translations.group_published_notification.tags.message_from_admin.description".translate}, :example => Proc.new{"email_translations.group_published_notification.tags.message_from_admin.example".translate} do
      @group.message.presence || "-"
    end

    tag :message_from_admin_as_quote, :description => Proc.new{"email_translations.group_published_notification.tags.message_from_admin_as_quote.description".translate}, :example => Proc.new{"feature.email.tags.message_from_user_v3_html".translate(message: "email_translations.group_published_notification.tags.message_from_admin_as_quote.example".translate, name: 'feature.email.tags.mentor_name.example'.translate)} do
      word_wrap(@group.message.present? ? "feature.email.tags.message_from_user_v3_html".translate(message: @group.message, name: administrator_or_owner_name) : "").html_safe
    end

    tag :administrator_or_owner_name, :description => Proc.new{"email_translations.group_published_notification.tags.administrator_or_owner_name.description".translate}, :example => Proc.new { |program| "email_translations.group_published_notification.tags.administrator_or_owner_name.content".translate(program: program.organization.term_for(CustomizedTerm::TermType::PROGRAM_TERM).term_downcase, administrator: program.organization.admin_custom_term.term_downcase) } do
      (@actor.present? && @actor.is_owner_of?(@group)) ? @actor.name(name_only: true) : "email_translations.group_published_notification.tags.administrator_or_owner_name.content".translate(program: customized_subprogram_term, administrator: customized_admin_term)
    end

    tag :project_name, :description => Proc.new{"email_translations.group_published_notification.tags.project_name.description".translate}, :example => Proc.new{"email_translations.group_published_notification.tags.project_name.example".translate} do
      @group.name
    end

    tag :mentoring_connection_button, :description => Proc.new{|program| "email_translations.group_published_notification.tags.mentoring_connection_button.description_v1".translate(program.return_custom_term_hash)}, :example => Proc.new{|program| call_to_action_example("email_translations.group_published_notification.visit_your_connection_text_html".translate(:mentoring_connection_term => program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase)) } do
      call_to_action("email_translations.group_published_notification.visit_your_connection_text_html".translate(:mentoring_connection_term => @_mentoring_connection_string), group_url(@group, :subdomain => @organization.subdomain, :src => 'mail'))
    end
  end

  self.register!

end

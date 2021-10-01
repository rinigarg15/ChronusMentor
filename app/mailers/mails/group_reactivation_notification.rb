class GroupReactivationNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'u978au0d', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::MENTORING_CONNECTIONS_NOTIFICATION,
    :title        => Proc.new{|program| "email_translations.group_reactivation_notification.title_v3".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.group_reactivation_notification.description_v3".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.group_reactivation_notification.subject_v1".translate},
    :campaign_id  => CampaignConstants::MENTORING_CONNECTION_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :program_settings => Proc.new{ |program| program.ongoing_mentoring_enabled?},
    :campaign_id_2  => CampaignConstants::GROUP_REACTIVATION_NOTIFICATION_MAIL_ID,
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 8
  }

  def group_reactivation_notification(user, group, actor)
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
    setup_email(@user, :from => :admin, :sender_name => @actor && @actor.visible_to?(@user) ? @actor.name(:name_only => true) : nil)
    super
    set_layout_options(:program => @program, :show_change_notif_link => true)
  end

  register_tags do
    tag :url_mentoring_connection, :description => Proc.new{|program| 'email_translations.group_reactivation_notification.tags.url_mentoring_connection.description_v1'.translate(program.return_custom_term_hash)}, :example => Proc.new{'http://www.chronus.com'} do
      group_url(@group, :subdomain => @organization.subdomain, :src => 'mail')
    end

    tag :group_name, :description => Proc.new{|program| 'email_translations.group_reactivation_notification.tags.group_name.description_v1'.translate(program.return_custom_term_hash)}, :example => Proc.new{'email_translations.group_reactivation_notification.tags.group_name.example'.translate} do
      @group.name
    end

    tag :reason_for_reactiviation, :description => Proc.new{'email_translations.group_reactivation_notification.tags.reason_for_reactiviation.description'.translate}, :example => Proc.new{'email_translations.group_reactivation_notification.tags.reason_for_reactiviation.example'.translate} do
      @group.message.presence || 'display_string.n_a'.translate
    end

    tag :mentoring_connection_expiry_date, :description => Proc.new{|program| 'email_translations.group_reactivation_notification.tags.mentoring_connection_expiry_date.description_v2'.translate(program.return_custom_term_hash)}, :example => Proc.new{'email_translations.group_reactivation_notification.tags.mentoring_connection_expiry_date.example'.translate} do
      formatted_time_in_words(@group.expiry_time, :no_ago => true, :no_time => true)
    end

    tag :administrator_or_owner_name, :description => Proc.new{ |program| "email_translations.group_reactivation_notification.tags.administrator_or_owner_name.description_v1".translate(program.return_custom_term_hash)}, :example => Proc.new { |program| "email_translations.group_reactivation_notification.tags.administrator_or_owner_name.content".translate(program: program.organization.term_for(CustomizedTerm::TermType::PROGRAM_TERM).term_downcase, administrator: program.organization.admin_custom_term.term_downcase) } do
      (@actor.present? && @actor.is_owner_of?(@group)) ? @actor.name(name_only: true) : "email_translations.group_reactivation_notification.tags.administrator_or_owner_name.content".translate(program: customized_subprogram_term, administrator: customized_admin_term)
    end

    tag :mentoring_connection_button, :description => Proc.new{|program| "email_translations.group_reactivation_notification.tags.mentoring_connection_button.description_v1".translate(program.return_custom_term_hash)}, :example => Proc.new{|program|  call_to_action_example("email_translations.group_reactivation_notification.visit_your_connection_text".translate(:mentoring_connection_term => program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase)) } do
      call_to_action("email_translations.group_reactivation_notification.visit_your_connection_text".translate(:mentoring_connection_term => @_mentoring_connection_string), group_url(@group, :subdomain => @organization.subdomain, :src => 'mail'))
    end

    tag :url_contact_admin, :description => Proc.new{'email_translations.group_reactivation_notification.tags.url_contact_admin.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      get_contact_admin_path(@program, url_params: { subdomain: @organization.subdomain, root: @program.root }, only_url: true)
    end
  end

  self.register!

end

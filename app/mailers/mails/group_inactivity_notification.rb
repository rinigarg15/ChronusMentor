class GroupInactivityNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'thk4rudl', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::MENTORING_CONNECTIONS_NOTIFICATION,
    :title        => Proc.new{|program| "email_translations.group_inactivity_notification.title_v1".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.group_inactivity_notification.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.group_inactivity_notification.subject_v1".translate},
    :campaign_id  => CampaignConstants::MENTORING_CONNECTION_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :program_settings => Proc.new{|program| (program.only_career_based_ongoing_mentoring_enabled? || program.project_based?) && !program.inactivity_tracking_period.nil?},
    :campaign_id_2  => CampaignConstants::GROUP_INACTIVITY_NOTIFICATION_MAIL_ID,
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 3
  }

  def group_inactivity_notification(user, group)
    @user = user
    @group = group
    init_mail
    render_mail
  end
  
  private

  def init_mail
    set_program(@group.program)
    set_username(@user)
    setup_email(@user, :from => :admin)
    super
    set_layout_options(:program => @program, :show_change_notif_link => false)
  end

  register_tags do
    tag :url_connection, :description => Proc.new{|program| 'email_translations.group_inactivity_notification.tags.url_connection.description_v1'.translate(program.return_custom_term_hash)}, :example => Proc.new{'http://www.chronus.com'} do
      group_url(@group, :subdomain => @organization.subdomain, :src => 'mail', :activation => 1)
    end

    tag :group_name, :description => Proc.new{|program| 'email_translations.group_inactivity_notification.tags.group_name.description_v1'.translate(program.return_custom_term_hash)}, :example => Proc.new{'email_translations.group_inactivity_notification.tags.group_name.example'.translate} do
      @group.name
    end

    tag :inactivity_tracking_period, :description => Proc.new{|program| 'email_translations.group_inactivity_notification.tags.inactivity_tracking_period.description_v1'.translate(program.return_custom_term_hash)}, :example => Proc.new{'21'} do
      @program.inactivity_tracking_period / 1.day
    end

    tag :last_activity_date, :description => Proc.new{|program| 'email_translations.group_inactivity_notification.tags.last_activity_date.description_v1'.translate(program.return_custom_term_hash)}, :example => Proc.new{'email_translations.group_inactivity_notification.tags.last_activity_date.example'.translate} do
      inactivity = @group.inactivity_in_days(@group.membership_of(@user))
      formatted_time_in_words(Time.now.utc - inactivity.days, :no_ago => true, :no_time => true)
    end

    tag :mentoring_area_button, :description => Proc.new{|program| 'email_translations.group_inactivity_notification.tags.mentoring_area_button.description_v1'.translate(program.return_custom_term_hash)}, :example => Proc.new{|program| call_to_action_example("email_translations.group_inactivity_notification.visit_your_connection".translate(mentoring_connection: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase)) } do
      call_to_action("email_translations.group_inactivity_notification.visit_your_connection".translate(mentoring_connection: @_mentoring_connection_string), group_url(@group, :subdomain => @organization.subdomain, :root => @program.root, :src => :mail))
    end

    tag :url_contact_admin, :description => Proc.new{'email_translations.group_inactivity_notification.tags.url_contact_admin.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      get_contact_admin_path(@program, url_params: { subdomain: @organization.subdomain, root: @program.root }, only_url: true)
    end
  end

  self.register!

end

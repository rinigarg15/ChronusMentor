class AutoPublishCirclesFailureNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => '43j69rh6', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::NEW_CIRCLES_CREATION,
    :title        => Proc.new{|program| "email_translations.auto_publish_circles_failure_notification.title".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.auto_publish_circles_failure_notification.description".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.auto_publish_circles_failure_notification.subject".translate},
    :campaign_id  => CampaignConstants::MENTORING_CONNECTION_MAIL_ID,
    :user_states  => [User::Status::ACTIVE],
    :program_settings => Proc.new{ |program| program.project_based? && program.allow_circle_start_date?},
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 8
  }

  def auto_publish_circles_failure_notification(owner, group)
    @group = group
    @owner = owner
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@group.program)
    set_username(@owner)
    setup_email(@owner, :from => :admin)
    super
  end

  register_tags do
    tag :url_mentoring_connection, :description => Proc.new{|program| "email_translations.auto_publish_circles_failure_notification.tags.url_mentoring_connection.description".translate(program.return_custom_term_hash)}, :example => Proc.new{'http://www.chronus.com'} do
        profile_group_url(@group, :subdomain => @organization.subdomain, :src => 'mail')
    end
    
    tag :group_name, :description => Proc.new{|program| "email_translations.auto_publish_circles_failure_notification.tags.group_name.description".translate(program.return_custom_term_hash)}, :example => Proc.new{"email_translations.auto_publish_circles_failure_notification.tags.group_name.example".translate} do
      @group.name
    end

    tag :circle_start_date, :description => Proc.new{|program| "email_translations.auto_publish_circles_failure_notification.tags.circle_start_date.description".translate(program.return_custom_term_hash)}, :example => Proc.new{"email_translations.auto_publish_circles_failure_notification.tags.circle_start_date.example".translate} do
      DateTime.localize(@group.start_date.in_time_zone(@owner.member.get_valid_time_zone), format: :short)
    end

    tag :url_contact_admin, :description => Proc.new{|program| 'email_translations.auto_publish_circles_failure_notification.tags.url_contact_admin.description'.translate(program.return_custom_term_hash)}, :example => Proc.new{'http://www.chronus.com'} do
      get_contact_admin_path(@program, url_params: { subdomain: @organization.subdomain, root: @program.root, src: 'mail' }, only_url: true)
    end

    tag :update_circle_start_date_button, :description => Proc.new{|program| "email_translations.auto_publish_circles_failure_notification.tags.update_circle_start_date_button.description".translate(program.return_custom_term_hash)}, :example => Proc.new{|program| call_to_action_example('email_translations.auto_publish_circles_failure_notification.update_start_date_button_text'.translate(mentoring_connection: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase)) } do
      call_to_action('email_translations.auto_publish_circles_failure_notification.update_start_date_button_text'.translate(mentoring_connection: @_mentoring_connection_string), profile_group_url(@group, :subdomain => @organization.subdomain, :src => 'mail', show_set_start_date_popup: true))
    end

    tag :manage_circle_members_button, :description => Proc.new{|program| "email_translations.auto_publish_circles_failure_notification.tags.manage_circle_members_button.description".translate(program.return_custom_term_hash)}, :example => Proc.new{|program| 'email_translations.auto_publish_circles_failure_notification.manage_circle_members_help_text_html'.translate(mentoring_connection: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase) + call_to_action_example('email_translations.auto_publish_circles_failure_notification.manage_circle_members_button_text'.translate(mentoring_connection: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase)) } do
      if @owner.can_manage_members_of_group?(@group)
        'email_translations.auto_publish_circles_failure_notification.manage_circle_members_help_text_html'.translate(mentoring_connection: @_mentoring_connection_string) +
        call_to_action('email_translations.auto_publish_circles_failure_notification.manage_circle_members_button_text'.translate(mentoring_connection: @_mentoring_connection_string), profile_group_url(@group, :subdomain => @organization.subdomain, :src => 'mail', manage_circle_members: true))
      end
    end
  end

  self.register!

end

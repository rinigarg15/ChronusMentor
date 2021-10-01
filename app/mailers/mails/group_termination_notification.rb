class GroupTerminationNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => '2o7kqtws', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::MENTORING_CONNECTIONS_NOTIFICATION,
    :title        => Proc.new{|program| "email_translations.group_termination_notification.title_v2".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.group_termination_notification.description".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.group_termination_notification.subject".translate},
    :campaign_id  => CampaignConstants::MENTORING_CONNECTION_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :level        => EmailCustomization::Level::PROGRAM,
    :program_settings => Proc.new{ |program| program.ongoing_mentoring_enabled?},
    :campaign_id_2  => CampaignConstants::GROUP_TERMINATION_NOTIFICATION_MAIL_ID,
    :skip_rollout => true,
    :listing_order => 7
  }

  def group_termination_notification(user, terminator, group)
    @user = user
    @group = group
    @closed_by = @group.closed_by
    @terminator = terminator
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@group.program)
    set_username(@user)
    setup_email(@user, :from => :admin)
    super
    set_layout_options(:program => @program, :show_change_notif_link => true) if @group.closed_by_admin? || @group.closed_due_to_expiry?
  end

  register_tags do
    tag :group_name, :description => Proc.new{|program| 'email_translations.group_termination_notification.tags.group_name.description_v1'.translate(program.return_custom_term_hash)}, :example => Proc.new{'email_translations.group_termination_notification.tags.group_name.example'.translate} do
      @group.name
    end

    tag :reason_for_closure, :description => Proc.new{|program| 'email_translations.group_termination_notification.tags.reason_for_closure.description_v1'.translate(program.return_custom_term_hash)}, :example => Proc.new{|program| 'email_translations.group_termination_notification.tags.reason_for_closure.example_v1_html'.translate(program.return_custom_term_hash)} do
      if @group.closed_due_to_inactivity?
        'email_translations.group_termination_notification.tags.reason_for_closure.auto_terminated_inactivity_html'.translate
      elsif @group.closed_due_to_expiry?
        'email_translations.group_termination_notification.tags.reason_for_closure.mentoring_connection_ended_html'.translate(:Mentoring_Connection => customized_mentoring_connection_term_capitalized)
      elsif @group.closed_by_admin?
        @group.termination_reason.present? ? 'email_translations.group_termination_notification.tags.reason_for_closure.admin_terminating_connection_with_reason_html'.translate(:reason_for_closure => @group.termination_reason) : 'email_translations.group_termination_notification.tags.reason_for_closure.admin_terminating_connection_html'.translate(:Mentoring_Connection => customized_mentoring_connection_term_capitalized, :administrator => customized_admin_term, :program => customized_subprogram_term)
      elsif @group.closed_by_leaving?
        'email_translations.group_termination_notification.tags.reason_for_closure.member_leaving_terminates_connection_html'.translate(:name_of_person_terminating => @terminator.name, :Mentoring_Connection => customized_mentoring_connection_term)
      end
    end

    tag :url_contact_admin, :description => Proc.new{'email_translations.group_termination_notification.tags.url_contact_admin.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      get_contact_admin_path(@program, url_params: { subdomain: @organization.subdomain, root: @program.root }, only_url: true)
    end

    tag :reactivate_connection, description: Proc.new{ |program| 'email_translations.group_termination_notification.tags.reactivate_connection.description'.translate(program.return_custom_term_hash)}, example: Proc.new{ |program| 'email_translations.group_termination_notification.tags.reactivate_connection.example'.translate(program.return_custom_term_hash)} do
      if @group.can_be_reactivated_by_user?(@user)
        buttton_link = call_to_action('email_translations.group_termination_notification.tags.reactivate_connection.reactivate_button_text'.translate(Mentoring_Connection: customized_mentoring_connection_term_capitalized), fetch_reactivate_group_url(@group, subdomain: @organization.subdomain, src: GroupsController::ReactivationSrc::MAIL))
        'email_translations.group_termination_notification.tags.reactivate_connection.end_user_reactivation_with_button_html'.translate(reactivate_button: buttton_link)
      else
        'email_translations.group_termination_notification.tags.reactivate_connection.admin_reactivation_html'.translate(administrator: customized_admin_term, contact_admin_url: get_contact_admin_path(@program, url_params: { subdomain: @organization.subdomain, root: @program.root }, only_url: true))
      end
    end
  end

  self.register!

end
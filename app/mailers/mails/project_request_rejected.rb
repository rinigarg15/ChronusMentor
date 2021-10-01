class ProjectRequestRejected < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'q3w1qhzf', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::CIRCLE_REQUEST_RELATED,
    :title        => Proc.new{|program| "email_translations.project_request_rejected.title_v3".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.project_request_rejected.description_v3".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.project_request_rejected.subject_v1".translate},
    :campaign_id  => CampaignConstants::PROJECT_REQUESTS_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :program_settings => Proc.new{ |program| program.project_based? && program.allows_users_to_apply_to_join_in_project?},
    :campaign_id_2  => CampaignConstants::PROJECT_REQUEST_REJECTED_MAIL_ID,
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 6
  }

  def project_request_rejected(sender, project_request, options={})
    @sender = sender
    @project_request = project_request
    @project = project_request.group
    @from_user = :admin

    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@project_request.program)
    set_username(@sender)
    setup_email(@sender, from: @from_user)
    super
    set_layout_options(show_change_notif_link: true)
  end

  register_tags do
    tag :project_name, description: Proc.new{'email_translations.project_request_rejected.tags.project_name.description'.translate}, example: Proc.new{'email_translations.project_request_rejected.tags.project_name.example'.translate} do
      @project.name
    end

    tag :url_find_new_projects, description: Proc.new{'email_translations.project_request_rejected.tags.url_projects_listing.description'.translate}, example: Proc.new{'http://www.chronus.com'} do
      find_new_groups_url(subdomain: @organization.subdomain)
    end

    tag :message_from_admin, description: Proc.new{'email_translations.project_request_rejected.tags.message_from_admin.description'.translate}, example: Proc.new{'email_translations.project_request_rejected.tags.message_from_admin.example'.translate} do
      @project_request.response_text.presence || "-"
    end

    tag :message_from_admin_as_quote, description: Proc.new{'email_translations.project_request_rejected.tags.message_from_admin_as_quote.description'.translate}, example: Proc.new{"feature.email.tags.message_from_user_v3_html".translate(message: 'email_translations.project_request_rejected.tags.message_from_admin_as_quote.example'.translate, name: 'feature.email.tags.mentor_name.example'.translate)} do
      word_wrap(@project_request.response_text.present? ? "feature.email.tags.message_from_user_v3_html".translate(message: @project_request.response_text, name: @project_request.receiver.name(name_only: true)) : "").html_safe
    end

    tag :visit_other_connections_button, description: Proc.new{|program| 'email_translations.project_request_rejected.tags.visit_other_connections_button.description_v1'.translate(program.return_custom_term_hash)}, example: Proc.new{|program| call_to_action_example("email_translations.project_request_rejected.visit_other_connections_html".translate(:mentoring_connection_term => program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).pluralized_term_downcase)) } do
      call_to_action("email_translations.project_request_rejected.visit_other_connections_html".translate(:mentoring_connection_term => @_mentoring_connections_string), find_new_groups_url(subdomain: @organization.subdomain))
    end
  end

  self.register!

end

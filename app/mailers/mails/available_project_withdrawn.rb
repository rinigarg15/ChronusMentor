class AvailableProjectWithdrawn < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 's0gx2fwz', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::CIRCLE_REQUEST_RELATED,
    :title        => Proc.new{|program| "email_translations.available_project_withdrawn.title".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.available_project_withdrawn.description".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.available_project_withdrawn.subject".translate},
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :program_settings => Proc.new{ |program| program.project_based? },
    :campaign_id  => CampaignConstants::AVAILABLE_PROJECT_WITHDRAWN_MAIL_ID,
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 5
  }

  def available_project_withdrawn(user, project)
    @user = user
    @project = project
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@project.program)
    set_username(@user)
    setup_email(@user, from: :admin)
    super
    set_layout_options(show_change_notif_link: true)
  end

  register_tags do
    tag :project_name, description: Proc.new{'email_translations.available_project_withdrawn.tags.project_name.description'.translate}, example: Proc.new{'email_translations.available_project_withdrawn.tags.project_name.example'.translate} do
      @project.name
    end

    tag :url_project, description: Proc.new{'email_translations.available_project_withdrawn.tags.url_project.description'.translate}, example: Proc.new{'http://www.chronus.com'} do
      profile_group_url(@project, subdomain: @organization.subdomain)
    end

    tag :message_from_admin, description: Proc.new{'email_translations.available_project_withdrawn.tags.message_from_admin.description'.translate}, example: Proc.new{'feature.email.tags.message_from_user_v3_html'.translate(:message => 'email_translations.available_project_withdrawn.tags.message_from_admin.example'.translate, :name => 'feature.email.tags.mentor_name.example'.translate)} do
      @project.termination_reason.presence ? 'feature.email.tags.message_from_user_v3_html'.translate(:message =>  @project.termination_reason, :name => @project.closed_by.name).html_safe : "".html_safe
    end

    tag :visit_other_connections_button, description: Proc.new{|program| 'email_translations.available_project_withdrawn.tags.visit_other_connections_button.description'.translate(program.return_custom_term_hash)}, example: Proc.new{|program| call_to_action_example("email_translations.available_project_withdrawn.visit_other_connections_html".translate(:mentoring_connection_term => program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).pluralized_term_downcase)) } do
      call_to_action("email_translations.available_project_withdrawn.visit_other_connections_html".translate(:mentoring_connection_term => @_mentoring_connections_string), find_new_groups_url(subdomain: @organization.subdomain))
    end

  end

  self.register!
end

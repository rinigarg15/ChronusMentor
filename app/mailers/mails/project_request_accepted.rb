class ProjectRequestAccepted < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => '1t4d1mrk', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::CIRCLE_REQUEST_RELATED,
    :title        => Proc.new{|program| "email_translations.project_request_accepted.title_v3".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.project_request_accepted.description_v3".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.project_request_accepted.subject_v1".translate},
    :campaign_id  => CampaignConstants::PROJECT_REQUESTS_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :program_settings => Proc.new{ |program| program.project_based? && program.allows_users_to_apply_to_join_in_project?},
    :campaign_id_2  => CampaignConstants::PROJECT_REQUEST_ACCEPTED_MAIL_ID,
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 4
  }

  def project_request_accepted(sender, project_request, options={})
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
    tag :project_name, description: Proc.new{'email_translations.project_request_accepted.tags.project_name.description'.translate}, example: Proc.new{'email_translations.project_request_rejected.tags.project_name.example'.translate} do
      @project.name
    end

    tag :url_project, description: Proc.new{'email_translations.project_request_accepted.tags.url_project.description'.translate}, example: Proc.new{'http://www.chronus.com'} do
      profile_group_url(@project, subdomain: @organization.subdomain)
    end

    tag :visit_program_button, description: Proc.new{'email_translations.project_request_accepted.tags.visit_program_button.description'.translate}, example: Proc.new{ call_to_action_example('email_translations.project_request_accepted.visit_program_html'.translate(:program_name => "feature.custom_terms.program".translate)) } do
      call_to_action('email_translations.project_request_accepted.visit_program_html'.translate(:program_name => @program.name), login_url(:subdomain => @organization.subdomain, :root => @program.root, :src => :mail))
    end
  end

  self.register!

end

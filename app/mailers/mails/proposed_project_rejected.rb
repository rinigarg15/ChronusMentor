class ProposedProjectRejected < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'wn13ohrp', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::NEW_CIRCLES_CREATION,
    :title        => Proc.new{|program| "email_translations.proposed_project_rejected.title_v3".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.proposed_project_rejected.description_v3".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.proposed_project_rejected.subject_v1".translate},
    :campaign_id  => CampaignConstants::PROJECT_REQUESTS_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :program_settings => Proc.new{ |program| program.project_based? && (program.should_display_proposed_projects_emails? || program.groups.proposed.any?) },
    :campaign_id_2  => CampaignConstants::PROPOSED_PROJECT_REJECTED_MAIL_ID,
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 3
  }

  def proposed_project_rejected(proposer, project)
    @proposer = proposer
    @project = project
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@project.program)
    set_username(@proposer)
    setup_email(@proposer, from: :admin)
    super
    set_layout_options(show_change_notif_link: true)
  end

  register_tags do
    tag :project_name, description: Proc.new{'email_translations.proposed_project_rejected.tags.project_name.description'.translate}, example: Proc.new{'email_translations.project_request_rejected.tags.project_name.example'.translate} do
      @project.name
    end

    tag :url_project, description: Proc.new{'email_translations.proposed_project_rejected.tags.url_project.description'.translate}, example: Proc.new{'http://www.chronus.com'} do
      profile_group_url(@project, subdomain: @organization.subdomain)
    end

    tag :message_from_admin, description: Proc.new{'email_translations.proposed_project_rejected.tags.message_from_admin.description'.translate}, example: Proc.new{'feature.email.tags.message_from_user_v3_html'.translate(:message => 'email_translations.proposed_project_rejected.tags.message_from_admin.example'.translate, :name => 'feature.email.tags.mentor_name.example'.translate)} do
      @project.termination_reason.presence ? 'feature.email.tags.message_from_user_v3_html'.translate(:message =>  @project.termination_reason, :name => @project.created_by.name).html_safe : "".html_safe
    end

  end

  self.register!
end

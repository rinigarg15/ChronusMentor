class ProposedProjectAccepted < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => '6of3r4v9', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::NEW_CIRCLES_CREATION,
    :title        => Proc.new{|program| "email_translations.proposed_project_accepted.title_v3".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.proposed_project_accepted.description_v3".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.proposed_project_accepted.subject_v1".translate},
    :campaign_id  => CampaignConstants::PROJECT_REQUESTS_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :program_settings => Proc.new{ |program| program.project_based? && (program.should_display_proposed_projects_emails? || program.groups.proposed.any?) },
    :campaign_id_2  => CampaignConstants::PROPOSED_PROJECT_ACCEPTED_MAIL_ID,
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 2
  }

  def proposed_project_accepted(proposer, project, made_proposer_owner)
    @proposer = proposer
    @project = project
    @made_proposer_owner = made_proposer_owner

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
    tag :project_name, description: Proc.new{'email_translations.proposed_project_accepted.tags.project_name.description'.translate}, example: Proc.new{'email_translations.proposed_project_accepted.tags.project_name.example'.translate} do
      @project.name
    end

    tag :url_project, description: Proc.new{'email_translations.proposed_project_accepted.tags.url_project.description'.translate}, example: Proc.new{'http://www.chronus.com'} do
      profile_group_url(@project, subdomain: @organization.subdomain)
    end

    tag :message_from_admin, description: Proc.new{'email_translations.proposed_project_accepted.tags.message_from_admin.description'.translate}, example: Proc.new{'email_translations.proposed_project_accepted.tags.message_from_admin.example'.translate} do
      @project.message.presence || "-"
    end

    tag :message_from_admin_as_quote, description: Proc.new{'email_translations.proposed_project_accepted.tags.message_from_admin_as_quote.description'.translate}, example: Proc.new{'feature.email.tags.message_from_user_v3_html'.translate(:message => 'email_translations.proposed_project_accepted.tags.message_from_admin_as_quote.example'.translate, :name => 'feature.email.tags.mentor_name.example'.translate)} do
      @project.message.presence ? 'feature.email.tags.message_from_user_v3_html'.translate(:message =>  @project.message, :name => @project.created_by.name) : ""
    end

    tag :text_for_owner, description: Proc.new{'email_translations.proposed_project_accepted.tags.text_for_owner.description'.translate}, example: Proc.new{'email_translations.proposed_project_accepted.tags.text_for_owner.example'.translate} do
      @made_proposer_owner ? "email_translations.proposed_project_accepted.tags.text_for_owner.content_v1".translate(:project => project_name) : ""
    end

    tag :mentoring_connection_button, description: Proc.new{|program| 'email_translations.proposed_project_accepted.tags.mentoring_connection_button.description_v1'.translate(program.return_custom_term_hash)}, example: Proc.new{|program| call_to_action_example('email_translations.proposed_project_accepted.button_text'.translate(mentoring_connection: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase)) } do
      call_to_action('email_translations.proposed_project_accepted.button_text'.translate(mentoring_connection: @_mentoring_connection_string), profile_group_url(@project, subdomain: @organization.subdomain))
    end  

  end

  self.register!

end

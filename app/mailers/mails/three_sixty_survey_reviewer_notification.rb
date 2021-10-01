class ThreeSixtySurveyReviewerNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'cn9i6kcd', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::THREE_SIXTY_RELATED,
    :title        => Proc.new{|program| "email_translations.three_sixty_survey_reviewer_notification.title_v1".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.three_sixty_survey_reviewer_notification.description_v1".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.three_sixty_survey_reviewer_notification.subject_v1".translate},
    :campaign_id  => CampaignConstants::THREE_SIXTY_MAIL_ID,
    :campaign_id_2  => CampaignConstants::THREE_SIXTY_SURVEY_REVIEWER_NOTIFICATION_MAIL_ID,
    :feature      => FeatureName::THREE_SIXTY,
    :level        => EmailCustomization::Level::ORGANIZATION,
    :listing_order => 2
  }

  def three_sixty_survey_reviewer_notification(survey, reviewer, options={})
    @reviewer = reviewer
    @survey_assessee = @reviewer.survey_assessee
    @survey = survey

    init_mail
    render_mail
  end

  private

  def init_mail
    setup_recipient_and_organization(nil, @survey.organization)
    set_program(@survey.program) if @survey.program
    set_username(nil, :name => @reviewer.name)
    setup_email(nil, {:email => @reviewer.email, :sender_name => assessee_name})
    super    
  end

  register_tags do
    tag :survey_title, :description => Proc.new{'email_translations.three_sixty_survey_reviewer_notification.tags.survey_title.description'.translate}, :example => Proc.new{'email_translations.three_sixty_survey_reviewer_notification.tags.survey_title.example'.translate} do
      @survey.title
    end

    tag :survey_expiry_text, :description => Proc.new{'email_translations.three_sixty_survey_reviewer_notification.tags.survey_expiry_text.description_v1'.translate}, :example => Proc.new{'email_translations.three_sixty_survey_reviewer_notification.tags.survey_expiry_text.example'.translate} do
      @survey.expiry_date.present? ? 'email_translations.three_sixty_survey_reviewer_notification.tags.survey_expiry_text.tag_content_html'.translate(date: DateTime.localize(@survey.expiry_date, format: :short)) : ""
    end

    tag :url_survey, :description => Proc.new{'email_translations.three_sixty_survey_reviewer_notification.tags.url_survey.description'.translate}, :example => Proc.new{'https://www.chronus.com'} do
      options = @survey.program.present? ? {:root => @survey.program.root} : {:organization_level => true}
      show_reviewers_three_sixty_survey_assessee_reviewers_url(@survey, @survey_assessee, options.merge({:subdomain => @organization.subdomain, :code => @reviewer.invitation_code, :src => 'email', :organization_level => true}))
    end

    tag :assessee_name, :description => Proc.new{'email_translations.three_sixty_survey_reviewer_notification.tags.assessee_name.description'.translate}, :example => Proc.new{'Ashley Williams'} do
      @survey_assessee.name
    end

    tag :complete_survey_button, :description => Proc.new{'email_translations.three_sixty_survey_reviewer_notification.tags.complete_survey_button.description'.translate}, :example => Proc.new{ call_to_action_example('email_translations.three_sixty_survey_reviewer_notification.complete_your_survey_html'.translate) } do
      options = @survey.program.present? ? {:root => @survey.program.root} : {:organization_level => true}
      call_to_action('email_translations.three_sixty_survey_reviewer_notification.complete_your_survey_html'.translate, show_reviewers_three_sixty_survey_assessee_reviewers_url(@survey, @survey_assessee, options.merge({:subdomain => @organization.subdomain, :code => @reviewer.invitation_code, :src => 'email', :organization_level => true})))
    end
  end

  self.register!
end
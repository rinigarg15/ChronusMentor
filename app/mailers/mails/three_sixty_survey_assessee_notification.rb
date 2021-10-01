class ThreeSixtySurveyAssesseeNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => '2wfvobvw', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::THREE_SIXTY_RELATED,
    :title        => Proc.new{|program| "email_translations.three_sixty_survey_assessee_notification.title_v1".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.three_sixty_survey_assessee_notification.description_v1".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.three_sixty_survey_assessee_notification.subject".translate},
    :campaign_id  => CampaignConstants::THREE_SIXTY_MAIL_ID,
    :campaign_id_2  => CampaignConstants::THREE_SIXTY_SURVEY_ASSESSEE_NOTIFICATION_MAIL_ID,
    :feature      => FeatureName::THREE_SIXTY,
    :user_states  => [User::Status::ACTIVE],
    :level        => EmailCustomization::Level::ORGANIZATION,
    :listing_order => 1
  }
  def three_sixty_survey_assessee_notification(member, survey, options = {})
    @member = member
    @survey = survey
    @survey_assessee = @survey.survey_assessees.find_by(member_id: @member.id)

    init_mail
    render_mail
  end

  def self.mailer_locale(member, survey, options = {})
    Language.for_member(member, survey.program)
  end

  private

  def init_mail
    setup_recipient_and_organization(@member, @member.organization)
    set_program(@survey.program) if @survey.program
    set_username(@member, :name_only => true)
    setup_email(@member)
    super
  end

  register_tags do
    tag :survey_title, :description => Proc.new{'email_translations.three_sixty_survey_assessee_notification.tags.survey_title.description'.translate}, :example => Proc.new{'email_translations.three_sixty_survey_assessee_notification.tags.survey_title.example'.translate} do
      @survey.title
    end

    tag :survey_expiry_text, :description => Proc.new{'email_translations.three_sixty_survey_assessee_notification.tags.survey_expiry_text.description_v1'.translate}, :example => Proc.new{'email_translations.three_sixty_survey_assessee_notification.tags.survey_expiry_text.example'.translate} do
      @survey.expiry_date.present? ? 'email_translations.three_sixty_survey_assessee_notification.tags.survey_expiry_text.tag_content_html'.translate(date: DateTime.localize(@survey.expiry_date, format: :short)) : ""
    end

    tag :url_survey, :description => Proc.new{'email_translations.three_sixty_survey_assessee_notification.tags.url_survey.description'.translate}, :example => Proc.new{'https://www.chronus.com'} do
      options = @survey.program.present? ? {:root => @survey.program.root} : {:organization_level => true}
      show_reviewers_three_sixty_survey_assessee_reviewers_url(@survey, @survey_assessee, options.merge({:subdomain => @organization.subdomain, :code => @survey_assessee.self_reviewer.invitation_code, :src => 'email'}))
    end

    tag :add_reviewers_text, :description => Proc.new{'email_translations.three_sixty_survey_assessee_notification.tags.add_reviewers_text.description'.translate}, :example => Proc.new{'email_translations.three_sixty_survey_assessee_notification.tags.add_reviewers_text.example'.translate} do
      @survey.only_assessee_can_add_reviewers? ? 'email_translations.three_sixty_survey_assessee_notification.tags.add_reviewers_text.tag_content_html'.translate : ""
    end

    tag :complete_survey_button, :description => Proc.new{'email_translations.three_sixty_survey_assessee_notification.tags.complete_survey_button.description'.translate}, :example => Proc.new{ call_to_action_example('email_translations.three_sixty_survey_assessee_notification.complete_your_survey_html'.translate) } do
      options = @survey.program.present? ? {:root => @survey.program.root} : {:organization_level => true}
      call_to_action('email_translations.three_sixty_survey_assessee_notification.complete_your_survey_html'.translate, show_reviewers_three_sixty_survey_assessee_reviewers_url(@survey, @survey_assessee, options.merge({:subdomain => @organization.subdomain, :code => @survey_assessee.self_reviewer.invitation_code, :src => 'email'})))
    end
  end

  self.register!
end
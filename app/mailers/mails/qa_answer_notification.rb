class QaAnswerNotification < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'mzeidstr', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::COMMUNITY,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::QA_RELATED,
    :title        => Proc.new{|program| "email_translations.qa_answer_notification.title_v2".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.qa_answer_notification.description_v1".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.qa_answer_notification.subject_v1".translate},
    :campaign_id  => CampaignConstants::COMMUNITY_MAIL_ID,
    :campaign_id_2  => CampaignConstants::QA_ANSWER_NOTIFICATION_MAIL_ID,
    :feature      => FeatureName::ANSWERS,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 1
  }

  def qa_answer_notification(user, qa_answer, options = {})
    @user = user
    @qa_answer = qa_answer
    @qa_question = qa_answer.qa_question
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@user.program)
    set_username(@user, :name_only => true)
    setup_email(@user, :sender_name => @qa_answer.user.visible_to?(@user) ? answerer_name : nil)
    super
    set_layout_options(:show_change_notif_link => true)
  end

  register_tags do
    tag :url_question, :description => Proc.new{'email_translations.qa_answer_notification.tags.url_question.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      qa_question_url(@qa_question, :subdomain => @organization.subdomain)
    end

    tag :answerer_name, :description => Proc.new{'email_translations.qa_answer_notification.tags.answerer_name.description'.translate}, :example => Proc.new{'William Smith'} do
      @qa_answer.user.name
    end

    tag :question_description, :description => Proc.new{'email_translations.qa_answer_notification.tags.question_description.description'.translate}, :example => Proc.new{'"' + "#{'email_translations.qa_answer_notification.tags.question_description.example'.translate}" + '"'} do
      @qa_question.description.blank? ? "" : "#{h(@qa_question.description)}<br/>".html_safe
    end

    tag :question_summary, :description => Proc.new{'email_translations.qa_answer_notification.tags.question_summary.description'.translate}, :example => Proc.new{'email_translations.qa_answer_notification.tags.question_summary.example_v1'.translate} do
      @qa_question.summary
    end

    tag :answer, :description => Proc.new{'email_translations.qa_answer_notification.tags.answer.description'.translate}, :example => Proc.new{'email_translations.qa_answer_notification.tags.answer.example_v1'.translate} do
      @qa_answer.content
    end

    tag :view_all_responses_button, :description => Proc.new{'email_translations.qa_answer_notification.tags.view_all_responses_button.description'.translate}, :example => Proc.new{ call_to_action_example('email_translations.qa_answer_notification.view_response_button_text'.translate) } do
      call_to_action('email_translations.qa_answer_notification.view_response_button_text'.translate, qa_question_url(@qa_question, :subdomain => @organization.subdomain))
    end

    tag :mark_it_helpful_button, :description => Proc.new{'email_translations.qa_answer_notification.tags.mark_it_helpful_button.description'.translate}, :example => Proc.new{ call_to_action_example('email_translations.qa_answer_notification.mark_it_helpful_button_text'.translate) } do
      call_to_action('email_translations.qa_answer_notification.mark_it_helpful_button_text'.translate, qa_question_url(@qa_question, :subdomain => @organization.subdomain, :mark_helpful_answer_id => @qa_answer.id))
    end

    tag :link_to_answerer, :description => Proc.new{'email_translations.qa_answer_notification.tags.link_to_answerer.description'.translate}, :example => Proc.new{'email_translations.qa_answer_notification.tags.link_to_answerer.example_html'.translate} do
      link_to(@qa_answer.user.name, user_url(@qa_answer.user, :subdomain => @organization.subdomain, :root => @program.root))
    end
  end

  self.register!

end

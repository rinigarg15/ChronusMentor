class CoachRatingNotificationToStudent < ChronusActionMailer::Base
  @mailer_attributes = {
    :uid          => 'ezqhilty', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::MENTORING_CONNECTIONS_NOTIFICATION,
    :title        => Proc.new{|program| "email_translations.coach_rating_notification_to_student.title_v1".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.coach_rating_notification_to_student.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.coach_rating_notification_to_student.subject".translate},
    :feature      => FeatureName::COACH_RATING,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :program_settings => Proc.new{|program| program.only_career_based_ongoing_mentoring_enabled? || program.project_based?},
    :campaign_id  => CampaignConstants::COACH_RATING_NOTIFICATION_TO_STUDENT_MAIL_ID,
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 5
  }  


  def coach_rating_notification_to_student(student, mentor, group)
    @student = student
    @mentor = mentor
    @group = group
    @program = @student.program
    init_mail
    render_mail
  end

  def init_mail
    set_program(@program)
    set_username(@student, :name_only => true)
    setup_email(@student)
    super
  end

  register_tags do
   	tag :mentor_name, :description => Proc.new{"email_translations.coach_rating_notification_to_student.tags.mentor_name.description".translate}, :example => Proc.new{"email_translations.coach_rating_notification_to_student.tags.mentor_name.example".translate} do
      @mentor.name
    end

    tag :url_mentor, :description => Proc.new{"email_translations.coach_rating_notification_to_student.tags.url_mentor.description".translate}, :example => Proc.new{"email_translations.coach_rating_notification_to_student.tags.url_mentor.example".translate} do
      member_url(@mentor.member, :subdomain => @organization.subdomain, :root => @program.root)
    end

    tag :url_feedback_form, :description => Proc.new{"email_translations.coach_rating_notification_to_student.tags.url_feedback_form.description".translate}, :example => Proc.new{"email_translations.coach_rating_notification_to_student.tags.url_feedback_form.example".translate} do
      group_url(@group, :subdomain => @organization.subdomain, :root => @program.root, :coach_rating => @mentor.id)
    end

    tag :rate_your_mentor_button, :description => Proc.new{"email_translations.coach_rating_notification_to_student.tags.rate_your_mentor_button.description".translate}, :example => Proc.new{ call_to_action_example('email_translations.coach_rating_notification_to_student.button_text'.translate(mentor: "feature.custom_terms.downcase.mentor".translate)) } do
      call_to_action('email_translations.coach_rating_notification_to_student.button_text'.translate(mentor: @_mentor_string), group_url(@group, :subdomain => @organization.subdomain, :root => @program.root, :coach_rating => @mentor.id))
    end
  end

  self.register!

end
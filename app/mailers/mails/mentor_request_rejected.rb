class MentorRequestRejected < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'au2ahh7v', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::MENTOR_REQUEST_RELATED,
    :title        => Proc.new{|program| "email_translations.mentor_request_rejected.title_v4".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.mentor_request_rejected.description_v3".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.mentor_request_rejected.subject_v5".translate},
    :campaign_id  => CampaignConstants::MENTORING_REQUESTS_OFFERS_MAIL_ID,
    :program_settings => Proc.new{|program| program.only_career_based_ongoing_mentoring_enabled? && (program.matching_by_mentee_and_admin? || program.matching_by_mentee_alone?)},
    :campaign_id_2  => CampaignConstants::MENTOR_REQUEST_REJECTED_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :level        => EmailCustomization::Level::PROGRAM,
    :other_registered_tags => [:recommended_mentors_tag, :admin_and_mentor_url_tags],
    :listing_order => 6
  }

  def mentor_request_rejected(student, mentor_request, options)
    @student = student
    @mentor_request = mentor_request
    @program = mentor_request.program

    if @program.matching_by_mentee_and_admin?
      @rejector = options[:rejector]
      @from_user = :admin      
    elsif @program.matching_by_mentee_alone?
      @rejector = mentor_request.mentor
      @from_user = mentor_request.mentor.name
    end
    @mentor = @rejector
    @mentee = student
    @request = mentor_request
    @options = options
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@program)
    set_sender(@options)
    set_username(@student)
    setup_email(@student, :from => @from_user, :sender_name => @rejector.visible_to?(@student) ? mentor_name : nil, message_type: EmailCustomization::MessageType::COMMUNICATION)
    super
    set_layout_options(:show_change_notif_link => true)
  end

  register_tags do
    tag :mentor_name, :description => Proc.new{'email_translations.mentor_request_rejected.tags.mentor_name.description'.translate}, :example => Proc.new{'email_translations.mentor_request_rejected.tags.mentor_name.example'.translate} do
      @rejector.name
    end

    tag :url_mentors_listing, :description => Proc.new{'email_translations.mentor_request_rejected.tags.url_mentors_listing.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      users_url(:subdomain => @organization.subdomain, src: EngagementIndex::Src::BrowseMentors::EMAIL)
    end

    tag :message_from_mentor, :description => Proc.new{'email_translations.mentor_request_rejected.tags.message_from_mentor.description'.translate}, :example => Proc.new{'feature.email.tags.message_from_user_v3_html'.translate(:message => 'email_translations.mentor_request_rejected.tags.message_from_mentor.example'.translate, :name => 'email_translations.mentor_request_rejected.tags.mentor_name.example'.translate)} do
      @mentor_request.response_text.present? ? 'feature.email.tags.message_from_user_v3_html'.translate(:message => @mentor_request.response_text, :name => mentor_name) : ""
    end

    tag :view_mentors_button, :description => Proc.new{'email_translations.mentor_request_rejected.tags.view_mentors_button.description'.translate}, :example => Proc.new{ |program| call_to_action_example("email_translations.mentor_request_rejected.tags.view_mentors_button.view_mentors".translate(Mentors: program.find_role(RoleConstants::MENTOR_NAME).customized_term.pluralized_term)) } do
      call_to_action("email_translations.mentor_request_rejected.tags.view_mentors_button.view_mentors".translate(Mentors: @_Mentors_string), users_url(:subdomain => @organization.subdomain, src: EngagementIndex::Src::BrowseMentors::EMAIL))
    end
  end

  self.register!

end

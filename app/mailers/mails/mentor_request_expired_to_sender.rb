class MentorRequestExpiredToSender < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'e7wlwot0', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::MENTOR_REQUEST_RELATED,
    :title        => Proc.new{|program| "email_translations.mentor_request_expired_to_sender.title_v2".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.mentor_request_expired_to_sender.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.mentor_request_expired_to_sender.subject_v3".translate},
    :campaign_id  => CampaignConstants::MENTORING_REQUESTS_OFFERS_MAIL_ID,
    :program_settings => Proc.new{|program| program.only_career_based_ongoing_mentoring_enabled? && program.matching_by_mentee_alone? && !program.mentor_request_expiration_days.nil?},
    :campaign_id_2  => CampaignConstants::MENTOR_REQUEST_EXPIRED_TO_SENDER_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :level        => EmailCustomization::Level::PROGRAM,
    :other_registered_tags => [:recommended_mentors_tag, :admin_and_mentor_url_tags],
    :listing_order => 10
  }

  def mentor_request_expired_to_sender(student, mentor_request)
    @student = student
    @mentee = student
    @request = mentor_request
    @mentor_request = mentor_request
    @program = mentor_request.program
    @mentor = mentor_request.mentor
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@program)
    set_username(@student, :name_only => true)
    setup_email(@student, :from => :admin)
    super
    set_layout_options(:show_change_notif_link => true)
  end

  register_tags do
    tag :recipient_name, :description => Proc.new{'email_translations.mentor_request_expired_to_sender.tags.recipient_name.description'.translate}, :example => Proc.new{'email_translations.mentor_request_expired_to_sender.tags.recipient_name.example'.translate} do
      @mentor.name
    end

    tag :url_mentors_listing, :description => Proc.new{'email_translations.mentor_request_expired_to_sender.tags.url_mentors_listing.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      users_url(:subdomain => @organization.subdomain, src: EngagementIndex::Src::BrowseMentors::EMAIL)
    end

    tag :message_from_server, :description => Proc.new{'email_translations.mentor_request_expired_to_sender.tags.message.description'.translate},
        :example => Proc.new{'feature.mentor_request.tasks.expired_message_v1'.translate(mentor: 'mentor', expiration_days: 10)} do
      @mentor_request.response_text
    end

    tag :view_mentors_button, :description => Proc.new{'email_translations.mentor_request_expired_to_sender.tags.view_mentors_button.description'.translate}, :example => Proc.new{ |program| call_to_action_example("email_translations.mentor_request_expired_to_sender.tags.view_mentors_button.view_mentors".translate(Mentors: program.find_role(RoleConstants::MENTOR_NAME).customized_term.pluralized_term)) } do
      call_to_action("email_translations.mentor_request_expired_to_sender.tags.view_mentors_button.view_mentors".translate(Mentors: @_Mentors_string), users_url(:subdomain => @organization.subdomain, src: EngagementIndex::Src::BrowseMentors::EMAIL))
    end

    tag :max_pending_duration, :description => Proc.new{'email_translations.mentor_request_expired_to_sender.tags.max_pending_duration.description'.translate}, :example => Proc.new{'email_translations.mentor_request_expired_to_sender.tags.max_pending_duration.example'.translate} do
      'email_translations.mentor_request_expired_to_sender.pending_duration'.translate(:count => @program.mentor_request_expiration_days)
    end
  end

  self.register!

end

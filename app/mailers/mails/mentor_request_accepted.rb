class MentorRequestAccepted < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => 'j88s0r82', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::MENTOR_REQUEST_RELATED,
    :title        => Proc.new{|program| "email_translations.mentor_request_accepted.title_v2".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.mentor_request_accepted.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.mentor_request_accepted.subject_v2".translate},
    :campaign_id  => CampaignConstants::MENTORING_REQUESTS_OFFERS_MAIL_ID,
    :program_settings => Proc.new{|program| program.only_career_based_ongoing_mentoring_enabled? && program.matching_by_mentee_alone?},
    :campaign_id_2  => CampaignConstants::MENTOR_REQUEST_ACCEPTED_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :level        => EmailCustomization::Level::PROGRAM,
    :listing_order => 3
  }

  def mentor_request_accepted(student, mentor_request, options)
    @student = student
    @mentor_request = mentor_request
    @group = mentor_request.group
    @options = options
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@mentor_request.program)
    set_sender(@options)
    set_username(@student)
    setup_email(@student, :from => @mentor_request.mentor.name, :sender_name => @mentor_request.mentor.visible_to?(@student) ? mentor_name : nil, message_type: EmailCustomization::MessageType::COMMUNICATION)
    super
    set_layout_options(:show_change_notif_link => true)
  end

  register_tags do
    tag :mentor_name, :description => Proc.new{'email_translations.mentor_request_accepted.tags.mentor_name.description'.translate}, :example => Proc.new{'email_translations.mentor_request_accepted.tags.mentor_name.example'.translate} do
      @mentor_request.mentor.name(:name_only => true)      
    end

    tag :mentor_url, :description => Proc.new{'email_translations.mentor_request_accepted.tags.mentor_url.description'.translate}, :example => Proc.new{'http://chronus.com'} do
      user_url(@mentor_request.mentor, subdomain: @organization.subdomain, :root => @program.root)
    end

    tag :url_mentoring_connection, :description => Proc.new{|program| 'email_translations.mentor_request_accepted.tags.url_mentoring_connection.description_v1'.translate(program.return_custom_term_hash)},  :example => Proc.new{'http://www.chronus.com'} do
      group_url(@group, :subdomain => @organization.subdomain, :first_visit => 1)
    end

    tag :expiry_date, :description => Proc.new{|program| 'email_translations.mentor_request_accepted.tags.expiry_date.description_v2'.translate(program.return_custom_term_hash)},  :example => Proc.new{'email_translations.mentor_request_accepted.tags.expiry_date.example'.translate} do
      formatted_time_in_words(@group.expiry_time, :no_ago => true, :no_time => true)
    end

    tag :group_name, :description => Proc.new{'email_translations.mentor_request_accepted.tags.group_name.description'.translate}, :example => Proc.new{'email_translations.mentor_request_accepted.tags.group_name.example_v1'.translate} do
      @group.name
    end

    tag :mentoring_area_button, :description => Proc.new{'email_translations.mentor_request_accepted.tags.mentoring_area_button.description'.translate}, :example => Proc.new{|program| call_to_action_example("email_translations.mentor_request_accepted.tags.mentoring_area_button.visit_your_connection".translate(mentoring_connection: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase)) } do
      call_to_action("email_translations.mentor_request_accepted.tags.mentoring_area_button.visit_your_connection".translate(mentoring_connection: @_mentoring_connection_string), group_url(@group, :subdomain => @organization.subdomain, :root => @program.root, :src => 'mail'))
    end
  end

  self.register!

end

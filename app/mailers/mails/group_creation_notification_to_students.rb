class GroupCreationNotificationToStudents < ChronusActionMailer::Base

  @mailer_attributes = {
    :uid          => '6tkd5hoc', # rand(36**8).to_s(36)
    :category     => EmailCustomization::NewCategories::Type::MATCHING_AND_ENGAGEMENT,
    :subcategory  => EmailCustomization::NewCategories::SubCategories::ADMIN_INITIATED_MATCHING,
    :title        => Proc.new{|program| "email_translations.group_creation_notification_to_students.title_v2".translate(program.return_custom_term_hash)},
    :description  => Proc.new{|program| "email_translations.group_creation_notification_to_students.description_v2".translate(program.return_custom_term_hash)},
    :subject      => Proc.new{"email_translations.group_creation_notification_to_students.subject_v1".translate},
    :campaign_id  => CampaignConstants::MENTORING_CONNECTION_MAIL_ID,
    :user_states  => [User::Status::ACTIVE, User::Status::PENDING],
    :program_settings => Proc.new{|program| program.only_career_based_ongoing_mentoring_enabled?},
    :campaign_id_2  => CampaignConstants::GROUP_CREATION_NOTIFICATION_TO_STUDENTS_MAIL_ID,
    :level        => EmailCustomization::Level::PROGRAM,
    :for_role_names => [RoleConstants::STUDENT_NAME],
    :listing_order => 3
  }

  def group_creation_notification_to_students(student, group)
    @student = student
    @mentors = group.mentors
    @group = group
    @creator = @group.created_by
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@group.program)
    set_username(@student)
    setup_email(@student, :from => :admin, :sender_name => @creator && @creator.visible_to?(@student) ? @creator.name(:name_only => true) : nil)
    super
  end

  register_tags do
    tag :mentor_or_mentors_term, :description => Proc.new{'email_translations.group_creation_notification_to_students.tags.mentor_or_mentors_term.description'.translate}, :example => Proc.new{'email_translations.group_creation_notification_to_students.tags.mentor_or_mentors_term.example'.translate} do
      @mentors.size > 1 ? customized_mentors_term : customized_mentor_term
    end

    tag :has_or_have, :description => Proc.new{'email_translations.group_creation_notification_to_students.tags.has_or_have.description'.translate}, :example => Proc.new{'email_translations.group_creation_notification_to_students.tags.has_or_have.example'.translate} do
      'email_translations.group_creation_notification_to_students.tags.has_or_have.content'.translate(count: @mentors.size)
    end

    tag :url_mentoring_connection, :description => Proc.new{|program| 'email_translations.group_creation_notification_to_students.tags.url_mentoring_connection.description_v1'.translate(program.return_custom_term_hash)},  :example => Proc.new{'http://www.chronus.com'} do
      group_url(@group, :subdomain => @organization.subdomain, :first_visit => 1, :src => 'mail')
    end

    tag :mentoring_connection_expiry_date, :description => Proc.new{|program| 'email_translations.group_creation_notification_to_students.tags.mentoring_connection_expiry_date.description_v2'.translate(program.return_custom_term_hash)}, :example => Proc.new{'email_translations.group_creation_notification_to_students.tags.mentoring_connection_expiry_date.example'.translate} do
      formatted_time_in_words(@group.expiry_time, :no_ago => true, :no_time => true)
    end

    tag :message_from_admin, :description => Proc.new{"email_translations.group_creation_notification_to_students.tags.message_from_admin.description".translate}, :example => Proc.new{'feature.email.tags.message_from_administrator_v2_html'.translate(:message_from_admin => "email_translations.group_creation_notification_to_students.tags.message_from_admin.example".translate, :admin => "feature.custom_terms.downcase.admin".translate)} do
      @group.message.present? ? 'feature.email.tags.message_from_administrator_v2_html'.translate(:message_from_admin => @group.message, :admin => @_admin_string) : ""
    end

    tag :mentor_names, :description => Proc.new{'email_translations.group_creation_notification_to_students.tags.mentor_names.description'.translate}, :example => Proc.new{'William Smith'} do
      @mentors.collect(&:name).to_sentence
    end

    tag :url_signup, :description => Proc.new{'email_translations.group_creation_notification_to_students.tags.url_signup.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      reset_password = Password.create!(:member => @student.member)
      new_user_followup_users_url(:subdomain => @organization.subdomain, :reset_code => reset_password.reset_code)
    end

    tag :mentoring_area_button, :description => Proc.new{|program| 'email_translations.group_creation_notification_to_students.tags.mentoring_area_button.description_v1'.translate(program.return_custom_term_hash)}, :example => Proc.new{|program| call_to_action_example("email_translations.group_creation_notification_to_students.visit_your_connection".translate(mentoring_connection: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase)) } do
      call_to_action("email_translations.group_creation_notification_to_students.visit_your_connection".translate(mentoring_connection: @_mentoring_connection_string), group_url(@group, :subdomain => @organization.subdomain, :root => @program.root, :src => :mail))
    end

    tag :mentors_list_with_profile_link, :description => Proc.new{"email_translations.group_creation_notification_to_students.tags.mentors_list_with_profile_link.description".translate}, :example => Proc.new{"email_translations.group_creation_notification_to_students.tags.mentors_list_with_profile_link.example_html".translate} do
      @mentors.map{|mentor| user_link_in_email(mentor)}.join(', ').html_safe
    end

    tag :url_contact_admin, :description => Proc.new{'email_translations.group_creation_notification_to_students.tags.url_contact_admin.description'.translate}, :example => Proc.new{'http://www.chronus.com'} do
      get_contact_admin_path(@student.program, url_params: { subdomain: @organization.subdomain, root: @student.program.root }, only_url: true)
    end
  end

  self.register!

end

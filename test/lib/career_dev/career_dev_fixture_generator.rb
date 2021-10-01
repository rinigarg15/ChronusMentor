class CareerDevFixtureGenerator < ChronusFixtureGenerator
  def populate
    [
      Permission, Organization, Program::Domain, Program, CareerDev::Portal,
      Member, User, Section, ProfileQuestion, RoleQuestion, ProfileAnswer,
      ProgramEvent, Education, Article, QaQuestion, QaAnswer, OrganizationLanguage,
      ProgramLanguage, AdminMessage, Forum
    ].each do |klass|
      self.send("populate_#{klass.name.underscore.parameterize(separator: '_').pluralize}")
    end

    update_customized_terms
    apply_wcag_theme

    [Connection::Activity, ProgramActivity, RecentActivity].each(&:delete_all)
  end

  def populate_permissions
    say_populating(Permission.name)
    count = "#{Permission.all.count}"
    permissions = RoleConstants::DEFAULT_CAREER_DEV_ROLE_PERMISSIONS.values.flatten.uniq - RoleConstants::DEFAULT_PERMISSIONS
    permissions.each do |permission_name|
      permission = Permission.find_by(name: permission_name)
      create_record(Permission, "permissions_#{count.succ!}", name: permission_name) if permission.nil?
    end
  end

  def populate_organizations
    populate_objects(Organization, [
      [:org_nch, name: "Nation Wide Children Hospital Org", description: "Organization for career development"]
    ])
  end

  def populate_program_domains
    populate_objects(Program::Domain, [
      [:org_nch, organization: programs(:org_nch), subdomain: "nch", domain: DEFAULT_DOMAIN_NAME]
    ])
  end

  def populate_programs
    populate_objects(Program, [
      [:nch_mentoring, name: "NCH Mentoring Program", description: "Mentoring program for NCH", mentor_request_style: Program::MentorRequestStyle::MENTEE_TO_MENTOR, allow_one_to_many_mentoring: false, organization: programs(:org_nch), root: 'main', creation_way: Program::CreationWay::MANUAL]
    ])
  end

  def populate_career_dev_portals
    populate_objects(CareerDev::Portal, [
      [:primary_portal, name: "Primary Career Portal", organization: programs(:org_nch), root: 'portal']
    ])
  end

  def populate_members
    populate_objects(Member, [
      [:nch_admin, organization: programs(:org_nch), first_name: "Freakin", last_name: "Admin", email: "nch_admin@example.com", admin: true],
      [:nch_mentor, organization: programs(:org_nch), first_name: "Nch", last_name: "mentor", email: "nch_mentor@example.com", admin: false],
      [:nch_mentee, organization: programs(:org_nch), first_name: "Nch", last_name: "Mentee", email: "nch_mentee@example.com", admin: false],
      [:portal_admin2, organization: programs(:org_nch), first_name: "Nch", last_name: "Another Admin", email: "nch_admin2@example.com", admin: false],
      [:portal_employee, organization: programs(:org_nch), first_name: "Nch Portal", last_name: "Employee", email: "nch_employee@example.com", admin: false],
      [:subportal_admin, organization: programs(:org_nch), first_name: "Nch Sub Portal", last_name: "Admin", email: "nch_sub_portal_admin@example.com", admin: false]
    ])
  end

  def populate_users
    populate_objects(User, [
      [:portal_admin, program: programs(:primary_portal), member: members(:nch_admin), role_names: [:admin]],
      [:portal_admin2, program: programs(:primary_portal), member: members(:portal_admin2), role_names: [:admin]],
      [:subportal_admin, program: programs(:primary_portal), member: members(:subportal_admin), role_names: [:admin]],
      [:portal_employee, program: programs(:primary_portal), member: members(:portal_employee), role_names: [:employee]],
      [:nch_admin, program: programs(:nch_mentoring), member: members(:nch_admin), role_names: [:admin]],
      [:nch_mentor, program: programs(:nch_mentoring), member: members(:nch_mentor), role_names: [:mentor]],
      [:nch_mentee, program: programs(:nch_mentoring), member: members(:nch_mentee), role_names: [:student]]
    ])
  end

  def populate_sections
    populate_objects(Section, [
      [:section_more_info_nch, organization: programs(:org_nch), title: "More Information", position: 4, default_field: false]
    ])
  end

  def populate_profile_questions
    work_and_education_section = programs(:org_nch).sections.find_by(title: "Work and Education")

    populate_objects(ProfileQuestion, [
      [:nch_string_q, question_type: ProfileQuestion::Type::STRING, question_text: "How old are you?", organization: programs(:org_nch), section: sections(:section_more_info_nch)],
      [:nch_single_choice_q, question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "What is your interest?", organization: programs(:org_nch), section: sections(:section_more_info_nch)],
      [:nch_education_q, question_type: ProfileQuestion::Type::EDUCATION, question_text: "Current Education", organization: programs(:org_nch), section: work_and_education_section]
    ])

    attrs_array = []
    "Photography,Swimming,Dance".split(",").each_with_index do |choice, index|
      attrs_array << ["nch_single_choice_q#{index + 1}".to_sym, text: choice, ref_obj: profile_questions(:nch_single_choice_q), position: index + 1]
    end
    populate_objects(QuestionChoice, attrs_array)
  end

  def populate_role_questions
    nch_employee_role = programs(:primary_portal).get_role(RoleConstants::EMPLOYEE_NAME)
    nch_location_question = programs(:org_nch).profile_questions.find_by(question_type: ProfileQuestion::Type::LOCATION)

    populate_objects(RoleQuestion, [
      [:nch_string_role_q, profile_question: profile_questions(:nch_string_q), role: nch_employee_role, in_summary: true],
      [:nch_single_choice_role_q, profile_question: profile_questions(:nch_single_choice_q), role: nch_employee_role, in_summary: true],
      [:nch_education_role_q, profile_question: profile_questions(:nch_education_q), role: nch_employee_role],
      [:nch_location_role_q, profile_question: nch_location_question, role: nch_employee_role]
    ])
  end

  def populate_profile_answers
    nch_location_question = programs(:org_nch).profile_questions.find_by(question_type: ProfileQuestion::Type::LOCATION)

    populate_objects(ProfileAnswer, [
      [:nch_age_employee_answer, profile_question: profile_questions(:nch_string_q), answer_text: "I forgot", ref_obj: members(:portal_employee)],
      [:nch_interest_employee_answer, profile_question: profile_questions(:nch_single_choice_q), answer_value: { answer_text: "Photography", question: profile_questions(:nch_single_choice_q) }, ref_obj: members(:portal_employee)],
      [:nch_location_employee_answer, profile_question: nch_location_question, answer_text: "chennai", ref_obj: members(:portal_employee), location: locations(:chennai)]
    ])
  end

  def populate_program_events
    # ES index won't be available at the time of fixture generation
    # Hence fetching user ids from SQL
    admin_view = programs(:primary_portal).admin_views.find_by(title: "All Employees")
    user_ids = programs(:primary_portal).users.pluck(:id)

    populate_objects(ProgramEvent, [
      [:portal_birthday_party, title: "Birthday Party", location: "chennai, tamilnadu, india", start_time: Time.now + 10.days, status: ProgramEvent::Status::PUBLISHED, program: programs(:primary_portal), admin_view: admin_view, admin_view_title: admin_view.title, user: users(:portal_admin), time_zone: "Asia/Kolkata", email_notification: true, precomputed_user_ids: user_ids]
    ])
  end

  def populate_educations
    populate_objects(Education, [
      [:edu_employee_answer, school_name: "American boys school",   degree: "Science", major: "Mechanical", graduation_year: 2003, member: members(:portal_employee), question: profile_questions(:nch_education_q)]
    ])
  end

  def populate_articles
    populate_objects(Article, [
      [:nch_article, author: members(:nch_admin), organization: programs(:org_nch), published_programs: [programs(:nch_mentoring), programs(:primary_portal)],
        content: {
          title: "Nch: India state economy",
          body: "Prof. Amarthya Sen told the toddlers today to take the toll of the terrific thunderstorms that the traumatic tensions in the tanzanian east coast. <br /> <span> Test </span>",
          type: "text",
          status: ArticleContent::Status::PUBLISHED,
          published_at: 2.days.ago
        }
      ],
      [:portal_article, author: members(:nch_admin), organization: programs(:org_nch), published_programs: [programs(:primary_portal)],
        content: {
          title: "Portal specific: India is a great democratic country",
          body: "India is a great democratic country. Its bigger than Pakistan and Srilanka.",
          type: "text",
          status: ArticleContent::Status::PUBLISHED,
          published_at: 1.days.ago
        }
      ]
    ])
  end

  def populate_qa_questions
    populate_objects(QaQuestion, [
      [:portal_what, program: programs(:primary_portal), user: users(:portal_employee), summary: "where is chennai?", description: "I live in america, can anyone tell me where is chennai", views: 1],
      [:nch_why, program: programs(:nch_mentoring), user: users(:nch_mentor), summary: "why chennai?", description: "My friend lives in chennai, thats the reason", views: 1]
    ])
  end

  def populate_qa_answers
    populate_objects(QaAnswer, [
      [:for_portal_what, qa_question: qa_questions(:portal_what), user: users(:portal_admin), content: "Content by nch_admin"],
      [:for_nch_why, qa_question: qa_questions(:nch_why), user: users(:nch_mentor), content: "Content by mentor"]
    ])
  end

  def populate_organization_languages
    populate_objects(OrganizationLanguage, [
      [:hindi_nch, organization: programs(:org_nch), enabled: true, language: languages(:hindi), title: "Hindi", display_title: "Hindilu"]
    ])
  end

  def populate_program_languages
    organization_languages(:hindi_nch).send(:enable_for_program_ids, programs(:org_nch).program_ids)
  end

  def populate_admin_messages
    populate_objects(AdminMessage, [
      [:nch_first_admin_message, sender: members(:portal_employee), program: programs(:primary_portal), subject: "First admin message", content: "This is going to be very interesting"]
    ])

    populate_objects(AdminMessage, [
      [:nch_reply_to_offline_user, sender: members(:nch_admin), receiver_name: "Test User", receiver_email: "test@chronus.com", program: programs(:primary_portal), subject: "Re - Second admin message", content: "This is not going to be interesting", status: AbstractMessageReceiver::Status::UNREAD, parent_id: messages(:nch_first_admin_message).id]
    ], skip_message: true)
  end

  def populate_forums
    populate_objects(Forum, [
      [:employee_forum, name: "Employee forum", program: programs(:primary_portal), access_role_names: [:employee]]
    ])
  end

  def populate_subscriptions
    populate_objects(Subscription, [
      [forums(:employee_forum), [:portal_employee]]
    ])
  end

  def create_career_dev_portal(record_name, attrs = {})
    attrs.merge!(created_at: attrs[:organization].created_at)
    attrs.reverse_merge!(program_type: CareerDev::Portal::ProgramType::CHRONUS_CAREER)

    create_record(CareerDev::Portal, record_name, attrs)
  end

  def create_organization(record_name, attrs = {})
    organization = super
    organization.enable_feature(FeatureName::CAREER_DEVELOPMENT)
    organization
  end

  def apply_wcag_theme
    AbstractProgram.update_all(theme_id: themes(:wcag_theme).id)
  end
end
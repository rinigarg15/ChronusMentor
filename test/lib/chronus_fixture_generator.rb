require Rails.root.to_s + '/test/lib/parallel_overrides'
require Rails.root.to_s + '/test/lib/fixture_generator/fixture_generator'

class ChronusFixtureGenerator < FixtureGenerator
  include ActionDispatch::TestProcess

  def self.generate(opts = {})
    ApplicationEagerLoader.load
    opts[:except] = [
      Delayed::Job, ActiveRecord::SessionStore::Session, RecentActivity,
      AdminMessages::Receiver, Messages::Receiver, Scraps::Receiver,
      MentoringModelTaskCommentScrap, MobileDevice, Feedback::Question, FlagView,
      MeetingRequestView, ProjectRequestView, MembershipRequestView, ConnectionView,
      MentorRequestView, ProgramInvitationView, AdminView, ChronusVersion
    ]
    opts[:include] = []
    super(opts)
  end

  CHAR_ARRAY = "abcdefghijklmnopqrstuvwxyz".split("")

  def populate
    [
      Theme, Location, Organization, Program::Domain, Program,
      Section, ProfileQuestion, RoleQuestion, RoleQuestionPrivacySetting, Member,
      ProfileAnswer, User, Education, Experience, Publication, Manager, DateAnswer, MembershipRequest,
      MentorRequest, RequestFavorite, Group, ProjectRequest, Connection::PrivateNote,
      Announcement, Message, MeetingRequest, QaQuestion, QaAnswer,
      ProgramSurvey, EngagementSurvey, SurveyQuestion, SurveyAnswer,
      Article, Comment, Forum, Subscription, Connection::Question, Connection::Answer,
      CommonQuestion, SchedulingAccount, Meeting, MemberMeetingResponse, MentoringSlot,
      UserSetting, Language, OrganizationLanguage, ProgramLanguage, MemberLanguage, ThreeSixty::Competency,
      ThreeSixty::Question, ThreeSixty::Survey, ThreeSixty::SurveyReviewer, ThreeSixty::SurveyAnswer, ProgramEvent,
      CampaignManagement::UserCampaign, CampaignManagement::UserCampaignMessage, AdminMessage, Scrap, ProgramInvitation,
      CampaignManagement::UserCampaignStatus, CampaignManagement::UserCampaignMessageJob, CampaignManagement::CampaignEmail,
      CampaignManagement::EmailEventLog, Report::Section, Report::Metric, Report::Alert, GroupCheckin, AbstractBulkMatch,
      MentorRecommendation, RecommendationPreference, ActivityLog, PrivateMeetingNote, ViewedObject,
      FavoritePreference, IgnorePreference, AdminViewUserCache, LoginToken, Summary, ExplicitUserPreference, UserSearchActivity
    ].each do |klass|
      self.send("populate_#{klass.name.underscore.parameterize(separator: '_').pluralize}")
    end

    update_groups
    update_calendar_settings
    update_security_settings
    update_customized_terms
    apply_wcag_theme

    [Connection::Activity, ProgramActivity, RecentActivity].each(&:delete_all)
    AuthConfig.unscoped.where(auth_type: AuthConfig::Type::OPEN).update_all(enabled: true)
    Role.all.each {|role| role.remove_permission(RolePermission::CREATE_PROJECT_WITHOUT_APPROVAL)}
  end

  def populate_themes
    say_populating(Theme.name)
    wcag_theme_css_file = ThemeUtils.generate_theme(JSON.parse(File.read("#{Rails.root}/test/fixtures/files/wcag_theme_variables.json")), true)
    wcag_fixture_file = fixture_file_upload(wcag_theme_css_file, 'text/css')

    non_wcag_theme_css_file = ThemeUtils.generate_theme(JSON.parse(File.read("#{Rails.root}/test/fixtures/files/non_wcag_theme_variables.json")))
    non_wcag_fixture_file = fixture_file_upload(non_wcag_theme_css_file, 'text/css')

    create_record(Theme, "themes_1", name: "Non WCAG Theme", css: non_wcag_fixture_file, temp_path: non_wcag_fixture_file.path)
    create_record(Theme, "wcag_theme", name: "Default", css: wcag_fixture_file, temp_path: wcag_fixture_file.path)
  end

  def populate_locations
    populate_objects(Location, [
      ["chennai", city: "Chennai", state: "Tamil Nadu", country: "India", lat: 13.060416, lng: 80.249634, full_address: "Chennai, Tamil Nadu, India", reliable: true],
      ["delhi", city: "New Delhi", state: "Delhi", country: "India", lat: 28.635308, lng: 77.22496, full_address: "New Delhi, Delhi, India", reliable: true],
      ["pondicherry", city: "Pondicherry", state: "Pondicherry", country: "India", lat: 11.93288, lng: 79.837067, full_address: "Pondicherry, Pondicherry, India", reliable: true],
      ["ukraine", city: "Kiev", state: "Kiev", country: "Ukraine", lat: 50.4020355, lng: 30.5326905, full_address: "Kiev, Kiev, Ukraine", reliable: true],
      ["invalid_geo", city: "Invalid", state: "Good State", country: "Nice Country", full_address: "Invalid, Good State, Nice Country", reliable: false],
      ["cha_am", city: "Cha-am", state: "Changwat Phetchaburi", country: "Thailand", lat: 12.8, lng: 99.9667, full_address: "Cha-am,Changwat Phetchaburi,Thailand", reliable: true],
      ["st_mary", city: nil, state: "England", country: "United Kingdom", lat: 51.3878, lng: 0.110626, full_address: "St. Mary Cray, Orpington BR5, UK", reliable: true]
    ])
  end

  def populate_organizations
    populate_objects(Organization, [
      [:org_primary, name: "Primary Organization", description: "Albers mentoring program."],
      [:org_anna_univ, name: "Anna University", description: "Mentoring Programs under Anna University"],
      [:org_foster, name: "Foster School of Business", description: "Foster MBA"],
      [:org_custom_domain, name: "Custom Domain Organization", description: "Custom Domain"],
      [:org_no_subdomain, name: "No Sub Domain Organization", description: "No Sub Domain"]
    ])
  end

  def populate_program_domains
    populate_objects(Program::Domain, [
      [:org_primary, organization: programs(:org_primary), subdomain: "primary", domain: DEFAULT_DOMAIN_NAME],
      [:org_anna_univ, organization: programs(:org_anna_univ), subdomain: "annauniv", domain: DEFAULT_DOMAIN_NAME],
      [:org_foster, organization: programs(:org_foster), subdomain: "foster", domain: DEFAULT_DOMAIN_NAME],
      [:org_custom_domain, organization: programs(:org_custom_domain), subdomain: "mentor", domain: "customtest.com"],
      [:org_no_subdomain, organization: programs(:org_no_subdomain), subdomain: nil, domain: "nosubdomtest.com"]
    ])
  end

  def populate_programs
    populate_objects(Program, [
      [:albers, name: "Albers Mentor Program", description: "Albers Mentor Program", mentor_request_style: Program::MentorRequestStyle::MENTEE_TO_MENTOR, allow_one_to_many_mentoring: false, allow_non_match_connection: true, organization: programs(:org_primary), root: 'albers', creation_way: Program::CreationWay::MANUAL],
      [:ceg, name: "CEG Mentor Program", description: "CEG Mentor Program", mentor_request_style: Program::MentorRequestStyle::MENTEE_TO_MENTOR, allow_one_to_many_mentoring: false, allow_non_match_connection: true, mentoring_period: 3.months, organization: programs(:org_anna_univ), root: 'ceg', creation_way: Program::CreationWay::MANUAL],
      [:nwen, name: "NWEN", description: "NWEN", mentor_request_style: Program::MentorRequestStyle::MENTEE_TO_MENTOR, allow_one_to_many_mentoring: false, organization: programs(:org_primary), root: 'nwen', creation_way: Program::CreationWay::MANUAL],
      [:moderated_program, name: "Moderated Program", description: "Moderated Program", mentor_request_style: Program::MentorRequestStyle::MENTEE_TO_ADMIN, allow_one_to_many_mentoring: false, organization: programs(:org_primary), root: 'modprog', creation_way: Program::CreationWay::MANUAL, min_preferred_mentors: 0],
      [:psg, name: "psg", description: "psg program", mentor_request_style: Program::MentorRequestStyle::MENTEE_TO_ADMIN, allow_one_to_many_mentoring: true, organization: programs(:org_anna_univ), root: 'psg', creation_way: Program::CreationWay::MANUAL, min_preferred_mentors: 0],
      [:foster, name: "foster", description: "Foster MBA", mentor_request_style: Program::MentorRequestStyle::MENTEE_TO_ADMIN, allow_one_to_many_mentoring: true, organization: programs(:org_foster), root: 'main', sort_users_by: Program::SortUsersBy::LAST_NAME, creation_way: Program::CreationWay::MANUAL, min_preferred_mentors: 0],
      [:no_mentor_request_program, name: "No Mentor Request Program", description: "No Mentor Request Program", mentor_request_style: Program::MentorRequestStyle::NONE, allow_one_to_many_mentoring: true, organization: programs(:org_primary), root: 'nomreqpro', creation_way: Program::CreationWay::MANUAL],
      [:custom_domain, name: "Custom Domain Program", description: "Custom domain Program", mentor_request_style: Program::MentorRequestStyle::NONE, allow_one_to_many_mentoring: true, organization: programs(:org_custom_domain), root: 'main', creation_way: Program::CreationWay::MANUAL],
      [:cit, name: "Coimbatore Institute of Technology", description: "The college is in Coimbatore", mentor_request_style: Program::MentorRequestStyle::MENTEE_TO_ADMIN, allow_one_to_many_mentoring: true, organization: programs(:org_anna_univ), root: 'cit', creation_way: Program::CreationWay::MANUAL, min_preferred_mentors: 0],
      [:no_subdomain, name: "No Sub Domain Program", description: "No Sub Domain", mentor_request_style: Program::MentorRequestStyle::MENTEE_TO_ADMIN, allow_one_to_many_mentoring: true, organization: programs(:org_no_subdomain), root: 'main', creation_way: Program::CreationWay::MANUAL, min_preferred_mentors: 0],
      [:pbe, name: "Project Based Engagement", description: "PBE related track", engagement_type: Program::EngagementType::PROJECT_BASED, organization: programs(:org_primary), root: 'pbe', creation_way: Program::CreationWay::MANUAL]
    ])

    Role.create!(program: programs(:albers), name: "user")
    Role.create!(program: programs(:pbe), name: RoleConstants::TEACHER_NAME, for_mentoring: true)

    programs(:no_mentor_request_program).roles.each do |role|
      RoleConstants::MENTOR_REQUEST_PERMISSIONS.each do |permission_name|
        role.remove_permission(permission_name)
      end
    end
  end

  def populate_sections
    populate_objects(Section, [
      [:section_albers, organization: programs(:org_primary), title: "More Information", position: 4, default_field: false],
      [:section_albers_2, organization: programs(:org_primary), title: "More Information 2", position: 5, default_field: false],
      [:section_albers_students, organization: programs(:org_primary), title: "More Information Students", position: 6, default_field: false],
      [:section_fosters_3, organization: programs(:org_foster), title: "More Information 3", position: 4, default_field: false]
    ])
  end

  def populate_profile_questions
    section_mentor = sections(:section_albers)
    section_student = sections(:section_albers_students)
    work_and_education_section = programs(:org_primary).sections.find_by(title: "Work and Education")

    populate_objects(ProfileQuestion, [
      [:string_q, question_type: ProfileQuestion::Type::STRING, question_text: "What is your name", organization: programs(:org_primary), section: section_mentor],
      [:single_choice_q, question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "What is your name", organization: programs(:org_primary), section: section_mentor],
      [:multi_choice_q, question_type: ProfileQuestion::Type::MULTI_CHOICE, question_text: "What is your name", organization: programs(:org_primary), section: section_mentor],
      [:private_q, question_type: ProfileQuestion::Type::STRING, question_text: "What is your favorite location stop", organization: programs(:org_primary), section: section_mentor],
      [:student_string_q,question_type: ProfileQuestion::Type::STRING, question_text: "What is your hobby", organization: programs(:org_primary), section: section_student],
      [:student_single_choice_q, question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "What is your hobby", organization: programs(:org_primary), section: section_student],
      [:student_multi_choice_q, question_type: ProfileQuestion::Type::MULTI_CHOICE, question_text: "What is your hobby", organization: programs(:org_primary), section: section_student],
      [:mentor_file_upload_q, question_type: ProfileQuestion::Type::FILE, question_text: "Upload your Resume", organization: programs(:org_primary), section: section_mentor],
      [:education_q, question_type: ProfileQuestion::Type::EDUCATION, question_text: "Current Education", organization: programs(:org_primary), section: work_and_education_section],
      [:multi_education_q, question_type: ProfileQuestion::Type::MULTI_EDUCATION, question_text: "Entire Education", organization: programs(:org_primary), section: work_and_education_section],
      [:experience_q, question_type: ProfileQuestion::Type::EXPERIENCE, question_text: "Current Experience", organization: programs(:org_primary), section: work_and_education_section],
      [:multi_experience_q, question_type: ProfileQuestion::Type::MULTI_EXPERIENCE, question_text: "Work Experience", organization: programs(:org_primary), section: work_and_education_section],
      [:publication_q, question_type: ProfileQuestion::Type::PUBLICATION, question_text: "Current Publication", organization: programs(:org_primary), section: work_and_education_section],
      [:multi_publication_q, question_type: ProfileQuestion::Type::MULTI_PUBLICATION, question_text: "New Publication", organization: programs(:org_primary), section: work_and_education_section],
      [:manager_q, question_type: ProfileQuestion::Type::MANAGER, question_text: "Current Manager", organization: programs(:org_primary), section: work_and_education_section],
      [:date_question, question_type: ProfileQuestion::Type::DATE, question_text: "Date Question", organization: programs(:org_primary), section: work_and_education_section]
    ])
    populate_question_choices_for_profile_question
  end

  def populate_question_choices_for_profile_question
    attrs_array = []
    "opt_1,opt_2,opt_3".split(",").each_with_index do |choice, index|
      attrs_array << ["single_choice_q_#{index + 1}".to_sym, text: choice, ref_obj: profile_questions(:single_choice_q), position: index + 1]
    end
    "Stand,Walk,Run".split(",").each_with_index do |choice, index|
      attrs_array << ["multi_choice_q_#{index + 1}".to_sym, text: choice, ref_obj: profile_questions(:multi_choice_q), position: index + 1]
    end
    "opt_1,opt_2,opt_3".split(",").each_with_index do |choice, index|
      attrs_array << ["student_single_choice_q_#{index + 1}".to_sym, text: choice, ref_obj: profile_questions(:student_single_choice_q), position: index + 1]
    end
    "Stand,Walk,Run".split(",").each_with_index do |choice, index|
      attrs_array << ["student_multi_choice_q_#{index + 1}".to_sym, text: choice, ref_obj: profile_questions(:student_multi_choice_q), position: index + 1]
    end

    populate_objects(QuestionChoice, attrs_array, skip_message: true)
    populate_question_choice_translations_for_profile_question
  end

  def populate_question_choice_translations_for_profile_question
    begin
      I18n.locale = :'fr-CA'
      choices = [question_choices(:student_multi_choice_q_1), question_choices(:student_multi_choice_q_2), question_choices(:student_multi_choice_q_3)]
      translated_choices = ["Supporter", "Marcher", "Course"]
      choices.each_with_index do |choice, index|
        choice.update_attributes!(text: translated_choices[index])
      end
    ensure
      I18n.locale = :en
    end
  end

  def populate_role_questions
    albers_mentor_role = programs(:albers).get_role(RoleConstants::MENTOR_NAME)
    albers_student_role = programs(:albers).get_role(RoleConstants::STUDENT_NAME)

    populate_objects(RoleQuestion, [
      [:string_role_q, profile_question: profile_questions(:string_q), role: albers_mentor_role],
      [:single_choice_role_q, profile_question: profile_questions(:single_choice_q), role: albers_mentor_role],
      [:multi_choice_role_q, profile_question: profile_questions(:multi_choice_q), role: albers_mentor_role],
      [:private_role_q, profile_question: profile_questions(:private_q), role: albers_mentor_role, private: RoleQuestion::PRIVACY_SETTING::RESTRICTED],
      [:student_string_role_q,profile_question: profile_questions(:student_string_q), role: albers_student_role],
      [:student_single_choice_role_q, profile_question: profile_questions(:student_single_choice_q), role: albers_student_role],
      [:student_multi_choice_role_q, profile_question: profile_questions(:student_multi_choice_q), role: albers_student_role],
      [:mentor_file_upload_role_q, profile_question: profile_questions(:mentor_file_upload_q), filterable: false, role: albers_mentor_role],
      [:education_role_q, profile_question: profile_questions(:education_q), role: albers_mentor_role],
      [:multi_education_role_q, profile_question: profile_questions(:multi_education_q), role: albers_mentor_role],
      [:experience_role_q, profile_question: profile_questions(:experience_q), role: albers_mentor_role],
      [:multi_experience_role_q, profile_question: profile_questions(:multi_experience_q), role: albers_mentor_role],
      [:publication_role_q, profile_question: profile_questions(:publication_q), role: albers_mentor_role],
      [:multi_publication_role_q, profile_question: profile_questions(:multi_publication_q), role: albers_mentor_role],
      [:manager_role_q, profile_question: profile_questions(:manager_q), role: albers_mentor_role],
      [:date_role_question, profile_question: profile_questions(:date_question), role: albers_mentor_role]
    ])
  end

  def populate_role_question_privacy_settings
    populate_objects(RoleQuestionPrivacySetting, [
      [:connected_members_privacy_setting, role_question: role_questions(:private_role_q), setting_type: RoleQuestionPrivacySetting::SettingType::CONNECTED_MEMBERS]
    ])
  end

  def populate_members
    populate_objects(Member, [
      [:f_admin, organization: programs(:org_primary), first_name: "Freakin", last_name: "Admin", email: "ram@example.com", admin: true],
      [:f_student, organization: programs(:org_primary), first_name: "student", last_name: "example", email: "rahim@example.com"],
      [:f_mentor, organization: programs(:org_primary), first_name: "Good unique", last_name: "name", email: "robert@example.com"],
      [:f_user, organization: programs(:org_primary), first_name: "user", last_name: "name", email: "user_role@example.com"],
      [:f_mentor_student, organization: programs(:org_primary), first_name: "Mentor", last_name: "Studenter", email: "mentrostud@example.com"],
      [:ram, organization: programs(:org_primary), first_name: "Kal", last_name: "Raman", email: "userram@example.com"],
      [:rahim, organization: programs(:org_primary), first_name: "rahim", last_name: "user", email: "userrahim@example.com"],
      [:robert, organization: programs(:org_primary), first_name: "robert", last_name: "user", email: "userrobert@example.com"],
      [:mkr_student, organization: programs(:org_primary), first_name: "mkr_student", last_name: "madankumarrajan", email: "mkr@example.com"]
    ] +
      15.times.map { |i| ["student_#{i}", organization: programs(:org_primary), first_name: "student_#{CHAR_ARRAY[i]}", last_name: "example", email: "student_#{i}@example.com"] } +
      15.times.map { |i| ["mentor_#{i}", organization: programs(:org_primary), first_name: "mentor_#{CHAR_ARRAY[i]}", last_name: "chronus", email: "mentor_#{i}@example.com"] } +
    [
      [:arun_albers, organization: programs(:org_primary), first_name: "arun", last_name: "albers", email: "arun@albers.com"],
      [:arun_ceg, organization: programs(:org_anna_univ), first_name: "arun", last_name: "ceg", email: "arun@ceg.com"],
      [:not_requestable_mentor, organization: programs(:org_primary), first_name: "Non requestable", last_name: "mentor", email: "non_request@example.com"],
      [:requestable_mentor, organization: programs(:org_primary), first_name: "Requestable", last_name: "mentor", email: "request@example.com"],
      [:moderated_admin, organization: programs(:org_primary), first_name: "Moderated", last_name: "Admin", email: "moderated_admin@example.com"],
      [:moderated_student, organization: programs(:org_primary), first_name: "Moderated", last_name: "Student", email: "moderated_student@example.com"],
      [:moderated_mentor, organization: programs(:org_primary), first_name: "Moderated", last_name: "Mentor", email: "moderated_mentor@example.com"],
      [:anna_univ_admin, organization: programs(:org_anna_univ), first_name: "CEG", last_name: "Admin", email: "ceg_admin@example.com", admin: true],
      [:psg_only_admin, organization: programs(:org_anna_univ), first_name: "psg", last_name: "Admin", email: "psg@example.com"],
      [:psg_student1, organization: programs(:org_anna_univ), first_name: "studa", last_name: "psg", email: "stud1@psg.com"],
      [:psg_student2, organization: programs(:org_anna_univ), first_name: "studb", last_name: "psg", email: "stud2@psg.com"],
      [:psg_student3, organization: programs(:org_anna_univ), first_name: "studc", last_name: "psg", email: "stud3@psg.com"],
      [:anna_univ_mentor, organization: programs(:org_anna_univ), first_name: "mental", last_name: "mentor", email: "mentor@psg.com"],
      [:psg_mentor1, organization: programs(:org_anna_univ), first_name: "PSG", last_name: "mentora", email: "mentor1@psg.com"],
      [:psg_mentor2, organization: programs(:org_anna_univ), first_name: "PSG", last_name: "mentorb", email: "mentor2@psg.com"],
      [:psg_mentor3, organization: programs(:org_anna_univ), first_name: "PSG", last_name: "mentorc", email: "mentor3@psg.com"],
      [:inactive_user, organization: programs(:org_anna_univ), first_name: "inactive", last_name: "mentor", email: "inactivementor@albers.com"],
      [:foster_mentor1, organization: programs(:org_foster), first_name: "Miller", last_name: "Adams", email: "millad1@foster.com"],
      [:foster_mentor2, organization: programs(:org_foster), first_name: "Eric", last_name: "Anderson", email: "millad2@foster.com"],
      [:foster_mentor3, organization: programs(:org_foster), first_name: "Mary Baker", last_name: "Anderson", email: "millad3@foster.com"],
      [:foster_mentor4, organization: programs(:org_foster), first_name: "Brad", last_name: "Baker", email: "millad4@foster.com"],
      [:foster_mentor5, organization: programs(:org_foster), first_name: "Artie", last_name: "Artie", email: "millad5@foster.com"],
      [:foster_mentor6, organization: programs(:org_foster), first_name: "Walter", last_name: "Ingram", email: "millad6@foster.com"],
      [:foster_mentor7, organization: programs(:org_foster), first_name: "Kurt", last_name: "Zumwalt", email: "millad7@foster.com"],
      [:foster_student1, organization: programs(:org_foster), first_name: "Lao", last_name: "Zi", email: "studnt1@foster.com"],
      [:foster_admin, organization: programs(:org_foster), first_name: "Freakin", last_name: "Admin", email: "fosteradmin@example.com", admin: true],
      [:assistant, organization: programs(:org_primary), first_name: "Assistant", last_name: "User", email: "assistant@chronus.com", state: Member::Status::DORMANT],
      [:f_mentor_ceg, organization: programs(:org_anna_univ), first_name: "Good unique", last_name: "name", email: "robert@example.com"],
      [:no_mreq_admin, organization: programs(:org_primary), first_name: "No Mentor Request", last_name: "Admin", email: "no_mreq_admin@example.com"],
      [:no_mreq_student, organization: programs(:org_primary), first_name: "No Mentor Request", last_name: "Student", email: "no_mreq_student@example.com"],
      [:no_mreq_mentor, organization: programs(:org_primary), first_name: "No Mentor Request", last_name: "Mentor", email: "no_mreq_mentor@example.com"],
      [:nwen_admin, organization: programs(:org_primary), first_name: "Barren", last_name: "Despota", email: "bdespota@example.com"],
      [:pending_user, organization: programs(:org_primary), first_name: "pending", last_name: "user", email: "pending_user@example.com"],
      [:sarat_mentor_ceg, organization: programs(:org_anna_univ), first_name: "sarat", last_name: "Chennai", email: "sarat_mentor_ceg@example.com"],
      [:custom_domain_admin, organization: programs(:org_custom_domain), first_name: "Custom", last_name: "Admin", email: "custom@admin.com"],
      [:cit_admin_mentor, organization: programs(:org_anna_univ), first_name: "Rajesh", last_name: "Vijay", email: "man_cit@chronus.com"],
      [:no_subdomain_admin, organization: programs(:org_no_subdomain), first_name: "No Subdomain", last_name: "Admin", email: "no_subdomain_admin@example.com", admin: true],
      [:dormant_member, organization: programs(:org_no_subdomain), first_name: "Dormant", last_name: "Member", email: "dormant@example.com", state: Member::Status::DORMANT],
      [:not_accepted_tnc, organization: programs(:org_primary), first_name: "Not", last_name: "Accepted", email: 'na@chronus.com', admin: false, terms_and_conditions_accepted: nil],
      [:drafted_group_member, organization: programs(:org_primary), first_name: "Drafted", last_name: "User", email: "drafted-user@chronus.com"],
      [:psg_remove, organization: programs(:org_anna_univ), first_name: "PSG", last_name: "Remove", email: "remove@psg.com"]
    ] +
      5.times.map {|i| ["teacher_#{i}", organization: programs(:org_primary), first_name: "teacher_#{CHAR_ARRAY[i]}", last_name: "chronus", email: "teacher_#{i}@example.com"] }
    )
  end

  def populate_profile_answers
    location_question = programs(:org_primary).profile_questions.select{|ques| ques.location?}.first

    populate_objects(ProfileAnswer, [
      [:one, profile_question: profile_questions(:string_q), answer_text: "Computer", ref_obj: members(:f_mentor)],
      [:two, profile_question: profile_questions(:string_q), answer_text: "Bike race", ref_obj: members(:mentor_3)],
      [:single_choice_ans_1, profile_question: profile_questions(:single_choice_q), answer_value: "opt_1", ref_obj: members(:f_mentor)],
      [:single_choice_ans_2, profile_question: profile_questions(:single_choice_q), answer_value: "opt_3", ref_obj: members(:robert)],
      [:multi_choice_ans_1, profile_question: profile_questions(:multi_choice_q), answer_value: ["Stand", "Run"], ref_obj: members(:f_mentor)],
      [:multi_choice_ans_2, profile_question: profile_questions(:multi_choice_q), answer_value: ["Walk"], ref_obj: members(:mentor_3)],
      [:private_answer, profile_question: profile_questions(:private_q), answer_text: "Ooty", ref_obj: members(:f_mentor)],
      [:location_chennai_ans, profile_question: location_question, answer_text: "chennai", ref_obj: members(:f_mentor), location: locations(:chennai)],
      [:location_delhi_ans_1, profile_question: location_question, answer_text: "delhi", ref_obj: members(:inactive_user), location: locations(:delhi)],
      [:location_delhi_ans_2, profile_question: location_question, answer_text: "delhi", ref_obj: members(:robert), location: locations(:delhi)],
      [:mentor_file_upload_answer, profile_question: profile_questions(:mentor_file_upload_q), ref_obj: members(:f_mentor), attachment: fixture_file_upload(Rails.root.to_s + File.join('/test/fixtures/files', 'some_file.txt'), 'text/text', false)],
      [:not_applicable, profile_question: profile_questions(:string_q), ref_obj: members(:robert)],
      [:no_mreq_mentor_location, profile_question: location_question, answer_text: "chennai", ref_obj: members(:no_mreq_mentor), location: locations(:chennai)],
      [:no_mreq_student_location, profile_question: location_question, answer_text: "delhi", ref_obj: members(:no_mreq_student), location: locations(:delhi)]
    ])
  end

  def populate_users
    populate_objects(User, [
      [:f_admin, program: programs(:albers), member: members(:f_admin), role_names: [:admin]],
      [:f_student, program: programs(:albers), member: members(:f_student), role_names: [:student]],
      [:f_mentor, program: programs(:albers), member: members(:f_mentor), role_names: [:mentor], max_connections_limit: 2],
      [:f_user, program: programs(:albers), member: members(:f_user), roles: [Role.find_by(name: "user")]],
      [:f_mentor_student, program: programs(:albers), member: members(:f_mentor_student), role_names: [:mentor, :student], max_connections_limit: 2],
      [:ram, program: programs(:albers), member: members(:ram), role_names: [:admin, :mentor], max_connections_limit: 2],
      [:rahim, program: programs(:albers), member: members(:rahim), role_names: [:student]],
      [:robert, program: programs(:albers), member: members(:robert), role_names: [:mentor]],
      [:mkr_student, program: programs(:albers), member: members(:mkr_student), role_names: [:student]]
    ] +
      15.times.map { |i| ["student_#{i}", program: programs(:albers), member: members("student_#{i}"), role_names: [:student]] } +
      15.times.map { |i| ["mentor_#{i}", program: programs(:albers), member: members("mentor_#{i}"), role_names: [:mentor]] } +
    [
      [:arun_albers, program: programs(:albers), member: members(:arun_albers), role_names: [:student]],
      [:arun_ceg, program: programs(:ceg), member: members(:arun_ceg), role_names: [:student]],
      [:not_requestable_mentor, program: programs(:albers), member: members(:not_requestable_mentor), role_names: [:mentor], max_connections_limit: 2],
      [:requestable_mentor, program: programs(:albers), member: members(:requestable_mentor), role_names: [:mentor], max_connections_limit: 1],
      [:moderated_admin, program: programs(:moderated_program), member: members(:moderated_admin), role_names: [:admin]],
      [:moderated_student, program: programs(:moderated_program), member: members(:moderated_student), role_names: [:student]],
      [:moderated_mentor, program: programs(:moderated_program), member: members(:moderated_mentor), role_names: [:mentor], max_connections_limit: 2],
      [:ceg_admin, program: programs(:ceg), member: members(:anna_univ_admin), role_names: [:admin]],
      [:psg_admin, program: programs(:psg), member: members(:anna_univ_admin), role_names: [:admin]],
      [:psg_student1, program: programs(:psg), member: members(:psg_student1), role_names: [:student]],
      [:psg_student2, program: programs(:psg), member: members(:psg_student2), role_names: [:student]],
      [:psg_student3, program: programs(:psg), member: members(:psg_student3), role_names: [:student]],
      [:psg_mentor, program: programs(:psg), member: members(:anna_univ_mentor), role_names: [:mentor], max_connections_limit: 4],
      [:psg_mentor1, program: programs(:psg), member: members(:psg_mentor1), role_names: [:mentor], max_connections_limit: 4],
      [:psg_mentor2, program: programs(:psg), member: members(:psg_mentor2), role_names: [:mentor], max_connections_limit: 4],
      [:psg_mentor3, program: programs(:psg), member: members(:psg_mentor3), role_names: [:mentor], max_connections_limit: 4],
      [:inactive_user, program: programs(:psg), member: members(:inactive_user), role_names: [:mentor], max_connections_limit: 2],
      [:foster_mentor1, program: programs(:foster), member: members(:foster_mentor1), role_names: [:mentor], max_connections_limit: 2, protected_attrs: { state: User::Status::PENDING } ],
      [:foster_mentor2, program: programs(:foster), member: members(:foster_mentor2), role_names: [:mentor], max_connections_limit: 2, protected_attrs: { state: User::Status::PENDING } ],
      [:foster_mentor3, program: programs(:foster), member: members(:foster_mentor3), role_names: [:mentor], max_connections_limit: 2, protected_attrs: { state: User::Status::PENDING } ],
      [:foster_mentor4, program: programs(:foster), member: members(:foster_mentor4), role_names: [:mentor], max_connections_limit: 2, protected_attrs: { state: User::Status::PENDING } ],
      [:foster_mentor5, program: programs(:foster), member: members(:foster_mentor5), role_names: [:mentor], max_connections_limit: 2],
      [:foster_mentor6, program: programs(:foster), member: members(:foster_mentor6), role_names: [:mentor], max_connections_limit: 2, protected_attrs: { state: User::Status::PENDING } ],
      [:foster_mentor7, program: programs(:foster), member: members(:foster_mentor7), role_names: [:mentor], max_connections_limit: 2, protected_attrs: { state: User::Status::PENDING } ],
      [:foster_student1, program: programs(:foster), member: members(:foster_student1), role_names: [:student], max_connections_limit: 2, protected_attrs: { state: User::Status::PENDING } ],
      [:foster_admin, program: programs(:foster), member: members(:foster_admin), role_names: [:admin]],
      [:f_mentor_ceg, program: programs(:ceg), member: members(:f_mentor_ceg), role_names: [:mentor], max_connections_limit: 2],
      [:no_mreq_admin, program: programs(:no_mentor_request_program), member: members(:no_mreq_admin), role_names: [:admin]],
      [:no_mreq_student, program: programs(:no_mentor_request_program), member: members(:no_mreq_student), role_names: [:student]],
      [:no_mreq_mentor, program: programs(:no_mentor_request_program), member: members(:no_mreq_mentor), role_names: [:mentor]],
      [:nwen_admin, program: programs(:nwen), member: members(:nwen_admin), role_names: [:admin]],
      [:pending_user, program: programs(:albers), member: members(:pending_user), role_names: [:mentor], max_connections_limit: 2, protected_attrs: { state: User::Status::PENDING } ],
      [:sarat_mentor_ceg, program: programs(:ceg), member: members(:sarat_mentor_ceg), role_names: [:mentor], max_connections_limit: 2],
      [:custom_domain_admin, program: programs(:custom_domain), member: members(:custom_domain_admin), role_names: [:admin]],
      [:ceg_mentor, program: programs(:ceg), member: members(:anna_univ_mentor), role_names: [:mentor]],
      [:psg_only_admin, program: programs(:psg), member: members(:psg_only_admin), role_names: [:admin]],
      [:f_admin_nwen, program: programs(:nwen), member: members(:f_admin), role_names: [:admin]],
      [:f_admin_moderated_program, program: programs(:moderated_program), member: members(:f_admin), role_names: [:admin]],
      [:cit_admin_mentor, program: programs(:cit), member: members(:cit_admin_mentor), role_names: [:admin, :mentor]],
      [:f_mentor_nwen_student, program: programs(:nwen), member: members(:f_mentor), role_names: [:student]],
      [:f_student_nwen_mentor, program: programs(:nwen), member: members(:f_student), role_names: [:mentor]],
      [:no_subdomain_admin, program: programs(:no_subdomain), member: members(:no_subdomain_admin), role_names: [:admin]],
      [:not_accepted_tnc, program: programs(:albers), member: members(:not_accepted_tnc), role_names: [:mentor]],
      [:drafted_group_user, program: programs(:albers), member: members(:drafted_group_member), role_names: [:student]],
      [:psg_remove, program: programs(:psg), member: members(:psg_remove), role_names: [:mentor]],
      [:f_admin_pbe, program: programs(:pbe), member: members(:f_admin), role_names: [:admin]],
      [:f_student_pbe, program: programs(:pbe), member: members(:f_student), role_names: [:student]],
      [:f_mentor_pbe, program: programs(:pbe), member: members(:f_mentor), role_names: [:mentor]]
    ] +
      10.times.map { |i| ["pbe_student_#{i}", program: programs(:pbe), member: members("student_#{i}"), role_names: [:student]] } +
      10.times.map { |i| ["pbe_mentor_#{i}", program: programs(:pbe), member: members("mentor_#{i}"), role_names: [:mentor]] } +
      5.times.map { |i| ["pbe_teacher_#{i}", program: Program.find_by(root: "pbe"), member: members("teacher_#{i}"), role_names: [:teacher]] } +
    [
      [:f_onetime_mode_mentor, program: programs(:moderated_program), member: members(:f_mentor), role_names: [:mentor], mentoring_mode: User::MentoringMode::ONE_TIME]
    ])

    # Cannot add user to a suspended member
    user = users(:inactive_user)
    user.member.update_attribute(:state, Member::Status::SUSPENDED)
    user.state = User::Status::SUSPENDED
    user.global_reactivation_state = User::Status::ACTIVE
    user.save!

    users(:f_mentor).update_attributes(tag_list: "tag1, tag2")
    users(:f_mentor_student).update_attributes(tag_list: "tag3")
    users(:ram).update_attributes(tag_list: "tag1, tag4")
    users(:mentor_1).update_attribute(:last_seen_at, 20.minutes.ago)
    users(:mentor_2).update_attribute(:last_seen_at, 1.hour.ago)
  end

  def populate_educations
    populate_objects(Education, [
      [:edu_1, school_name: "American boys school", degree: "Science", major: "Mechanical", graduation_year: 2003, member: members(:f_mentor), question: profile_questions(:multi_education_q)],
      [:edu_2, school_name: "Indian college", degree: "Arts", major: "Computer Engineering", graduation_year: 2006, member: members(:f_mentor), question: profile_questions(:multi_education_q)],
      [:edu_3, school_name: "American boys school", degree: "Arts", major: "Mechanical", graduation_year: 2003, member: members(:mentor_3), question: profile_questions(:multi_education_q)],
      [:edu_4, school_name: "American boys school", degree: "Science", major: "Mechanical", graduation_year: 2003, member: members(:f_mentor), question: profile_questions(:education_q)]
    ])
  end

  def populate_experiences
    populate_objects(Experience, [
      [:exp_1, job_title: "Lead Developer",  company: "Microsoft", start_year: 1990, end_year: 1995, member: members(:f_mentor), question: profile_questions(:multi_experience_q)],
      [:exp_2, job_title: "Chief Software Architect And Programming Lead", company: "Mannar", start_year: 1990, end_year: 1995, member: members(:f_mentor), question: profile_questions(:multi_experience_q)],
      [:exp_3, job_title: "Chief Software Architect And Programming Lead", company: "Mannar", start_year: 1990, end_year: 1995, member: members(:mentor_3), question: profile_questions(:multi_experience_q)],
      [:exp_4, job_title: "Lead Developer",  company: "Microsoft", start_year: 1990, end_year: 1995, member: members(:f_mentor), question: profile_questions(:experience_q)]
    ])
  end

  def populate_publications
    populate_objects(Publication, [
      [:pub_1, title: "Useful publication", day: 11, month: 11, year: 2010, publisher: 'Publisher', authors: members(:f_mentor).name, url: 'http://publication.url', description: 'Very useful publication', member: members(:f_mentor), question: profile_questions(:multi_publication_q)],
      [:pub_2, title: "Mentor publication", day: 3, month: 1, year: 2012, publisher: 'Publisher', authors: members(:f_mentor).name, url: 'http://publication.url', description: 'Very useful publication', member: members(:f_mentor), question: profile_questions(:multi_publication_q)],
      [:pub_3, title: "Third publication", day: 5, month: 5, year: 2010, publisher: 'Publisher', authors: members(:mentor_3).name, url: 'http://publication.url', description: 'Very useful publication', member: members(:mentor_3), question: profile_questions(:multi_publication_q)],
      [:pub_4, title: "Forth publication", day: 3, month: 10, year: 2010, publisher: 'Publisher', authors: members(:f_mentor).name, url: 'http://publication.url', description: 'Very useful publication', member: members(:f_mentor), question: profile_questions(:publication_q)]
    ])
  end

  def populate_managers
    populate_objects(Manager, [
      [:manager_1, first_name: 'Manager1', last_name: 'Name1', email: 'manager1@example.com', managee: members(:f_mentor), question: profile_questions(:manager_q)],
      [:manager_2, first_name: 'Manager2', last_name: 'Name2', email: 'manager2@example.com', managee: members(:mentor_3), question: profile_questions(:manager_q)],
      [:manager_3, first_name: 'Existing Manager1', last_name: 'Name2', email: 'userrahim@example.com', managee: members(:student_1), question: profile_questions(:manager_q)]
    ])
  end

  def populate_date_answers
    populate_objects(DateAnswer, [
      [:date_answer_1, member: members(:f_mentor), question: profile_questions(:date_question), answer_text: "June 23, 2017"],
      [:date_answer_2, member: members(:f_mentor_student), question: profile_questions(:date_question), answer_text: "May 29, 2019"]
    ])
  end

  def populate_membership_requests
    populate_objects(MembershipRequest,
      6.times.map { |i| [members("student_#{i}"), RoleConstants::MENTOR_NAME, i] } +
      (6..11).to_a.map { |i| [members("mentor_#{i}"), RoleConstants::STUDENT_NAME, i] }
    )
  end

  def populate_mentor_requests
    populate_objects(MentorRequest, [
      [:moderated_request_with_favorites, program: programs(:moderated_program), sender_id: users(:moderated_student).id, status: AbstractRequest::Status::NOT_ANSWERED, message: "Hi"]
    ] +
      15.times.map { |i| ["mentor_request_#{i}", program: programs(:albers), sender_id: users("student_#{i}").id, receiver_id: users(:f_mentor).id, status: AbstractRequest::Status::NOT_ANSWERED, message: "Hi"] } +
      5.times.map { |i| ["mentor_request_#{15 + i}", program: programs(:albers), sender_id: users("student_#{i}").id, receiver_id: users(:robert).id, status: AbstractRequest::Status::NOT_ANSWERED, message: "Hi"] }
    )

    (11..14).to_a.each do |i|
      mentor_request = mentor_requests("mentor_request_#{i}")
      mentor_request.status = AbstractRequest::Status::REJECTED
      mentor_request.response_text = "Sorry"
      mentor_request.skip_observer = true
      mentor_request.save
    end
  end

  def populate_request_favorites
    populate_objects(RequestFavorite, [
      [:first_request_favorite, user: users(:moderated_student), mentor_request: mentor_requests(:moderated_request_with_favorites), favorite: users(:moderated_mentor)]
    ])
  end

  def populate_groups
    populate_objects(Group, [
      [:mygroup, program: programs(:albers), expiry_time: 4.months.from_now, mentors: [users(:f_mentor)], students: [users(:mkr_student)], global: true],
      [:group_2, program: programs(:albers), expiry_time: 4.days.from_now, mentors: [users(:not_requestable_mentor)], students: [users(:student_2)], global: true],
      [:group_3, program: programs(:albers), expiry_time: 4.months.from_now, mentors: [users(:not_requestable_mentor)], students: [users(:student_3)]],
      [:group_4, program: programs(:albers), expiry_time: 4.months.from_now, mentors: [users(:requestable_mentor)], students: [users(:student_4)]],
      [:group_5, program: programs(:albers), expiry_time: 4.months.from_now, mentors: [users(:mentor_1)], students: [users(:student_1)]],
      [:group_inactive, program: programs(:albers), expiry_time: 4.months.from_now, mentors: [users(:mentor_1)], students: [users(:student_2)], status: Group::Status::INACTIVE],
      [:multi_group, program: programs(:psg), expiry_time: 4.months.from_now, mentors: [users(:psg_mentor1), users(:psg_mentor2), users(:psg_mentor3)], students: [users(:psg_student1), users(:psg_student2), users(:psg_student3)]],
      [:group_nwen, program: programs(:nwen), expiry_time: 4.months.from_now, mentors: [users(:f_student_nwen_mentor)], students: [users(:f_mentor_nwen_student)]],
      [:old_group, program: programs(:albers), expiry_time: 6.months.from_now, mentors: [users(:robert)], students: [users(:student_2)]],
      [:drafted_group_1, program: programs(:albers), mentors: [users(:robert)], students: [users(:student_1)], status: Group::Status::DRAFTED, name: 'drafted_group_1', creator_id: users(:f_admin).id],
      [:drafted_group_2, program: programs(:albers), mentors: [users(:mentor_1)], students: [users(:student_3)], status: Group::Status::DRAFTED, creator_id: users(:f_admin).id],
      [:drafted_group_3, program: programs(:albers), mentors: [users(:mentor_1)], students: [users(:drafted_group_user)], status: Group::Status::DRAFTED, creator_id: users(:f_admin).id]
    ] +
      5.times.map { |i| ["group_pbe_#{i}", program: programs(:pbe), mentors: [users("pbe_mentor_#{i}")], students: [users("pbe_student_#{i}"), users("pbe_student_#{i + 5}")], status: Group::Status::PENDING, name: "project_#{CHAR_ARRAY[i]}", global: true, pending_at: i.days.ago] } +
    [
      [:group_pbe, program: programs(:pbe), expiry_time: 4.months.from_now, mentors: [users(:f_mentor_pbe)], students: [users(:f_student_pbe)], name: "project_group", global: true],
      [:proposed_group_1, program: programs(:pbe), mentors: [], students: [users(:f_student_pbe)], name: "Strategy to finish Game of Thrones in a weekend :)", global: true, created_by: users(:f_student_pbe), status: Group::Status::PROPOSED, created_at: 1.days.ago],
      [:proposed_group_2, program: programs(:pbe), mentors: [], students: [users(:f_student_pbe)], name: "Study the principles of Frank Underwood and share the learnings", global: true, created_by: users(:f_student_pbe), status: Group::Status::PROPOSED, created_at: 2.days.ago],
      [:proposed_group_3, program: programs(:pbe), mentors: [users(:f_mentor_pbe)], students: [], name: "Learn high funda, over the top arguments from Suits", global: true, created_by: users(:f_mentor_pbe), status: Group::Status::PROPOSED, created_at: 3.days.ago],
      [:proposed_group_4, program: programs(:pbe), mentors: [users(:f_mentor_pbe)], students: [], name: "Learn to decorate your Kill Room from Dexter", global: true, created_by: users(:f_mentor_pbe), status: Group::Status::PROPOSED, created_at: 4.days.ago],
      [:rejected_group_1, program: programs(:pbe), mentors: [], students: [users(:f_student_pbe)], name: "Incorporate family values by watching Breaking Bad", global: true, created_by: users(:f_student_pbe), status: Group::Status::REJECTED, closed_at: 2.days.ago, created_at: 3.days.ago, closed_by: users(:f_admin_pbe), termination_reason: "Objectives are not clear, Redo !!"],
      [:rejected_group_2, program: programs(:pbe), mentors: [users(:f_mentor_pbe)], students: [], name: "Misogyny, Drink, Smoke - Mad Men", global: true, created_by: users(:f_mentor_pbe), status: Group::Status::REJECTED, closed_at: 3.days.ago, created_at: 4.days.ago, closed_by: users(:f_admin_pbe), termination_reason: "There is more to it, please Re-work !!"],
      [:withdrawn_group_1, program: programs(:pbe), mentors: [users(:f_mentor_pbe)], students: [], name: "Learn to survive from Claire", global: true, created_by: users(:f_mentor_pbe), status: Group::Status::WITHDRAWN, closed_at: 3.days.ago, created_at: 4.days.ago, closed_by: users(:f_admin_pbe), termination_reason: "Admin is on leave !!"],
      [:no_mreq_group, program: programs(:no_mentor_request_program), expiry_time: 4.months.from_now, mentors: [users(:no_mreq_mentor)], students: [users(:no_mreq_student)], name: "No mentor request group"],
      [:drafted_pbe_group, program: programs(:pbe), mentors: [], students: [users(:f_student_pbe)], name: "Drafted PBE group", global: true, created_by: users(:f_admin_pbe), status: Group::Status::DRAFTED, created_at: 1.days.ago]
    ])

    groups(:group_4).terminate!(users(:f_admin), "Test reason", groups(:group_4).program.group_closure_reasons.first.id)
    teacher_role = programs(:pbe).roles.find_by(name: RoleConstants::TEACHER_NAME)
    groups(:rejected_group_1).add_and_remove_custom_users!(teacher_role, [users(:pbe_teacher_0)])
    groups(:rejected_group_2).add_and_remove_custom_users!(teacher_role, [users(:pbe_teacher_1)])
  end

  def populate_project_requests
    student_role_id = programs(:pbe).roles.find_by(name: RoleConstants::STUDENT_NAME).id
    populate_objects(ProjectRequest,
      5.times.map { |i| ["project_request_rejected_#{i}", program: programs(:pbe), sender_id: users("pbe_student_#{i + 1}").id, group_id: groups("group_pbe_#{i}").id, message: "Hi", sender_role_id: student_role_id, status: AbstractRequest::Status::REJECTED] } +
      5.times.map { |i| ["project_request_#{i}", program: programs(:pbe), sender_id: users("pbe_student_#{i + 2}").id, group_id: groups("group_pbe_#{i}").id, message: "Hi", sender_role_id: student_role_id] }
    )
  end

  def populate_connection_private_notes
    populate_objects(Connection::PrivateNote, [
      [:mygroup_student_1, connection_membership: groups(:mygroup).student_memberships.first, text: "I did the assignment yesterday; it was tough"],
      [:mygroup_student_2, connection_membership: groups(:mygroup).student_memberships.first, text: "My second note."],
      [:mygroup_student_3, connection_membership: groups(:mygroup).student_memberships.first, text: "My third note."],
      [:mygroup_mentor_1, connection_membership: groups(:mygroup).mentor_memberships.first, text: "mentor first note."],
      [:mygroup_mentor_2, connection_membership: groups(:mygroup).mentor_memberships.first, text: "mentor second note."],
      [:group_2_student_1, connection_membership: groups(:group_2).student_memberships.first, text: "second group first student note."],
      [:group_3_mentor_1, connection_membership: groups(:group_3).mentor_memberships.first, text: "third group mentor first note."],
      [:group_3_mentor_3, connection_membership: groups(:group_3).mentor_memberships.first, text: "third group mentor second note."]
    ])
  end

  def populate_announcements
    populate_objects(Announcement, [
      [:assemble, title: "All come to audi small", body: "All people should assemble in Vivek audi", program: programs(:albers), admin: users(:f_admin), recipient_role_names: [:mentor, :student]],
      [:big_announcement, title: "All come to audi big announce", body: "All people should assemble in Vivek audi" * 100, program: programs(:albers), admin: users(:f_admin), recipient_role_names: [:mentor, :student]],
      [:expired_announcement, title: "expired announcement", body: "All expired people should assemble in Arbit audi" * 100, expiration_date: 1.day.ago, program: programs(:albers), admin: users(:f_admin), recipient_role_names: [:mentor, :student]],
      [:drafted_announcement, title: "Drafted Announcement", body: "All people should assemble in Vivek audi", program: programs(:albers), admin: users(:f_admin), recipient_role_names: [:mentor], status: Announcement::Status::DRAFTED]
    ])
  end

  def populate_messages
    populate_objects(Message, [
      [:first_message, sender: members(:f_mentor_student), receivers: [members(:f_mentor)], organization: programs(:org_primary), subject: "First message", content: "This is going to be very interesting"],
      [:second_message, sender: members(:f_mentor), receivers: [members(:f_mentor_student)], organization: programs(:org_primary), subject: "Second message", content: "This is not going to be interesting"]
    ])
  end

  def populate_meeting_requests
    populate_objects(MeetingRequest, [
      [:pending_1, program: programs(:albers), mentor: users(:f_mentor), student: users(:f_student), status: AbstractRequest::Status::NOT_ANSWERED, skip_observer: true],
      [:pending_2, program: programs(:albers), mentor: users(:robert), student: users(:rahim), status: AbstractRequest::Status::NOT_ANSWERED, skip_observer: true],
      [:accepted, program: programs(:albers), mentor: users(:f_mentor), student: users(:mkr_student), status: AbstractRequest::Status::ACCEPTED, skip_observer: true, acceptance_message: "Meet me at 5:00 PM"],
      [:withdrawn, program: programs(:albers), mentor: users(:mentor_1), student: users(:f_student), status: AbstractRequest::Status::WITHDRAWN, skip_observer: true],
      [:rejected, program: programs(:albers), mentor: users(:robert), student: users(:student_1), status: AbstractRequest::Status::REJECTED, skip_observer: true]
    ])
  end

  def populate_qa_questions
    populate_objects(QaQuestion, [
      [:what, program: programs(:albers), user: users(:f_mentor), summary: "where is chennai?", description: "I live in america, can anyone tell me where is chennai", views: 1],
      [:why, program: programs(:albers), user: users(:f_mentor), summary: "why chennai?", description: "My friend lives in chennai, thats the reason", views: 1]
    ] +
      15.times.map { |i| ["qa_question_#{i + 100}", program: programs(:albers), user: users(:f_mentor), summary: "Is madurai in INDIA?", description: "Can anyone tell me whether madurai is in india?", views: 5000 - i * i * i + i * i] } +
    [
      [:question_for_stopwords_test, program: programs(:albers), user: users(:f_mentor), summary: "where in this world is coimbatore?", description: "coimbatore is in somewhere near salem.", views: 10],
      [:ceg_1, program: programs(:ceg), user: users(:ceg_mentor), summary: "where in this world is coimbatore?", description: "coimbatore is in somewhere near salem.", views: 3],
      [:psg_1, program: programs(:psg), user: users(:psg_student2), summary: "where in this world is coimbatore?", description: "coimbatore is in somewhere near salem.", views: 7],
      [:ceg_2, program: programs(:ceg), user: users(:ceg_mentor), summary: "where in this world is coimbatore?", description: "coimbatore is in somewhere near salem.", views: 5],
      [:cit_1, program: programs(:cit), user: users(:cit_admin_mentor), summary: "Do you like CIT?", description: "Do you really like CIT user?", views: 5]
    ])
  end

  def populate_qa_answers
    populate_objects(QaAnswer, [
      [:for_question_what, qa_question: qa_questions(:what), user: users(:f_student), content: "Content by f_student"],
      [:for_question_why, qa_question: qa_questions(:why), user: users(:f_student), content: "Content by f_student"]
    ] +
      5.times.map { |n| ["for_question_#{n+100}", qa_question: qa_questions("qa_question_#{n + 100}"), user: users(:f_student), content: "Content by f_student"] }
    )
  end

  def populate_program_surveys
    populate_objects(ProgramSurvey, [
      [:one, name: "How helpful is this program", program: programs(:albers), recipient_role_names: [:mentor, :student], edit_mode: Survey::EditMode::MULTIRESPONSE]
    ])
  end

  def populate_engagement_surveys
    populate_objects(EngagementSurvey, [
      [:two, name: "Introduce yourself", program: programs(:albers)],
      [:progress_report, name: "Progress Report", program: programs(:no_mentor_request_program)]
    ])
  end

  def populate_survey_questions
    populate_objects(SurveyQuestion, [
      [:q2_name, program: programs(:albers), question_type: CommonQuestion::Type::MULTI_STRING, question_text: "What is your name?", protected_attrs: { survey_id:  surveys(:two).id } ],
      [:q2_location, program: programs(:albers), question_type: CommonQuestion::Type::STRING, question_text: "Where do you live?", protected_attrs: { survey_id:  surveys(:two).id } ],
      [:q2_from, program: programs(:albers), question_type: CommonQuestion::Type::SINGLE_CHOICE, question_text: "Where are you from?",  protected_attrs: { survey_id: surveys(:two).id } ],
      [:q3_name, program: programs(:no_mentor_request_program), question_type: CommonQuestion::Type::MULTI_STRING, question_text: "What is your name?", protected_attrs: { survey_id: surveys(:progress_report).id } ],
      [:q3_from, program: programs(:no_mentor_request_program), question_type: CommonQuestion::Type::SINGLE_CHOICE, question_text: "Where are you from?",  protected_attrs: { survey_id: surveys(:progress_report).id } ]
    ])

    attrs_array = []
    "Smallville,Krypton,Earth".split(",").each_with_index do |choice, index|
      attrs_array << ["q2_from_#{index + 1}".to_sym, text: choice, ref_obj: common_questions(:q2_from), position: index + 1]
    end
    "Smallville,Krypton,Earth".split(",").each_with_index do |choice, index|
      attrs_array << ["q3_from_#{index + 1}".to_sym, text: choice, ref_obj: common_questions(:q3_from), position: index + 1]
    end
    populate_objects(QuestionChoice, attrs_array, skip_message: true)
  end

  def populate_survey_answers
    populate_objects(SurveyAnswer, [
      [:q3_name_answer_1, user: users(:no_mreq_mentor), answer_text: "remove mentor", response_id: 1, last_answered_at: Time.now, protected_attrs: { survey_id: surveys(:progress_report).id, survey_question: common_questions(:q3_name), group_id: groups(:no_mreq_group).id } ],
      [:q3_name_answer_2, user: users(:no_mreq_student), answer_text: "remove mentee", response_id: 2, group_id: groups(:no_mreq_group), last_answered_at: Time.now + 2.days, protected_attrs: { survey_id: surveys(:progress_report).id, survey_question: common_questions(:q3_name), group_id: groups(:no_mreq_group).id } ],
      [:q3_from_answer_1, user: users(:no_mreq_mentor), answer_value: { answer_text: "Smallville", question: common_questions(:q3_from) }, response_id: 1, group_id: groups(:no_mreq_group), last_answered_at: Time.now, protected_attrs: { survey_id: surveys(:progress_report).id, survey_question: common_questions(:q3_from), group_id: groups(:no_mreq_group).id } ],
      [:q3_from_answer_2, user: users(:no_mreq_student), answer_value: { answer_text: "Earth", question: common_questions(:q3_from) }, response_id: 2, group_id: groups(:no_mreq_group), last_answered_at: Time.now + 2.days, protected_attrs: { survey_id: surveys(:progress_report).id, survey_question: common_questions(:q3_from), group_id: groups(:no_mreq_group).id } ],
      [:q3_from_answer_draft, user: users(:no_mreq_student), answer_value: { answer_text: "Earth", question: common_questions(:q3_from) }, response_id: 3, group_id: groups(:no_mreq_group), last_answered_at: Time.now + 2.days, is_draft: true, protected_attrs: { survey_id: surveys(:progress_report).id, survey_question: common_questions(:q3_from), group_id: groups(:no_mreq_group).id } ]
    ])
  end

  def populate_articles
    populate_objects(Article, [
      [:economy, author: members(:f_admin), organization: programs(:org_primary), published_programs: [programs(:albers)],
        content: {
          title: "India state economy",
          body: "Prof. Amarthya Sen told the toddlers today to take the toll of the terrific thunderstorms that the traumatic tensions in the tanzanian east coast. <br /> <span> Test </span>",
          type: ArticleContent::Type::TEXT,
          status: ArticleContent::Status::PUBLISHED,
          published_at: 2.days.ago
        }
      ],
      [:india, author: members(:f_admin), organization: programs(:org_primary), published_programs: [programs(:albers)],
        content: {
          title: "India is a great democratic country",
          body: "India is a great democratic country. Its bigger than Pakistan and Srilanka.",
          type: ArticleContent::Type::TEXT,
          status: ArticleContent::Status::PUBLISHED,
          published_at: 1.days.ago
        }
      ],
      [:kangaroo, author: members(:f_mentor), organization: programs(:org_primary), published_programs: [programs(:albers)],
        content: {
          title: "Australia Kangaroo extinction",
          body: "Chris Byle is a kangaroo kid and a survivor of the plastic bottle sugar water gate conditioning. He knows how to swim.",
          type: ArticleContent::Type::TEXT,
          status: ArticleContent::Status::PUBLISHED,
          published_at: 21.days.ago
        }
      ],
      [:delhi, author: members(:ram), organization: programs(:org_primary), published_programs: [programs(:albers)],
        content: {
          title: "Capital city",
          body: "Capital of the world's seventh largest nation. Great city, but bad cricket pitch",
          type: ArticleContent::Type::TEXT,
          status: ArticleContent::Status::PUBLISHED,
          published_at: 12.days.ago
        }
      ],

      [:draft_article, author: members(:f_mentor), organization: programs(:org_primary), published_programs: [programs(:albers)],
        content: {
          title: "Draft article",
          body: "Draft is a way of pre preparation for the article creation phase.",
          type: ArticleContent::Type::TEXT,
          status: ArticleContent::Status::DRAFT
        }
      ],
      [:anna_univ_1, author: members(:anna_univ_mentor), organization: programs(:org_anna_univ), published_programs: [programs(:ceg), programs(:psg)],
        content: {
          title: "About Anna University",
          body: "Capital of the world's seventh largest nation. Great city, but bad cricket pitch",
          type: ArticleContent::Type::TEXT,
          status: ArticleContent::Status::PUBLISHED
        }
      ],
      [:anna_univ_psg_1, author: members(:anna_univ_admin), organization: programs(:org_anna_univ), published_programs: [programs(:psg)],
        content: {
          title: "About Anna University and PSG",
          body: "Capital of the world's seventh largest nation. Great city, but bad cricket pitch",
          type: ArticleContent::Type::TEXT,
          status: ArticleContent::Status::PUBLISHED
        }
      ]
    ])

    article_contents(:economy).update_attributes(label_list: "mba")
    article_contents(:delhi).update_attributes(label_list: "locations")
    article_contents(:india).update_attributes(label_list: "locations")
    article_contents(:kangaroo).update_attributes(label_list: "animals")
    article_contents(:draft_article).update_attributes(label_list: "locations")
    article_contents(:anna_univ_1).update_attributes(label_list: "locations, animals")
    article_contents(:anna_univ_psg_1).update_attributes(label_list: "locations, psg")
  end

  def populate_comments
    populate_objects(Comment, [
      [:anna_univ_ceg_1_c1, article: articles(:anna_univ_1), program: programs(:ceg), user: users(:f_mentor_ceg), body: "asd"],
      [:anna_univ_psg_1_c1, article: articles(:anna_univ_psg_1), program: programs(:psg), user: users(:psg_mentor3), body: "asd"],
      [:anna_univ_ceg_1_c2, article: articles(:anna_univ_1), program: programs(:ceg), user: users(:ceg_admin), body: "asd"],
      [:anna_univ_psg_1_c2, article: articles(:anna_univ_psg_1), program: programs(:psg), user: users(:psg_mentor1), body: "asd"],
      [:anna_univ_psg_2_c2, article: articles(:anna_univ_1), program: programs(:psg), user: users(:psg_mentor2), body: "asd"]
    ])
  end

  def populate_forums
    populate_objects(Forum, [
      [:common_forum, name: "Common forum", program: programs(:albers), access_role_names: [:mentor, :student]]
    ])
  end

  def populate_subscriptions
    populate_objects(Subscription, [
      [Forum.all.first, [:f_admin, :f_student]],
      [Forum.all.second, [:f_admin, :f_mentor]],
      [forums(:common_forum), [:f_admin, :f_mentor, :f_student]]
    ])
  end

  def populate_connection_questions
    populate_objects(Connection::Question, [
      [:string_connection_q, question_type: CommonQuestion::Type::STRING, question_text: "Funding Value", program: programs(:albers)],
      [:required_string_connection_q,question_type: CommonQuestion::Type::STRING, question_text: "Required Connection Question", program: programs(:albers), required: true],
      [:single_choice_connection_q, question_type: CommonQuestion::Type::SINGLE_CHOICE, question_text: "Industry", program: programs(:albers)],
      [:multi_choice_connection_q, question_type: CommonQuestion::Type::MULTI_CHOICE, question_text: "Scope", program: programs(:albers)],
      [:string_connection_q_psg, question_type: CommonQuestion::Type::STRING, question_text: "Funding Value PSG", program: programs(:psg)]
    ])
    populate_question_choices_for_connection_questions
  end

  def populate_question_choices_for_connection_questions
    attrs_array = []
    "opt_1,opt_2,opt_3".split(",").each_with_index do |choice, index|
      attrs_array << ["single_choice_connection_q_#{index + 1}".to_sym, text: choice, ref_obj: common_questions(:single_choice_connection_q), position: index + 1]
    end
    "Stand,Walk,Run".split(",").each_with_index do |choice, index|
      attrs_array << ["multi_choice_connection_q_#{index + 1}".to_sym, text: choice, ref_obj: common_questions(:multi_choice_connection_q), position: index + 1]
    end

    populate_objects(QuestionChoice, attrs_array, skip_message: true)
  end

  def populate_summaries
    populate_objects(Summary, [
      [:string_connection_summary_q, connection_question: common_questions(:string_connection_q)],
      [:string_connection_summary_q_psg, connection_question: common_questions(:string_connection_q_psg)]
    ])
  end

  def populate_connection_answers
    populate_objects(Connection::Answer, [
      [:one_connection, question: common_questions(:string_connection_q), answer_text: "Computer", group: groups(:mygroup)],
      [:single_choice_ans_1_connection, question: common_questions(:single_choice_connection_q), answer_value: { answer_text: "opt_1", question: common_questions(:single_choice_connection_q) }, group: groups(:mygroup)],
      [:multi_choice_ans_1_connection, question: common_questions(:multi_choice_connection_q), answer_value: { answer_text: ["Stand", "Run"], question: common_questions(:multi_choice_connection_q) }, group: groups(:mygroup)]
    ])
  end

  def populate_common_questions
    populate_objects(CommonQuestion, [
      [:multi_choice_common_q, program: programs(:albers), question_type: CommonQuestion::Type::MULTI_CHOICE, question_text: "What are your hobbies?"],
      [:single_choice_common_q, program: programs(:albers), question_type: CommonQuestion::Type::SINGLE_CHOICE, question_text: "What do you want to buy?"],
      [:rating_common_q, program: programs(:albers), question_type: CommonQuestion::Type::RATING_SCALE, question_text: "Rate Me"]
    ])
    populate_question_choices_for_common_question
  end

  def populate_question_choices_for_common_question
    attrs_array = []
    "Stand,Walk,Run".split(",").each_with_index do |choice, index|
      attrs_array << ["multi_choice_common_q_#{index + 1}".to_sym, text: choice, ref_obj: common_questions(:multi_choice_common_q), position: index + 1]
    end
    "Computer,Sofa".split(",").each_with_index do |choice, index|
      attrs_array << ["single_choice_common_q_#{index + 1}".to_sym, text: choice, ref_obj: common_questions(:single_choice_common_q), position: index + 1]
    end
    "Good,Bad,Weird".split(",").each_with_index do |choice, index|
      attrs_array << ["rating_common_q_#{index + 1}".to_sym, text: choice, ref_obj: common_questions(:rating_common_q), position: index + 1]
    end

    populate_objects(QuestionChoice, attrs_array, skip_message: true)
    populate_question_choice_translations_for_common_question
  end

  def populate_question_choice_translations_for_common_question
    begin
      I18n.locale = :'fr-CA'
      choices = [question_choices(:multi_choice_common_q_1), question_choices(:multi_choice_common_q_2), question_choices(:multi_choice_common_q_3)]
      translated_choices = ["Supporter", "Marcher", "Course"]
      choices.each_with_index do |choice, index|
        choice.update_attributes!(text: translated_choices[index])
      end

      choices = [question_choices(:single_choice_common_q_1), question_choices(:single_choice_common_q_2)]
      translated_choices = ["Ordinateur","Velo"]
      choices.each_with_index do |choice, index|
        choice.update_attributes!(text: translated_choices[index])
      end

      choices = [question_choices(:rating_common_q_1), question_choices(:rating_common_q_2), question_choices(:rating_common_q_3)]
      translated_choices = ["Bon","Mauvais","Bizarre"]
      choices.each_with_index do |choice, index|
        choice.update_attributes!(text: translated_choices[index])
      end
    ensure
      I18n.locale = :en
    end
  end

  def populate_scheduling_accounts
    populate_objects(SchedulingAccount, [
      [:scheduling_account_1, email: "scheduling-test1@chronus.com", status: SchedulingAccount::Status::ACTIVE],
      [:scheduling_account_2, email: "scheduling-test2@chronus.com", status: SchedulingAccount::Status::ACTIVE],
      [:scheduling_account_3, email: "scheduling-test3@chronus.com", status: SchedulingAccount::Status::ACTIVE],
      [:scheduling_account_4, email: "scheduling-test4@chronus.com", status: SchedulingAccount::Status::INACTIVE],
      [:scheduling_account_5, email: "scheduling-test5@chronus.com", status: SchedulingAccount::Status::INACTIVE]
    ])
  end

  def populate_meetings
    beginning_of_day_time = Time.current.beginning_of_day.change(usec: 0)

    Timecop.freeze(beginning_of_day_time - 2.days) do
      time = Time.current
      populate_objects(Meeting, [
        [:f_mentor_mkr_student, program: programs(:albers), group: groups(:mygroup), description: "General Meeting", topic: "Arbit Topic", start_time: time, end_time: (time + 30.minutes), location: "Chennai", members: [members(:f_mentor), members(:mkr_student)], owner_id: members(:f_mentor).id],
        [:student_2_not_req_mentor, program: programs(:albers), group: groups(:group_2), topic: "Arbit Topic2", start_time: time, end_time: (time + 20.minutes), members: [members(:student_2), members(:not_requestable_mentor)], owner_id: members(:student_2).id],
        [:psg_mentor_psg_student, program: programs(:psg), topic: "Sample Meeting", start_time: time, end_time: (time + 20.minutes), group: groups(:multi_group), members: [members(:psg_mentor1), members(:psg_student1)], owner_id: members(:psg_mentor1).id]
      ])
    end

    Timecop.freeze(beginning_of_day_time - 25.days) do
      time = Time.current
      populate_objects(Meeting, [
        [:past_psg_mentor_psg_student, program: programs(:psg), topic: "Past Meeting", start_time: time, end_time: (time + 1.day), group: groups(:multi_group), members: [members(:psg_mentor1), members(:psg_student1)], owner_id: members(:psg_mentor1).id]
      ], skip_message: true)
    end

    Timecop.freeze(beginning_of_day_time + 25.days) do
      time = Time.current
      populate_objects(Meeting, [
        [:upcoming_psg_mentor_psg_student, program: programs(:psg), topic: "Upcoming Meeting", start_time: time, end_time: (time + 1.day), group: groups(:multi_group), members: [members(:psg_mentor1), members(:psg_student1)], owner_id: members(:psg_mentor1).id]
      ], skip_message: true)
    end

    # Daily Meeting
    Timecop.freeze(beginning_of_day_time - 5.days) do
      time = Time.current
      repeats_end_date = (time + 10.days).to_date
      populate_objects(Meeting, [
        [:f_mentor_mkr_student_daily_meeting, program: programs(:albers), group: groups(:mygroup), description: "General daily Meeting", topic: "Arbit Daily Topic", start_time: time, end_time: (time + 10.days + 30.minutes), location: "Chennai", members: [members(:f_mentor), members(:mkr_student)], owner_id: members(:f_mentor).id, recurrent: "true", schedule_rule: "1", repeat_every: "1", repeats_end_date: repeats_end_date, duration: 30.minutes]
      ], skip_message: true)
    end

    # Calendar Meetings
    Timecop.freeze(beginning_of_day_time + 2.days) do
      time = Time.current
      populate_objects(Meeting, [
        [:upcoming_calendar_meeting, program: programs(:albers), description: "Upcoming Calendar Meeting", group: nil, topic: "Upcoming Calendar Meeting", start_time: time, end_time: (time + 30.minutes), location: "Chennai", members: [members(:f_mentor), members(:mkr_student)], owner_id: members(:f_mentor).id, mentor_created_meeting: true, mentee_id: members(:mkr_student).id],
        [:upcoming_psg_calendar_meeting, program: programs(:psg), description: "Upcoming PSG Calendar Meeting", group: nil, topic: "Upcoming PSG Calendar Meeting", start_time: time, end_time: (time + 30.minutes), location: "Chennai", members: [members(:psg_mentor1), members(:psg_student1)], owner_id: members(:psg_mentor1).id, mentor_created_meeting: true, mentee_id: members(:psg_student1).id]
      ], skip_message: true)
    end

    Timecop.freeze(beginning_of_day_time - 18.days) do
      attrs_array = []
      time = Time.current
      proposed_slot = initialize_proposed_slot_for_meeting(time)
      attrs_array << [:past_calendar_meeting, program: programs(:albers), description: "Past Calendar Meeting", topic: "Past Calendar Meeting", group: nil, start_time: time, end_time: (time + 30.minutes), location: "Chennai", members: [members(:f_mentor), members(:mkr_student)], requesting_mentor: users(:f_mentor), requesting_student: users(:mkr_student), owner_id: members(:mkr_student).id, mentee_id: members(:mkr_student).id, proposed_slots_details_to_create: proposed_slot]

      time += 1.day
      proposed_slot = initialize_proposed_slot_for_meeting(time)
      attrs_array << [:completed_calendar_meeting, program: programs(:albers), description: "Completed Calendar Meeting", topic: "Completed Calendar Meeting", group: nil, start_time: time, end_time: (time + 30.minutes), location: "Chennai", members: [members(:f_mentor), members(:mkr_student)], requesting_mentor: users(:f_mentor), requesting_student: users(:mkr_student), owner_id: members(:mkr_student).id, mentee_id: members(:mkr_student).id, proposed_slots_details_to_create: proposed_slot]

      time += 1.day
      proposed_slot = initialize_proposed_slot_for_meeting(time)
      attrs_array << [:cancelled_calendar_meeting, program: programs(:albers), description: "Cancelled Calendar Meeting", topic: "Cancelled Calendar Meeting", group: nil, start_time: time, end_time: (time + 30.minutes), location: "Chennai", members: [members(:f_mentor), members(:mkr_student)], requesting_mentor: users(:f_mentor), requesting_student: users(:mkr_student), owner_id: members(:mkr_student).id, mentee_id: members(:mkr_student).id, proposed_slots_details_to_create: proposed_slot]

      populate_objects(Meeting, attrs_array, skip_message: true)
      meetings(:past_calendar_meeting).meeting_request.update_attributes!(status: AbstractRequest::Status::ACCEPTED)
      meetings(:completed_calendar_meeting).meeting_request.update_attributes!(status: AbstractRequest::Status::ACCEPTED)
      meetings(:completed_calendar_meeting).update_attributes!(state: Meeting::State::COMPLETED)
      meetings(:cancelled_calendar_meeting).meeting_request.update_attributes!(status: AbstractRequest::Status::ACCEPTED)
      meetings(:cancelled_calendar_meeting).update_attributes!(state: Meeting::State::CANCELLED)
    end
  end

  def populate_scraps
    populate_objects(Scrap, [
      [:mygroup_mentor_1, content: "hello how are you", ref_obj: groups(:mygroup), sender: members(:f_mentor)],
      [:mygroup_student_1, content: "hello how are you", ref_obj: groups(:mygroup), sender: members(:mkr_student)],
      [:mygroup_mentor_2, content: "hello how are you", ref_obj: groups(:mygroup), sender: members(:f_mentor)],
      [:mygroup_mentor_3, content: "hello how are you", ref_obj: groups(:mygroup), sender: members(:f_mentor)],
      [:mygroup_student_2, content: "hello how are you", ref_obj: groups(:mygroup), sender: members(:mkr_student)],
      [:mygroup_mentor_4, content: "hello how are you", ref_obj: groups(:mygroup), sender: members(:f_mentor)],
      [:group_3_student_1, content: "hello how are you", ref_obj: groups(:group_3), sender: members(:not_requestable_mentor)],
      [:group_3_student_2, content: "hello how are you", ref_obj: groups(:group_3), sender: members(:not_requestable_mentor)],
      [:group_3_student_3, content: "hello how are you", ref_obj: groups(:group_3), sender: members(:not_requestable_mentor)],
      [:meeting_scrap, content: "how are you", ref_obj: meetings(:f_mentor_mkr_student), sender: members(:mkr_student)]
    ])
  end

  def populate_member_meeting_responses
    meeting = meetings(:f_mentor_mkr_student)
    meeting.guests.each { |m| m.mark_attending!(meeting) }

    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    member_meeting = meeting.member_meetings.find_by(member_id: members(:f_mentor).id)
    meeting_occurrences = meeting.occurrences
    meeting_occurrences_count = meeting_occurrences.count

    populate_objects(MemberMeetingResponse, [
      [:f_mentor_last_feedback, member_meeting_id: member_meeting.id, attending: MemberMeeting::ATTENDING::YES, meeting_occurrence_time: meeting_occurrences[meeting_occurrences_count - 1]],
      [:f_mentor_second_last_feedback, member_meeting_id: member_meeting.id, attending: MemberMeeting::ATTENDING::NO, meeting_occurrence_time: meeting_occurrences[meeting_occurrences_count - 2]],
      [:f_mentor_first_feedback, member_meeting_id: member_meeting.id, attending: MemberMeeting::ATTENDING::YES, meeting_occurrence_time: meeting_occurrences[0].start_time.to_s],
      [:f_mentor_second_feedback, member_meeting_id: member_meeting.id, attending: MemberMeeting::ATTENDING::NO, meeting_occurrence_time: meeting_occurrences[1].start_time]
    ])
  end

  def populate_mentoring_slots
    populate_objects(MentoringSlot, [
      [:f_mentor, start_time: 20.minutes.since, end_time: 50.minutes.since, repeats: MentoringSlot::Repeats::NONE, member: members(:f_mentor)],
      [:f_mentor_student, start_time: 30.minutes.since, end_time: 70.minutes.since, repeats: MentoringSlot::Repeats::MONTHLY, member: members(:mkr_student)]
    ])
  end

  def populate_user_settings
    populate_objects(UserSetting, [
      [:f_mentor, max_meeting_slots: 1, user: users(:f_mentor)],
      [:f_mentor_student, max_meeting_slots: 10, user: users(:f_mentor_student)],
      [:f_mentor_ceg, max_meeting_slots: 10, user: users(:f_mentor_ceg)]
    ])
  end

  def populate_languages
    populate_objects(Language, [
      [:hindi, title: 'Hindi', display_title: "Hindilu", language_name: 'de', enabled: true],
      [:telugu, title: 'Telugu', display_title: "Telugulu", language_name: 'es', enabled: true]
    ])
  end

  def populate_organization_languages
    populate_objects(OrganizationLanguage, [
      [:hindi, organization: programs(:org_primary), enabled: OrganizationLanguage::EnabledFor::ALL, language: languages(:hindi), title: "Hindi", display_title: "Hindilu"],
      [:telugu, organization: programs(:org_primary), enabled: OrganizationLanguage::EnabledFor::ALL, language: languages(:telugu), title: "Telugu", display_title: "Telugulu"]
    ])
  end

  def populate_program_languages
    program_ids = programs(:org_primary).program_ids
    [organization_languages(:hindi), organization_languages(:telugu)].each do |organization_language|
      organization_language.send(:enable_for_program_ids, program_ids)
    end
  end

  def populate_member_languages
    populate_objects(MemberLanguage, [
      [:hindi_member, member: members(:mentor_13), language: languages(:hindi)],
      [:telugu_member, member: members(:mentor_14), language: languages(:telugu)]
    ])
  end

  def populate_three_sixty_competencies
    programs(:org_primary).three_sixty_competencies.destroy_all

    populate_objects(ThreeSixty::Competency, [
      [:leadership, title: "Leadership", organization: programs(:org_primary)],
      [:delegating, title: "Delegating", organization: programs(:org_primary)],
      [:listening, title: "Listening", organization: programs(:org_primary)],
      [:team_work, title: "Team Work", organization: programs(:org_primary)],
      [:decision_making, title: "Decision Making", organization: programs(:org_primary)]
    ])
  end

  def populate_three_sixty_questions
    populate_objects(ThreeSixty::Question, [
      [:leadership_1, title: "Are you a leader?", competency: three_sixty_competencies(:leadership), question_type: ThreeSixty::Question::Type::RATING, organization: programs(:org_primary)],
      [:leadership_2, title: "Do people blindly follow you?", competency: three_sixty_competencies(:leadership), question_type: ThreeSixty::Question::Type::RATING, organization: programs(:org_primary)],
      [:leadership_3, title: "Do you often take responcibility?", competency: three_sixty_competencies(:leadership), question_type: ThreeSixty::Question::Type::RATING, organization: programs(:org_primary)],
      [:delegating_1, title: "Do you tend to micromanage?", competency: three_sixty_competencies(:delegating), question_type: ThreeSixty::Question::Type::RATING, organization: programs(:org_primary)],
      [:delegating_2, title: "Do you spread the work evenly among derect reports?", competency: three_sixty_competencies(:delegating), question_type: ThreeSixty::Question::Type::RATING, organization: programs(:org_primary)],
      [:listening_1, title: "Do you listen to your coleagues?", competency: three_sixty_competencies(:listening), question_type: ThreeSixty::Question::Type::RATING, organization: programs(:org_primary)],
      [:team_work_1, title: "Give an example to signify the ability to work in a team?", competency: three_sixty_competencies(:team_work), question_type: ThreeSixty::Question::Type::TEXT, organization: programs(:org_primary)],
      [:oeq_1, title: "Things to keep doing", question_type: ThreeSixty::Question::Type::TEXT, organization: programs(:org_primary)],
      [:oeq_2, title: "Things to start doing", question_type: ThreeSixty::Question::Type::TEXT, organization: programs(:org_primary)],
      [:oeq_3, title: "Things to stop doing", question_type: ThreeSixty::Question::Type::TEXT, organization: programs(:org_primary)]
    ])
  end

  def populate_three_sixty_surveys
    reviewer_group_2 = programs(:org_primary).three_sixty_reviewer_groups.find_by(name: ThreeSixty::ReviewerGroup::DefaultName::PEER)
    reviewer_group_3 = programs(:org_primary).three_sixty_reviewer_groups.find_by(name: ThreeSixty::ReviewerGroup::DefaultName::LINE_MANAGER)
    reviewer_group_4 = programs(:org_primary).three_sixty_reviewer_groups.find_by(name: ThreeSixty::ReviewerGroup::DefaultName::DIRECT_REPORT)

    populate_objects(ThreeSixty::Survey, [
      [:survey_1, title: "Survey For Level 1 Employees", organization: programs(:org_primary), expiry_date: 2.weeks.from_now.to_date, program: programs(:albers),
        reviewers_addition_type: ThreeSixty::Survey::ReviewersAdditionType::ASSESSEE_ONLY,
        questions: [three_sixty_questions(:listening_1), three_sixty_questions(:team_work_1), three_sixty_questions(:oeq_1), three_sixty_questions(:oeq_2)],
        assessees: [members(:f_admin), members(:f_student), members(:f_mentor)],
        reviewer_groups: [reviewer_group_2, reviewer_group_3, reviewer_group_4]
      ],
      [:survey_2, title: "Survey For Level 2 Employees", organization: programs(:org_primary), program: programs(:albers),
        reviewers_addition_type: ThreeSixty::Survey::ReviewersAdditionType::ASSESSEE_ONLY,
        questions: [three_sixty_questions(:listening_1), three_sixty_questions(:team_work_1), three_sixty_questions(:leadership_3), three_sixty_questions(:oeq_3)],
        assessees: [members(:mentor_0), members(:mentor_1), members(:mentor_2), members(:mentor_3)],
        reviewer_groups: [reviewer_group_2, reviewer_group_3]
      ],
      [:survey_3, title: "Survey For Level 3 Employees", organization: programs(:org_primary), expiry_date: 2.months.from_now.to_date,
        reviewers_addition_type: ThreeSixty::Survey::ReviewersAdditionType::ADMIN_ONLY,
        questions: [three_sixty_questions(:leadership_1), three_sixty_questions(:leadership_2), three_sixty_questions(:leadership_3), three_sixty_questions(:delegating_2)],
        assessees: [members(:student_0), members(:student_1)],
        reviewer_groups: [reviewer_group_2, reviewer_group_3, reviewer_group_4]
      ],
      [:survey_4, title: "Survey For Level 4 Employees", organization: programs(:org_primary), expiry_date: 5.months.from_now.to_date,
        questions: [three_sixty_questions(:leadership_1), three_sixty_questions(:leadership_2), three_sixty_questions(:leadership_3), three_sixty_questions(:delegating_2)],
        assessees: [members(:student_0), members(:student_1)],
        reviewer_groups: [reviewer_group_2, reviewer_group_3, reviewer_group_4]
      ],
      [:survey_5, title: "Survey For Level 5 Employees", organization: programs(:org_primary), expiry_date: 6.months.from_now.to_date,
        questions: [three_sixty_questions(:leadership_1), three_sixty_questions(:leadership_2), three_sixty_questions(:leadership_3), three_sixty_questions(:delegating_2)],
        assessees: [members(:student_0), members(:student_1), members(:f_student), members(:f_mentor)],
        reviewer_groups: [reviewer_group_2, reviewer_group_3, reviewer_group_4]
      ]
    ])

    three_sixty_surveys(:survey_2).update_attribute(:expiry_date, 2.weeks.ago)

    s3 = three_sixty_surveys(:survey_3)
    s3.issue_date = 1.months.from_now.to_date
    s3.save!

    s4 = three_sixty_surveys(:survey_4)
    s4.issue_date = 4.months.from_now.to_date
    s4.state = ThreeSixty::Survey::PUBLISHED
    s4.save!

    s5 = three_sixty_surveys(:survey_5)
    s5.issue_date = 3.months.from_now.to_date
    s5.state = ThreeSixty::Survey::PUBLISHED
    s5.save!
  end

  def populate_three_sixty_survey_reviewers
    s1 = three_sixty_surveys(:survey_1)
    survey_assessee_1 = s1.survey_assessees.find_by(member_id: members(:f_admin).id)
    survey_assessee_2 = s1.survey_assessees.find_by(member_id: members(:f_student).id)
    survey_assessee_3 = s1.survey_assessees.find_by(member_id: members(:f_mentor).id)
    survey_question_1 = s1.survey_questions.find_by(three_sixty_question_id: three_sixty_questions(:listening_1).id)
    survey_question_2 = s1.survey_questions.find_by(three_sixty_question_id: three_sixty_questions(:team_work_1).id)
    reviewer_group_2 = programs(:org_primary).three_sixty_reviewer_groups.find_by(name: ThreeSixty::ReviewerGroup::DefaultName::PEER)
    reviewer_group_3 = programs(:org_primary).three_sixty_reviewer_groups.find_by(name: ThreeSixty::ReviewerGroup::DefaultName::LINE_MANAGER)
    reviewer_group_4 = programs(:org_primary).three_sixty_reviewer_groups.find_by(name: ThreeSixty::ReviewerGroup::DefaultName::DIRECT_REPORT)
    survey_reviewer_group_2 = s1.survey_reviewer_groups.find_by(three_sixty_reviewer_group_id: reviewer_group_2.id)
    survey_reviewer_group_3 = s1.survey_reviewer_groups.find_by(three_sixty_reviewer_group_id: reviewer_group_3.id)
    survey_reviewer_group_4 = s1.survey_reviewer_groups.find_by(three_sixty_reviewer_group_id: reviewer_group_4.id)

    populate_objects(ThreeSixty::SurveyReviewer, [
      [:survey_reviewer_2, survey_assessee: survey_assessee_1, name: "Reviewer1 Name", email: "reviewer_1@example.com", survey_reviewer_group: survey_reviewer_group_3, inviter: members(:f_admin)],
      [:survey_reviewer_3, survey_assessee: survey_assessee_1, name: "Reviewer2 Name", email: "reviewer_2@example.com", survey_reviewer_group: survey_reviewer_group_4, inviter: members(:f_admin)],
      [:survey_reviewer_4, survey_assessee: survey_assessee_1, name: "Reviewer3 Name", email: "reviewer_3@example.com", survey_reviewer_group: survey_reviewer_group_4, inviter: members(:f_admin)],
      [:survey_reviewer_5, survey_assessee: survey_assessee_1, name: "Reviewer4 Name", email: "reviewer_4@example.com", survey_reviewer_group: survey_reviewer_group_2, inviter: members(:f_admin)],
      [:survey_reviewer_7, survey_assessee: survey_assessee_2, name: "Reviewer5 Name", email: "reviewer_5@example.com", survey_reviewer_group: survey_reviewer_group_2, inviter: members(:f_admin)],
      [:survey_reviewer_8, survey_assessee: survey_assessee_2, name: "Reviewer6 Name", email: "reviewer_6@example.com", survey_reviewer_group: survey_reviewer_group_3, inviter: members(:f_admin)],
      [:survey_reviewer_9, survey_assessee: survey_assessee_2, name: "Reviewer7 Name", email: "reviewer_7@example.com", survey_reviewer_group: survey_reviewer_group_4, inviter: members(:f_student)],
      [:survey_reviewer_10, survey_assessee: survey_assessee_2, name: "Reviewer8 Name", email: "reviewer_8@example.com", survey_reviewer_group: survey_reviewer_group_4, inviter: members(:f_student)],
      [:survey_reviewer_13, survey_assessee: survey_assessee_3, name: "Reviewer9 Name", email: "reviewer_9@example.com", survey_reviewer_group: survey_reviewer_group_2, inviter: members(:f_mentor)],
      [:survey_reviewer_14, survey_assessee: survey_assessee_3, name: "Reviewer10 Name", email: "reviewer_10@example.com", survey_reviewer_group: survey_reviewer_group_4, inviter: members(:f_mentor)],
      [:survey_reviewer_15, survey_assessee: survey_assessee_3, name: "Reviewer11 Name", email: "reviewer_11@example.com", survey_reviewer_group: survey_reviewer_group_4, inviter: members(:f_admin)],
      [:survey_reviewer_12, survey_assessee: survey_assessee_3, name: "Reviewer12 Name", email: "reviewer_12@example.com", survey_reviewer_group: survey_reviewer_group_2, inviter: members(:f_admin)]
    ])
  end

  def populate_three_sixty_survey_answers
    s1 = three_sixty_surveys(:survey_1)
    survey_assessee_1 = s1.survey_assessees.find_by(member_id: members(:f_admin).id)
    survey_question_1 = s1.survey_questions.find_by(three_sixty_question_id: three_sixty_questions(:listening_1).id)
    survey_question_2 = s1.survey_questions.find_by(three_sixty_question_id: three_sixty_questions(:team_work_1).id)

    populate_objects(ThreeSixty::SurveyAnswer, [
      [:answer_1, survey_question: survey_question_1, survey_reviewer: survey_assessee_1.self_reviewer, answer_value: '5'],
      [:answer_2, survey_question: survey_question_2, survey_reviewer: survey_assessee_1.self_reviewer, answer_text: 'I am the best'],
      [:answer_3, survey_question: survey_question_1, survey_reviewer: three_sixty_survey_reviewers(:survey_reviewer_2), answer_value: '4'],
      [:answer_4, survey_question: survey_question_2, survey_reviewer: three_sixty_survey_reviewers(:survey_reviewer_2), answer_text: 'He is good'],
      [:answer_5, survey_question: survey_question_1, survey_reviewer: three_sixty_survey_reviewers(:survey_reviewer_3), answer_value: '4'],
      [:answer_6, survey_question: survey_question_2, survey_reviewer: three_sixty_survey_reviewers(:survey_reviewer_3), answer_text: 'He is good'],
      [:answer_7, survey_question: survey_question_1, survey_reviewer: three_sixty_survey_reviewers(:survey_reviewer_4), answer_value: '2'],
      [:answer_8, survey_question: survey_question_2, survey_reviewer: three_sixty_survey_reviewers(:survey_reviewer_4), answer_text: 'He is bad'],
      [:answer_9, survey_question: survey_question_1, survey_reviewer: three_sixty_survey_reviewers(:survey_reviewer_5), answer_value: '3'],
      [:answer_10, survey_question: survey_question_2, survey_reviewer: three_sixty_survey_reviewers(:survey_reviewer_5), answer_text: 'He is ok']
    ])
  end

  def populate_program_events
    # ES index won't be available at the time of fixture generation
    # Hence fetching user ids from SQL
    albers_all_users_view = programs(:albers).admin_views.find_by(default_view: AbstractView::DefaultType::ALL_USERS)
    nwen_all_users_view = programs(:nwen).admin_views.find_by(default_view: AbstractView::DefaultType::ALL_USERS)
    albers_user_ids = programs(:albers).admin_or_student_or_mentor_users.pluck(:id).uniq
    nwen_user_ids = programs(:nwen).admin_or_student_or_mentor_users.pluck(:id).uniq

    populate_objects(ProgramEvent, [
      [:birthday_party, title: "Birthday Party", location: "chennai, tamilnadu, india", start_time: Time.now + 1.month, status: ProgramEvent::Status::PUBLISHED, program: programs(:albers), admin_view: albers_all_users_view, admin_view_title: albers_all_users_view.title, user: users(:ram), time_zone: "Asia/Kolkata", email_notification: true, precomputed_user_ids: albers_user_ids],
      [:ror_meetup, title: "RoR Meetup", start_time: Time.now + 1.month, program: programs(:albers), admin_view: albers_all_users_view, admin_view_title: albers_all_users_view.title, user: users(:ram), time_zone: "Asia/Kolkata", precomputed_user_ids: albers_user_ids],
      [:entrepreneur_meetup, title: "Enterpreneur Meetup", location: "chennai, tamilnadu, india", start_time: Time.now + 1.month, status: ProgramEvent::Status::PUBLISHED, program: programs(:nwen), admin_view: nwen_all_users_view, admin_view_title: nwen_all_users_view.title, user: users(:nwen_admin), time_zone: "Asia/Kolkata", precomputed_user_ids: nwen_user_ids]
    ])
  end

  def populate_campaign_management_user_campaigns
    trigger_params = { 1 => [programs(:albers).admin_views.where(default_view: AbstractView::DefaultType::ALL_USERS).first.id] }

    populate_objects(CampaignManagement::UserCampaign, [
      [:active_campaign_1, title: "Campaign1 Name", program: programs(:albers), state: CampaignManagement::AbstractCampaign::STATE::ACTIVE, trigger_params: trigger_params, created_at: Time.new(2000), enabled_at: Time.new(2000)],
      [:active_campaign_2, title: "Campaign2 Name", program: programs(:albers), state: CampaignManagement::AbstractCampaign::STATE::ACTIVE, trigger_params: trigger_params, created_at: Time.new(2001), enabled_at: Time.new(2001)],
      [:disabled_campaign_1, title: "Campaign4 Name", program: programs(:albers), state: CampaignManagement::AbstractCampaign::STATE::STOPPED, trigger_params: trigger_params, created_at: Time.new(2000)],
      [:disabled_campaign_2, title: "Campaign5 Name", program: programs(:albers), state: CampaignManagement::AbstractCampaign::STATE::STOPPED, trigger_params: trigger_params, created_at: Time.new(2000)],
      [:disabled_campaign_3, title: "Disabled Campaign-3 Name", program: programs(:albers), state: CampaignManagement::AbstractCampaign::STATE::STOPPED, trigger_params: trigger_params, created_at: Time.new(2000)],
      [:disabled_campaign_4, title: "Disabled Campaign4 Name", program: programs(:albers), state: CampaignManagement::AbstractCampaign::STATE::STOPPED, trigger_params: trigger_params, created_at: Time.new(2000)]
    ])

    cm_campaigns(:active_campaign_1).update_attribute(:enabled_at, Time.new(2000))
  end

  def populate_campaign_management_user_campaign_messages
    campaign_1 = cm_campaigns(:active_campaign_1)
    campaign_2 = cm_campaigns(:active_campaign_2)
    campaign_3 = cm_campaigns(:disabled_campaign_1)

    email_template_1 = Mailer::Template.new(subject: "Campaign Message - Subject1", source: "Campaign Message - Content 1", uid: 1111, program_id: programs(:albers).id)
    email_template_1.belongs_to_cm = true
    email_template_2 = Mailer::Template.new(subject: "Campaign Message - Subject2", source: "Campaign Message - Content 2", uid: 1110, program_id: programs(:albers).id)
    email_template_2.belongs_to_cm = true
    email_template_3 = Mailer::Template.new(subject: "Campaign Message - Subject3", source: "Campaign Message - Content 3", uid: 1101, program_id: programs(:albers).id)
    email_template_3.belongs_to_cm = true
    email_template_4 = Mailer::Template.new(subject: "Campaign Message - Subject4", source: "Campaign Message - Content 4", uid: 1011, program_id: programs(:albers).id)
    email_template_4.belongs_to_cm = true
    email_template_7 = Mailer::Template.new(subject: "Campaign Message - Subject7", source: "Campaign Message - Content 7", uid: 1111, program_id: programs(:albers).id)
    email_template_7.belongs_to_cm = true
    email_template_8 = Mailer::Template.new(subject: "Campaign Message - Subject8", source: "Campaign Message - Content 8", uid: 1110, program_id: programs(:albers).id)
    email_template_8.belongs_to_cm = true
    email_template_5 = Mailer::Template.new(subject: "Campaign Message - Subject5", source: "Campaign Message - Content 5", uid: 1001, program_id: programs(:albers).id)
    email_template_5.belongs_to_cm = true
    email_template_6 = Mailer::Template.new(subject: "Campaign Message - Subject6", source: "Campaign Message - Content 6", uid: 1000, program_id: programs(:albers).id)
    email_template_6.belongs_to_cm = true


    populate_objects(CampaignManagement::UserCampaignMessage, [
      [:campaign_message_1, campaign: campaign_1, sender_id: users(:f_admin).id, duration: 0, user_jobs_created: 1, email_template: email_template_1],
      [:campaign_message_2, campaign: campaign_1, sender_id: users(:f_admin).id, duration: 5, user_jobs_created: 1, email_template: email_template_2],
      [:campaign_message_3, campaign: campaign_1, sender_id: users(:f_admin).id, duration: 10, user_jobs_created: 1, email_template: email_template_3],
      [:campaign_message_4, campaign: campaign_1, sender_id: users(:f_admin).id, duration: 15, user_jobs_created: 1, email_template: email_template_4],
      [:campaign_message_7, campaign: campaign_2, sender_id: users(:f_admin).id, duration: 4, email_template: email_template_7],
      [:campaign_message_8, campaign: campaign_2, sender_id: users(:f_admin).id, duration: 6, email_template: email_template_8],
      [:campaign_message_5, campaign: campaign_3, sender_id: users(:f_admin).id, duration: 0, email_template: email_template_5],
      [:campaign_message_6, campaign: campaign_3, sender_id: users(:f_admin).id, duration: 0, email_template: email_template_6]
    ])
  end

  def populate_admin_messages
    populate_objects(AdminMessage, [
      [:first_admin_message, sender: members(:f_student), program: programs(:albers), subject: "First admin message", content: "This is going to be very interesting"],
      [:second_admin_message, sender_name: "Test User", sender_email: "test@chronus.com", program: programs(:albers), subject: "Second admin message", content: "This is not going to be interesting"]
    ])

    populate_objects(AdminMessage, [
      [:third_admin_message, sender: members(:f_admin), receivers: [members(:f_student)], program: programs(:albers), subject: "Re - First admin message", content: "This is not going to be interesting", parent_id: messages(:first_admin_message).id],
      [:reply_to_offline_user, sender: members(:f_admin), receiver_name: "Test User", receiver_email: "test@chronus.com", program: programs(:albers), subject: "Re - Second admin message", content: "This is not going to be interesting", status: AbstractMessageReceiver::Status::READ, parent_id: messages(:second_admin_message).id],
      [:first_campaigns_admin_message, sender: members(:f_admin),program: programs(:albers), subject: "First campaign admin message",content: "This is going to be very interesting", campaign_message: cm_campaign_messages(:campaign_message_1), created_at: Time.new(2004,01,01), receiver_name: "Test User", receiver_email: "test@example.com", auto_email: true],
      [:first_campaigns_second_admin_message, sender: members(:f_admin),program: programs(:albers), subject: "First campaign second admin message",content: "This is going to be very interesting", campaign_message: cm_campaign_messages(:campaign_message_1), created_at: Time.new(2004,02,02), receiver_name: "Test User", receiver_email: "test@example.com", auto_email: true],
      [:first_campaigns_third_admin_message, sender: members(:f_admin),program: programs(:albers), subject: "First campaign third admin message",content: "This is going to be very interesting", campaign_message: cm_campaign_messages(:campaign_message_1), created_at: Time.new(2004,01,03), receiver_name: "Test User", receiver_email: "test@example.com", auto_email: true],
      [:second_campaigns_admin_message, sender: members(:f_admin),program: programs(:albers), subject: "Second campaign admin message",content: "This is going to be very interesting", campaign_message: cm_campaign_messages(:campaign_message_2), created_at: Time.new(2004,01,01), receiver_name: "Test User", receiver_email: "test@example.com", auto_email: true],
      [:third_campaigns_admin_message, sender: members(:f_admin),program: programs(:albers), subject: "Third campaign admin message",content: "This is going to be very interesting", campaign_message: cm_campaign_messages(:campaign_message_3), created_at: Time.new(2003,12,30), receiver_name: "Test User", receiver_email: "test@example.com", auto_email: true],
      [:seventh_campaigns_admin_message, sender: members(:f_admin),program: programs(:albers), subject: "seventh campaign admin message",content: "This is going to be very interesting", campaign_message: cm_campaign_messages(:campaign_message_7), created_at: Time.new(2004,01,01), receiver_name: "Test User", receiver_email: "test@example.com", auto_email: true],
      [:eigth_campaigns_admin_message, sender: members(:f_admin),program: programs(:albers), subject: "Eigth campaign admin message",content: "This is going to be very interesting", campaign_message: cm_campaign_messages(:campaign_message_8), created_at: Time.new(2004,05,30), receiver_name: "Test User", receiver_email: "test@example.com", auto_email: true]
    ], skip_message: true)

    messages(:first_admin_message).mark_as_read!(members(:f_admin))
    messages(:second_admin_message).mark_as_read!(members(:f_admin))
    messages(:third_admin_message).mark_as_read!(members(:f_student))
  end

  def populate_program_invitations
    populate_objects(ProgramInvitation, [
      [:mentor, code: "A1A1A1A1", program: programs(:albers), sent_to: "mentor@chronus.com", user: users(:f_admin), expires_on: 28.days.from_now, role_names: [:mentor], role_type: ProgramInvitation::RoleType::ASSIGN_ROLE],
      [:student, code: "B2B2B2B2", program: programs(:albers), sent_to: "mentee@chronus.com", user: users(:f_student), expires_on: 20.days.from_now, role_names: [:student], role_type: ProgramInvitation::RoleType::ASSIGN_ROLE]
    ])
  end

  def populate_campaign_management_user_campaign_statuses
    populate_objects(CampaignManagement::UserCampaignStatus, [
      [:admin_active_campaign_status, campaign: cm_campaigns(:active_campaign_1), user: users(:f_admin), started_at: Time.now],
      [:student_active_campaign_status, campaign: cm_campaigns(:active_campaign_1), user: users(:f_student), started_at: Time.now],
      [:admin_disabled_campaign_status, campaign: cm_campaigns(:disabled_campaign_1), user: users(:f_admin), started_at: Time.now],
      [:student_disabled_campaign_status, campaign: cm_campaigns(:disabled_campaign_1), user: users(:f_student), started_at: Time.now]
    ])
  end

  def populate_campaign_management_user_campaign_message_jobs
    populate_objects(CampaignManagement::UserCampaignMessageJob, [
      [:pending_active_campaign_message_1_job_for_admin, campaign_message: cm_campaign_messages(:campaign_message_1), run_at: DateTime.parse("20140202"), user: users(:f_admin)],
      [:pending_active_campaign_message_1_job_for_student, campaign_message: cm_campaign_messages(:campaign_message_1), run_at: DateTime.parse("20140206"), user: users(:f_student)],
      [:pending_active_campaign_message_2_job_for_admin, campaign_message: cm_campaign_messages(:campaign_message_2), run_at: DateTime.parse("20140203"), user: users(:f_admin)],
      [:pending_active_campaign_message_2_job_for_student, campaign_message: cm_campaign_messages(:campaign_message_2), run_at: DateTime.parse("20140207"), user: users(:f_student)],
      [:pending_active_campaign_message_3_job_for_admin, campaign_message: cm_campaign_messages(:campaign_message_3), run_at: DateTime.parse("20140204"), user: users(:f_admin)],
      [:pending_active_campaign_message_3_job_for_student, campaign_message: cm_campaign_messages(:campaign_message_3), run_at: DateTime.parse("20140208"), user: users(:f_student)],
      [:pending_active_campaign_message_4_job_for_admin, campaign_message: cm_campaign_messages(:campaign_message_4), run_at: DateTime.parse("20140205"), user: users(:f_admin)],
      [:pending_active_campaign_message_4_job_for_student, campaign_message: cm_campaign_messages(:campaign_message_4), run_at: DateTime.parse("20140209"), user: users(:f_student)],
      [:pending_disabled_campaign_message_5_job_for_admin, campaign_message: cm_campaign_messages(:campaign_message_5), run_at: DateTime.parse("20140304"), user: users(:f_admin)],
      [:pending_disabled_campaign_message_5_job_for_student, campaign_message: cm_campaign_messages(:campaign_message_5), run_at: DateTime.parse("20140308"), user: users(:f_student)],
      [:pending_disabled_campaign_message_6_job_for_admin, campaign_message: cm_campaign_messages(:campaign_message_6), run_at: DateTime.parse("20140305"), user: users(:f_admin)],
      [:pending_disabled_campaign_message_6_job_for_student, campaign_message: cm_campaign_messages(:campaign_message_6), run_at: DateTime.parse("20140309"), user: users(:f_student)]
    ])
  end

  def populate_campaign_management_campaign_emails
    campaign_message_1, campaign_message_2 = programs(:albers).program_invitation_campaign.campaign_messages.limit(2)

    populate_objects(CampaignManagement::CampaignEmail, [
      [:first_program_invitation_campaign_messages_first_email, subject: "First program invitation campaign message's email subject", source: "First program invitation campaign message's email source", campaign_message: campaign_message_1, created_at: Time.new(2004,01,01), abstract_object_id: program_invitations(:mentor).id],
      [:first_program_invitation_campaign_messages_second_email, subject: "Second program invitation campaign message's email subject", source: "Second program invitation campaign message's email source", campaign_message: campaign_message_2, created_at: Time.new(2004,01,25), abstract_object_id: program_invitations(:mentor).id],
      [:first_program_invitation_campaign_messages_third_email, subject: "Third program invitation campaign message's email subject", source: "Third program invitation campaign message's email source", campaign_message: campaign_message_2, created_at: Time.new(2004,01,2), abstract_object_id: program_invitations(:student).id]
    ])
  end

  def populate_campaign_management_email_event_logs
    populate_objects(CampaignManagement::EmailEventLog, [
      [:cm_email_event_opened_1, event_type: CampaignManagement::EmailEventLog::Type::OPENED, message_type: CampaignManagement::EmailEventLog::MessageType::ADMIN_MESSAGE, message_id: messages(:first_campaigns_admin_message).id, timestamp: Time.new(2004,01,2)],
      [:cm_email_event_opened_2, event_type: CampaignManagement::EmailEventLog::Type::OPENED, message_type: CampaignManagement::EmailEventLog::MessageType::ADMIN_MESSAGE, message_id: messages(:first_campaigns_admin_message).id, timestamp: Time.new(2004,01,3)],
      [:cm_email_event_opened_3, event_type: CampaignManagement::EmailEventLog::Type::OPENED, message_type: CampaignManagement::EmailEventLog::MessageType::ADMIN_MESSAGE, message_id: messages(:seventh_campaigns_admin_message).id, timestamp: Time.new(2005,01,1)],
      [:cm_email_event_clicked_1, event_type: CampaignManagement::EmailEventLog::Type::CLICKED, message_type: CampaignManagement::EmailEventLog::MessageType::ADMIN_MESSAGE, message_id: messages(:first_campaigns_admin_message).id, timestamp: Time.new(2004,01,3)],
      [:cm_email_event_clicked_2, event_type: CampaignManagement::EmailEventLog::Type::CLICKED, message_type: CampaignManagement::EmailEventLog::MessageType::ADMIN_MESSAGE, message_id: messages(:second_campaigns_admin_message).id, timestamp: Time.new(2004,01,4)],
      [:cm_email_event_clicked_3, event_type: CampaignManagement::EmailEventLog::Type::CLICKED, message_type: CampaignManagement::EmailEventLog::MessageType::ADMIN_MESSAGE, message_id: messages(:eigth_campaigns_admin_message).id, timestamp: Time.new(2005,01,2)],
      [:cm_email_event_dropped_1, event_type: CampaignManagement::EmailEventLog::Type::DROPPED, message_type: CampaignManagement::EmailEventLog::MessageType::ADMIN_MESSAGE, message_id: messages(:first_campaigns_admin_message).id, timestamp: Time.new(2004,01,5)],
      [:cm_email_event_dropped_2, event_type: CampaignManagement::EmailEventLog::Type::DROPPED, message_type: CampaignManagement::EmailEventLog::MessageType::ADMIN_MESSAGE, message_id: messages(:first_campaigns_admin_message).id, timestamp: Time.new(2004,01,6)],
      [:cm_email_event_bounced_1, event_type: CampaignManagement::EmailEventLog::Type::BOUNCED, message_type: CampaignManagement::EmailEventLog::MessageType::ADMIN_MESSAGE, message_id: messages(:first_campaigns_admin_message).id, timestamp: Time.new(2004,01,7)],
      [:cm_email_event_bounced_2, event_type: CampaignManagement::EmailEventLog::Type::BOUNCED, message_type: CampaignManagement::EmailEventLog::MessageType::ADMIN_MESSAGE, message_id: messages(:third_campaigns_admin_message).id, timestamp: Time.new(2004,01,8)],
      [:cm_email_event_opened_4, event_type: CampaignManagement::EmailEventLog::Type::OPENED, message_type: CampaignManagement::EmailEventLog::MessageType::ADMIN_MESSAGE, message_id: messages(:first_campaigns_second_admin_message).id, timestamp: Time.new(2004,02,3)],
      [:cm_email_event_opened_for_pi_message_1, event_type: CampaignManagement::EmailEventLog::Type::OPENED, message_type: CampaignManagement::EmailEventLog::MessageType::PROGRAM_INVITATION_MESSAGE, message_id: cm_campaign_emails(:first_program_invitation_campaign_messages_first_email).id, timestamp: Time.new(2004,01,2)],
      [:cm_email_event_clicked_for_pi_message_1, event_type: CampaignManagement::EmailEventLog::Type::CLICKED, message_type: CampaignManagement::EmailEventLog::MessageType::PROGRAM_INVITATION_MESSAGE, message_id: cm_campaign_emails(:first_program_invitation_campaign_messages_first_email).id, timestamp: Time.new(2004,01,4)]
    ])
  end

  def populate_report_sections
    populate_objects(Report::Section, [
      [:report_section_1, program: programs(:albers), title: "Section1 Title", description: "Section1 Description"]
    ])
  end

  def populate_report_metrics
    populate_objects(Report::Metric, [
      [:report_metric_1, section: report_sections(:report_section_1), title: "Metric1 Title", description: "Metric1 Description", abstract_view: programs(:albers).abstract_views.first]
    ])
  end

  def populate_report_alerts
    populate_objects(Report::Alert, [
      [:report_alert_1, metric: report_metrics(:report_metric_1), description: "Alert1 Description", filter_params: "", operator: Report::Alert::OperatorType::LESS_THAN, target: 10]
    ])
  end

  def populate_group_checkins
    i = 0
    attrs_array = []
    Meeting.all.each do |meeting|
      meeting.occurrences.each do |occurrence|
        meeting.member_meetings.each do |member_meeting|
          program = meeting.program
          group = meeting.group
          user = member_meeting.member.user_in_program(program.id)
          if group.present? && group.has_mentor?(user) && (meeting.schedule.duration % (60 * 15) == 0)
            options = {
              user_id: user.id,
              checkin_ref_obj: member_meeting,
              date: occurrence,
              program: program,
              duration: meeting.schedule.duration / 60,
              title: meeting.topic,
              group: meeting.group
            }
            i = i + 1
            attrs_array << ["GroupCheckin#{i}", options]
          end
        end
      end
    end
    populate_objects(GroupCheckin, attrs_array)
  end

  def populate_abstract_bulk_matches
    program = programs(:albers)
    mentor_view = program.admin_views.default.find_by(default_view: AbstractView::DefaultType::MENTORS)
    mentee_view = program.admin_views.default.find_by(default_view: AbstractView::DefaultType::MENTEES)
    never_connected_mentee_view = program.admin_views.default.find_by(default_view: AbstractView::DefaultType::NEVER_CONNECTED_MENTEES)

    populate_objects(BulkMatch, [
      [:bulk_match_1, program_id: program.id, mentor_view_id: mentor_view.id, mentee_view_id: mentee_view.id, max_pickable_slots: 2, default: 1]
    ])

    populate_objects(BulkRecommendation, [
      [:bulk_recommendation_1, program_id: program.id, mentor_view_id: mentor_view.id, mentee_view_id: never_connected_mentee_view.id, max_pickable_slots: 2, max_suggestion_count: 2, request_notes: false, default: 0]
    ])

    populate_objects(BulkMatch, [
      [:bulk_match_2, program_id: program.id, mentor_view_id: mentor_view.id, mentee_view_id: mentee_view.id, max_pickable_slots: 2, default: 0, orientation_type: BulkMatch::OrientationType::MENTOR_TO_MENTEE]
    ])
  end

  def populate_mentor_recommendations
    populate_objects(MentorRecommendation, [
      [:mentor_recommendation_1, program_id: programs(:albers).id, sender_id: users(:f_admin).id, receiver_id: users(:rahim).id, status: MentorRecommendation::Status::PUBLISHED, published_at: Time.now]
    ])
  end

  def populate_recommendation_preferences
    mentor_recommendation = mentor_recommendations(:mentor_recommendation_1)

    populate_objects(RecommendationPreference, [
      [:recommendation_preference_1, user_id: users(:ram).id, note: "Test note 1 from the admin", position: 1, mentor_recommendation_id: mentor_recommendation.id],
      [:recommendation_preference_2, user_id: users(:robert).id, note: "Test note 2 from the admin", position:2, mentor_recommendation_id: mentor_recommendation.id]
    ])
  end

  def populate_activity_logs
    populate_objects(ActivityLog, [
      [:activity_log_1, user: users(:f_student), activity: ActivityLog::Activity::PROGRAM_VISIT, role_names: users(:f_student).role_names, program: users(:f_student).program]
    ])
  end

  def populate_private_meeting_notes
    populate_objects(PrivateMeetingNote, [
      [:meeting_mentor_student_1, member_meeting: meetings(:f_mentor_mkr_student).member_meetings.first, text: "I did the assignment yesterday; it was tough"],
      [:meeting_mentor_student_2, member_meeting: meetings(:f_mentor_mkr_student).member_meetings.second, text: "My second note."],
      [:meeting_not_req_mentor_student_2, member_meeting: meetings(:student_2_not_req_mentor).member_meetings.first, text: "My third note."],
      [:meeting_not_req_mentor_student_1, member_meeting: meetings(:student_2_not_req_mentor).member_meetings.second, text: "mentor first note."],
      [:meeting_mentor_student_4, member_meeting: meetings(:f_mentor_mkr_student).member_meetings.first, text: "mentor second note."],
      [:meeting_mentor_student_3, member_meeting: meetings(:f_mentor_mkr_student).member_meetings.second, text: "second group first student note."],
      [:meeting_not_req_mentor_student_3, member_meeting: meetings(:student_2_not_req_mentor).member_meetings.first, text: "third group mentor first note."],
      [:meeting_mentor_student_5, member_meeting: meetings(:f_mentor_mkr_student).member_meetings.first, text: "third group mentor second note."]
    ])
  end

  def populate_viewed_objects
    populate_objects(ViewedObject, [
      [:viewed_object_1, ref_obj: announcements(:assemble), user: users(:f_mentor)],
      [:viewed_object_2, ref_obj: announcements(:expired_announcement), user: users(:f_mentor)],
      [:viewed_object_3, ref_obj: announcements(:big_announcement), user: users(:f_mentor)],
      [:viewed_object_4, ref_obj: announcements(:assemble), user: users(:f_student)],
      [:viewed_object_5, ref_obj: announcements(:expired_announcement), user: users(:f_student)],
      [:viewed_object_6, ref_obj: announcements(:big_announcement), user: users(:f_student)],
      [:viewed_object_7, ref_obj: announcements(:assemble), user: users(:f_mentor_student)],
      [:viewed_object_8, ref_obj: announcements(:expired_announcement), user: users(:f_mentor_student)],
      [:viewed_object_9, ref_obj: announcements(:big_announcement), user: users(:f_mentor_student)],
      [:viewed_object_10, ref_obj: announcements(:assemble), user: users(:f_user)],
      [:viewed_object_11, ref_obj: announcements(:expired_announcement), user: users(:f_user)],
      [:viewed_object_12, ref_obj: announcements(:big_announcement), user: users(:f_user)],
      [:viewed_object_13, ref_obj: announcements(:assemble), user: users(:f_admin)],
      [:viewed_object_14, ref_obj: announcements(:expired_announcement), user: users(:f_admin)],
      [:viewed_object_15, ref_obj: announcements(:big_announcement), user: users(:f_admin)],
      [:viewed_object_16, ref_obj: announcements(:assemble), user: users(:ram)],
      [:viewed_object_17, ref_obj: announcements(:expired_announcement), user: users(:ram)],
      [:viewed_object_18, ref_obj: announcements(:big_announcement), user: users(:ram)],
      [:viewed_object_19, ref_obj: announcements(:assemble), user: users(:rahim)],
      [:viewed_object_20, ref_obj: announcements(:expired_announcement), user: users(:rahim)],
      [:viewed_object_21, ref_obj: announcements(:big_announcement), user: users(:rahim)],
      [:viewed_object_22, ref_obj: announcements(:assemble), user: users(:robert)],
      [:viewed_object_23, ref_obj: announcements(:expired_announcement), user: users(:robert)],
      [:viewed_object_24, ref_obj: announcements(:big_announcement), user: users(:robert)],
      [:viewed_object_25, ref_obj: announcements(:assemble), user: users(:arun_albers)],
      [:viewed_object_26, ref_obj: announcements(:expired_announcement), user: users(:arun_albers)],
      [:viewed_object_27, ref_obj: announcements(:big_announcement), user: users(:arun_albers)],
      [:viewed_object_28, ref_obj: announcements(:assemble), user: users(:requestable_mentor)],
      [:viewed_object_29, ref_obj: announcements(:expired_announcement), user: users(:requestable_mentor)],
      [:viewed_object_30, ref_obj: announcements(:big_announcement), user: users(:requestable_mentor)],
      [:viewed_object_31, ref_obj: announcements(:assemble), user: users(:mkr_student)],
      [:viewed_object_32, ref_obj: announcements(:expired_announcement), user: users(:mkr_student)],
      [:viewed_object_33, ref_obj: announcements(:big_announcement), user: users(:mkr_student)],
      [:viewed_object_34, ref_obj: announcements(:assemble), user: users(:not_requestable_mentor)],
      [:viewed_object_35, ref_obj: announcements(:big_announcement), user: users(:drafted_group_user)]
      
    ] +
      15.times.map { |i| ["viewed_object_2_#{i}", ref_obj: announcements(:big_announcement), user: users("student_#{i}")] } +
      15.times.map { |i| ["viewed_object_3_#{i}", ref_obj: announcements(:assemble), user: users("student_#{i}")] } +
      15.times.map { |i| ["viewed_object_4_#{i}", ref_obj: announcements(:expired_announcement), user: users("student_#{i}")] } +
      15.times.map { |i| ["viewed_object_5_#{i}", ref_obj: announcements(:big_announcement), user: users("mentor_#{i}")] } +
      15.times.map { |i| ["viewed_object_6_#{i}", ref_obj: announcements(:expired_announcement), user: users("mentor_#{i}")] } + 
      15.times.map { |i| ["viewed_object_7_#{i}", ref_obj: announcements(:assemble), user: users("mentor_#{i}")] } 

    )
  end

  def populate_favorite_preferences
    populate_objects(FavoritePreference, [
      [:favorite_1, preference_marker_user: users(:f_student), preference_marked_user: users(:f_mentor)],
      [:favorite_2, preference_marker_user: users(:rahim), preference_marked_user: users(:ram)],
      [:favorite_3, preference_marker_user: users(:f_student), preference_marked_user: users(:robert)]
    ])
  end

  def populate_ignore_preferences
    populate_objects(IgnorePreference, [
      [:ignore_1, preference_marker_user: users(:f_student), preference_marked_user: users(:f_mentor)],
      [:ignore_2, preference_marker_user: users(:rahim), preference_marked_user: users(:robert)],
      [:ignore_3, preference_marker_user: users(:f_student), preference_marked_user: users(:ram)]
    ])
  end

  def populate_admin_view_user_caches
    populate_objects(AdminViewUserCache, [
      [:admin_view_user_cache_1, admin_view: programs(:albers).admin_views.first, user_ids: programs(:albers).users.pluck(:id).join(",")],
      [:admin_view_user_cache_2, admin_view: programs(:albers).admin_views.default.find_by(default_view: AbstractView::DefaultType::MENTORS), user_ids: programs(:albers).mentor_users.pluck(:id).join(",")]
    ])
  end

  def populate_login_tokens
    populate_objects(LoginToken, [
      [:login_token_1, member: members(:f_mentor)],
      [:login_token_2, member: members(:f_student)],
      [:login_token_3, member: members(:f_mentor)]
    ])
  end

  def populate_user_search_activities
    populate_objects(UserSearchActivity, [
      [:user_search_activity_1, user: users(:mkr_student), program: programs(:albers), profile_question: profile_questions(:string_q), profile_question_text: "What is your name", search_text: "sample answer text", locale: "de", session_id: "1ab234er5fdjc24123mcn"],
      [:user_search_activity_2, user: users(:f_student), program: programs(:albers), profile_question: profile_questions(:student_multi_choice_q), profile_question_text: "What is your hobby", question_choice: question_choices(:student_multi_choice_q_1), search_text: "sample choice text", locale: "es", session_id: "f8wc6kler5fdjc24123mcn"],
      [:user_search_activity_3, user: users(:mkr_student), program: programs(:albers), search_text: "sample search text", locale: "de", session_id: "1234nbjkb56lkkjmwc8ak3g"]
    ])
  end

  def populate_explicit_user_preferences
    location_role_question = users(:drafted_group_user).roles.first.role_questions.select{|role_que| role_que.profile_question.location?}.first
    populate_objects(ExplicitUserPreference, [
      [:explicit_user_preference_1, user_id: users(:arun_albers).id, role_question: role_questions(:student_single_choice_role_q), question_choices: [question_choices(:student_single_choice_q_2)], preference_weight: 5],
      [:explicit_user_preference_2, user_id: users(:arun_albers).id, role_question: role_questions(:single_choice_role_q), question_choices: [question_choices(:single_choice_q_1), question_choices(:single_choice_q_2)]],
      [:explicit_user_preference_3, user_id: users(:arun_albers).id, role_question: role_questions(:multi_choice_role_q), question_choices: [question_choices(:multi_choice_q_1), question_choices(:multi_choice_q_2)]],
      [:explicit_user_preference_4, user_id: users(:drafted_group_user).id, role_question: location_role_question, preference_string: "Chennai,Tamilnadu,India"]
    ])
  end

  def update_groups
    say_updating Group.name

    groups(:mygroup).update_attribute(:last_activity_at, 20.minutes.ago)
    groups(:group_2).update_attribute(:last_activity_at, 2.hours.ago)
    groups(:group_3).update_attribute(:last_activity_at, 2.minutes.ago)
    groups(:old_group).update_attribute(:last_activity_at, 35.days.ago)

    groups(:mygroup).update_attribute(:last_member_activity_at, 20.minutes.ago)
    groups(:group_2).update_attribute(:last_member_activity_at, 2.minutes.ago)
    groups(:group_3).update_attribute(:last_member_activity_at, 2.hours.ago)
    groups(:old_group).update_attribute(:last_member_activity_at, 40.days.ago)

    groups(:mygroup).update_attribute(:created_at, 2.hours.ago)
    groups(:group_2).update_attribute(:created_at, 20.minutes.ago)
    groups(:group_3).update_attribute(:created_at, 2.minutes.ago)
    groups(:old_group).update_attribute(:created_at, 45.days.ago)

    groups(:mygroup).update_attribute(:published_at, 2.hours.ago)
    groups(:group_2).update_attribute(:published_at, 20.minutes.ago)
    groups(:group_3).update_attribute(:published_at, 2.minutes.ago)
    groups(:old_group).update_attribute(:published_at, 45.days.ago)
  end

  def update_calendar_settings
    say_updating CalendarSetting.name
    calendar_setting = programs(:albers).calendar_setting
    calendar_setting.update_attributes(max_pending_meeting_requests_for_mentee: 2, allow_mentor_to_describe_meeting_preference: true)
  end

  def update_security_settings
    say_updating SecuritySetting.name
    programs(:org_primary).security_setting.update_attributes(linkedin_token: "75jo4at0q18n71", linkedin_secret: "VEebFFqxekoFuzkc")
    programs(:org_anna_univ).security_setting.update_attributes(linkedin_token: "token2", linkedin_secret: "secret2")
  end

  def update_customized_terms
    say_updating CustomizedTerm.name
    Role.where(name: RoleConstants::STUDENT_NAME).each do |student_role|
      student_role.customized_term.update_attributes(term: "Student", pluralized_term: "Students", articleized_term_downcase: "a student", term_downcase: "student", pluralized_term_downcase: "students", articleized_term: "a Student")
    end
  end

  def apply_wcag_theme
    AbstractProgram.update_all(theme_id: themes(:wcag_theme).id)
  end

  ##############################################################################
  # BASIC CREATION HELPERS
  ##############################################################################

  def create_record(klass, record_name, attrs = {})
    protected_attrs = attrs.delete(:protected_attrs)
    attrs = reorder_role_params(attrs)

    object = klass.new(attrs)
    unless protected_attrs.nil?
      protected_attrs.each do |field, value|
        object.send("#{field}=", value)
      end
    end
    object.save!
    add_record(record_name, object)
  end

  def populate_objects(klass, attrs_array, options = {})
    method_name = "create_#{klass.name.underscore.parameterize(separator: "_")}"
    method_name = "create_record" unless self.method_exists?(method_name)

    say_populating klass.name unless options[:skip_message]
    attrs_array.each do |attrs|
      if method_name == "create_record"
        self.send(method_name, klass, *attrs)
      else
        self.send(method_name, *attrs)
      end
    end
  end

  def create_organization(record_name, attrs = {})
    attrs.merge!(
      created_at: (30..60).to_a.sample.days.ago,
      account_name: record_name.to_s + "_account"
    )
    organization = create_record(Organization, record_name, attrs)

    [
      FeatureName::ANSWERS,
      FeatureName::FORUMS,
      FeatureName::ARTICLES,
      FeatureName::SKYPE_INTERACTION,
      FeatureName::PROFILE_COMPLETION_ALERT,
      FeatureName::MANAGER
    ].each { |feature_name| organization.enable_feature(feature_name) }
    organization.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, false)
    organization.enable_feature(FeatureName::EXPLICIT_USER_PREFERENCES, false)

    unless record_name == :org_nch
      organization.customized_terms.find_by(term_type: CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).update_attributes(term: "Mentoring Connection", term_downcase: "mentoring connection", pluralized_term: "Mentoring Connections", pluralized_term_downcase: "mentoring connections", articleized_term: "a Mentoring Connection", articleized_term_downcase: "a mentoring connection")
      DataPopulator.populate_default_contents(organization)
    end
    organization
  end

  def create_program(record_name, attrs = {})
    attrs.merge!(created_at: attrs[:organization].created_at)
    attrs.reverse_merge!(engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING)
    program = create_record(Program, record_name, attrs)

    unless record_name == :nch_mentoring
      program.customized_terms.find_by(term_type: CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).update_attributes(term: "Mentoring Connection", term_downcase: "mentoring connection", pluralized_term: "Mentoring Connections", pluralized_term_downcase: "mentoring connections", articleized_term: "a Mentoring Connection", articleized_term_downcase: "a mentoring connection")
      DataPopulator.populate_default_contents(program)
    end
  end

  def create_member(record_name, attrs= {})
    # accept T&C for all members
    create_record(Member, record_name, ( { terms_and_conditions_accepted: Time.current }.merge(attrs)).merge(password: 'monkey', password_confirmation: 'monkey', state: (attrs[:state] || Member::Status::ACTIVE)))
  end

  def create_education(record_name, options = {})
    member = options.delete(:member)
    question = options.delete(:question)
    answer = member.answer_for(question) || member.profile_answers.build( profile_question: question)
    education = answer.educations.build(options)
    education.profile_answer = answer
    answer.save!
    add_record(record_name, education)
  end

  def create_experience(record_name, options = {})
    member = options.delete(:member)
    question = options.delete(:question)
    answer = member.answer_for(question) || member.profile_answers.build( profile_question: question)
    experience = answer.experiences.build(options)
    experience.profile_answer = answer
    answer.save!
    add_record(record_name, experience)
  end

  def create_publication(record_name, options = {})
    member = options.delete(:member)
    question = options.delete(:question)
    answer = member.answer_for(question) || member.profile_answers.build( profile_question: question)
    publication = answer.publications.build(options)
    publication.profile_answer = answer
    answer.save!
    add_record(record_name, publication)
  end

  def create_manager(record_name, options = {})
    managee = options.delete(:managee)
    question = options.delete(:question)
    answer = managee.answer_for(question) || managee.profile_answers.build( profile_question: question)
    manager = answer.build_manager(options)
    manager.profile_answer = answer
    manager.save!
    add_record(record_name, manager)
  end

  def create_date_answer(record_name, options = {})
    member = options.delete(:member)
    question = options.delete(:question)
    answer = member.answer_for(question) || member.profile_answers.build(profile_question: question, answer_text: options[:answer_text])
    answer.save_answer!(question, answer.answer_text)
    add_record(record_name, answer.date_answer)
  end

  def create_membership_request(member, role, i)
    program = programs(:albers)
    attrs = {
      first_name: member.first_name,
      last_name: member.last_name,
      email: member.email,
      roles: [role],
      program: program
    }
    membership_request = MembershipRequest.create_from_params(attrs.delete(:program), attrs, member)
    membership_request.response_text = attrs[:response_text] || "Sorry" if membership_request.rejected?
    membership_request.admin = (attrs[:admin] || users(:f_admin)) unless membership_request.pending?
    membership_request.save!

    add_record("membership_request_#{i}", membership_request)
  end

  def create_login_token(record_name, attrs = {})
    create_record(LoginToken, record_name, attrs)
  end

  def create_user_search_activity(record_name, attrs = {})
    create_record(UserSearchActivity, record_name, attrs)
  end

  def create_scrap(record_name, attrs = {})
    group_or_meeting = attrs[:ref_obj]
    attrs[:subject] = "Subject"
    attrs[:program] = program = programs(:albers)

    # Receivers - Other members of the group or meeting
    participant_users = group_or_meeting.is_a?(Group) ? group_or_meeting.members : group_or_meeting.participant_users
    sender_user = attrs[:sender].user_in_program(program)
    receiver_users = participant_users - [sender_user]
    attrs[:receivers] = []
    receiver_users.each { |receiver_user| attrs[:receivers] << receiver_user.member }
    create_record(Scrap, record_name, attrs)
  end

  def create_announcement(record_name, attrs = {})
    create_record(Announcement, record_name, attrs.merge(email_notification: UserConstants::DigestV2Setting::ProgramUpdates::DONT_SEND.to_s))
  end

  def create_article(record_name, attrs = {})
    attrs[:article_content] ||= create_record(ArticleContent ,record_name, attrs.delete(:content))
    create_record(Article, record_name, attrs)
  end

  def create_comment(record_name, attrs = {})
    article = attrs.delete(:article)
    program = attrs.delete(:program)
    attrs[:publication] ||= article.get_publication(program)
    create_record(Comment, record_name, attrs)
  end

  def create_admin_message(record_name, options = {})
    if options[:receivers]
      receivers = options.delete(:receivers)
      admin_message = AdminMessage.new({program: programs(:albers), subject: "This is subject", content: "This is content"}.merge(options))

      receivers.each do |rc|
        admin_message.message_receivers.build(
          member: rc, message: admin_message)
      end
    else
      msg_recevier_attrs = {
        member: options.delete(:receiver),
        email: options.delete(:receiver_email),
        name: options.delete(:receiver_name),
        status: options.delete(:status) || AbstractMessageReceiver::Status::UNREAD}
      admin_message = AdminMessage.new({program: programs(:albers), subject: "This is subject", content: "This is content"}.merge(options))
      admin_message.message_receivers.build(msg_recevier_attrs)

      admin_message.message_receivers.each do |msg_rec|
        msg_rec.message = admin_message
      end
    end

    admin_message.save!
    add_record(record_name, admin_message)
  end

  def create_three_sixty_survey(record_name, attrs = {})
    questions = attrs.delete(:questions)
    assessees = attrs.delete(:assessees)
    reviewer_groups = attrs.delete(:reviewer_groups)

    survey = create_record(ThreeSixty::Survey, record_name, attrs)
    questions.each { |question| survey.add_question(question) }
    survey.assessees = assessees
    survey.reviewer_groups += reviewer_groups
    survey.save!
  end

  def create_subscription(forum, subscribers)
    return if subscribers.blank?

    subscribers.each do |subscriber|
      forum.subscribe_user(users(subscriber))
    end
  end

  ##############################################################################
  # UTILITY METHODS
  ##############################################################################

  def S3Helper.transfer(source_path, prefix, dest_bucket, options = {})
    return 'https://s3.amazonaws.com/chronus-mentor-assets/global-assets/files/20140321091645_sample_event.ics'
  end

  def initialize_proposed_slot_for_meeting(time)
    date = time.strftime("%B %d, %Y")
    start_time = time.strftime("%I:%M %P")
    end_time = (time + 30.minutes).strftime("%I:%M %P")
    proposed_slot = OpenStruct.new(location: "Hyderabad", date: date)
    proposed_slot.start_time, proposed_slot.end_time = MentoringSlot.fetch_start_and_end_time(date, start_time, end_time)
    return proposed_slot
  end

  def demo_file(*path)
    file_name = path.pop
    dirs = path.join("/") + "/" unless path.empty?;
    Rails.root.to_s + "/demo/#{dirs}#{file_name}"
  end

  def reorder_role_params(attrs)
    map = ActiveSupport::OrderedHash.new
    program = attrs.delete(:program)
    map[:program] = program if program.present?
    attrs.each { |a, b| map[a] = b }
    map
  end
end
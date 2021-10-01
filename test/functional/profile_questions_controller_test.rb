require_relative './../test_helper.rb'

class ProfileQuestionsControllerTest < ActionController::TestCase
  def test_only_admin_can_access
    current_member_is :f_mentor

    assert_permission_denied do
      get :index
    end
  end

  def test_new_question
    current_member_is :f_admin

    get :new, xhr: true, params: { :section_id => sections(:section_albers).id}
    assert assigns(:profile_question).new_record?
    assert_equal programs(:org_primary), assigns(:profile_question).organization
    assert_equal sections(:section_albers), assigns(:profile_question).section
  end

  def test_new_question_when_manager_disabled
    current_member_is :f_admin
    programs(:org_primary).enable_feature(FeatureName::MANAGER, false)

    get :new, xhr: true, params: { :section_id => sections(:section_albers).id}
    assert_response :success

    # as same edit form is used here
    assert_match /form.*id.*edit_profile_question/, response.body
    assert_match /label.*Field Type/, response.body
    assert_match /select.*name.*profile_question[question_type]/, response.body
    assert_no_match(/option.*Manager/, response.body)
  end

  def test_create_success
    current_member_is :f_admin
    assert_false programs(:albers).standalone?
    student_role =programs(:albers).get_role(RoleConstants::STUDENT_NAME)
    conditional_question = profile_questions(:multi_choice_q)
    assert_false conditional_question.has_dependent_questions?

    assert_difference 'programs(:org_primary).profile_questions.count' do
      post :create, xhr: true, params: { profile_question: {
        question_text: "About me",
        question_type: ProfileQuestion::Type::SINGLE_CHOICE,
        existing_question_choices_attributes: [{"101" => {"text" => "good"}, "102" => {"text" => "bad"}, "103" => {"text" => "ugly"}}],
        question_choices: {"new_order" => "103,101,102"},
        allow_other_option: true,
        conditional_question_id: conditional_question.id,
        conditional_match_choices_list: [question_choices(:multi_choice_q_1).id]
        },
        section_id: sections(:section_albers).id
    }
    end

    q = ProfileQuestion.last
    assert_response :success
    assert_equal "About me", q.question_text
    assert_equal ProfileQuestion::Type::SINGLE_CHOICE, q.question_type
    assert_match /profile_questions_for_section_#{q.section.id}.*append/, @response.body
    assert_match /profile_question_#{q.id}.*show/, @response.body
    assert_equal programs(:org_primary), q.organization
    assert_equal conditional_question, q.conditional_question
    assert_equal ["Stand"], q.conditional_text_choices
    assert conditional_question.reload.has_dependent_questions?

    assert q.allow_other_option?
  end

  def test_update_success_private_value_all
    current_user_is :portal_admin
    employee_role =programs(:primary_portal).get_role(RoleConstants::EMPLOYEE_NAME)
    pq = create_profile_question(question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "Choice Field1", question_choices: ["Choice 1", "Choice 2"], organization: programs(:org_nch))

    assert_nil pq.role_questions.first

    post :update, xhr: true, params: { id: pq.id, skip_other_roles: "false",
      profile_question: { role_id: "" }, skip_role_visibility_options_includein: "true",
      programs: { "#{programs(:primary_portal).id}" => ["#{ employee_role.id}"] }
    }

    assert_response :success
    q = pq.role_questions.first
    assert_equal RoleQuestion::PRIVACY_SETTING::ALL, q.private
    assert_false q.in_summary
    assert q.filterable
    assert_false q.required
  end

  def test_update_success_private_value_restricted_to_admin_alone
    current_user_is :portal_admin
    employee_role =programs(:primary_portal).get_role(RoleConstants::EMPLOYEE_NAME)
    pq = create_profile_question(question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "Choice Field1", question_choices: ["Choice 1", "Choice 2"], organization: programs(:org_nch))
    q = pq.role_questions.create!(role_id: employee_role.id)

    assert_not_equal RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE, q.private
    assert_false q.in_summary
    assert q.filterable

    assert_false q.show_in_summary?
    assert_false q.required

    post :update, xhr: true, params: { id: pq.id, skip_other_roles: "true",
      profile_question: {role_id: []}, available_for_flag: "true",
      role_questions: {"#{ employee_role.id}" => {in_summary: true}}
    }

    assert_response :success
    q = ProfileQuestion.last.role_questions.first
    assert_equal RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE, q.private
    assert q.in_summary
    assert_false q.show_in_summary?
    assert_false q.filterable
    assert_false q.required
  end

  def test_update_success_private_value_user_and_admin_only
    current_user_is :portal_admin
    employee_role =programs(:primary_portal).get_role(RoleConstants::EMPLOYEE_NAME)
    pq = create_profile_question(question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "Choice Field1", question_choices: ["Choice 1", "Choice 2"], organization: programs(:org_nch))
    q = pq.role_questions.create!(role_id: employee_role.id)

    assert_not_equal RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY, q.private
    assert_false q.in_summary
    assert q.filterable

    assert_false q.show_in_summary?
    assert_false q.required

    post :update, xhr: true, params: { id: pq.id, skip_other_roles: "true",
      profile_question: { role_id: "" }, available_for_flag: "true",
      role_questions: { "#{ employee_role.id}" => { in_summary: true, privacy_settings: {RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY.to_s => '0' } } }
    }

    assert_response :success
    q = pq.role_questions.first
    assert_equal RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY, q.private
    assert q.in_summary
    assert_false q.show_in_summary?
    assert_false q.filterable
    assert_false q.required
  end

  def test_update_success_private_value_restricted_to_connected_members
    current_member_is :f_admin
    student_role =programs(:albers).get_role(RoleConstants::STUDENT_NAME)
    pq = create_profile_question(question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "Choice Field1", question_choices: ["Choice 1", "Choice 2"], organization: programs(:org_primary))
    q = pq.role_questions.create!(role_id: student_role.id)
    assert_not_equal RoleQuestion::PRIVACY_SETTING::RESTRICTED, q.private
    assert q.show_connected_members?
    assert_equal 0, q.privacy_settings.size
    assert_false q.in_summary
    assert_false q.show_in_summary?
    assert q.filterable
    assert_false q.required

    privacy_settings = default_restricted_privacy_settings(programs(:albers))
    privacy_settings[RoleQuestion::PRIVACY_SETTING::RESTRICTED.to_s].delete(RoleQuestionPrivacySetting::SettingType::ROLE.to_s)
    post :update, xhr: true, params: { id: pq.id, skip_other_roles: "true",
      profile_question: { role_id: "" }, available_for_flag: "true",
      role_questions: { "#{ student_role.id}" => { required: true, in_summary: true, filterable: true, privacy_settings: privacy_settings } }
    }

    assert_response :success
    q = ProfileQuestion.last.role_questions.first
    assert_equal RoleQuestion::PRIVACY_SETTING::RESTRICTED, q.private
    assert q.show_connected_members?
    assert_equal 1, q.privacy_settings.size
    assert q.in_summary
    assert_false q.show_in_summary?
    assert_false q.filterable
    assert q.required
  end

  def test_update_success_private_value_restricted_not_to_connected_members
    current_member_is :f_admin
    student_role =programs(:albers).get_role(RoleConstants::STUDENT_NAME)
    pq = create_profile_question(question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "Choice Field1", question_choices: ["Choice 1", "Choice 2"], organization: programs(:org_primary))
    q = pq.role_questions.create!(role_id: student_role.id)
    assert_not_equal RoleQuestion::PRIVACY_SETTING::RESTRICTED, q.private
    assert q.show_connected_members?
    assert_equal 0, q.privacy_settings.size
    assert_false q.in_summary
    assert q.filterable
    assert_false q.required

    privacy_settings = default_restricted_privacy_settings(programs(:albers))
    privacy_settings[RoleQuestion::PRIVACY_SETTING::RESTRICTED.to_s].delete(RoleQuestionPrivacySetting::SettingType::CONNECTED_MEMBERS.to_s)
    post :update, xhr: true, params: { id: pq.id, skip_other_roles: "true",
      profile_question: { role_id: "" }, available_for_flag: "true",
      role_questions: { "#{ student_role.id}" => {required: true, in_summary: true, filterable: true, privacy_settings: privacy_settings } }
    }

    assert_response :success
    q = ProfileQuestion.last.role_questions.first
    assert_equal RoleQuestion::PRIVACY_SETTING::RESTRICTED, q.private
    assert_false q.show_connected_members?
    assert_equal 3, q.privacy_settings.size
    assert q.in_summary
    assert_false q.filterable
    assert q.required
  end

  def test_update_success_private_value_shown_to_all_mentors
    current_member_is :f_admin
    student_role =programs(:albers).get_role(RoleConstants::STUDENT_NAME)

    mentor_role = programs(:albers).get_role(RoleConstants::MENTOR_NAME)

    pq = create_profile_question(question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "Choice Field1", question_choices: ["Choice 1", "Choice 2"], organization: programs(:org_primary))
    q = pq.role_questions.create!(role_id: student_role.id)
    assert_not_equal RoleQuestion::PRIVACY_SETTING::RESTRICTED, q.private
    assert q.show_connected_members?
    assert_equal 0, q.privacy_settings.size
    assert_false q.in_summary
    assert q.filterable
    assert_false q.required

    privacy_settings = {RoleQuestion::PRIVACY_SETTING::RESTRICTED.to_s => {RoleQuestionPrivacySetting::SettingType::ROLE.to_s => {mentor_role.id.to_s => '1'}}}
    post :update, xhr: true, params: { id: pq.id, skip_other_roles: "true",
      profile_question: { role_id: "" }, available_for_flag: "true",
      role_questions: {"#{ student_role.id}" => { required: true, in_summary: true, filterable: true, privacy_settings: privacy_settings } }
    }

    assert_response :success
    q = ProfileQuestion.last.role_questions.first
    assert_equal RoleQuestion::PRIVACY_SETTING::RESTRICTED, q.private
    assert_false q.show_connected_members?
    assert_equal 1, q.privacy_settings.size
    assert q.in_summary
    assert_false q.filterable
    assert q.required
  end

  def test_create_success_with_text_only_option_changed_by_super_user
    login_as_super_user
    current_member_is :f_admin

    assert_difference 'programs(:org_primary).profile_questions.count' do
      post :create, xhr: true, params: { :profile_question => {
        :question_text => "About me",
        :text_only_option => true,
        :question_type => ProfileQuestion::Type::STRING},
        :section_id => sections(:section_albers).id
    }
    end

    assert_response :success
    assert ProfileQuestion.last.text_only_option
  end

  def test_create_with_question_type_single_choice
    current_member_is :f_admin
    assert_false programs(:albers).standalone?
    student_role =programs(:albers).get_role(RoleConstants::STUDENT_NAME)

    assert_difference 'programs(:org_primary).profile_questions.count' do
      post :create, xhr: true, params: { :profile_question => {
        :question_text => "About me",
        :question_type => ProfileQuestion::Type::SINGLE_CHOICE,
        :existing_question_choices_attributes => [{"101" => {"text" => "good"}, "102" => {"text" => "bad"}, "103" => {"text" => "ugly"}}],
        :question_choices => {"new_order" => "103,101,102"},
        :allow_other_option => true
        },
        :section_id => sections(:section_albers).id
    }
    end

    q = ProfileQuestion.last
    assert_response :success
    assert_equal "About me", q.question_text
    assert_equal ProfileQuestion::Type::SINGLE_CHOICE, q.question_type
    assert_match /profile_questions_for_section_#{q.section.id}.*append/, @response.body
    assert_match /profile_question_#{q.id}.*show/, @response.body
    assert_equal programs(:org_primary), q.organization
  end

  def test_create_with_question_type_multple_education
    current_member_is :f_admin
    assert_false programs(:albers).standalone?
    student_role =programs(:albers).get_role(RoleConstants::STUDENT_NAME)

    assert_difference 'programs(:org_primary).profile_questions.count' do
      post :create, xhr: true, params: { :profile_question => {
        :question_text => "About me",
        :question_type => ProfileQuestion::Type::MULTI_EDUCATION,
        :existing_question_choices_attributes => [{"101" => {"text" => "good"}, "102" => {"text" => "bad"}, "103" => {"text" => "ugly"}}],
        :question_choices => {"new_order" => "103,101,102"},
        :allow_other_option => true
        },
        :section_id => sections(:section_albers).id
    }
    end

    q = ProfileQuestion.last
    assert_response :success
    assert_equal "About me", q.question_text
    assert_equal ProfileQuestion::Type::MULTI_EDUCATION, q.question_type
    assert_match /profile_questions_for_section_#{q.section.id}.*append/, @response.body
    assert_match /profile_question_#{q.id}.*show/, @response.body
    assert_equal programs(:org_primary), q.organization
  end

  def test_create_success_for_standalone
    current_member_is :foster_admin
    assert programs(:foster).standalone?
    student_role =programs(:foster).get_role(RoleConstants::STUDENT_NAME)

    assert_difference 'programs(:org_foster).profile_questions.count' do
      post :create, xhr: true, params: { :profile_question => {
        :question_text => "About me",
        :question_type => ProfileQuestion::Type::TEXT},
        :section_id => programs(:org_foster).sections.first
    }
    end

    q = ProfileQuestion.last
    assert_response :success
    assert_equal "About me", q.question_text
    assert_equal ProfileQuestion::Type::TEXT, q.question_type
    assert_match /profile_questions_for_section_#{q.section.id}.*append/, @response.body
    assert_match /profile_question_#{q.id}.*show/, @response.body
    assert_equal programs(:org_foster), q.organization
  end

  def test_create_failure_with_field_blank
    current_member_is :f_admin

    assert_no_difference 'ProfileQuestion.count' do
      post :create, xhr: true, params: { :profile_question => {
        :question_text => "",
        :question_type => ProfileQuestion::Type::TEXT
        },
        :section_id => sections(:section_albers).id
      }
    end

    assert_response :success
    assert_match /Field name cannot be blank/, response.body
  end

  def test_create_failure_with_empty_choices
    current_member_is :f_admin

    assert_no_difference 'ProfileQuestion.count' do
      post :create, xhr: true, params: { :profile_question => {
        :question_text => "Gender",
        :question_type => ProfileQuestion::Type::SINGLE_CHOICE
        },
        :section_id => sections(:section_albers).id
      }
    end

    assert_response :success
    assert_match /ChronusValidator.ErrorManager.ShowResponseFlash.*Choices can&#39;t be blank for choice based questions/, response.body
  end

  def test_index_for_profile_questions
    current_member_is :f_admin

    programs(:org_primary).profile_questions.destroy_all
    email_question = programs(:org_primary).profile_questions_with_email_and_name.email_question
    name_question = programs(:org_primary).profile_questions_with_email_and_name.name_question
    q = create_profile_question(:organization => programs(:org_primary))

    get :index
    assert_equal name_question + email_question + [q], assigns(:profile_questions)
    assert_response :success
  end

  def test_index_for_profile_questions_standalone
    current_member_is :foster_admin

    programs(:org_foster).profile_questions.destroy_all
    email_question = programs(:org_foster).profile_questions_with_email_and_name.email_question
    name_question = programs(:org_foster).profile_questions_with_email_and_name.name_question
    q = create_profile_question(:organization => programs(:org_foster))

    get :index
    assert_equal name_question + email_question + [q], assigns(:profile_questions)
    role_questions = assigns(:profile_questions).collect(&:role_questions).flatten
    assert_response :success
  end

  def test_index_ignores_membership_only_and_skype_questions
    update_profile_question_types_appropriately
    organization = programs(:org_primary)
    # disabling allow to join for all roles
    disable_membership_request!(organization)
    organization.enable_feature(FeatureName::SKYPE_INTERACTION, false)

    section = organization.sections.create!(title: "New Section")
    membership_question = create_profile_question
    skype_question = create_profile_question(question_type: ProfileQuestion::Type::SKYPE_ID)
    membership_question.update_attribute(:section_id, section.id)
    create_role_question(
      role_names: [RoleConstants::MENTOR_NAME],
      available_for: RoleQuestion::AVAILABLE_FOR::MEMBERSHIP_QUESTIONS,
      profile_question: membership_question
    )
    assert membership_question.reload.membership_only?
    assert_false skype_question.membership_only?

    current_member_is :f_admin
    get :index
    assert assigns(:sections).include?(section)
    assert_false assigns(:profile_questions).include?(membership_question)
    assert_false assigns(:profile_questions).include?(skype_question)
  end

  def test_index_includes_membership_only_and_skype_questions
    update_profile_question_types_appropriately
    organization = programs(:org_primary)
    # allowing atleast one role of one of the programs to join
    enable_membership_request!(programs(:org_primary))
    organization.enable_feature(FeatureName::SKYPE_INTERACTION, true)

    section = organization.sections.create!(title: "New Section")
    membership_question = create_profile_question
    skype_question = create_profile_question(question_type: ProfileQuestion::Type::SKYPE_ID)
    membership_question.update_attribute(:section_id, section.id)
    create_role_question(
      role_names: [RoleConstants::MENTOR_NAME],
      available_for: RoleQuestion::AVAILABLE_FOR::MEMBERSHIP_QUESTIONS,
      profile_question: membership_question
    )
    assert membership_question.reload.membership_only?
    assert_false skype_question.membership_only?

    current_member_is :f_admin
    get :index
    assert assigns(:sections).include?(section)
    assert assigns(:profile_questions).include?(membership_question)
    assert assigns(:profile_questions).include?(skype_question)
  end

  def test_preview_for_profile_questions_ajax_part_1
    update_profile_question_types_appropriately
    current_member_is :f_admin

    mentor_role = programs(:albers).roles.find{|r| r.name == RoleConstants::MENTOR_NAME}
    admin_role = programs(:albers).roles.find{|r| r.name == RoleConstants::ADMIN_NAME}
    programs(:org_primary).profile_questions.destroy_all
    name_question = programs(:org_primary).profile_questions_with_email_and_name.name_question
    email_question = programs(:org_primary).profile_questions_with_email_and_name.email_question
    q = create_question(:organization => programs(:org_primary), :role_names => [RoleConstants::MENTOR_NAME])
    all_questions = name_question + [q]
    all_questions = all_questions.group_by(&:section_id)

    get :preview, xhr: true, params: { :filter =>{:program => "#{programs(:albers).id}", :role => [mentor_role.id], viewer_role: [admin_role.id]}}
    all_questions.each do |key,value|
      assert_equal_unordered value, assigns(:profile_questions)[key]
    end
    assert_equal programs(:albers), assigns(:preview_program)
    assert_equal [RoleConstants::MENTOR_NAME], assigns(:filter_role)
    required_questions = programs(:albers).role_questions_for([RoleConstants::MENTOR_NAME]).required.select([:required, :profile_question_id]).group_by(&:profile_question_id)
    required_questions.each do |key,value|
      assert_equal value.first.attributes, assigns(:required_questions)[key].first.attributes
    end

    grouped_role_questions = programs(:albers).role_questions_for([RoleConstants::MENTOR_NAME], fetch_all: true).group_by(&:profile_question_id)
    grouped_role_questions.each do |key,value|
      assert_equal value, assigns(:grouped_role_questions)[key]
    end
  end

  def test_preview_for_profile_questions_ajax_part_2
    update_profile_question_types_appropriately
    current_member_is :f_admin
    programs(:org_primary).profile_questions.destroy_all

    name_question = programs(:org_primary).profile_questions_with_email_and_name.name_question
    all_questions = name_question
    all_questions = all_questions.group_by(&:section_id)
    nwen_mentor_role = programs(:nwen).roles.find{|r| r.name == RoleConstants::MENTOR_NAME}
    nwen_admin_role = programs(:nwen).roles.find{|r| r.name == RoleConstants::ADMIN_NAME}
    get :preview, xhr: true, params: { :filter =>{:program => "#{programs(:nwen).id}", :role => [nwen_mentor_role.id], viewer_role: [nwen_admin_role.id]}}
    all_questions.each do |key,value|
      assert_equal_unordered value, assigns(:profile_questions)[key]
    end
    assert_equal programs(:nwen), assigns(:preview_program)
    assert_equal [RoleConstants::MENTOR_NAME], assigns(:filter_role)
    required_questions = programs(:nwen).role_questions_for([RoleConstants::MENTOR_NAME]).required.select([:required, :profile_question_id]).group_by(&:profile_question_id)
    required_questions.each do |key,value|
      assert_equal value.first.attributes, assigns(:required_questions)[key].first.attributes
    end

    grouped_role_questions = programs(:nwen).role_questions_for([RoleConstants::MENTOR_NAME], fetch_all: true).group_by(&:profile_question_id)
    grouped_role_questions.each do |key,value|
      assert_equal value, assigns(:grouped_role_questions)[key]
    end
    assert_response :success
  end

  def test_preview_for_profile_questions_non_ajax
    current_member_is :f_admin

    get :preview, params: { :program_id => "#{programs(:albers).id}"}
    assert_equal programs(:albers), assigns(:preview_program)
    assert_empty assigns(:profile_questions)
    assert_empty assigns(:filter_role)
    assert_empty assigns(:required_questions)
    assert_empty assigns(:grouped_role_questions)
  end

  def test_preview_for_profile_questions_non_ajax_user_profile_form
    current_member_is :f_admin

    get :preview
    assert_equal ProfileQuestionsController::PreviewType::USER_PROFILE_FORM, assigns(:preview_type)
    assert_equal programs(:albers), assigns(:preview_program)
    assert_empty assigns(:profile_questions)
    assert_empty assigns(:filter_role)
    assert_empty assigns(:required_questions)
    assert_empty assigns(:grouped_role_questions)
  end

  def test_preview_for_profile_preview_type
    current_member_is :f_admin
    get :preview, params: { preview_type: ProfileQuestionsController::PreviewType::USER_PROFILE}
    assert_equal ProfileQuestionsController::PreviewType::USER_PROFILE, assigns(:preview_type)
    assert_equal programs(:org_primary).programs.ordered, assigns(:profile_preview_programs)
    assert_equal programs(:albers), assigns(:preview_program)
  end

  def test_preview_for_profile_preview_type_ajax_filter
    current_member_is :f_admin
    program = programs(:albers)
    mentor_role = program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    student_role = program.roles.find_by(name: RoleConstants::STUDENT_NAME)
    get :preview, xhr: true, params: { preview_type: :user_profile, filter: {role: [mentor_role.id], program: program.id, viewer_role: [student_role.id], should_be_connected: "true"}}
    assert_equal ProfileQuestionsController::PreviewType::USER_PROFILE, assigns(:preview_type)
    assert_equal programs(:org_primary).programs.ordered, assigns(:profile_preview_programs)
    assert_equal programs(:albers), assigns(:preview_program)
    assert_equal_hash({}, assigns(:all_answers))
    assert_equal [RoleConstants::MENTOR_NAME], assigns(:filter_role)
    assert_equal [mentor_role.id.to_s], assigns(:filter_role_ids)
    assert_equal [student_role.id.to_s], assigns(:viewer_roles)
    assert assigns(:should_be_connected)
    profile_questions = program.profile_questions_for([RoleConstants::MENTOR_NAME], {fetch_all: true, default: true, skype: program.organization.skype_enabled?, pq_translation_include: true}).sort_by(&:position)
    profile_questions.select! { |pq| pq.role_questions.where(role_id: [mentor_role.id]).map { |rq| rq.show_for_roles?([student_role.id]) || rq.show_connected_members? }.inject(:|) }
    sections = profile_questions.collect(&:section).uniq.sort_by(&:position)
    profile_questions = profile_questions.group_by(&:section_id)
    assert_equal sections, assigns(:sections)
    assert_equal_hash(profile_questions, assigns(:profile_questions))
  end

  def test_preview_for_profile_questions_at_program_level
    user = users(:f_mentor)
    user.promote_to_role!([RoleConstants::ADMIN_NAME], users(:f_admin))
    current_user_is :f_mentor
    current_program_is :albers

    get :preview
    assert_response :success

    assert_equal programs(:albers), assigns(:preview_program)
    assert_empty assigns(:profile_questions)
    assert_empty assigns(:filter_role)
    assert_empty assigns(:required_questions)
    assert_empty assigns(:grouped_role_questions)
  end

  def test_sub_program_admin_view
    current_member_is :f_admin
    members(:f_admin).demote_from_admin!
    members(:f_admin).reload

    assert members(:f_admin).programs.size > 1
    assert_false members(:f_admin).admin?
    assert members(:f_admin).is_admin?

    assert_permission_denied do
      get :index
    end
  end

  def test_edit_profile_questions_locked_by_matching
    current_member_is :f_admin
    program = programs(:albers)
    q1 = create_question(:question_type => ProfileQuestion::Type::SINGLE_CHOICE, :question_text => "Choice Field1", 
      :question_choices => ["Choice 1", "Choice 2"],
      :role_names => [:mentor], :program => program, :filterable => false)
    q1.save!
    assert_equal ["Choice 1", "Choice 2"], q1.question_choices.collect(&:text)
    prof_q1 = ProfileQuestion.last
    mentor_q1 = prof_q1.role_questions.first
    assert_difference 'MatchConfig.count' do
      stud_q1 = prof_q1.role_questions.new()
      stud_q1.role = program.get_role(RoleConstants::STUDENT_NAME)
      stud_q1.save!
      MatchConfig.create!(:program => program, :mentor_question => mentor_q1, :student_question => stud_q1, :matching_type => MatchConfig::MatchingType::SET_MATCHING)
    end

    get :edit, xhr: true, params: { :id => prof_q1.id}
    assert assigns(:disabled_for_editing)
    assert_match /Please note only parts of the field can be edited as this field is used for matching users. Please contact Chronus support for assistance/, @response.body
  end

  def test_update_success_for_description_and_definition
    current_member_is :f_admin

    q = create_question(:organization => programs(:org_primary))
    assert_equal "Whats your age?", q.question_text
    assert_equal ProfileQuestion::Type::STRING, q.question_type
    assert_equal false, q.allow_other_option?
    conditional_question = profile_questions(:multi_choice_q)
    assert_false conditional_question.has_dependent_questions?
    assert_nil q.conditional_question
    ProfileQuestion.expects(:delayed_es_reindex).with(q.id).once

    post :update, xhr: true, params: { :id => q.id, :profile_question => {
      :question_text => "About me",
      :question_type => ProfileQuestion::Type::SINGLE_CHOICE,
      :existing_question_choices_attributes => [{"101" => {"text" => "good"}, "102" => {"text" => "bad"}, "103" => {"text" => "ugly"}}],
      :question_choices => {"new_order" => "103,101,102"},
      :allow_other_option => true,
      :conditional_question_id => conditional_question.id,
      :conditional_match_choices_list => [question_choices(:multi_choice_q_1).id]
      },
      skip_role_settings: true
    }

    assert_equal "About me", q.reload.question_text
    assert_equal ProfileQuestion::Type::SINGLE_CHOICE, q.question_type
    assert q.allow_other_option?
    assert_response :success
    assert_match (/profile_question_#{assigns(:profile_question).id}.*replaceWith/), @response.body
    assert_equal conditional_question, q.conditional_question
    assert_equal ["Stand"], q.conditional_text_choices
    assert conditional_question.reload.has_dependent_questions?
  end

  def test_update_success_for_role_questions
    current_member_is :f_admin

    q = create_question(:organization => programs(:org_primary))
    student_role = programs(:albers).get_role(RoleConstants::STUDENT_NAME)
    mentor_role = programs(:albers).get_role(RoleConstants::MENTOR_NAME)
    assert_equal 1, q.role_questions.size

    post :update, xhr: true, params: { :id => q.id, :profile_question => {
        id: q.id
      },
      skip_role_visibility_options_includein: true,
      programs: {"#{programs(:albers).id}" => [student_role.id.to_s, mentor_role.id.to_s]}
    }

    assert_response :success
    assert_match (/profile_question_#{assigns(:profile_question).id}.*replaceWith/), @response.body
    assert_equal 2, q.role_questions.size
  end

  def test_update_success_for_advanced_options
    current_member_is :f_admin

    q = create_question(:organization => programs(:org_primary))
    student_role = programs(:albers).get_role(RoleConstants::STUDENT_NAME)
    assert !q.role_questions.first.required
    assert !q.role_questions.first.in_summary

    post :update, xhr: true, params: { :id => q.id, :profile_question => {
        id: q.id
      },
      role_questions: {"#{student_role.id}" => {:required => true, :in_summary => true, :available_for => {:profile => RoleQuestion::AVAILABLE_FOR::PROFILE_QUESTIONS, :membership_form => RoleQuestion::AVAILABLE_FOR::MEMBERSHIP_QUESTIONS}, :privacy_settings => default_restricted_privacy_settings(programs(:albers))}},
      skip_other_roles: true, available_for_flag: true
    }

    assert_response :success
    assert_match (/profile_question_#{assigns(:profile_question).id}.*replaceWith/), @response.body

    assert q.role_questions.first.required
    assert q.role_questions.first.in_summary
    assert_false q.role_questions.first.filterable
    assert_equal RoleQuestion::AVAILABLE_FOR::BOTH, q.role_questions.first.available_for
  end

  def test_update_success_with_text_only_option_changed_by_super_user
    login_as_super_user
    current_member_is :f_admin

    q = create_question(:organization => programs(:org_primary))
    assert_false q.text_only_option

    post :update, xhr: true, params: { :id => q.id, :profile_question => {
      :question_text => "About me",
      :text_only_option => true},
      skip_role_settings: true
    }

    assert_response :success
    assert q.reload.text_only_option
  end

  def test_update_success_with_multi_string_question_type
    current_member_is :f_admin

    q = create_question(:organization => programs(:org_primary))
    assert_equal "Whats your age?", q.question_text
    assert_equal ProfileQuestion::Type::STRING, q.question_type
    student_role = programs(:albers).get_role(RoleConstants::STUDENT_NAME)
    assert_equal 1, q.role_questions.size
    assert !q.role_questions.first.required
    assert !q.role_questions.first.in_summary
    assert_equal false, q.allow_other_option?

    post :update, xhr: true, params: { :id => q.id, :profile_question => {
      :question_text => "About me",
      :question_type => CommonQuestion::Type::MULTI_STRING,
      :existing_question_choices_attributes => [{"101" => {"text" => "good"}, "102" => {"text" => "bad"}, "103" => {"text" => "ugly"}}],
      :question_choices => {"new_order" => "103,101,102"}
      },
      skip_role_settings: true
    }

    assert_equal "About me", q.reload.question_text
    assert_equal CommonQuestion::Type::MULTI_STRING, q.question_type
    assert_response :success
    assert_match /profile_question_#{assigns(:profile_question).id}.*replaceWith/, @response.body
  end

  def test_update_success_email_question_description_and_definition
    current_member_is :foster_admin
    q = programs(:org_foster).profile_questions_with_email_and_name.email_question.first
    assert_equal "Email", q.question_text
    assert_equal ProfileQuestion::Type::EMAIL, q.question_type

    post :update, xhr: true, params: { :id => q.id, :profile_question => {
      :question_text => "Email",
      :question_type => ProfileQuestion::Type::EMAIL,
      },
      skip_role_settings: true
    }

    assert_equal "Email", q.reload.question_text
    assert_equal ProfileQuestion::Type::EMAIL, q.question_type
    assert_response :success
    assert_match (/profile_question_#{assigns(:profile_question).id}.*replaceWith/), @response.body
  end

  def test_update_success_email_question_advanced_settings
    current_member_is :foster_admin
    q = programs(:org_foster).profile_questions_with_email_and_name.email_question.first
    student_role = programs(:foster).get_role(RoleConstants::STUDENT_NAME)
    mentor_role = programs(:foster).get_role(RoleConstants::MENTOR_NAME)
    assert_equal 2, q.role_questions.size
    assert q.role_questions.first.required
    assert !q.role_questions.first.in_summary

    post :update, xhr: true, params: { :id => q.id, :profile_question => {
        id: q.id
      },
      :role_questions => {"#{mentor_role.id}" => {:required => true, :in_summary => false, :privacy_settings => default_restricted_privacy_settings(programs(:foster))}, "#{student_role.id}" => {:required => true, :in_summary => false, :privacy_settings => default_restricted_privacy_settings(programs(:foster))}},
      skip_other_roles: true
    }

    assert_response :success
    assert_match (/profile_question_#{assigns(:profile_question).id}.*replaceWith/), @response.body

    assert_equal 2, q.role_questions.size
    assert q.role_questions.first.required
    assert !q.role_questions.first.in_summary
  end

  def test_update_with_admin_only_editable_setting
    current_member_is :f_admin
    q = profile_questions(:profile_questions_8)
    mentor_role = programs(:albers).get_role(RoleConstants::MENTOR_NAME)

    post :update, xhr: true, params: { :id => q.id, :profile_question => {id: q.id, role_id: mentor_role.id},
      :role_questions => {"#{mentor_role.id}" => {}},
      skip_other_roles: true, available_for_flag: true
    }
    assert_response :success
    q.reload
    rq = q.role_questions.find_by(role_id: mentor_role.id)
    assert_equal "About Me", q.question_text
    assert_equal RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE, rq.private
    assert_equal [true, false, false, false], [rq.admin_only_editable, rq.required, rq.in_summary, rq.filterable]
  end

  def test_update_failure_with_field_blank
    current_member_is :f_admin

    q = create_profile_question(:organization => programs(:org_primary))
    mentor_role = programs(:albers).get_role(RoleConstants::MENTOR_NAME)
    assert_equal "Whats your age?", q.question_text
    assert_equal ProfileQuestion::Type::STRING, q.question_type

    post :update, xhr: true, params: { :id => q.id, :profile_question => {:question_text => "", :question_type => ProfileQuestion::Type::TEXT},
      :programs => {"#{programs(:albers).id}" => ["#{mentor_role.id}"]},
      :role_questions => {"#{mentor_role.id}" => {:required => true, :in_summary => true, :privacy_settings => default_restricted_privacy_settings(programs(:albers))}}
    }
    assert_response :success
    assert_match /Field name cannot be blank/, response.body
  end

  def test_update_success_private_value
    current_member_is :f_admin
    q = profile_questions(:profile_questions_8)
    role_question = q.role_questions.first
    assert_equal role_question.private, RoleQuestion::PRIVACY_SETTING::ALL

    post :update, xhr: true, params: { :id => q.id, :profile_question => {id: q.id},
      :role_questions => {"#{role_question.role_id}" => {:required => true, :in_summary => true, :filterable => true, :admin_only_editable => true, :privacy_settings => {RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY.to_s => '1'}}},
      skip_other_roles: true, available_for_flag: true
    }

    assert_response :success
    role_question.reload
    assert_equal RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY, role_question.private
    assert_equal [true, true, false, true, false] , [role_question.admin_only_editable, role_question.required, role_question.filterable, role_question.in_summary, role_question.show_in_summary?]
  end

  def test_update_success_private_value_restricted_to_admin_alone
    current_member_is :f_admin
    q = profile_questions(:profile_questions_8)
    role_question = q.role_questions.first
    assert_equal role_question.private, RoleQuestion::PRIVACY_SETTING::ALL

    post :update, xhr: true, params: { :id => q.id, :profile_question => {id: q.id},
      :role_questions => {"#{role_question.role_id}" => {:required => false, :in_summary => true, :filterable => true, :admin_only_editable => true}},
      skip_other_roles: true, available_for_flag: true
    }
    assert_response :success
    role_question.reload
    assert_equal RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE, role_question.private
    assert_equal [true, false, false, true, false] , [role_question.admin_only_editable, role_question.required, role_question.filterable, role_question.in_summary, role_question.show_in_summary?]
  end

  def test_update_success_private_value_restricted_to_all_mentors
    current_member_is :f_admin
    q = profile_questions(:profile_questions_8)
    role_question = q.role_questions.first
    privacy_settings = {RoleQuestion::PRIVACY_SETTING::RESTRICTED.to_s => {RoleQuestionPrivacySetting::SettingType::ROLE.to_s => {role_question.role_id.to_s => '1'}}}
    assert_equal role_question.private, RoleQuestion::PRIVACY_SETTING::ALL

    post :update, xhr: true, params: { :id => q.id, :profile_question => {id: q.id},
      :role_questions => {"#{role_question.role_id}" => {:required => true, :in_summary => true, :filterable => true, :privacy_settings => privacy_settings}},
      skip_other_roles: true, available_for_flag: true
    }
    assert_response :success
    role_question.reload
    assert_equal RoleQuestion::PRIVACY_SETTING::RESTRICTED, role_question.private
    assert_equal 1, role_question.privacy_settings.size
    assert_equal [false, true, false, true] , [role_question.admin_only_editable, role_question.required, role_question.filterable, role_question.in_summary]
  end

  def test_update_failure_with_empty_choices
    current_member_is :f_admin

    q = create_profile_question(:organization => programs(:org_primary))
    mentor_role = programs(:albers).get_role(RoleConstants::MENTOR_NAME)
    assert_equal "Whats your age?", q.question_text
    assert_equal ProfileQuestion::Type::STRING, q.question_type

    post :update, xhr: true, params: { :id => q.id, :profile_question => {:question_text => "Degree", :question_type => ProfileQuestion::Type::SINGLE_CHOICE},
      :programs => {"#{programs(:albers).id}" => ["#{mentor_role.id}"]},
      :role_questions => {"#{mentor_role.id}" => {:required => true, :in_summary => true, :privacy_settings => default_restricted_privacy_settings(programs(:albers))}}
    }
    assert_response :success
    assert_match /ChronusValidator.ErrorManager.ShowResponseFlash.*Choices can&#39;t be blank for choice based questions/, response.body
  end

  def test_remove
    current_member_is :f_admin

    q = profile_questions(:string_q)

    assert_difference "programs(:org_primary).profile_questions.count", -1 do
      post :destroy, xhr: true, params: { :id => q.id}
    end
    assert_response :success
  end

  def test_update_prog_question_in_standalone_program
    current_member_is :foster_admin

    question = create_profile_question({:position => 1, :organization => programs(:org_foster)})

    put :update, xhr: true, params: { :id => question.id, :profile_question => {
        :question_text => "Hello123"
      },
      skip_role_settings: true
    }


    assert_response :success
    assert_equal "Hello123", question.reload.question_text
  end

  def test_destroy_org_question_in_standalone_program
    current_member_is :foster_admin

    question = create_profile_question(:position => 1, :organization => programs(:org_foster))

    assert_difference 'programs(:org_foster).profile_questions.reload.count', -1 do
      delete :destroy, xhr: true, params: { :id => question.id}
    end

    assert_response :success
  end

  def test_question_update_order
    section = sections(:section_albers)
    section_1 = sections(:sections_1)
    section_questions = section.profile_questions
    section_1_questions_id_position = section_1.profile_questions.select('id, position')
    assert_equal section.organization, section_1.organization

    new_order = [section_questions[0].id, section_questions[3].id, section_questions[4].id, section_questions[1].id, section_questions[2].id]
    current_member_is :f_admin
    put :update, xhr: true, params: { section_id: section, new_order: new_order}
    assert_equal section_questions, assigns(:profile_questions)
    assert_equal new_order, section.reload.profile_questions.collect(&:id)
    assert_equal section_1_questions_id_position, section_1.reload.profile_questions.select('id, position')
  end

  def test_question_update_order_doesnt_alter_default_questions
    section = sections(:sections_1)
    questions = section.profile_questions
    non_default_questions = questions.except_email_and_name_question.to_a
    assert section.default_field?
    assert questions[0].default_type? && questions[1].default_type?
    assert_equal 1, questions[0].position
    assert_equal 2, questions[1].position

    new_order = [questions[3].id, questions[4].id, questions[2].id]
    current_member_is :f_admin
    put :update, xhr: true, params: { section_id: section, new_order: new_order}
    assert_equal_unordered non_default_questions, assigns(:profile_questions)
    assert_equal (questions[0..1].collect(&:id) + new_order), section.reload.profile_questions.collect(&:id)
    assert_equal 1, questions[0].reload.position
    assert_equal 2, questions[1].reload.position
  end

  def test_question_update_order_across_sections
    section = sections(:sections_1)
    section_questions_id_position = section.profile_questions.select('id, position')
    profile_question = create_profile_question
    profile_question.update_attribute(:section_id, section.id)
    new_section = section.organization.sections.create!(title: "New Section")

    current_member_is :f_admin
    put :update, xhr: true, params: { section_id: new_section.id, new_order: [profile_question.id]}
    assert_empty assigns(:profile_questions)
    assert_equal new_section.id, profile_question.reload.section_id
    assert_equal 1, profile_question.position
    assert_equal section_questions_id_position, section.reload.profile_questions.select('id, position')
    assert_equal 1, new_section.profile_questions.size
  end

  def test_question_create_with_help_text_with_vulnerable_content_with_version_v2
    current_member_is :f_admin
    current_user_is :f_admin
    assert_false programs(:albers).standalone?
    student_role =programs(:albers).get_role(RoleConstants::STUDENT_NAME)
    conditional_question = profile_questions(:multi_choice_q)
    assert_false conditional_question.has_dependent_questions?

    assert_difference "VulnerableContentLog.count" do
      assert_difference 'programs(:org_primary).profile_questions.count' do
        post :create, xhr: true, params: { :profile_question => {
          :question_text => "About me",
          :question_type => ProfileQuestion::Type::SINGLE_CHOICE,
          :existing_question_choices_attributes => [{"101" => {"text" => "good"}, "102" => {"text" => "bad"}, "103" => {"text" => "ugly"}}],
          :question_choices => {"new_order" => "103,101,102"},
          :help_text => "<b>help text</b> <a href=\"https://www.chronus.com\"> chronus </a> <script>alert(\"help text\")</script>",
          :allow_other_option => true,
          :conditional_question_id => conditional_question.id,
          :conditional_match_choices_list => [question_choices(:multi_choice_q_1).id]
          },
          :section_id => sections(:section_albers).id
        }
      end
    end

    q = ProfileQuestion.last
    assert_response :success
    assert_equal "About me", q.question_text
    assert_equal "<b>help text</b> <a href=\"https://www.chronus.com\"> chronus </a> <script>alert(\"help text\")</script>", q.help_text
    assert_equal ProfileQuestion::Type::SINGLE_CHOICE, q.question_type
    assert_match /profile_questions_for_section_#{q.section.id}.*append/, @response.body
    assert_match /profile_question_#{q.id}.*show/, @response.body
    assert_equal programs(:org_primary), q.organization
    assert_equal conditional_question, q.conditional_question
    assert_equal ["Stand"], q.conditional_text_choices
    assert conditional_question.reload.has_dependent_questions?
  end

  def test_question_update_with_help_text_with_vulnerable_content_with_version_v2
    current_member_is :f_admin
    current_user_is :f_admin

    q = create_question(:organization => programs(:org_primary))
    assert_equal "Whats your age?", q.question_text
    assert_equal ProfileQuestion::Type::STRING, q.question_type
    assert_equal false, q.allow_other_option?
    conditional_question = profile_questions(:multi_choice_q)
    assert_false conditional_question.has_dependent_questions?
    assert_nil q.conditional_question
    ProfileQuestion.expects(:delayed_es_reindex).with(q.id).once

    assert_difference "VulnerableContentLog.count" do
      post :update, xhr: true, params: { :id => q.id, :profile_question => {
        :question_text => "About me",
        :question_type => ProfileQuestion::Type::SINGLE_CHOICE,
        :help_text => "<b>help text</b> <a href=\"https://www.chronus.com\"> chronus </a> <script>alert(\"help text\")</script>",
        :existing_question_choices_attributes => [{"101" => {"text" => "good"}, "102" => {"text" => "bad"}, "103" => {"text" => "ugly"}}],
        :question_choices => {"new_order" => "103,101,102"},
        :allow_other_option => true,
        :conditional_question_id => conditional_question.id,
        :conditional_match_choices_list => [question_choices(:multi_choice_q_1).id]
        },
        skip_role_settings: true
      }
    end
    assert_response :success
    assert_equal "About me", q.reload.question_text
    assert_equal ProfileQuestion::Type::SINGLE_CHOICE, q.question_type
    assert q.allow_other_option?
    assert_match (/profile_question_#{assigns(:profile_question).id}.*replaceWith/), @response.body
    assert_equal conditional_question, q.conditional_question
    assert_equal ["Stand"], q.conditional_text_choices
    assert conditional_question.reload.has_dependent_questions?
    assert_equal "<b>help text</b> <a href=\"https://www.chronus.com\"> chronus </a> <script>alert(\"help text\")</script>", q.help_text
  end

  def test_profile_questions_edit_should_not_lock_if_matching_is_disable_in_program
    current_member_is :f_admin
    program = programs(:albers)
    q1 = create_question(:question_type => ProfileQuestion::Type::SINGLE_CHOICE, :question_text => "Choice Field1", :question_choices => "Choice 1,Choice 2", :role_names => [:mentor], :program => program, :filterable => false)
    q1.save!
    assert_equal "Choice 1,Choice 2", q1.default_choices.join(",")
    prof_q1 = ProfileQuestion.last
    mentor_q1 = prof_q1.role_questions.first
    assert_difference 'MatchConfig.count' do
      stud_q1 = prof_q1.role_questions.new()
      stud_q1.role = program.get_role(RoleConstants::STUDENT_NAME)
      stud_q1.save!
      MatchConfig.create!(:program => program, :mentor_question => mentor_q1, :student_question => stud_q1, :matching_type => MatchConfig::MatchingType::SET_MATCHING)
    end

    program.engagement_type = nil
    program.enable_feature(FeatureName::CALENDAR, false)
    program.save!
    program.reload

    get :edit, xhr: true, params: { :id => prof_q1.id}
    assert_false assigns(:disabled_for_editing)
  end

  def test_update_for_all_roles
    current_member_is :f_admin
    section = sections(:sections_1)
    question = section.profile_questions.last
    program = question.programs.last
    current_program_is program
    program.role_questions.where(profile_question_id: question.id).destroy_all
    assert_equal 0, program.role_questions.where(profile_question_id: question.id).size
    User.expects(:es_reindex_for_profile_score).with(any_parameters).once
    post :update_for_all_roles, xhr: true, params: { id: question.reload.id, section_id: section.id}
    assert section, assigns(:section)
    assert_equal program.roles_without_admin_role.size, program.role_questions.where(profile_question_id: question.id).size
  end

  def test_update_profile_question_section
    current_member_is :f_admin
    organization = members(:f_admin).organization
    source_section = organization.sections.find_by(default_field: false)
    destination_section = organization.default_section
    question = source_section.profile_questions.last
    Organization.any_instance.stubs(:skype_enabled?).returns(false)
    assert_difference 'destination_section.reload.profile_questions.count' do
      patch :update_profile_question_section, xhr: true, params: { id: question.id, section_id: destination_section.id}
    end
    question.reload
    assert_equal destination_section, assigns[:section]
    assert_equal question, assigns[:profile_question]
    assert_equal question.section_id, destination_section.id
    assert_equal destination_section.profile_questions.last.id, question.id
    assert_match "cjs-profile-question-section-#{destination_section.id}", @response.body
  end

  def test_get_role_question_settings
    current_member_is :f_admin
    current_organization_is members(:f_admin).organization
    role_question = role_questions(:role_questions_1)
    get :get_role_question_settings, xhr: true, params: { id: role_question.profile_question_id, role_id: role_question.role.id, program_id: role_question.program.id}
    assert_match "edit_profile_question_role_settings_#{role_question.profile_question.id}", @response.body
  end

  def test_get_conditional_options
    current_member_is :f_admin
    organization = programs(:org_primary)
    conditional_question = profile_questions(:multi_choice_q)
    profile_question = create_question(:question_text => "About me",
        :question_type => ProfileQuestion::Type::SINGLE_CHOICE,
        :allow_other_option => true,
        :conditional_question_id => conditional_question.id,
        :conditional_match_text => "Stand",
        help_text: "Description")
    get :get_conditional_options, xhr: true, params: { id: profile_question.id, question_id: conditional_question.id}
    assert_match %Q[value=\\\"#{question_choices(:multi_choice_q_1).id}\\\"], @response.body
    assert_match %Q[data-placeholder=\\\"Select...\\\"], @response.body
  end

  def test_export
    program = programs(:ceg)
    current_program_is program
    current_user_is :f_admin
    login_as_super_user
    ProgramExporter.any_instance.expects(:export).once

    get :export
    assert_response :success
  end

  def test_import
    program = programs(:ceg)
    current_program_is program
    current_user_is :f_admin
    login_as_super_user

    mimeType = "application/zip"
    attached_file = Rack::Test::UploadedFile.new(File.join(Rails.root, 'test/fixtures/files/profile_questions.zip'), mimeType)

    assert_nothing_raised do
        post :import, xhr: true, params: {profile_question_file: attached_file}
    end
    assert_response :success
    assert_equal "Profile fields are successfully imported. Please refresh!", flash[:notice]
  end

  def test_import_invalid_attachment
    program = programs(:ceg)
    current_program_is program
    current_user_is :f_admin
    login_as_super_user

    mimeType = "application/jar"
    attached_file = Rack::Test::UploadedFile.new(File.join(Rails.root, 'test/fixtures/files/helloworld.jar'), mimeType)
    post :import, xhr: true, params: {profile_question_file: attached_file}
    assert_response :success
    assert_equal "Failed to import profile fields", assigns(:error_flash)
  end

  private

  def default_restricted_privacy_settings(program)
    settings = RoleQuestionPrivacySetting.restricted_privacy_setting_options_for(program).collect {|setting| setting[:privacy_setting]}
    output = {}
    settings.each do |setting|
      if setting[:setting_type] == RoleQuestionPrivacySetting::SettingType::ROLE
        output[setting[:setting_type].to_s] ||= {}
        output[setting[:setting_type].to_s][setting[:role_id].to_s] = '1'
      else
        output[setting[:setting_type].to_s] = '1'
      end
    end
    {RoleQuestion::PRIVACY_SETTING::RESTRICTED.to_s => output}
  end
end
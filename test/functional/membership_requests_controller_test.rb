require_relative './../test_helper.rb'

class MembershipRequestsControllerTest < ActionController::TestCase

  def setup
    super
    @program = programs(:albers)
    current_program_is @program
    @approve_role = create_role(name: 'approver')
    add_role_permission(@approve_role, 'approve_membership_request')
    add_role_permission(@approve_role, RoleConstants::MANAGEMENT_PERMISSIONS.first)
    @approver = create_user(name: 'approver', role_names: ['approver'])
  end

  def test_signup_options
    mentor_role = @program.find_role(RoleConstants::MENTOR_NAME)
    @program.organization.auth_configs.create!(auth_type: AuthConfig::Type::OPENSSL)

    get :signup_options, xhr: true, params: { roles: [RoleConstants::MENTOR_NAME]}
    assert_response :success
    assert_equal [mentor_role], assigns(:roles)
    assert_equal_unordered @program.organization.auth_configs, assigns(:auth_configs)
    assert_equal 2, assigns(:login_sections).size
    assert_equal_hash({ @program.root => [RoleConstants::MENTOR_NAME] }, @request.session[:signup_roles])
  end

  def test_signup_options_when_join_directly_with_sso
    custom_auth = @program.organization.auth_configs.create!(auth_type: AuthConfig::Type::OPENSSL)
    mentor_role = @program.find_role(RoleConstants::MENTOR_NAME)
    mentor_role.update_attributes!(membership_request: false, join_directly_only_with_sso: true)

    get :signup_options, xhr: true, params: { roles: [RoleConstants::MENTOR_NAME]}
    assert_response :success
    assert_equal [mentor_role], assigns(:roles)
    assert_equal [custom_auth], assigns(:auth_configs)
    assert_equal 1, assigns(:login_sections).size
    assert_equal_hash({ @program.root => [RoleConstants::MENTOR_NAME] }, @request.session[:signup_roles])
  end

  def test_apply_new_member
    @controller.stubs(:simple_captcha_valid?).returns(true)
    Password.any_instance.stubs(:reset_code).returns("signup-code")
    ChronusMailer.expects(:complete_signup_new_member_notification).with(@program, "newmember@chronus.com", [RoleConstants::STUDENT_NAME], "signup-code", { locale: I18n.default_locale } ).once.returns(stub(:deliver_now))
    ChronusMailer.expects(:complete_signup_existing_member_notification).never
    ChronusMailer.expects(:complete_signup_suspended_member_notification).never
    post :apply, params: { roles: RoleConstants::STUDENT_NAME, email: "newmember@chronus.com"}
  end

  def test_apply_existing_member
    @controller.stubs(:simple_captcha_valid?).returns(true)
    user = users(:f_mentor_student)
    assert user.active?
    assert_equal [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], user.role_names
    Password.any_instance.stubs(:reset_code).returns("reset-code")
    ChronusMailer.expects(:complete_signup_existing_member_notification).with(@program, user.member, [RoleConstants::STUDENT_NAME], "reset-code", false).once.returns(stub(:deliver_now))
    ChronusMailer.expects(:complete_signup_new_member_notification).never
    ChronusMailer.expects(:complete_signup_suspended_member_notification).never
    post :apply, params: { roles: RoleConstants::STUDENT_NAME, email: user.email}
  end

  def test_apply_gloablly_suspended_member
    current_program_is :psg
    user = users(:inactive_user)
    assert user.suspended?
    assert user.member.suspended?
    assert_equal [RoleConstants::MENTOR_NAME], user.role_names
    ChronusMailer.expects(:complete_signup_suspended_member_notification).with(programs(:psg), user.member).once.returns(stub(:deliver_now))
    ChronusMailer.expects(:complete_signup_new_member_notification).never
    ChronusMailer.expects(:complete_signup_existing_member_notification).never
    post :apply, params: { roles: RoleConstants::STUDENT_NAME, email: user.email}
  end

  def test_apply_user_suspended_in_program
    user = users(:f_mentor_student)
    suspend_user(user)
    assert user.reload.suspended?
    assert_false user.member.suspended?
    assert_equal [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], user.role_names
    Password.any_instance.stubs(:reset_code).returns("reset-code")
    ChronusMailer.expects(:complete_signup_new_member_notification).never
    ChronusMailer.expects(:complete_signup_existing_member_notification).with(@program, user.member, [RoleConstants::STUDENT_NAME], "reset-code", true).once.returns(stub(:deliver_now))
    ChronusMailer.expects(:complete_signup_suspended_member_notification).never
    post :apply, params: { roles: RoleConstants::STUDENT_NAME, email: user.email}
  end

  def test_apply_captcha_fails
    @controller.stubs(:simple_captcha_valid?).returns(false)
    ChronusMailer.expects(:complete_signup_new_member_notification).never
    post :apply, params: { roles: RoleConstants::STUDENT_NAME, email: "newmember@chronus.com"}
    assert_redirected_to new_membership_request_path
    assert_equal "Word verification failed. Please try again.", flash[:error]
  end

  def test_apply_permission_denied_with_only_sso_roles
    @program.find_role(RoleConstants::MENTOR_NAME).update_attributes(membership_request: false, join_directly_only_with_sso: true)
    assert_permission_denied do
      post :apply, params: { roles: RoleConstants::MENTOR_NAME, email: "newmember@chronus.com"}
    end
  end

  def test_apply_new_not_eligibile_member
    member = members(:f_mentor)
    member.user_in_program(@program).destroy
    @controller.stubs(:simple_captcha_valid?).returns(true)
    Member.any_instance.expects(:can_modify_eligibility_details?).once.returns(false)
    Member.any_instance.expects(:is_eligible_to_join?).once.returns(false, false)
    ChronusMailer.expects(:not_eligible_to_join_notification).once.with(@program, member, [RoleConstants::STUDENT_NAME]).returns(stub(:deliver_now))
    post :apply, params: { roles: RoleConstants::STUDENT_NAME, email: member.email}
  end

  def test_new_unlogged_in_user
    get :new, params: { src: "favorite"}
    assert_response :success
    assert assigns(:only_login)
    assert_equal_unordered [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], assigns(:roles).map(&:name)
    assert_equal "You must be a member of the program to request the mentor.", flash[:notice]
    assert_template :apply_for
  end

  def test_new_with_roles_without_logged_in_or_signup_code
    get :new, params: { roles: RoleConstants::MENTOR_NAME}
    assert_response :success
    assert_equal [RoleConstants::MENTOR_NAME], assigns(:roles).map(&:name)
    assert_template :apply_for
  end

  def test_new_redirect_unlogged_in_user_program_does_not_allow_join_now
    Program.any_instance.stubs(:allow_join_now?).returns(false)
    get :new
    assert_redirected_to program_root_path(root: @program.root)
    assert_match /To join the program, please .*click here.* to contact the administrators./, flash[:notice]
  end

  def test_new_redirect_logged_in_user_program_does_not_allow_join_now
    Program.any_instance.stubs(:allow_join_now?).returns(false)
    current_member_is :f_student
    current_program_is :moderated_program
    get :new
    assert_redirected_to program_root_path(root: programs(:moderated_program).root)
    assert_match /To join the program, please .*click here.* to contact the administrators./, flash[:notice]
  end

  def test_new_redirect_logged_in_user_no_roles_to_join
    @program.find_role(RoleConstants::MENTOR_NAME).update_attribute(:membership_request, false)
    current_member_is :f_student
    get :new
    assert_redirected_to program_root_path(root: @program.root, src: MembershipRequest::Source::MEMBERSHIP_REQUEST_PAGE)
    assert_empty assigns(:can_apply_role_names)
    assert_match /You are already.*Student.*in.*Albers Mentor Program.*/, flash[:notice]
  end

  def test_new_redirect_invalid_signup_code
    get :new, params: { signup_code: "invalid"}
    assert_redirected_to program_root_path
    assert_equal "The signup code is invalid.", flash[:error]
  end

  def test_new_redirect_force_login_if_member_can_signin
    member = members(:f_student)
    assert member.can_signin?
    password = Password.create!(email_id: member.email)

    get :new, params: { signup_code: password.reset_code, roles: RoleConstants::MENTOR_NAME}
    assert_redirected_to login_path(root: @program.root, auth_config_ids: [member.organization.chronus_auth.id])
    assert_equal "Please login to join the program.", flash[:info]
    assert_equal member, assigns(:member)
    assert_equal_hash( { @program.root => { code: password.reset_code, roles: [RoleConstants::MENTOR_NAME] } }, @request.session[:signup_code])
  end

  def test_new_with_member
    current_member_is :f_student
    member = members(:f_student)
    question = create_membership_profile_question(question_text: 'Question', role_names: [RoleConstants::MENTOR_NAME], question_type: ProfileQuestion::Type::STRING)
    profile_answer = member.profile_answers.create!(profile_question: question, answer_text: 'get')
    password = Password.create!(email_id: member.email)
    get :new, params: { signup_code: password.reset_code, roles: RoleConstants::MENTOR_NAME}
    assert_match(/Please complete the registration form provided below. Fields marked with asterisks \(“\*”\) are mandatory. You can edit your profile anytime after signing up/, @response.body)
    assert_equal member, assigns(:member)
    assert assigns(:is_self_view)

    answer_map = assigns(:answer_map)
    answer = answer_map[question.id.to_s]
    assert_equal profile_answer.answer_value, answer.answer_value
    assert_equal ProfileAnswer::PRIORITY::EXISTING, answer.priority
  end

  def test_new_redirect_logout_unlogged_in_user_when_email_differs
    current_member_is :f_student
    password = Password.create!(email_id: "newemail@chronus.com")
    get :new, params: { signup_code: password.reset_code, roles: RoleConstants::MENTOR_NAME}
    assert_redirected_to new_membership_request_path(signup_code: password.reset_code, roles: [RoleConstants::MENTOR_NAME])
    assert_nil @request.session[:member_id]
  end

  def test_new_redirect_applying_multiple_roles_when_not_allowed
    Program.any_instance.stubs(:show_and_allow_multiple_role_memberships?).returns(false)
    get :new, params: { roles: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]}
    assert_redirected_to new_membership_request_path
    assert_equal "Sorry, you can apply for only one role at a time.", flash[:notice]
  end

  def test_new_redirect_unlogged_in_user_can_apply_only_subset_of_roles
    Program.any_instance.stubs(:show_and_allow_multiple_role_memberships?).returns(true)
    @program.find_role(RoleConstants::MENTOR_NAME).update_attribute(:membership_request, false)
    password = Password.create!(email_id: "newemail@chronus.com")
    get :new, params: { signup_code: password.reset_code, roles: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]}
    assert_redirected_to new_membership_request_path(signup_code: password.reset_code, roles: [RoleConstants::STUDENT_NAME])
  end

  def test_new_redirect_with_xhr
    @program.find_role(RoleConstants::MENTOR_NAME).update_attribute(:membership_request, false)
    password = Password.create!(email_id: "newemail@chronus.com")
    get :new, xhr: true, params: { format: :js, signup_code: password.reset_code, roles: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]}
    assert_response :success
    assert_equal "window.location.href = \"#{new_membership_request_path}\";", @response.body
  end

  def test_new_permission_denied_sso_roles
    @program.find_role(RoleConstants::MENTOR_NAME).update_attributes(membership_request: false, join_directly_only_with_sso: true)
    password = Password.create(email_id: "test@example.com")
    assert_permission_denied do
      get :new, params: { signup_code: password.reset_code, roles: [RoleConstants::MENTOR_NAME]}
    end
  end

  def test_new_suspended_user_apply_to_join
    user = users(:inactive_user)
    program = user.program
    assert_equal [RoleConstants::MENTOR_NAME], user.role_names
    assert program.find_role(RoleConstants::MENTOR_NAME).membership_request?
    assert program.find_role(RoleConstants::STUDENT_NAME).membership_request?

    current_user_is user
    get :new
    assert_response :success
    assert_equal "Your profile in #{program.name} is currently not active. To join as <b>Mentor and Student</b>, complete and submit the form below.", flash[:notice]
  end

  def test_new_suspended_user_join_directly
    user = users(:inactive_user)
    member = user.member
    member.update_attribute(:state, Member::Status::ACTIVE)
    program = user.program
    assert_equal [RoleConstants::MENTOR_NAME], user.role_names
    program.find_role(RoleConstants::MENTOR_NAME).update_attributes(membership_request: false, join_directly: true)
    program.find_role(RoleConstants::STUDENT_NAME).update_attributes(membership_request: false, join_directly: true)

    current_user_is user
    get :new
    assert_match /To join as .*Mentor and Student.* complete and submit the form below./, flash[:notice]
  end

  def test_new_logged_in_user_with_favorite_src
    current_user_is :f_mentor
    get :new, params: { src: "favorite"}
    assert_response :success
    assert_select "html"
    assert_equal "You must be a member of the program to request the mentor. You are already <b>Mentor</b> in <b>Albers Mentor Program</b>. To join as <b>Student</b>, complete and submit the form below.", flash[:notice]
  end

  def test_new_logged_in_user_with_favorite_src_flash_not_persisting_to_next_page
    current_user_is :f_mentor
    get :new, params: { src: "favorite"}
    assert_response :success
    assert_select "html"
    assert_equal "You must be a member of the program to request the mentor. You are already <b>Mentor</b> in <b>Albers Mentor Program</b>. To join as <b>Student</b>, complete and submit the form below.", flash[:notice]
    get :signup_options
    assert_nil flash[:notice]
  end

  def test_new_logged_in_user_via_enrollment_applies_for_membership_request_required_role_empty_form_case
    @controller.stubs(:current_root).returns(nil)
    current_member_is :f_student
    mentor_role = @program.roles.where(name: RoleConstants::MENTOR_NAME).first
    assert mentor_role.membership_request
    get :new, params: { roles: RoleConstants::MENTOR_NAME, program: @program.id, from_enrollment: "true"}
    assert assigns(:empty_form)
    assert_redirected_to program_root_path(root: @program.root, src: MembershipRequest::Source::MEMBERSHIP_REQUEST_PAGE)

    assert assigns(:from_enrollment)
    membership_request = assigns(:membership_request)
    assert_equal @program, membership_request.program
    assert_equal false, membership_request.joined_directly
    assert_nil membership_request.accepted_as
  end

  def test_new_logged_in_user_via_enrollment_applies_for_join_directly_role_empty_form_case
    @controller.stubs(:current_root).returns(nil)
    current_member_is :f_student
    mentor_role = @program.roles.where(name: RoleConstants::MENTOR_NAME).first
    mentor_role.update_role_join_settings!(RoleConstants::JoinSetting::JOIN_DIRECTLY)

    get :new, params: { roles: RoleConstants::MENTOR_NAME, program: @program.id, from_enrollment: "true"}
    assert assigns(:empty_form)
    assert_redirected_to edit_member_path(members(:f_student), root: @program.root, first_visit: true, ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION)

    assert assigns(:from_enrollment)
    membership_request = assigns(:membership_request)
    assert_equal @program, membership_request.program
    assert_equal true, membership_request.joined_directly
    assert_equal "mentor", membership_request.accepted_as
  end

  def test_new_logged_in_user_via_enrollment_nonempty_form_case
    @controller.stubs(:current_root).returns(nil)
    current_member_is :f_student
    role_questions = @program.role_questions_for([RoleConstants::MENTOR_NAME], user: nil)
    role_questions.last.update_attribute(:available_for, RoleQuestion::AVAILABLE_FOR::MEMBERSHIP_QUESTIONS)
    assert_equal  RoleQuestion::AVAILABLE_FOR::MEMBERSHIP_QUESTIONS, role_questions.last.reload.available_for

    get :new, params: { roles: RoleConstants::MENTOR_NAME, program: @program.id, from_enrollment: "true"}
    assert_false assigns(:empty_form)
    assert_response :success
    membership_request = assigns(:membership_request)
    assert_equal @program, membership_request.program
    assert assigns(:from_enrollment)
    assert_match "To join as <b>Mentor</b>, complete and submit the form below.", flash[:notice]
  end

  def test_new_logged_in_user_without_roles
    member = members(:f_student)
    current_member_is :f_student
    get :new
    assert_response :success
    assert_false assigns(:from_enrollment)
    membership_request = assigns(:membership_request)
    assert assigns(:section_id_questions_map).present?
    assert assigns(:sections).present?
    assert_false assigns(:no_redirect)
    assert_empty assigns(:roles)
    assert_equal @program.show_and_allow_multiple_role_memberships?, assigns(:is_checkbox)
    assert_equal member.email, membership_request.email
    assert_equal member.first_name, membership_request.first_name
    assert_equal member.last_name, membership_request.last_name
    assert_equal @program, membership_request.program
    assert_match /You are already .*Student.* in .*Albers Mentor Program.*. To join as .*Mentor.*, complete and submit the form below./, flash[:notice]
  end

  def test_new_unlogged_in_user_with_roles
    organization = @program.organization
    password = Password.create(email_id: "test@example.com")
    question = create_membership_profile_question(question_text: 'Question', role_names: [RoleConstants::MENTOR_NAME], question_type: ProfileQuestion::Type::STRING)
    get :new, params: { signup_code: password.reset_code, roles: RoleConstants::MENTOR_NAME}
    assert_response :success
    membership_request = assigns(:membership_request)
    assert_equal [RoleConstants::MENTOR_NAME], assigns(:roles)
    assert_equal_unordered [organization.name_question, organization.email_question, question], assigns(:section_id_questions_map).values.flatten
    assert_equal_unordered [organization.name_question.id, organization.email_question.id], assigns(:required_question_ids)
    assert_equal ({}), assigns(:answer_map)
    assert_equal membership_request.email, password.email_id
    assert_equal [RoleConstants::MENTOR_NAME], membership_request.role_names
    assert_equal "To join as <b>Mentor</b>, complete and submit the form below.", flash[:notice]
  end

  def test_new_unlogged_in_user_with_roles_flash_doesnt_persist
    organization = @program.organization
    password = Password.create(email_id: "test@example.com")
    question = create_membership_profile_question(question_text: 'Question', role_names: [RoleConstants::MENTOR_NAME], question_type: ProfileQuestion::Type::STRING)
    get :new, params: { signup_code: password.reset_code, roles: RoleConstants::MENTOR_NAME}
    assert_response :success
    membership_request = assigns(:membership_request)
    assert_equal [RoleConstants::MENTOR_NAME], assigns(:roles)
    assert_equal_unordered [organization.name_question, organization.email_question, question], assigns(:section_id_questions_map).values.flatten
    assert_equal_unordered [organization.name_question.id, organization.email_question.id], assigns(:required_question_ids)
    assert_equal ({}), assigns(:answer_map)
    assert_equal membership_request.email, password.email_id
    assert_equal [RoleConstants::MENTOR_NAME], membership_request.role_names
    assert_equal "To join as <b>Mentor</b>, complete and submit the form below.", flash[:notice]
    get :signup_options
    assert_nil flash[:notice]
  end

  def test_new_mentor_trying_to_join_as_mentor
    current_user_is :f_mentor
    user = users(:f_mentor)
    password = Password.create(email_id: user.member.email)
    get :new, params: { signup_code: password.reset_code, roles: RoleConstants::MENTOR_NAME}
    assert_equal "You are already <b>Mentor</b> in <b>Albers Mentor Program</b>. To join as <b>Student</b>, complete and submit the form below.", flash[:notice]
    assert_false assigns(:no_redirect)
    assert_redirected_to new_membership_request_path(signup_code: password.reset_code)
  end

  def test_new_mentor_existing_request_trying_to_join_as_mentor
    current_user_is :f_mentor
    user = users(:f_mentor)

    create_membership_request(member: user.member, roles: [RoleConstants::STUDENT_NAME])
    password = Password.create(email_id: user.member.email)
    get :new, params: { signup_code: password.reset_code, roles: RoleConstants::MENTOR_NAME}
    assert_response :success
    assert assigns(:no_redirect)
    assert_match "You are already <b>Mentor</b> in <b>Albers Mentor Program</b>. Your request to join <b>Albers Mentor Program</b> as <b>Student</b> is currently under review", flash[:notice]
  end

  def test_new_external_authenticated_user_without_roles
    auth_config = @program.organization.auth_configs.first
    auth_config.update_attribute(:auth_type, AuthConfig::Type::SAML)

    @request.session[:new_custom_auth_user] = { @program.parent_id => "12345", auth_config_id: auth_config.id }
    @request.session[:new_user_import_data] = { @program.parent_id => { "Member" => { "email" => "test@mail.com", "first_name" => "test", "last_name" => "tester" }  } }
    get :new
    assert_response :success
    membership_request = assigns(:membership_request)
    assert assigns(:section_id_questions_map).present?
    assert assigns(:sections).present?
    assert_empty assigns(:roles)
    assert_equal @program.show_and_allow_multiple_role_memberships?, assigns(:is_checkbox)
    assert_equal "test@mail.com", membership_request.email
    assert_equal "test", membership_request.first_name
    assert_equal "tester", membership_request.last_name
    assert_equal @program, membership_request.program
    assert_empty membership_request.role_names
    assert_equal "To join as <b>Mentor and Student</b>, complete and submit the form below.", flash[:notice]
  end

  def test_new_external_authenticated_user_without_roles_flash_not_going_to_next_page
    auth_config = @program.organization.auth_configs.first
    auth_config.update_attribute(:auth_type, AuthConfig::Type::SAML)

    @request.session[:new_custom_auth_user] = { @program.parent_id => "12345", auth_config_id: auth_config.id }
    get :new
    assert_response :success
    membership_request = assigns(:membership_request)
    assert assigns(:section_id_questions_map).present?
    assert assigns(:sections).present?
    assert_empty assigns(:roles)
    assert_equal @program.show_and_allow_multiple_role_memberships?, assigns(:is_checkbox)
    assert_nil membership_request.email
    assert_equal @program, membership_request.program
    assert_empty membership_request.role_names
    assert_equal "To join as <b>Mentor and Student</b>, complete and submit the form below.", flash[:notice]

    get :signup_options
    assert_nil flash[:notice]
  end

  def test_new_email_is_disabled_if_session_data_import_email_is_present
    auth_config = @program.organization.auth_configs.first
    auth_config.update_attribute(:auth_type, AuthConfig::Type::SAML)

    @request.session[:new_custom_auth_user] = { @program.parent_id => "12345", auth_config_id: auth_config.id }
    @request.session[:new_user_import_data] = { @program.parent_id => { "Member" => { "email" => "test@mail.com", "first_name" => "test", "last_name" => "tester" }  } }
    get :new, params: { roles: RoleConstants::MENTOR_NAME}
    assert_select 'input#membership_request_email', disabled: "disabled", value: "test@mail.com"
  end

  def test_new_show_linkedin_link
    auth_config = @program.organization.auth_configs.first
    auth_config.update_attribute(:auth_type, AuthConfig::Type::SAML)
    question = create_membership_profile_question(question_text: 'Question', role_names: [RoleConstants::MENTOR_NAME], question_type: ProfileQuestion::Type::EXPERIENCE)

    @request.session[:new_custom_auth_user] = { @program.parent_id => "12345", auth_config_id: auth_config.id }
    @request.session[:new_user_import_data] = { @program.parent_id => { "Member" => { "email" => "test@mail.com", "first_name" => "test", "last_name" => "tester" }, "ProfileAnswer" => { question.id => sample_multi_field_question_attributes[:experience] } } }
    get :new, params: { roles: RoleConstants::MENTOR_NAME}
    assert_match 'Click here to import your experience from', response.body
    assert_match /Users.startLinkedIn.*, \&\#39;\&\#39;, \&\#39;#{RoleConstants::MENTOR_NAME}\&\#39;/ , response.body
  end

  def test_new_dont_show_linkedin_link
    auth_config = @program.organization.auth_configs.first
    auth_config.update_attribute(:auth_type, AuthConfig::Type::SAML)
    question = create_membership_profile_question(question_text: 'Question', role_names: [RoleConstants::MENTOR_NAME], question_type: ProfileQuestion::Type::STRING)

    @request.session[:new_custom_auth_user] = { @program.parent_id => "12345", auth_config_id: auth_config.id }
    @request.session[:new_user_import_data] = { @program.parent_id => { "Member" => { "email" => "test@mail.com", "first_name" => "test", "last_name" => "tester" }, "ProfileAnswer" => { question.id => "answer" } } }
    get :new, params: { roles: RoleConstants::MENTOR_NAME}
    assert_no_match(/Click here to import your experience from/, response.body)
  end

  def test_new_external_authenticated_user_with_roles_and_import_attributes
    organization = @program.organization
    auth_config = organization.auth_configs.first
    auth_config.update_attribute(:auth_type, AuthConfig::Type::SAML)
    question = create_membership_profile_question(question_text: 'Question', role_names: [RoleConstants::MENTOR_NAME], question_type: ProfileQuestion::Type::STRING)
    @request.session[:new_custom_auth_user] = { @program.parent_id => "12345", auth_config_id: auth_config.id }
    @request.session[:new_user_import_data] = { @program.parent_id => { "Member" => { "email" => "test@mail.com", "first_name" => "test", "last_name" => "tester" }, "ProfileAnswer" => { question.id => "answer" } } }
    get :new, params: { roles: RoleConstants::MENTOR_NAME}

    profile_answer = ProfileAnswer.new(profile_question_id: question.id)
    profile_answer.answer_value = "answer"
    profile_answer.priority = ProfileAnswer::PRIORITY::IMPORTED
    answer_map = assigns(:answer_map)
    answer = answer_map[question.id.to_s]

    assert_response :success
    membership_request = assigns(:membership_request)
    assert_equal [RoleConstants::MENTOR_NAME], assigns(:roles)
    assert_equal_unordered [organization.name_question, organization.email_question, question], assigns(:section_id_questions_map).values.flatten
    assert_equal_unordered [organization.name_question.id, organization.email_question.id], assigns(:required_question_ids)

    assert_equal profile_answer.answer_value, answer.answer_value
    assert_equal ProfileAnswer::PRIORITY::IMPORTED, answer.priority
    assert_equal question.id, answer.profile_question_id

    assert_equal "test", membership_request.first_name
    assert_equal "tester", membership_request.last_name
    assert_equal "test@mail.com", membership_request.email
    assert_equal [RoleConstants::MENTOR_NAME], membership_request.role_names
    assert_equal "To join as <b>Mentor</b>, complete and submit the form below.", flash[:notice]
  end

  def test_new_user_from_other_program_with_roles_and_profile_answers
    albers_member = members(:robert)
    program = programs(:moderated_program)
    organization = program.organization
    education_question = create_membership_profile_question(question_text: 'Education', program: program, question_type: ProfileQuestion::Type::EDUCATION)
    experience_question = create_membership_profile_question(question_text: 'Experience', program: program, question_type: ProfileQuestion::Type::EXPERIENCE)
    manager_question = organization.profile_questions.manager_questions.first
    publication_question = create_membership_profile_question(question_text: 'Publication', program: program, question_type: ProfileQuestion::Type::PUBLICATION)
    file_question = create_membership_profile_question(question_text: 'Upload File', program: program, question_type: ProfileQuestion::Type::FILE)
    string_question = create_membership_profile_question(question_text: 'String', program: program, question_type: ProfileQuestion::Type::STRING)

    current_member_is albers_member
    current_program_is program

    file_uploader = FileUploader.new(file_question.id, albers_member.id.to_s, fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text'), base_path: ProfileAnswer::TEMP_BASE_PATH)
    file_uploader.save

    params = {
      roles: RoleConstants::MENTOR_NAME,
      "question_#{file_question.id}_code" => file_uploader.uniq_code,
      profile_answers: {
        education_question.id => sample_multi_field_question_attributes[:education],
        experience_question.id => sample_multi_field_question_attributes[:experience],
        publication_question.id => sample_multi_field_question_attributes[:publication],
        manager_question.id => sample_multi_field_question_attributes[:manager],
        file_question.id => "some_file.txt",
        string_question.id => "string answer"
      }
    }

    get :new, params: params
    assert_response :success

    assert_equal [RoleConstants::MENTOR_NAME], assigns(:roles)
    membership_request = assigns(:membership_request)
    answer_map = assigns(:answer_map)

    assert_equal ["CEG", "BTECH"], answer_map[education_question.id.to_s].educations.first.attributes.values_at("school_name", "degree")
    assert_equal ProfileAnswer::PRIORITY::IMPORTED, answer_map[education_question.id.to_s].priority
    assert_equal ["Chronus"], answer_map[experience_question.id.to_s].experiences.first.attributes.values_at("company")
    assert_equal ["title1"], answer_map[publication_question.id.to_s].publications.first.attributes.values_at("title")
    assert_equal "some_file.txt", answer_map[file_question.id.to_s].temp_file_name
    assert_equal file_uploader.uniq_code, answer_map[file_question.id.to_s].temp_file_code
    assert_equal albers_member, answer_map[file_question.id.to_s].ref_obj
    assert_equal "manager@example.com", answer_map[manager_question.id.to_s].manager.email
    assert_equal "string answer", answer_map[string_question.id.to_s].answer_text

    assert_equal albers_member.first_name, membership_request.first_name
    assert_equal albers_member.last_name, membership_request.last_name
    assert_equal albers_member.email, membership_request.email
    assert_equal [RoleConstants::MENTOR_NAME], membership_request.role_names
    assert_equal "To join as <b>Mentor</b>, complete and submit the form below.", flash[:notice]
    assert_match /Users.startLinkedIn.*, \&\#39;#{albers_member.id}\&\#39;, \&\#39;#{RoleConstants::MENTOR_NAME}\&\#39;/ , response.body
  end

  def test_user_entered_profile_answers_over_writes_session_imported_profile_answers
    organization = @program.organization
    auth_config = organization.auth_configs.first
    auth_config.update_attribute(:auth_type, AuthConfig::Type::SAML)
    question = create_membership_profile_question(question_text: 'Question', role_names: [RoleConstants::MENTOR_NAME], question_type: ProfileQuestion::Type::STRING)
    @request.session[:new_custom_auth_user] = { @program.parent_id => "12345", auth_config_id: auth_config.id }
    @request.session[:new_user_import_data] = { @program.parent_id => {
      "Member" => { "email" => "test@mail.com", "first_name" => "test", "last_name" => "tester" },
      "ProfileAnswer" => { question.id => "answer" }
    } }

    get :new, params: { roles: RoleConstants::MENTOR_NAME, profile_answers: { question.id => "Updated Answer" }}
    assert_response :success

    answer_map = assigns(:answer_map)
    assert_equal "Updated Answer", answer_map[question.id.to_s].answer_text
  end

  def test_new_logged_in_user_with_conditional_questions
    conditional_question = create_question(role_names: [RoleConstants::STUDENT_NAME], question_text: "Conditional question", program: programs(:moderated_program), question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_choices: ["a", "b", "c"], available_for: RoleQuestion::AVAILABLE_FOR::BOTH)
    dependent_question = create_question(role_names: [RoleConstants::STUDENT_NAME], question_text: "Dependent question", program: programs(:moderated_program), available_for: RoleQuestion::AVAILABLE_FOR::BOTH, conditional_question_id: conditional_question.id, conditional_match_text: "a")
    create_role_question(profile_question: conditional_question, program: @program, role_names: [RoleConstants::STUDENT_NAME])
    create_role_question(profile_question: dependent_question, program: @program, role_names: [RoleConstants::STUDENT_NAME])
    current_member_is :f_student
    current_program_is :moderated_program
    get :new, xhr: true, params: { roles: [RoleConstants::STUDENT_NAME]}
    assert_response :success
    assert assigns(:section_id_questions_map).values.flatten.include?(conditional_question)
    assert assigns(:section_id_questions_map).values.flatten.include?(dependent_question)
  end

  def test_new_logged_in_user_with_answer_match_for_conditional_question
    conditional_question = create_question(role_names: [RoleConstants::STUDENT_NAME], question_text: "Conditional question", program: programs(:moderated_program), question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_choices: ["a", "b", "c"], available_for: RoleQuestion::AVAILABLE_FOR::BOTH)
    dependent_question = create_question(role_names: [RoleConstants::STUDENT_NAME], question_text: "Dependent question", program: programs(:moderated_program), available_for: RoleQuestion::AVAILABLE_FOR::BOTH, conditional_question_id: conditional_question.id, conditional_match_text: "a")
    create_role_question(profile_question: conditional_question, program: @program, role_names: [RoleConstants::STUDENT_NAME])
    create_role_question(profile_question: dependent_question, program: @program, role_names: [RoleConstants::STUDENT_NAME])
    ProfileAnswer.create!(profile_question: conditional_question, ref_obj: members(:f_student), answer_value: "a")

    current_member_is :f_student
    current_program_is :moderated_program
    get :new, xhr: true, params: { roles: [RoleConstants::STUDENT_NAME]}
    assert_response :success
    assert assigns(:section_id_questions_map).values.flatten.include?(conditional_question)
    assert assigns(:section_id_questions_map).values.flatten.include?(dependent_question)
  end

  def test_new_logged_in_user_with_no_answer_match_for_conditional_question
    conditional_question = create_question(role_names: [RoleConstants::STUDENT_NAME], question_text: "Conditional question", program: programs(:moderated_program), question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_choices: ["a", "b", "c"], available_for: RoleQuestion::AVAILABLE_FOR::BOTH)
    dependent_question = create_question(role_names: [RoleConstants::STUDENT_NAME], question_text: "Dependent question", program: programs(:moderated_program), available_for: RoleQuestion::AVAILABLE_FOR::BOTH, conditional_question_id: conditional_question.id, conditional_match_text: "a")
    create_role_question(profile_question: conditional_question, program: @program, role_names: [RoleConstants::STUDENT_NAME])
    create_role_question(profile_question: dependent_question, program: @program, role_names: [RoleConstants::STUDENT_NAME])
    ProfileAnswer.create!(profile_question: conditional_question, ref_obj: members(:f_student), answer_value: "b")

    current_member_is :f_student
    current_program_is :moderated_program
    get :new, xhr: true, params: { roles: [RoleConstants::STUDENT_NAME]}
    assert_response :success
    assert_false assigns(:section_id_questions_map).include?(conditional_question)
    assert_false assigns(:section_id_questions_map).include?(dependent_question)
  end

  def test_new_skip_terms_and_conditions_acceptance_for_membership_request_with_empty_form_case
    member = members(:f_student)
    member.update_attribute :terms_and_conditions_accepted, nil

    current_member_is member
    get :new, params: { roles: RoleConstants::MENTOR_NAME}
    # Although its an empty form but we need to show the page as the user needs to accept T & C
    assert_response :success
  end

  def test_create_suspended_user_join_directly_should_create_membership_request_without_accepting
    user = users(:inactive_user)
    member = user.member
    member.update_attribute(:state, Member::Status::ACTIVE)
    program = user.program
    assert_equal [RoleConstants::MENTOR_NAME], user.role_names
    program.find_role(RoleConstants::MENTOR_NAME).update_attributes(membership_request: false, join_directly: true)
    program.find_role(RoleConstants::STUDENT_NAME).update_attributes(membership_request: false, join_directly: true)
    current_program_is program
    current_user_is user
    assert_difference "MembershipRequest.count" do
      post :create, params: { membership_request: { first_name: member.first_name, last_name: member.last_name }, roles: RoleConstants::MENTOR_NAME}
    end
    assert_response :redirect
    assert_redirected_to program_root_path(root: program.root, src: MembershipRequest::Source::MEMBERSHIP_REQUEST_PAGE)

    membership_request = MembershipRequest.last
    assert_equal "inactivementor@albers.com", membership_request.email
    assert_equal MembershipRequest::Status::UNREAD, membership_request.status
    assert_false membership_request.joined_directly
    assert_nil membership_request.accepted_as
    assert_equal [RoleConstants::MENTOR_NAME], membership_request.role_names
  end

  def test_create_for_eligible_roles_for_suspended_user_should_not_accept_membership_request
    question = create_membership_profile_question(question_text: 'Question', role_names: [RoleConstants::MENTOR_NAME], question_type: ProfileQuestion::Type::STRING)
    password = Password.create(email_id: "newmember@chronus.com")
    @program.enable_feature(FeatureName::MEMBERSHIP_ELIGIBILITY_RULES, true)
    role = @program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    role.update_attribute(:eligibility_rules, true)

    user = @program.users.last
    member = user.member
    member.update_attribute(:state, Member::Status::ACTIVE)
    user.update_attribute(:state, User::Status::SUSPENDED)

    current_program_is @program
    current_user_is user

    admin_view = AdminView.create!(program: @program.organization, role_id: role.id, title: "New View", filter_params: AdminView.convert_to_yaml({
      profile: {questions: {question_1: {question: "#{question.id}", operator: AdminViewsHelper::QuestionType::WITH_VALUE.to_s, value: "answer"}}},
      program_role_state: {AdminView::ProgramRoleStateFilterObjectKey::ALL_MEMBERS => true}
    }))
    assert_difference "MembershipRequest.count" do
      post :create, params: { membership_request: { first_name: member.first_name, last_name: member.last_name }, roles: RoleConstants::MENTOR_NAME, profile_answers: { question.id => "answer" }}
    end
    assert_response :redirect
    assert_redirected_to program_root_path(root: @program.root, src: MembershipRequest::Source::MEMBERSHIP_REQUEST_PAGE)

    assert_nil assigns(:answer_map)
    membership_request = assigns(:membership_request)
    assert_equal member.email, membership_request.email
    assert_equal MembershipRequest::Status::UNREAD, membership_request.status
    assert_false membership_request.joined_directly
    assert_nil membership_request.accepted_as
    assert_equal [RoleConstants::MENTOR_NAME], membership_request.role_names
    assert assigns(:eligible_to_join)
  end

  def test_create_unlogged_in_user_join_directly_with_sso_with_import_data_using_a_different_mail_from_the_one_imported
    @program.find_role(RoleConstants::MENTOR_NAME).update_attributes(membership_request: false, join_directly_only_with_sso: true)
    auth_config = @program.organization.auth_configs.first
    auth_config.update_attributes(auth_type: AuthConfig::Type::SAML)
    @request.session[:new_custom_auth_user] = { @program.parent_id => "12345", auth_config_id: auth_config.id }
    @request.session[:new_user_import_data] = { @program.parent_id => { "Member" => { "email" => "test@mail.com", "first_name" => "test", "last_name" => "tester" }  } }
    @request.session[:signup_roles] = { @program.root => [RoleConstants::MENTOR_NAME] }

    Airbrake.expects(:notify).never
    assert_difference "Member.count" do
      assert_difference "User.count" do
        assert_difference "MembershipRequest.count" do
          post :create, params: { membership_request: { first_name: "New", last_name: "Member", email: "newmember@chronus.com" }, roles: RoleConstants::MENTOR_NAME}
        end
      end
    end
    membership_request = assigns(:membership_request)
    assert_equal "New", membership_request.first_name
    assert_equal "Member", membership_request.last_name
    assert_equal "test@mail.com", membership_request.email
    assert membership_request.joined_directly?
    member = assigns(:member)
    assert_equal "New", member.first_name
    assert_equal "Member", member.last_name
    assert_equal "test@mail.com", member.email
    assert_nil member.crypted_password
    user = assigns(:new_user)
    assert_redirected_to edit_member_path(member, first_visit: user.role_names.to_sentence(last_word_connector: " #{'display_string.and'.translate} ").downcase, ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION)
  end

  def test_create_profile_update_from_membership_request
    programs(:org_no_subdomain).profile_questions.destroy_all
    current_member_is members(:dormant_member)
    member = members(:dormant_member)
    conditional_question = create_question(organization: programs(:org_no_subdomain), program: programs(:no_subdomain), role_names: [RoleConstants::MENTOR_NAME], question_text: "a conditional question", question_type: ProfileQuestion::Type::SINGLE_CHOICE, available_for: RoleQuestion::AVAILABLE_FOR::BOTH, question_choices: ["some text that wont match", "no match"])
    dependent_question = create_question(organization: programs(:org_no_subdomain), program: programs(:no_subdomain), role_names: [RoleConstants::MENTOR_NAME], question_text: "dependent question", question_type: ProfileQuestion::Type::TEXT, available_for: RoleQuestion::AVAILABLE_FOR::BOTH, conditional_question_id: conditional_question.id, conditional_match_text: "some text that wont match")
    pa1 = ProfileAnswer.create!(profile_question: dependent_question, ref_obj: members(:dormant_member), answer_text: 'Conditional answer')
    assert members(:dormant_member).profile_answers.include?(pa1)
    post :create, params: { membership_request: { first_name: member.first_name, last_name: member.last_name }, roles: RoleConstants::MENTOR_NAME, profile_answers: { conditional_question.id => "no match" }, password: "123456", password_confirmation: "123456"}
    assert_false members(:dormant_member).profile_answers.include?(pa1)
  end

  def test_create_profile_update_from_membership_request_profile_answer_kept_intact
    programs(:org_no_subdomain).profile_questions.destroy_all
    current_member_is members(:dormant_member)
    member = members(:dormant_member)
    conditional_question = create_question(organization: programs(:org_no_subdomain), program: programs(:no_subdomain), role_names: [RoleConstants::MENTOR_NAME], question_text: "a conditional question", question_type: ProfileQuestion::Type::SINGLE_CHOICE, available_for: RoleQuestion::AVAILABLE_FOR::BOTH, question_choices: "match_1,match_2,match_3")
    dependent_question = create_question(organization: programs(:org_no_subdomain), program: programs(:no_subdomain), role_names: [RoleConstants::MENTOR_NAME], question_text: "dependent question", question_type: ProfileQuestion::Type::TEXT, available_for: RoleQuestion::AVAILABLE_FOR::BOTH, conditional_question_id: conditional_question.id, conditional_match_text: "match_1")
    pa1 = ProfileAnswer.create!(profile_question: dependent_question, ref_obj: members(:dormant_member), answer_text: 'Conditional answer')
    assert members(:dormant_member).profile_answers.include?(pa1)
    post :create, params: { membership_request: { first_name: member.first_name, last_name: member.last_name }, roles: RoleConstants::MENTOR_NAME, profile_answers: { conditional_question.id => "match_1" }, password: "123456", password_confirmation: "123456"}
    assert members(:dormant_member).profile_answers.include?(pa1)
  end

  def test_create_failure_unlogged_in_user_no_password
    question = create_membership_profile_question(question_text: 'Question', role_names: [RoleConstants::MENTOR_NAME], question_type: ProfileQuestion::Type::STRING)
    password = Password.create(email_id: "newmember@chronus.com")
    Airbrake.expects(:notify).never
    assert_no_difference "Member.count" do
      assert_no_difference "User.count" do
        assert_no_difference "MembershipRequest.count" do
          post :create, params: { membership_request: { first_name: "New", last_name: "Member" }, roles: RoleConstants::MENTOR_NAME, signup_code: password.reset_code,
            profile_answers: { question.id => "answer" }, password: "123", password_confirmation: "123"
          }
        end
      end
    end
    assert_template :new

    profile_answer = ProfileAnswer.new(profile_question_id: question.id)
    profile_answer.answer_value = "answer"
    profile_answer.priority = ProfileAnswer::PRIORITY::IMPORTED
    answer_map = assigns(:answer_map)
    answer = answer_map[question.id.to_s]
    assert_equal profile_answer.answer_value, answer.answer_value
    assert_equal ProfileAnswer::PRIORITY::IMPORTED, answer.priority
    assert_equal question.id, answer.profile_question_id

    membership_request = assigns(:membership_request)
    assert_equal "New", membership_request.first_name
    assert_equal "Member", membership_request.last_name
    assert_equal "newmember@chronus.com", membership_request.email
    assert_nil assigns(:member)
    assert assigns(:log_error)
    assert assigns(:invalid_password)
    assert_empty assigns(:invalid_answer_details)
    assert_false assigns(:is_checkbox)
    assert_false assigns(:valid_member)
  end

  def test_create_fail_for_invalid_email_domain_through_security_setting
    security_setting = programs(:org_primary).security_setting
    security_setting.update_attribute :email_domain, "  gmail.com, chronus.com     "
    password = Password.create(email_id: "newmember@test.com")
    assert_no_difference "MembershipRequest.count" do
      post :create, params: { membership_request: { first_name: "New", last_name: "Member" }, roles: RoleConstants::MENTOR_NAME, signup_code: password.reset_code,
        password: "123456", password_confirmation: "123456"
      }
    end
  end

  def test_create_logged_in_user_apply_to_join_create_membership_request_email_domain_through_security_setting
    security_setting = programs(:org_primary).security_setting
    security_setting.update_attribute :email_domain, "  gmail.com, chronus.com     "
    member = members(:f_student)
    current_member_is member
    assert_no_difference "Member.count" do
      assert_no_difference "User.count" do
        assert_difference "MembershipRequest.count" do
          post :create, params: { membership_request: { first_name: "New", last_name: "Member", roles: RoleConstants::MENTOR_NAME },
            password: "123", password_confirmation: "123"
          }
        end
      end
    end
  end

  def test_create_success_for_valid_email_domain_through_security_setting
    security_setting = programs(:org_primary).security_setting
    security_setting.update_attribute :email_domain, "  gmail.com, chronus.com     "
    password = Password.create(email_id: "newmember@chronus.com")
    assert_difference "MembershipRequest.count" do
      post :create, params: { membership_request: { first_name: "New", last_name: "Member" }, roles: RoleConstants::MENTOR_NAME, signup_code: password.reset_code,
        password: "123456", password_confirmation: "123456"
      }
    end
  end

  def test_create_unlogged_in_user_apply_to_join
    current_locale_is :de
    create_organization_language(organization: @program.organization, enabled: OrganizationLanguage::EnabledFor::ALL)
    question = create_membership_profile_question(question_text: 'Question', role_names: [RoleConstants::MENTOR_NAME], question_type: ProfileQuestion::Type::STRING)
    password = Password.create(email_id: "newmember@chronus.com")
    @controller.expects(:welcome_the_new_user).never
    Airbrake.expects(:notify).never
    assert_difference "Member.count" do
      assert_no_difference "User.count" do
        assert_difference "MembershipRequest.count" do
          post :create, params: { membership_request: { first_name: "New", last_name: "Member" }, roles: RoleConstants::MENTOR_NAME, signup_code: password.reset_code,
            password: "123456", password_confirmation: "123456", profile_answers: { question.id => "answer" },
            time_zone: "Asia/Kolkata", signup_terms: "true"
          }
        end
      end
    end
    membership_request = assigns(:membership_request)
    assert_equal "New", membership_request.first_name
    assert_equal "Member", membership_request.last_name
    assert_equal "newmember@chronus.com", membership_request.email
    assert_false membership_request.joined_directly?
    assert membership_request.pending?
    member = assigns(:member)
    assert_equal :de, Language.for_member(member)
    assert_equal "New", member.first_name
    assert_equal "Member", member.last_name
    assert_equal "newmember@chronus.com", member.email
    assert member.dormant?
    assert member.can_signin?
    assert_equal "Asia/Kolkata", member.time_zone
    assert member.terms_and_conditions_accepted?
    assert_equal "answer", member.answer_for(question).answer_text
    assert_equal [@program.organization.chronus_auth], member.auth_configs
    assert_nil assigns(:is_checkbox)
    assert_nil assigns(:answer_map)
    assert_equal "[[ Ýóůř řéƣůéšť ĥáš ƀééɳ šéɳť ťó ťĥé program administrators. Ýóů ŵíłł řéčéíνé áɳ éɱáíł óɳčé ťĥé řéƣůéšť íš áččéƿťéď. ]]", flash[:notice]
    assert_redirected_to program_root_path(root: @program.root, src: MembershipRequest::Source::MEMBERSHIP_REQUEST_PAGE)
  end

  def test_create_unlogged_in_user_join_directly
    current_locale_is :de
    @program.find_role(RoleConstants::MENTOR_NAME).update_attributes(membership_request: false, join_directly: true)
    question = create_membership_profile_question(question_text: 'Question', role_names: [RoleConstants::MENTOR_NAME], question_type: ProfileQuestion::Type::STRING)
    password = Password.create(email_id: "newmember@chronus.com")
    Airbrake.expects(:notify).never
    assert_difference "Member.count" do
      assert_difference "User.count" do
        assert_difference "MembershipRequest.count" do
          post :create, params: { membership_request: { first_name: "New", last_name: "Member" }, roles: RoleConstants::MENTOR_NAME, signup_code: password.reset_code,
            password: "123456", password_confirmation: "123456", profile_answers: { question.id => "answer" }, signup_terms: "true"
          }
        end
      end
    end
    membership_request = assigns(:membership_request)
    assert_equal "New", membership_request.first_name
    assert_equal "Member", membership_request.last_name
    assert_equal "newmember@chronus.com", membership_request.email
    assert membership_request.joined_directly?
    assert membership_request.accepted?
    assert RoleConstants::MENTOR_NAME, membership_request.accepted_as
    member = assigns(:member)
    assert_equal :de, Language.for_member(member)
    assert_equal "New", member.first_name
    assert_equal "Member", member.last_name
    assert_equal "newmember@chronus.com", member.email
    assert member.active?
    assert member.can_signin?
    assert member.terms_and_conditions_accepted?
    assert_equal "answer", member.answer_for(question).answer_text
    assert_equal [@program.organization.chronus_auth], member.auth_configs
    user = assigns(:new_user)
    assert_equal [RoleConstants::MENTOR_NAME], user.role_names
    assert_nil assigns(:is_checkbox)
    assert_nil assigns(:answer_map)
    assert_equal member.id, @request.session[:member_id]
    assert_equal "[[ Ŵéłčóɱé ťó Albers Mentor Program. Рłéášé čóɱƿłéťé ýóůř óɳłíɳé ƿřóƒíłé ťó ƿřóčééď. ]]", flash[:notice]
    assert_nil Password.find_by(email_id: member.email)
    assert_redirected_to edit_member_path(member, first_visit: user.role_names.to_sentence(last_word_connector: " #{'display_string.and'.translate} ").downcase, ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION)
  end

  def test_create_unlogged_in_user_signup_terms_not_sent
    current_locale_is :de
    @program.find_role(RoleConstants::MENTOR_NAME).update_attributes(membership_request: false, join_directly: true)
    question = create_membership_profile_question(question_text: 'Question', role_names: [RoleConstants::MENTOR_NAME], question_type: ProfileQuestion::Type::STRING)
    password = Password.create(email_id: "newmember@chronus.com")
    Airbrake.expects(:notify).never
    assert_difference "Member.count" do
      assert_difference "User.count" do
        assert_difference "MembershipRequest.count" do
          post :create, params: { membership_request: { first_name: "New", last_name: "Member" }, roles: RoleConstants::MENTOR_NAME, signup_code: password.reset_code,
            password: "123456", password_confirmation: "123456", profile_answers: { question.id => "answer" }}
        end
      end
    end
    assert_nil assigns(:member).terms_and_conditions_accepted
  end

  def test_create_skip_terms_and_conditions_acceptance_for_membership_request_create
    member = members(:f_student)
    member.update_attribute :terms_and_conditions_accepted, nil
    current_member_is member
    assert_difference "MembershipRequest.count" do
      post :create, params: { membership_request: { first_name: member.first_name, last_name: member.last_name }, roles: RoleConstants::MENTOR_NAME, signup_terms: "true"}
    end
    assert_response :redirect
    assert_redirected_to program_root_path(src: MembershipRequest::Source::MEMBERSHIP_REQUEST_PAGE)
    assert member.reload.terms_and_conditions_accepted
  end

  def test_create_unlogged_in_user_join_directly_with_sso
    current_locale_is :de
    @program.find_role(RoleConstants::MENTOR_NAME).update_attributes(membership_request: false, join_directly_only_with_sso: true)
    auth_config = @program.organization.auth_configs.first
    auth_config.update_attributes(auth_type: AuthConfig::Type::SAML)
    @request.session[:new_custom_auth_user] = { @program.parent_id => "12345", auth_config_id: auth_config.id }
    @request.session[:linkedin_access_token] = "li123"
    @request.session[:signup_roles] = { @program.root => [RoleConstants::MENTOR_NAME] }
    question = create_membership_profile_question(question_text: 'Question', role_names: [RoleConstants::MENTOR_NAME], question_type: ProfileQuestion::Type::STRING)

    Airbrake.expects(:notify).never
    assert_difference "Member.count" do
      assert_difference "User.count" do
        assert_difference "MembershipRequest.count" do
          post :create, params: { membership_request: { first_name: "New", last_name: "Member", email: "newmember@chronus.com" }, roles: RoleConstants::MENTOR_NAME,
            profile_answers: { question.id => "answer" }, signup_terms: "true"
          }
        end
      end
    end
    membership_request = assigns(:membership_request)
    assert_equal "New", membership_request.first_name
    assert_equal "Member", membership_request.last_name
    assert_equal "newmember@chronus.com", membership_request.email
    assert membership_request.joined_directly?
    member = assigns(:member)
    assert_equal :de, Language.for_member(member)
    assert_equal "New", member.first_name
    assert_equal "Member", member.last_name
    assert_equal "newmember@chronus.com", member.email
    assert member.active?
    assert_nil member.crypted_password
    assert_equal "12345", member.login_identifiers.first.identifier
    assert_equal "li123", member.linkedin_access_token
    assert member.can_signin?
    assert member.terms_and_conditions_accepted?
    assert_equal "answer", member.answer_for(question).answer_text
    assert_equal [auth_config], member.auth_configs
    user = assigns(:new_user)
    assert_equal [RoleConstants::MENTOR_NAME], user.role_names
    assert_nil assigns(:is_checkbox)
    assert_nil assigns(:answer_map)
    assert_equal member.id, @request.session[:member_id]
    assert_nil @request.session[:signup_roles]
    assert_equal "[[ Ŵéłčóɱé ťó Albers Mentor Program. Рłéášé čóɱƿłéťé ýóůř óɳłíɳé ƿřóƒíłé ťó ƿřóčééď. ]]", flash[:notice]
    assert_redirected_to edit_member_path(member, first_visit: user.role_names.to_sentence(last_word_connector: " #{'display_string.and'.translate} ").downcase, ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION)
  end

  def test_create_redirect_duplicate_request
    member = members(:dormant_member)
    password = Password.create(email_id: member.email)
    assert_difference "MembershipRequest.count" do
      create_membership_request(member: member, roles: [RoleConstants::MENTOR_NAME])
    end

    current_member_is member
    current_program_is :albers
    assert_no_difference "Member.count" do
      assert_no_difference "User.count" do
        assert_no_difference "MembershipRequest.count" do
          post :create, params: { membership_request: { first_name: "New", last_name: "Member" }, roles: RoleConstants::MENTOR_NAME, signup_code: password.reset_code }
        end
      end
    end

    assert_redirected_to new_membership_request_path(root: @program.root, signup_code: password.reset_code)
    assert_match /Your request to join .*#{@program.name}.* is currently under review./, flash[:notice]
  end

  def test_create_permission_denied_when_not_authenticated_externally_for_roles_only_with_sso
    @program.find_role(RoleConstants::MENTOR_NAME).update_attributes(membership_request: false, join_directly_only_with_sso: true)
    password = Password.create(email_id: "newmember@mail.com")
    assert_permission_denied do
      post :create, params: { membership_request: { first_name: "New", last_name: "Member" }, roles: RoleConstants::MENTOR_NAME, signup_code: password.reset_code,
        password: "123456", password_confirmation: "123456"
      }
    end
  end

  def test_create_when_member_who_can_signin_has_logged_in_externally
    member = members(:f_student)
    organization = @program.organization
    password = Password.create(email_id: member.email)

    @request.session[:new_custom_auth_user] = { organization.id => "12345", auth_config_id: organization.linkedin_oauth.id }
    post :create, params: { membership_request: { first_name: "New", last_name: "Member" }, roles: RoleConstants::MENTOR_NAME, signup_code: password.reset_code}
    assert_redirected_to login_path(root: @program.root, auth_config_ids: [organization.chronus_auth.id])
    assert_equal "The user associated with email #{member.email} is already part of the program. Please <a href=\"/p/albers/login\">login</a> using appropriate credentials.", flash[:error]
    assert_nil @request.session[:new_custom_auth_user]
  end

  def test_create_force_login_if_member_can_signin
    password = Password.create(email_id: members(:f_mentor).email)

    assert_no_difference "MembershipRequest.count" do
      post :create, params: { membership_request: { first_name: "New", last_name: "Member" }, roles: RoleConstants::MENTOR_NAME, signup_code: password.reset_code}
    end
    assert_redirected_to login_path(root: @program.root, auth_config_ids: [@program.organization.chronus_auth.id])
    assert_equal "Please login to join the program.", flash[:info]
  end

  def test_create_logged_in_user_apply_to_join
    member = members(:f_student)
    current_member_is member
    question = create_membership_profile_question(question_text: 'Question', role_names: [RoleConstants::MENTOR_NAME], question_type: ProfileQuestion::Type::ORDERED_OPTIONS, question_choices: ["a", "b", "c"], options_count: 2)

    dj_stub = mock()
    Member.expects(:delay).returns(dj_stub).once
    dj_stub.expects(:clear_invalid_answers).once
    Matching.expects(:perform_users_delta_index_and_refresh_later).once
    @controller.expects(:welcome_the_new_user).never
    Airbrake.expects(:notify).never
    assert_no_difference "Member.count" do
      assert_no_difference "User.count" do
        assert_difference "MembershipRequest.count" do
          post :create, params: { membership_request: { first_name: "New", last_name: "Member", roles: RoleConstants::MENTOR_NAME },
            password: "123", password_confirmation: "123", profile_answers: { question.id => { "0" => "a", "1" => "b" } }, signup_terms: "true"
          }
        end
      end
    end
    membership_request = assigns(:membership_request)
    assert_equal "student", membership_request.first_name
    assert_equal "example", membership_request.last_name
    assert_equal "rahim@example.com", membership_request.email
    assert_false membership_request.joined_directly?
    assert membership_request.pending?
    member = assigns(:member)
    assert_equal "student", member.first_name
    assert_equal "example", member.last_name
    assert_equal "rahim@example.com", member.email
    assert member.active?
    assert member.can_signin?
    assert member.terms_and_conditions_accepted?
    assert_equal "a | b", member.answer_for(question).answer_text
    assert_nil assigns(:is_checkbox)
    assert_nil assigns(:answer_map)
    assert_equal "Your request has been sent to the program administrators. You will receive an email once the request is accepted.", flash[:notice]
    assert_redirected_to program_root_path(root: @program.root, src: MembershipRequest::Source::MEMBERSHIP_REQUEST_PAGE)
  end

  def test_create_logged_in_user_join_directly
    @program.find_role(RoleConstants::MENTOR_NAME).update_attributes(membership_request: false, join_directly: true)
    member = members(:f_student)
    current_member_is member
    question = create_membership_profile_question(question_text: 'Question', role_names: [RoleConstants::MENTOR_NAME], question_type: ProfileQuestion::Type::STRING)

    dj_stub = mock()
    Member.expects(:delay).returns(dj_stub).once
    dj_stub.expects(:clear_invalid_answers).once
    Matching.expects(:perform_users_delta_index_and_refresh_later).twice
    @controller.expects(:welcome_the_new_user).never
    Airbrake.expects(:notify).never
    assert_no_difference "Member.count" do
      assert_no_difference "User.count" do
        assert_difference "MembershipRequest.count" do
          post :create, params: { membership_request: { first_name: "New", last_name: "Member", roles: RoleConstants::MENTOR_NAME },
            profile_answers: { question.id => "answer" }
          }
        end
      end
    end
    membership_request = assigns(:membership_request)
    assert_equal "student", membership_request.first_name
    assert_equal "example", membership_request.last_name
    assert_equal "rahim@example.com", membership_request.email
    assert membership_request.joined_directly?
    assert membership_request.accepted?
    assert_equal RoleConstants::MENTOR_NAME, membership_request.accepted_as
    member = assigns(:member)
    assert_equal "student", member.first_name
    assert_equal "example", member.last_name
    assert_equal "rahim@example.com", member.email
    assert member.active?
    assert member.can_signin?
    assert member.terms_and_conditions_accepted?
    assert_equal "answer", member.answer_for(question).answer_text
    assert_nil assigns(:is_checkbox)
    assert_nil assigns(:answer_map)
    user = assigns(:new_user)
    assert assigns(:user)
    assert_equal_unordered [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], user.role_names
    assert_equal "You are now a mentor in #{@program.name}", flash[:notice]
    assert_redirected_to edit_member_path(member, root: @program.root, first_visit: true, ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION)
  end

  def test_create_logged_in_user_joins_new_program
    program = programs(:moderated_program)
    program.find_role(RoleConstants::MENTOR_NAME).update_attributes(membership_request: false, join_directly: true)
    member = members(:f_student)
    assert_false member.user_in_program(program).present?

    current_member_is member
    current_program_is program
    dj_stub = mock()
    Member.any_instance.expects(:delay).returns(dj_stub).never
    dj_stub.expects(:clear_invalid_answers).never
    Matching.expects(:perform_users_delta_index_and_refresh_later).twice
    @controller.expects(:logout_killing_session!).never
    Airbrake.expects(:notify).never
    assert_no_difference "Member.count" do
      assert_difference "User.count" do
        assert_difference "MembershipRequest.count" do
          post :create, params: { membership_request: { first_name: "New", last_name: "Member", roles: RoleConstants::MENTOR_NAME }}
        end
      end
    end
    user = assigns(:new_user)
    assert_false assigns(:user).present?
    assert_equal_unordered [RoleConstants::MENTOR_NAME], user.role_names
    assert_equal "Welcome to #{program.name}. Please complete your online profile to proceed.", flash[:notice]
    assert_redirected_to edit_member_path(member, root: program.root, first_visit: RoleConstants::MENTOR_NAME, ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION)
  end

  def test_send_manager_notification_upon_membership_request_creation
    mentor_role = @program.find_role(RoleConstants::MENTOR_NAME)
    mentor_role.update_attributes(membership_request: false, join_directly: true)
    manager_question = @program.organization.profile_questions.find_by(question_type: ProfileQuestion::Type::MANAGER)
    manager_role_question = manager_question.role_questions.find_by(role_id: mentor_role.id)
    manager_role_question.update_attribute(:available_for, RoleQuestion::AVAILABLE_FOR::BOTH)
    password = Password.create(email_id: "newmember@chronus.com")

    Organization.any_instance.stubs(:manager_enabled?).returns(true)
    Airbrake.expects(:notify).never
    assert_emails 2 do # welcome email and manager email
      assert_difference "Manager.count" do
        assert_difference "MembershipRequest.count" do
          post :create, params: { membership_request: { first_name: "New", last_name: "Member" }, roles: RoleConstants::MENTOR_NAME, signup_code: password.reset_code,
            password: "123456", password_confirmation: "123456",
            profile_answers: { manager_question.id.to_s => sample_multi_field_question_attributes[:manager] }
          }
        end
      end
    end
    membership_request = assigns(:membership_request)
    member = assigns(:member)
    manager = Manager.last
    emails = ActionMailer::Base.deliveries.last(2).select { |mail| mail.to == [manager.email] }
    assert_equal 1, emails.size
    manager_mail = emails[0]
    assert_equal "manager@example.com", membership_request.manager.email
    assert_equal member.manager, membership_request.manager
    assert_equal [manager.email], manager_mail.to
    assert_equal "Information about #{member.name}'s participation in #{@program.name}", manager_mail.subject
  end

  def test_create_manager_update_during_membership_request_creation
    program = programs(:moderated_program)
    member = members(:f_student)
    program.find_role(RoleConstants::MENTOR_NAME).update_attributes(membership_request: true, join_directly: false)

    manager_question = program.organization.profile_questions.find_by(question_type: ProfileQuestion::Type::MANAGER)
    create_role_question(program: program, profile_question: manager_question, role_names: [RoleConstants::MENTOR_NAME], available_for: RoleQuestion::AVAILABLE_FOR::BOTH)
    manager = create_manager(member, manager_question)
    assert_equal "manager@example.com", member.manager.email

    current_member_is member
    current_program_is program
    Organization.any_instance.stubs(:manager_enabled?).returns(true)
    Airbrake.expects(:notify).never
    assert_emails 1 do
      assert_no_difference "Manager.count" do
        assert_difference "MembershipRequest.count" do
          post :create, params: { membership_request: { roles: RoleConstants::MENTOR_NAME },
            profile_answers: { manager_question.id.to_s => { "existing_manager_attributes" => { manager.id.to_s => { first_name: "Updated", last_name: 'Manager', email: 'updated_manager@example.com' } } } }
          }
        end
      end
    end
    membership_request = assigns(:membership_request)
    member = assigns(:member)
    manager = Manager.last
    emails = ActionMailer::Base.deliveries.last(2).select { |mail| mail.to == [manager.email] }
    assert_equal 1, emails.size
    manager_mail = emails[0]
    assert_equal "updated_manager@example.com", membership_request.manager.email
    assert_equal [manager.email], manager_mail.to
    assert_equal "Information about #{member.name}'s participation in #{program.name}", manager_mail.subject
  end

  def test_create_profile_answers_updation_failure
    @program.find_role(RoleConstants::MENTOR_NAME).update_attributes(membership_request: false, join_directly: true)
    choice_role_question = role_questions(:single_choice_role_q)
    choice_role_question.update_attribute(:available_for, RoleQuestion::AVAILABLE_FOR::BOTH)
    choice_profile_question = choice_role_question.profile_question
    assert_equal ["opt_1", "opt_2", "opt_3"], choice_profile_question.default_choices
    assert_false choice_profile_question.allow_other_option?

    current_member_is members(:f_student)
    Matching.expects(:perform_users_delta_index_later).never
    @controller.expects(:welcome_the_new_user).never
    Airbrake.expects(:notify).never
    assert_no_difference "Member.count" do
      assert_no_difference "User.count" do
        assert_no_difference "MembershipRequest.count" do
          assert_no_difference "ProfileAnswer.count" do
            post :create, params: { membership_request: { first_name: "New", last_name: "Member", roles: RoleConstants::MENTOR_NAME },
              profile_answers: { choice_profile_question.id => "invalid_option" }
            }
          end
        end
      end
    end
    assert assigns(:log_error)
    assert assigns(:profile_answers_updation_error)
  end

  def test_create_dormant_user_cannot_signin
    member = programs(:org_primary).members.create!(
      first_name: "Dormant",
      last_name: "User",
      email: "dormant+1@example.com",
      state: Member::Status::DORMANT
    )
    password = Password.create(email_id: member.email)
    assert member.dormant?
    assert_false member.can_signin?
    assert_nil member.terms_and_conditions_accepted

    assert_no_difference "Member.count" do
      assert_no_difference "User.count" do
        assert_difference "MembershipRequest.count" do
          post :create, params: { membership_request: { roles: RoleConstants::MENTOR_NAME }, signup_code: password.reset_code,
            password: "123456", password_confirmation: "123456", signup_terms: "true"
          }
        end
      end
    end
    assert member.reload.can_signin?
    assert member.terms_and_conditions_accepted
  end

  def test_membership_request_with_infected_file
    password = Password.create(email_id: "newmember@example.com")
    q1 = create_membership_profile_question(role_names: [RoleConstants::MENTOR_NAME])
    q2 = create_membership_profile_question(role_names: [RoleConstants::MENTOR_NAME], question_type: ProfileQuestion::Type::FILE)

    ProfileAnswer.any_instance.expects(:valid?).at_least(0).raises(VirusError)
    assert_no_difference('MembershipRequest.count') do
      assert_no_difference('ProfileAnswer.count') do
        assert_no_difference('RecentActivity.count') do
          post :create, params: { membership_request: { first_name: "New", last_name: "Member" }, roles: RoleConstants::MENTOR_NAME, signup_code: password.reset_code,
            password: "123456", password_confirmation: "123456",
            profile_answers: {
              q1.id => "Land",
              q2.id => fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')
            }
          }
        end
      end
    end
    assert_redirected_to new_membership_request_path(signup_code: password.reset_code, roles: [RoleConstants::MENTOR_NAME])
    assert_equal "Our security system has detected the presence of a virus in your resume.", flash[:error]
  end

  def test_should_not_get_index_for_mentor
    current_user_is :f_mentor
    assert_permission_denied do
      get :index
    end
  end

  def test_should_not_get_index_for_student
    current_user_is :f_student
    assert_permission_denied do
      get :index
    end
  end

  def test_auth_for_index
    mentor_role = @program.find_role(RoleConstants::MENTOR_NAME)
    mentor_role.membership_request = false
    mentor_role.save
    mentee_role = @program.find_role(RoleConstants::STUDENT_NAME)
    mentee_role.membership_request = false
    mentee_role.save
    assert_false @program.allow_join_now?

    current_user_is @approver
    assert @program.membership_requests.for_role(mentor_role.name).present?
    assert @program.membership_requests.for_role(mentee_role.name).present?
    assert_nothing_raised do
      get :index
    end
  end

  def test_should_show_not_specified_when_answer_is_not_present
    current_user_is @approver
    q1 = create_membership_profile_question(role_names: [RoleConstants::MENTOR_NAME])
    q2 = create_membership_profile_question(
      question_text: 'nothing',
      role_names: [RoleConstants::MENTOR_NAME],
      question_type: ProfileQuestion::Type::SINGLE_CHOICE,
      question_choices: ["get", "set", "go"])
    mem_req = create_membership_request(member: members(:dormant_member), roles: [RoleConstants::MENTOR_NAME])
    mem_req.member.profile_answers.create!(
      profile_question: q1, answer_text: 'get')

    get :index
    assert_response :success
    assert_select 'html' do
      assert_select "div.listing" do
        assert_select "div#mem_req_#{mem_req.id}" do
          assert_select "div" do
            assert_select 'h4', text: /#{q1.question_text}/
            assert_select 'div', text: /get/
          end
          assert_select "div" do
            assert_select 'h4', text: /#{q2.question_text}/
            assert_select 'div', text: /Not Specified/
          end
        end
      end
    end
  end

  def test_should_show_not_applicable_when_answer_is_not_applicable
    current_user_is @approver
    q2 = create_membership_profile_question(
      question_text: 'nothing',
      role_names: [RoleConstants::MENTOR_NAME],
      question_type: ProfileQuestion::Type::SINGLE_CHOICE,
      question_choices: ["get", "set", "go"])
    mem_req = create_membership_request(member: members(:dormant_member), roles: [RoleConstants::MENTOR_NAME])
    mem_req.member.profile_answers.create!(profile_question: q2, not_applicable: true)

    get :index
    assert_response :success
    assert_select 'html' do
      assert_select "div.listing" do
        assert_select "div#mem_req_#{mem_req.id}" do
          assert_select "div" do
            assert_select 'h4', text: /#{q2.question_text}/
            assert_select 'div', text: /Not Applicable/
          end
        end
      end
    end
  end

  def test_index_should_get_all_requests_for_voter
    current_user_is @approver

    get :index
    assert_response :success
    assert_select 'html'
    assert_page_title("Membership requests")
    assert_equal('pending', assigns(:tab))
    assert_not_nil assigns(:membership_requests)
    assert_equal(10, assigns(:membership_requests).size)
    assert_tab TabConstants::MANAGE
  end

  def test_index_with_src
    current_user_is @approver
    get :index, params: { src: ReportConst::ManagementReport::SourcePage}
    assert_response :success
    assert_equal ReportConst::ManagementReport::SourcePage, assigns(:src_path)
  end

  def test_index_no_src
    current_user_is @approver
    get :index
    assert_response :success
    assert_nil assigns(:src_path)
  end

  def test_index_should_get_all_requests_for_approver
    current_user_is @approver

    get :index
    assert_response :success
    assert_select 'html'
    assert_page_title("Membership requests")
    assert_equal('pending', assigns(:tab))
    assert_not_nil assigns(:membership_requests)
    assert_equal(10, assigns(:membership_requests).size)
    assert_tab TabConstants::MANAGE
  end

  def test_index_should_get_all_requests_for_approver_without_management_permission
    current_user_is @approver
    User.any_instance.expects(:view_management_console?).at_least(1).returns(false)

    get :index
    assert_response :success
    assert_select 'html'
    assert_page_title("Membership requests")
    assert_equal('pending', assigns(:tab))
    assert_not_nil assigns(:membership_requests)
    assert_equal(10, assigns(:membership_requests).size)
    assert_tab TabConstants::HOME
  end

  def test_index_should_show_current_status_of_existing_user
    user = users(:drafted_group_user)
    user.update_attribute(:state, User::Status::SUSPENDED)
    membership_request_params = { first_name: user.first_name, last_name: user.first_name, email: user.email }
    membership_request = MembershipRequest.create_from_params(@program, membership_request_params, user.member, {roles: RoleConstants::MENTOR_NAME})

    current_user_is @approver
    User.any_instance.expects(:view_management_console?).at_least(1).returns(false)

    get :index
    assert_response :success
    assert_select "#request_#{membership_request.id}" do
      assert_select 'h4', text: /Current Status/
      assert_select 'div', text: /State: Deactivated, Role: Student/
    end
  end

  def test_should_list_all_accepted_requests
    current_user_is @approver
    reqs = MembershipRequest.all
    mark_requests_accepted(reqs[4..7])

    get :index, params: { :tab => 'accepted'}
    assert_response :success
    assert_select 'html'
    assert_page_title("Membership requests")
    assert_equal('accepted', assigns(:tab))
    assert_equal(4, assigns(:membership_requests).size)
    assert_equal(reqs[4..7].reverse, assigns(:membership_requests))
    assert_tab TabConstants::MANAGE
  end

  def test_filtering_sent_between
    current_user_is @approver
    reqs = MembershipRequest.all
    req1 = reqs[0]
    req1.update_attribute(:created_at, Time.new(1947))

    get :index, params: { sent_between: "01/01/1945 - 01/01/1950"}
    assert_response :success
    assert_equal "01/01/1945 - 01/01/1950", assigns(:filters_to_apply)[:filters][:date_range]
    assert_equal Date.strptime("01/01/1945", MeetingsHelper::DateRangeFormat.call).to_date, assigns(:filters_to_apply)[:filters][:start_date]
    assert_equal Date.strptime("01/01/1950", MeetingsHelper::DateRangeFormat.call).to_date, assigns(:filters_to_apply)[:filters][:end_date]
    assert_equal_unordered [req1], assigns(:membership_requests)
    assert_tab TabConstants::MANAGE
  end

  def test_should_list_all_accepted_requests_not_joined_directly
    current_user_is @approver
    reqs = MembershipRequest.all
    mark_requests_accepted(reqs[4..7])
    req1 = create_membership_request(roles: [RoleConstants::MENTOR_NAME])
    req1.joined_directly = true
    req1.status = MembershipRequest::Status::ACCEPTED
    req1.accepted_as = RoleConstants::MENTOR_NAME
    req1.save

    get :index, params: { :tab => 'accepted'}
    assert_response :success
    assert_select 'html'
    assert_page_title("Membership requests")
    assert_equal('accepted', assigns(:tab))
    assert_equal(4, assigns(:membership_requests).size)
    assert_equal(reqs[4..7].reverse, assigns(:membership_requests))
    assert_tab TabConstants::MANAGE
  end

  def test_should_list_all_rejected_requests
    current_user_is @approver
    reqs = MembershipRequest.all
    mark_requests_rejected(reqs[4..7])
    req1 = create_membership_request(roles: [RoleConstants::MENTOR_NAME])
    req1.joined_directly = true
    req1.status = MembershipRequest::Status::REJECTED
    req1.accepted_as = RoleConstants::MENTOR_NAME
    req1.save

    get :index, params: { :tab => 'rejected'}
    assert_response :success
    assert_select 'html'
    assert_page_title("Membership requests")
    assert_equal('rejected', assigns(:tab))
    assert_equal(4, assigns(:membership_requests).size)
    assert_equal(reqs[4..7].reverse, assigns(:membership_requests))
    assert_tab TabConstants::MANAGE
  end

  def test_display_proper_role_name_in_listing
    current_user_is @approver
    @approver.program.find_role(RoleConstants::STUDENT_NAME).customized_term.update_attribute :term, 'Raaja'
    mem_request = create_membership_request(member: members(:dormant_member), roles: [RoleConstants::STUDENT_NAME])

    get :index
    assert_response :success
    assert_select 'html'
    assert_select "div#request_#{mem_request.id}" do
      assert_select "div" do
        assert_select "h4", text: /Request to join as/
        assert_select 'div', text: /Raaja/
      end
    end
  end

  def test_no_pagination_when_no_requests_in_listing
    current_user_is @approver
    @program.membership_requests.destroy_all

    get :index
    assert_response :success
    assert_empty assigns(:membership_requests)
    assert_select 'html'
    assert_no_select 'ul.pagination'
  end

  def test_items_per_page
    current_user_is @approver
    get :index
    assert_response :success
    assert_equal MembershipRequest::ListStyle::DETAILED, assigns(:list_type)
    assert assigns(:items_per_page).present?
    assert_equal(10, assigns(:items_per_page))
    assert assigns(:membership_requests).present?
    assert_select 'html' do
      assert_select 'div.listing_bottom_bar' do
        assert_select 'select#items_per_page_selector' do
          assert_select 'option', count: 4
          assert_select 'option', text: '10'
          assert_select 'option', text: '20'
          assert_select 'option', text: '30'
          assert_select 'option', text: '40'
        end
      end
    end
  end

  def test_index_should_get_empty_page_if_there_are_no_requests
    MembershipRequest.destroy_all
    current_user_is @approver
    get :index
    assert_response :success
    assert_select 'html'
    assert_select 'div#membership_requests' do
      assert_select 'div.empty_listing'
    end
  end

  def test_index_should_not_show_invite_url_for_empty_results
    MembershipRequest.destroy_all
    current_user_is @approver
    get :index, params: { filter: RoleConstants::STUDENT_NAME}
    assert_response :success
    assert_select 'html'
    assert_select 'div#membership_requests' do
      assert_select 'div.empty_listing'
      assert_select 'a', count: 0, text: "Invite students"
    end
  end

  def test_index_should_paginate_requests_10_at_a_time_by_default_for_detailed_view
    current_user_is @approver

    get :index
    assert_response :success
    assert_select 'html'
    assert_equal MembershipRequest::ListStyle::DETAILED, assigns(:list_type)
    assert_equal 10, assigns(:items_per_page)
    assert_not_nil assigns(:membership_requests)
    assert_equal(10, assigns(:membership_requests).size)

    get :index, params: { page: 2}
    assert_response :success
    assert_not_nil assigns(:membership_requests)
    assert_equal(2, assigns(:membership_requests).size)

    get :index, params: { page: 20}
    assert_empty assigns(:membership_requests)

    # Try getting a page with an invalid page number. It should default to page 1.
    get :index, params: { page: 'a'}
    assert_response :success
    assert_not_nil assigns(:membership_requests)
    assert_equal(10, assigns(:membership_requests).size)
  end

  def test_index_should_paginate_requests_20_at_a_time_by_default_for_list_view
    current_user_is @approver

    get :index, params: { list_type: MembershipRequest::ListStyle::LIST}
    assert_response :success
    assert_select 'html'
    assert_equal MembershipRequest::ListStyle::LIST, assigns(:list_type)
    assert_equal 20, assigns(:items_per_page)
    assert_not_nil assigns(:membership_requests)
    assert_equal(12, assigns(:membership_requests).size)

    get :index, params: { page: 2, list_type: MembershipRequest::ListStyle::LIST}
    assert_response :success
    assert_not_nil assigns(:membership_requests)
    assert_blank assigns(:membership_requests)
  end

  def test_index_action_with_both_roles
    current_user_is @approver
    req = @program.membership_requests.first
    req.role_names = [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]
    req.save!

    get :index, params: { filters: {role: RoleConstants::MENTOR_NAME}}
    assert_response :success
    assert assigns(:membership_requests).include?(req)
  end

  def test_index_membership_questions
    current_user_is @approver
    program = @program
    mentor_questions = program.membership_questions_for(RoleConstants::MENTOR_NAME)
    student_questions =  program.membership_questions_for(RoleConstants::STUDENT_NAME)

    get :index, params: { filter: RoleConstants::MENTOR_NAME}
    assert_equal mentor_questions, assigns(:membership_questions_for_roles)[RoleConstants::MENTOR_NAME.singularize]
    assert_equal student_questions, assigns(:membership_questions_for_roles)[RoleConstants::STUDENT_NAME.singularize]

    get :index, params: { filter: RoleConstants::STUDENT_NAME}
    assert_equal mentor_questions, assigns(:membership_questions_for_roles)[RoleConstants::MENTOR_NAME.singularize]
    assert_equal student_questions, assigns(:membership_questions_for_roles)[RoleConstants::STUDENT_NAME.singularize]

    get :index
    assert_equal mentor_questions, assigns(:membership_questions_for_roles)[RoleConstants::MENTOR_NAME.singularize]
    assert_equal student_questions, assigns(:membership_questions_for_roles)[RoleConstants::STUDENT_NAME.singularize]
  end

  def test_index_with_view_mentors_should_get_requests_from_mentors
    current_user_is @approver

    get :index, params: { filters: {role: RoleConstants::MENTOR_NAME}}
    assert_response :success
    assert_page_title("Membership requests")
    assert_select 'html'
    assert_not_nil assigns(:membership_requests)
    reqs = assigns(:membership_requests)
    assert_equal(6, reqs.size)
    reqs.each {|req| assert_equal([RoleConstants::MENTOR_NAME], req.role_names)}
  end

  def test_index_with_view_students_should_get_requests_from_students
    current_user_is @approver

    get :index, params: { filters: {role: RoleConstants::STUDENT_NAME}}
    assert_response :success
    assert_select 'html'
    assert_page_title("Membership requests")
    assert_not_nil assigns(:membership_requests)
    reqs = assigns(:membership_requests)
    assert_equal(6, reqs.size)
    reqs.each {|req| assert_equal([RoleConstants::STUDENT_NAME], req.role_names)}
  end

  def test_membership_requests_list_sorting
    current_user_is @approver
    all_mem_reqs = MembershipRequest.order("id").to_a

    requests = all_mem_reqs[0, 10]
    get :index, params: { order: 'desc', sort: 'first_name'}
    assert_response :success
    assert_not_nil assigns(:membership_requests)
    reqs = assigns(:membership_requests)
    assert_equal(10, reqs.size)
    assert_equal (1..6).to_a.reverse, reqs.first(6).collect(&:id)

    requests = all_mem_reqs[0, 10]
    get :index, params: { order: 'asc', sort: 'first_name'}
    assert_response :success
    assert_not_nil assigns(:membership_requests)
    reqs = assigns(:membership_requests)
    assert_equal (7..12).to_a, reqs.first(6).collect(&:id)
  end

  def test_membership_requests_sort_education_field
    current_user_is :f_admin
    profile_question = create_membership_profile_question(
      question_text: 'Education',
      role_names: [RoleConstants::MENTOR_NAME],
      question_type: ProfileQuestion::Type::EDUCATION)
    mem_req1 = create_membership_request(roles: [RoleConstants::MENTOR_NAME])
    mem_req2 = create_membership_request(roles: [RoleConstants::STUDENT_NAME])
    create_education_answers(mem_req1.member, profile_question, [school_name: 'IIT'])
    create_education_answers(mem_req2.member, profile_question, [school_name: 'CEG'])

    get :index, xhr: true, params: { sort: "question-#{profile_question.id}", order: "desc", list_type: MembershipRequest::ListStyle::LIST, format: :js}
    assert_response :success
    assert_not_nil assigns(:membership_requests)
    membership_requests =  assigns(:membership_requests).collect(&:id)
    assert_operator membership_requests.find_index(mem_req1.id), :<, membership_requests.find_index(mem_req2.id)
  end

  def test_membership_requests_listing_with_an_invalid_sort_param_should_throw_an_exception
    current_user_is @approver
    assert_raise(ActiveRecord::StatementInvalid) {
      get :index, params: { order: 'whatever', sort: 'no-order'}
    }
  end

  def test_requests_listing_should_not_show_accepted_or_rejected_membership_requests
    current_user_is @approver
    membership_requests(:membership_request_11).update_attributes!({
        status: MembershipRequest::Status::REJECTED,
        response_text: "Reason",
        admin: users(:f_admin)
      })
    assert membership_requests(:membership_request_11).rejected?
    membership_requests(:membership_request_10).update_attributes!({
        status: MembershipRequest::Status::ACCEPTED,
        response_text: "Reason",
        accepted_as: RoleConstants::STUDENT_NAME,
        admin: users(:f_admin)
      })
    assert membership_requests(:membership_request_10).accepted?
    requests = MembershipRequest.limit(10).reverse

    get :index
    assert_response :success
    assert_not_nil(assigns(:membership_requests))
    assert_equal(10, assigns(:membership_requests).size)
    assert_equal(requests, assigns(:membership_requests))
  end

  def test_should_display_mentor_mentee_request
    current_user_is @approver
    req = create_membership_request(roles: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])

    get :index
    assert_response :success
    assert_select "div.listing" do
      assert_select "div#mem_req_#{req.id}", 1 # There should 1 request
      assert_select "div#request_#{req.id}" do
        assert_select "div.media-body" do
          assert_select "div.p-b-xs:nth-child(3)" do
            assert_select "div", /Mentor and Student/
          end
        end
      end
    end
  end

  def test_show_requests_from_role_currently_not_allowed_to_send_requests
    MembershipRequest.destroy_all
    member = members(:dormant_member)
    user_role = @program.find_role("user")
    user_role.update_attribute(:membership_request, true)
    req = MembershipRequest.create!({
      first_name: member.first_name,
      last_name: member.last_name,
      email: member.email,
      program: @program,
      role_names: ["user"],
      member: member,
      status: MembershipRequest::Status::UNREAD
    })
    user_role.update_attribute(:membership_request, false)

    current_user_is @approver
    get :index
    assert_response :success
    assert_equal [req], assigns(:membership_requests)
  end

  def test_membership_requests_view_title
    current_user_is :f_admin
    program = @program
    view = program.abstract_views.where(default_view: AbstractView::DefaultType::PENDING_REQUESTS).first
    section = program.report_sections.first
    metric = section.metrics.create(title: "Metric Title", description: "Pending membership requests", abstract_view_id: view.id)

    get :index, params: { metric_id: metric.id}
    assert_response :success
    assert_not_nil assigns(:metric)
    assert_page_title(metric.title)
  end

  def test_membership_requests_view_with_alert_id_param
    current_user_is :f_admin
    program = @program
    view = program.abstract_views.where(default_view: AbstractView::DefaultType::PENDING_REQUESTS).first
    section = program.report_sections.first
    metric = section.metrics.create(title: "Metric Title", description: "Pending membership requests", abstract_view_id: view.id)
    alert_params = {target: 20, description: "alert description", operator: Report::Alert::OperatorType::LESS_THAN, filter_params: {cjs_alert_filter_params_0: {name: FilterUtils::MembershipRequestViewFilters::FILTERS.first[1][:value], operator: FilterUtils::DateRange::IN_LAST, value: "10"}}.to_yaml.gsub(/--- \n/, "")}
    alert = create_alert_for_metric(metric, alert_params)

    get :index, params: { metric_id: metric.id, view_id: view.id, alert_id: alert.id}
    assert_response :success
    assert_not_nil assigns(:filter_hash)[:sent_between]

    get :index, params: { metric_id: metric.id, view_id: view.id}
    assert_response :success
    assert_nil assigns(:filter_hash)[:sent_between]
  end

  def test_membership_requests_pagination_default_page_number
    current_user_is :f_admin
    program = @program
    post :index, xhr: true, params: { root: program.root, format: "js"}
    assert_equal [12, 11, 10, 9, 8, 7, 6, 5, 4, 3], assigns(@membership_requests)["membership_requests"].collect(&:id)
    assert_match /listing_bottom_bar/, response.body
  end

  def test_membership_requests_check_pagination_bar_single_page
    current_user_is :f_admin
    program = @program
    post :index, xhr: true, params: { root: program.root, format: "js", items_per_page: 12}
    assert_equal [12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1], assigns(@membership_requests)["membership_requests"].collect(&:id)
    assert_match /listing_bottom_bar/, response.body
  end

  def test_membership_requests_pagination_default_page_number_with_per_page
    current_user_is :f_admin
    program = @program
    post :index, xhr: true, params: { root: program.root, format: "js", items_per_page: 3}
    assert_equal [12, 11, 10], assigns(@membership_requests)["membership_requests"].collect(&:id)
  end

  def test_membership_requests_pagination_explicit_page_number
    current_user_is :f_admin
    program = @program
    post :index, xhr: true, params: { root: program.root, format: "js", page: 2}
    assert_equal [2, 1], assigns(@membership_requests)["membership_requests"].collect(&:id)
  end

  def test_membership_requests_pagination_explicit_page_number_with_per_page
    current_user_is :f_admin
    program = @program
    post :index, xhr: true, params: { root: program.root, format: "js", page: 2, items_per_page: 3}
    assert_equal [9, 8, 7], assigns(@membership_requests)["membership_requests"].collect(&:id)
  end

  def test_membership_requests_pagination_explicit_page_number_per_page_alert_id
    current_user_is :f_admin
    program = @program
    view = program.abstract_views.where(default_view: AbstractView::DefaultType::PENDING_REQUESTS).first
    section = program.report_sections.first
    metric = section.metrics.create(title: "Metric Title", description: "Pending membership requests", abstract_view_id: view.id)
    alert_params = {target: 20, description: "alert description", operator: Report::Alert::OperatorType::LESS_THAN, filter_params: {cjs_alert_filter_params_0: {name: FilterUtils::MembershipRequestViewFilters::FILTERS.first[1][:value], operator: FilterUtils::DateRange::IN_LAST, value: "10"}}.to_yaml.gsub(/--- \n/, "")}
    alert = create_alert_for_metric(metric, alert_params)

    post :index, xhr: true, params: { metric_id: metric.id, view_id: view.id, alert_id: alert.id, page: 2, items_per_page: 3, format: "js"}
    assert_response :success
    assert_equal [9, 8, 7], assigns(@membership_requests)["membership_requests"].collect(&:id)
  end

  def test_membership_requests_pagination_explicit_page_number_per_page_alert_id_html
    current_user_is :f_admin
    program = @program
    view = program.abstract_views.where(default_view: AbstractView::DefaultType::PENDING_REQUESTS).first
    section = program.report_sections.first
    metric = section.metrics.create(title: "Metric Title", description: "Pending membership requests", abstract_view_id: view.id)
    alert_params = {target: 20, description: "alert description", operator: Report::Alert::OperatorType::LESS_THAN, filter_params: {cjs_alert_filter_params_0: {name: FilterUtils::MembershipRequestViewFilters::FILTERS.first[1][:value], operator: FilterUtils::DateRange::IN_LAST, value: "10"}}.to_yaml.gsub(/--- \n/, "")}
    alert = create_alert_for_metric(metric, alert_params)

    get :index, params: { metric_id: metric.id, view_id: view.id, alert_id: alert.id, page: 2, items_per_page: 3}
    assert_response :success
    assert_equal [9, 8, 7], assigns(@membership_requests)["membership_requests"].collect(&:id)
  end

  def test_membership_requests_pagination_explicit_page_number_per_page_view_id
    current_user_is :f_admin
    program = @program
    view = program.abstract_views.where(default_view: AbstractView::DefaultType::PENDING_REQUESTS).first
    section = program.report_sections.first
    metric = section.metrics.create(title: "Metric Title", description: "Pending membership requests", abstract_view_id: view.id)
    alert_params = {target: 20, description: "alert description", operator: Report::Alert::OperatorType::LESS_THAN, filter_params: {cjs_alert_filter_params_0: {name: FilterUtils::MembershipRequestViewFilters::FILTERS.first[1][:value], operator: FilterUtils::DateRange::IN_LAST, value: "10"}}.to_yaml.gsub(/--- \n/, "")}
    alert = create_alert_for_metric(metric, alert_params)

    post :index, xhr: true, params: { metric_id: metric.id, view_id: view.id, page: 2, items_per_page: 3, format: "js"}
    assert_response :success
    assert_equal [9, 8, 7], assigns(@membership_requests)["membership_requests"].collect(&:id)
  end

  def test_membership_requests_pagination_explicit_page_number_per_page_view_id_html
    current_user_is :f_admin
    program = @program
    view = program.abstract_views.where(default_view: AbstractView::DefaultType::PENDING_REQUESTS).first
    section = program.report_sections.first
    metric = section.metrics.create(title: "Metric Title", description: "Pending membership requests", abstract_view_id: view.id)
    alert_params = {target: 20, description: "alert description", operator: Report::Alert::OperatorType::LESS_THAN, filter_params: {cjs_alert_filter_params_0: {name: FilterUtils::MembershipRequestViewFilters::FILTERS.first[1][:value], operator: FilterUtils::DateRange::IN_LAST, value: "10"}}.to_yaml.gsub(/--- \n/, "")}
    alert = create_alert_for_metric(metric, alert_params)

    get :index, params: { metric_id: metric.id, view_id: view.id, page: 2, items_per_page: 3}
    assert_response :success
    assert_equal [9, 8, 7], assigns(@membership_requests)["membership_requests"].collect(&:id)
  end

  def test_new_bulk_action_should_deny_for_student_role
    current_user_is :f_student
    assert_permission_denied do
      get :new_bulk_action, xhr: true, params: { membership_request_ids: ["1", "2", "3"]}
    end
  end

  def test_new_bulk_Action_for_showing_note_in_accept_popup
    current_user_is :f_admin
    post :new_bulk_action, xhr: true, params: { membership_request_ids: "1", status: MembershipRequest::Status::ACCEPTED}
    assert_response :success
    assert_match MembershipRequestAccepted.mailer_attributes[:uid], response.body
    assert_select "b", text: "Note:"
  end

  def test_new_bulk_Action_for_hiding_note_in_reject_popup
    current_user_is :f_admin
    post :new_bulk_action, xhr: true, params: { membership_request_ids: ["1", "2"], status: MembershipRequest::Status::REJECTED}
    assert_response :success
    assert_match MembershipRequestNotAccepted.mailer_attributes[:uid], response.body
    assert_select "b", text: "Note:", count: 0
  end

  def test_new_admin_view_bulk_action
    current_user_is :f_admin

    get :new_bulk_action, xhr: true, params: { membership_request_ids: ["1", "2", "3"]}
    assert_response :success
    assert_equal_unordered [1, 2, 3], assigns(:membership_requests).map(&:id)
    assert_nil assigns(:status)
    assert_select "input", type: "hidden", value: assigns(:membership_requests).map(&:id).join(",")
  end

  def test_select_all_ids_permission_denied
    current_user_is :moderated_mentor
    assert_permission_denied { get :select_all_ids }
  end

  def test_select_all_ids_no_filter_params
    pending_requests = @program.membership_requests.pending
    assert_equal 12, pending_requests.size

    current_user_is :f_admin
    get :select_all_ids
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal_unordered pending_requests.collect(&:id).map(&:to_s), json_response["membership_request_ids"]
    assert_equal_unordered pending_requests.collect(&:member_id), json_response["member_ids"]
  end

  def test_select_all_ids_with_filter_params
    requests = @program.membership_requests
    request_params = { 'param1' => '1', 'param_2' => '2' }

    MembershipRequestService.expects(:get_filtered_membership_requests).returns(@program.membership_requests.where(id: 1)).once
    current_user_is :f_admin
    get :select_all_ids, params: request_params
    json_response = JSON.parse(response.body)
    assert_equal ["1"], json_response["membership_request_ids"]
    assert_equal [10], json_response["member_ids"]
  end

  def test_bulk_accepting_membership_requests
    current_user_is @approver
    request = create_membership_request(member: members(:dormant_member), roles: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])

    assert_emails 1 do
      assert_difference "User.count", 1 do
        post :bulk_update, params: {
            membership_request_ids: request.id,
            membership_request: { status: MembershipRequest::Status::ACCEPTED,
            accepted_as: [RoleConstants::STUDENT_NAME] }}
      end
    end
    assert request.reload.accepted?
    assert_equal @approver, request.admin
    assert_equal_unordered [RoleConstants::STUDENT_NAME], request.accepted_role_names
    assert_redirected_to membership_requests_path
    click_here = "<a href='#{member_path(request.user.member)}'>Click here</a>"
    assert_equal "The request has been accepted. #{click_here} to view the member's profile.", flash[:notice]
  end

  def test_bulk_accepting_membership_requests_without_accepted_as
    current_user_is @approver
    request = create_membership_request(member: members(:dormant_member), roles: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])

    assert_emails 1 do
      assert_difference "User.count", 1 do
        post :bulk_update, params: {
            membership_request_ids: request.id,
            membership_request: { status: MembershipRequest::Status::ACCEPTED }}
      end
    end
    assert request.reload.accepted?
    assert_equal @approver, request.admin
    assert_equal_unordered [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], request.accepted_role_names
    assert_redirected_to membership_requests_path
    click_here = "<a href='#{member_path(request.user.member)}'>Click here</a>"
    assert_equal "The request has been accepted. #{click_here} to view the member's profile.", flash[:notice]
  end

  def test_bulk_rejecting_membership_requests
    current_user_is @approver
    request_1 = create_membership_request(member: members(:dormant_member), roles: [RoleConstants::MENTOR_NAME])
    request_2 = create_membership_request(member: members(:dormant_member), roles: [RoleConstants::STUDENT_NAME])

    assert_emails 2 do
      assert_no_difference "User.count" do
        post :bulk_update, params: {
            membership_request_ids: "#{request_1.id},#{request_2.id}",
            membership_request: { status: MembershipRequest::Status::REJECTED,
            response_text: "Sorry not accepted",
            accepted_as: [RoleConstants::STUDENT_NAME] }}
      end
    end
    assert request_1.reload.rejected?
    assert request_2.reload.rejected?
    assert_equal @approver, request_1.admin
    assert_equal @approver, request_2.admin
    assert_equal "Sorry not accepted", request_1.response_text
    assert_equal "Sorry not accepted", request_2.response_text
    assert_nil request_1.accepted_as
    assert_nil request_2.accepted_as
    assert_redirected_to membership_requests_path
    assert_equal "Users have been notified that the membership request was not accepted.", flash[:notice]
  end

  def test_bulk_ignoring_a_membership_request
    current_user_is @approver
    request = create_membership_request
    assert_difference "MembershipRequest.count", -1 do
      post :bulk_update, params: { membership_request_ids: request.id}
    end
    assert_redirected_to membership_requests_path
    assert_equal "The request was deleted.", flash[:notice]
  end

  def test_auth_for_update
    User.any_instance.expects(:visible_to?).at_least(0).returns(true)
    mentor_role = @program.find_role(RoleConstants::MENTOR_NAME)
    mentor_role.membership_request = false
    mentor_role.save
    mentee_role = @program.find_role(RoleConstants::STUDENT_NAME)
    mentee_role.membership_request = false
    mentee_role.save
    assert_false @program.allow_join_now?

    current_user_is @approver
    request = create_membership_request(member: members(:dormant_member))
    assert_nothing_raised do
      assert_difference('User.count') do
        post :bulk_update, params: {
            membership_request_ids: request.id,
            membership_request: { status: MembershipRequest::Status::ACCEPTED,
            accepted_as: [RoleConstants::STUDENT_NAME] }}
      end
    end
  end

  def test_csv_export
    MembershipRequest.destroy_all
    current_user_is @approver
    assert @program.membership_requests.empty?
    MembershipRequest.expects(:delay).times(0)

    get :export, params: { :membership_request_ids => "", :format => 'csv'}
    assert_redirected_to membership_requests_path
    assert_equal("No membership requests to export!", flash[:error])
  end

  def test_csv_export_for_approver
    current_user_is @approver
    create_dummy_membership_requests(@program)
    get :export, params: { membership_request_ids: "1", format: 'csv'}
    assert_response :success
  end

  def test_pdf_export_for_approver
    current_user_is @approver
    create_dummy_membership_requests(@program)
    dj_stub = mock()
    MembershipRequest.expects(:delay).returns(dj_stub)
    JobLog.expects(:generate_uuid).returns('uniq_id')
    dj_stub.expects(:generate_and_email_report).with(@approver, [MembershipRequest.first.id], 'pending', [:order_by, "id", "desc"], :pdf, 'uniq_id', :en)
    get :export, xhr: true, params: { membership_request_ids: "1"}
    assert_response :success
    assert_equal("Membership Requests are being exported to PDF. You will receive an email soon with the PDF report", assigns(:success_message))
  end

  def test_create_with_member_not_eligible
    question = create_membership_profile_question(question_text: 'Question', role_names: [RoleConstants::MENTOR_NAME], question_type: ProfileQuestion::Type::STRING)
    password = Password.create(email_id: "newmember@chronus.com")
    @program.enable_feature(FeatureName::MEMBERSHIP_ELIGIBILITY_RULES, true)
    role = @program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    role.update_attribute(:eligibility_rules, true)

    admin_view = AdminView.create!(program: @program.organization, role_id: role.id, title: "New View", filter_params: AdminView.convert_to_yaml({
      profile: {questions: {question_1: {question: "#{question.id}", operator: AdminViewsHelper::QuestionType::WITH_VALUE.to_s, value: "xyz"}}},
      program_role_state: {AdminView::ProgramRoleStateFilterObjectKey::ALL_MEMBERS => true}
    }))
    Airbrake.expects(:notify).times(0)
    assert_no_difference "Member.count" do
      assert_no_difference "User.count" do
        assert_no_difference "MembershipRequest.count" do
          post :create, params: { membership_request: { first_name: "New", last_name: "Member" }, roles: RoleConstants::MENTOR_NAME, signup_code: password.reset_code,
            password: "123456", password_confirmation: "123456",
            profile_answers: { question.id => "answer" }
          }
        end
      end
    end

    assert_template :new

    profile_answer = ProfileAnswer.new(profile_question_id: question.id)
    profile_answer.answer_value = "answer"
    profile_answer.priority = ProfileAnswer::PRIORITY::IMPORTED
    answer_map = assigns(:answer_map)
    answer = answer_map[question.id.to_s]
    assert_equal profile_answer.answer_value, answer.answer_value
    assert_equal ProfileAnswer::PRIORITY::IMPORTED, answer.priority
    assert_equal question.id, answer.profile_question_id

    membership_request = assigns(:membership_request)
    assert_equal "New", membership_request.first_name
    assert_equal "Member", membership_request.last_name
    assert_equal "newmember@chronus.com", membership_request.email
    assert_nil assigns(:member)
    assert assigns(:valid_member)
    assert_empty assigns(:invalid_answer_details)
    assert_false assigns(:is_checkbox)
    assert_false assigns(:is_checkbox)
    assert assigns(:log_error)
    assert_equal("Based on available information, it appears you can not join the program as Mentor. Please <a href=\"http:\/\/test.host\/p\/albers\/contact_admin\" class=\"no-waves\">Contact Administrator<\/a> for further assistance.", flash[:error])
  end


  def test_create_with_member_eligible
    current_locale_is :de
    question = create_membership_profile_question(question_text: 'Question', role_names: [RoleConstants::MENTOR_NAME], question_type: ProfileQuestion::Type::STRING)
    password = Password.create(email_id: "newmember@chronus.com")
    @program.enable_feature(FeatureName::MEMBERSHIP_ELIGIBILITY_RULES, true)
    role = @program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    role.update_attribute(:eligibility_rules, true)

    admin_view = AdminView.create!(program: @program.organization, role_id: role.id, title: "New View", filter_params: AdminView.convert_to_yaml({
      profile: {questions: {question_1: {question: "#{question.id}", operator: AdminViewsHelper::QuestionType::WITH_VALUE.to_s, value: "answer"}}},
      program_role_state: {AdminView::ProgramRoleStateFilterObjectKey::ALL_MEMBERS => true}
    }))
    assert_difference "Member.count" do
      assert_difference "User.count" do
        assert_difference "MembershipRequest.count" do
          post :create, params: { membership_request: { first_name: "New", last_name: "Member" }, roles: RoleConstants::MENTOR_NAME, signup_code: password.reset_code,
            password: "123456", password_confirmation: "123456",
            profile_answers: { question.id => "answer" },
            time_zone: "Asia/Kolkata"
          }
        end
      end
    end

    assert_nil assigns(:answer_map)

    membership_request = assigns(:membership_request)
    assert_equal "New", membership_request.first_name
    assert_equal "Member", membership_request.last_name
    assert_equal "newmember@chronus.com", membership_request.email
    assert_equal MembershipRequest::Status::ACCEPTED, membership_request.status
    member = Member.last
    assert_equal :de, Language.for_member(member)
    assert_equal member, assigns(:member)
    assert_equal "Asia/Kolkata", member.time_zone
    assert assigns(:eligible_to_join)
  end

  def test_no_password_error_when_using_sso_as_well_as_chronus_auth
    #New User logs in using SSO and then clicks on login?mode=strict which sets session[:auth_config_id] to ChronusAuth and while submitting membership request, it validates password since member's auth_config is set to ChronusAuth.
    @program = programs(:albers)
    current_program_is @program
    auth_config_1 = @program.organization.auth_configs.find_by(auth_type: AuthConfig::Type::CHRONUS)
    auth_config_2 = @program.organization.auth_configs.create!(auth_type: AuthConfig::Type::SAML)
    @request.session[:new_custom_auth_user] = { @program.organization.id => "12345", auth_config_id: auth_config_2.id}
    @request.session[:auth_config_id] = { @program.id => auth_config_1.id }
    post :create, params: { membership_request: { first_name: "New", last_name: "Member", email: "newmember@test.com", program_id: @program.id }, roles: RoleConstants::MENTOR_NAME}
    assert_nil assigns(:creation_failure), "Membership Request creation failure"
  end

  def test_apply_with_one_allowed_one_not_allowed_role
    member = members(:f_mentor)
    member.user_in_program(@program).destroy
    mentor_role = @program.roles.where(name: RoleConstants::MENTOR_NAME).first
    student_role = @program.roles.where(name: RoleConstants::STUDENT_NAME).first
    @controller.stubs(:simple_captcha_valid?).returns(true)
    Member.any_instance.expects(:is_eligible_to_join?).with([mentor_role]).once.returns(false, false)
    Member.any_instance.expects(:is_eligible_to_join?).with([student_role]).once.returns(true, true)
    ChronusMailer.expects(:complete_signup_existing_member_notification).once.returns(stub(:deliver_now))
    post :apply, params: { roles: "#{RoleConstants::MENTOR_NAME}, #{RoleConstants::STUDENT_NAME}", email: member.email}
  end

  def test_create_with_one_allowed_one_not_allowed_role
    question = create_membership_profile_question(question_text: 'Question', role_names: [RoleConstants::MENTOR_NAME], question_type: ProfileQuestion::Type::STRING)
    password = Password.create(email_id: "newmember@chronus.com")
    @program.enable_feature(FeatureName::MEMBERSHIP_ELIGIBILITY_RULES, true)
    @program.update_attribute(:show_multiple_role_option, true)
    mentor_role = @program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    student_role = @program.roles.find_by(name: RoleConstants::STUDENT_NAME)
    mentor_role.update_attribute(:eligibility_rules, true)
    student_role.update_attribute(:eligibility_rules, true)

    admin_view = AdminView.create!(program: @program.organization, role_id: mentor_role.id, title: "New View", filter_params: AdminView.convert_to_yaml({
      profile: {questions: {question_1: {question: "#{question.id}", operator: AdminViewsHelper::QuestionType::WITH_VALUE.to_s, value: "xyz"}}},
      program_role_state: {AdminView::ProgramRoleStateFilterObjectKey::ALL_MEMBERS => true}
    }))

    assert_difference "Member.count" do
      assert_difference "User.count" do
        assert_difference "MembershipRequest.count" do
          post :create, params: { membership_request: { first_name: "New", last_name: "Member" }, roles: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], signup_code: password.reset_code,
            password: "123456", password_confirmation: "123456",
            profile_answers: { question.id => "answer" }
          }
        end
      end
    end

    assert assigns(:eligible_to_join)
    assert assigns(:eligible_to_join_directly)
    assert_equal [student_role], assigns(:eligible_to_join_roles)
    assert_equal [student_role], assigns(:eligible_to_join_directly_roles)
    assert_equal [mentor_role], assigns(:not_eligible_to_join_roles)
    assert_equal [mentor_role], assigns(:not_eligible_to_join_directly_roles)
    assert_equal "Welcome to #{@program.name}. Please complete your online profile to proceed. However you are not allowed to join as a #{mentor_role.customized_term.term_downcase}.", flash[:warning]
    assert_equal [student_role], User.last.roles
  end

  def test_new_with_not_eligible_member
    member = members(:f_mentor)
    member.user_in_program(@program).destroy
    current_member_is :f_mentor
    password = Password.create!(email_id: member.email)
    mentor_role = @program.roles.where(name: RoleConstants::MENTOR_NAME).first
    Member.any_instance.expects(:can_modify_eligibility_details?).once.returns(false)
    Member.any_instance.expects(:is_eligible_to_join?).with([mentor_role]).once.returns(false, false)
    get :new, params: { roles: RoleConstants::MENTOR_NAME, signup_code: password.reset_code}
    assert assigns(:show_roles)
    assert_equal("Based on available information, it appears you can not join the program as Mentor. Please <a href=\"http://test.host/p/albers/contact_admin\" class=\"no-waves\">Contact Administrator</a> for further assistance.", flash[:error])
    assert_redirected_to program_root_path(root: @program.root)
  end

  def test_new_xhr_with_eligible_member
    question = create_membership_profile_question(question_text: 'Question', role_names: [RoleConstants::MENTOR_NAME], question_type: ProfileQuestion::Type::STRING)
    member = members(:f_student)
    current_member_is :f_student
    mentor_role = @program.roles.where(name: RoleConstants::MENTOR_NAME).first
    admin_view = AdminView.create!(program: @program.organization, role_id: mentor_role.id, title: "New View", filter_params: AdminView.convert_to_yaml({
          profile: {questions: {question_1: {question: "#{question.id}", operator: AdminViewsHelper::QuestionType::NOT_ANSWERED.to_s, value: "xyz"}}},
        }))
    Member.any_instance.expects(:can_modify_eligibility_details?).never
    Member.any_instance.expects(:is_eligible_to_join?).with([mentor_role]).once.returns([true, true])
    get :new, xhr: true, params: { roles: RoleConstants::MENTOR_NAME, format: :js}
    assert_response :success
    assert_equal assigns(:user), member.user_in_program(@program)
    assert assigns(:roles)
    assert assigns(:member)
    assert_nil assigns(:new_user)
    assert_false assigns(:show_roles)
    assert assigns(:eligible_to_join)
    assert assigns(:eligible_to_join_directly)
  end

  def test_not_eligibile_single_role_customized_eligibility_message
    member = members(:f_mentor)
    member.user_in_program(@program).destroy
    current_member_is :f_mentor
    password = Password.create!(email_id: member.email)
    mentor_role = @program.roles.where(name: RoleConstants::MENTOR_NAME).first
    mentor_role.eligibility_message = "Customized Message\nFor Mentor"
    mentor_role.save!
    Member.any_instance.expects(:can_modify_eligibility_details?).once.returns(false)
    Member.any_instance.expects(:is_eligible_to_join?).with([mentor_role]).once.returns(false, false)
    get :new, params: { roles: RoleConstants::MENTOR_NAME, signup_code: password.reset_code}
    assert_equal("Customized Message\n<br />For Mentor", flash[:error])
    assert_redirected_to program_root_path(root: @program.root)
  end

  def test_not_eligibile_double_roles_same_customized_eligibility_message
    member = members(:f_mentor)
    member.user_in_program(@program).destroy
    current_member_is :f_mentor
    password = Password.create!(email_id: member.email)
    mentor_role = @program.roles.where(name: RoleConstants::MENTOR_NAME).first
    mentor_role.eligibility_message = " Customized Message"
    mentor_role.save!
    student_role = @program.roles.where(name: RoleConstants::STUDENT_NAME).first
    student_role.eligibility_message = "   Customized Message  "
    student_role.save!
    Member.any_instance.expects(:can_modify_eligibility_details?).once.returns(false)
    Member.any_instance.expects(:is_eligible_to_join?).with([mentor_role]).once.returns(false, false)
    Member.any_instance.expects(:is_eligible_to_join?).with([student_role]).once.returns(false, false)
    Program.any_instance.stubs(:show_and_allow_multiple_role_memberships?).returns(true)
    get :new, params: { roles: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], signup_code: password.reset_code}
    assert_equal("Customized Message", flash[:error])
    assert_redirected_to program_root_path(root: @program.root)
  end

  def test_not_eligibile_double_roles_different_customized_eligibility_message
    member = members(:f_mentor)
    member.user_in_program(@program).destroy
    current_member_is :f_mentor
    password = Password.create!(email_id: member.email)
    mentor_role = @program.roles.where(name: RoleConstants::MENTOR_NAME).first
    mentor_role.eligibility_message = "Customized Message for Mentor"
    mentor_role.save!
    student_role = @program.roles.where(name: RoleConstants::STUDENT_NAME).first
    student_role.eligibility_message = "Customized Message for Student"
    student_role.save!
    Member.any_instance.expects(:can_modify_eligibility_details?).once.returns(false)
    Member.any_instance.expects(:is_eligible_to_join?).with([mentor_role]).once.returns(false, false)
    Member.any_instance.expects(:is_eligible_to_join?).with([student_role]).once.returns(false, false)
    Program.any_instance.stubs(:show_and_allow_multiple_role_memberships?).returns(true)
    get :new, params: { roles: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], signup_code: password.reset_code}
    assert_equal("Customized Message for Mentor\n<br />\n<br />Customized Message for Student", flash[:error])
    assert_redirected_to program_root_path(root: @program.root)
  end

  def test_resend_signup_mail_with_params
    email = "newmember@chronus.com"
    password1 = Password.create!(email_id: email)
    password2 = Password.create!(email_id: email)
    assert_emails do
      get :resend_signup_mail, xhr: true, params: { roles: RoleConstants::STUDENT_NAME, email: email}
    end
    assert assigns(:is_valid)
    mail = ActionMailer::Base.deliveries.last
    text = get_text_part_from(mail)
    assert_match(/#{password2.reset_code}/, text)
    assert_no_match(/#{password1.reset_code}/, text)
  end

  def test_apply_new_member_mail_thro_send_mail_chronusauth
    @controller.stubs(:simple_captcha_valid?).returns(true)
    email = "newmember@chronus.com"
    password = Password.create!(email_id: email)
    assert_emails do
      post :apply, params: { roles: RoleConstants::STUDENT_NAME, email: email}
    end
    mail = ActionMailer::Base.deliveries.last
    text = get_text_part_from(mail)
    assert_no_match(/#{password.reset_code}/, text)
    password_newly_created = Password.where(email_id: email).last
    assert_not_equal password_newly_created, password
    assert_match(/#{password_newly_created.reset_code}/, text)
  end

  def test_redirect_to_signup_instructions_after_apply
    email = "newmember@chronus.com"
    password = Password.create!(email_id: email)
    post :apply, params: { roles: RoleConstants::STUDENT_NAME, email: email}
    assert_response :redirect
    assert_redirected_to signup_instructions_membership_requests_path(roles: RoleConstants::STUDENT_NAME, email: email)
  end

  def test_experiment_finished
    @controller.expects(:finished_chronus_ab_test_only_use_cookie).with(ProgramAbTest::Experiment::MOBILE_APP_LOGIN_WORKFLOW, true, true).once
    @controller.stubs(:is_mobile_app?).returns(true)
    get :signup_instructions
  end

  def test_resend_signup_mail_without_params_should_send_no_mail
    email = "newmember@chronus.com"
    assert_no_emails do
      get :resend_signup_mail, xhr: true
    end
  end

  def test_resend_signup_mail_after_signing_in
    # There will be a Member object but no Password object (destroyed after membership request create)
    member = members(:f_student)
    email = "newmember@chronus.com"
    member.update_attributes(email: email)
    assert_no_emails do
      get :resend_signup_mail, xhr: true, params: { roles: RoleConstants::STUDENT_NAME, email: email}
    end
    assert_false assigns(:valid)
  end

  def test_new_eligible_to_join_directly
    member = members(:dormant_member)
    current_member_is :dormant_member
    org = programs(:org_no_subdomain)
    program = org.programs.first
    current_program_is :no_subdomain
    mentor_role = program.roles.where(name: RoleConstants::MENTOR_NAME).first
    Member.any_instance.expects(:can_modify_eligibility_details?).returns(false)
    values = lambda {return true, true}
    Member.any_instance.stubs(:is_eligible_to_join?).returns(values.call)
    assert_difference "MembershipRequest.count" do
      assert_difference "User.count" do
        get :new, params: { roles: [RoleConstants::MENTOR_NAME]}
      end
    end
    membership_request = MembershipRequest.last
    assert_equal membership_request.roles, [mentor_role]
    assert membership_request.joined_directly?
    assert_equal membership_request.accepted_as, mentor_role.name
    assert membership_request.accepted?
    assert_redirected_to edit_member_path(member, root: program.root, first_visit: RoleConstants::MENTOR_NAME, ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION)
  end

  def test_edit_answered_membership_request_redirects_to_listing_page
    mem_req = membership_requests(:membership_request_0)
    mem_req.update_attributes!(status: MembershipRequest::Status::ACCEPTED, accepted_as: mem_req.role_names_str, admin: users(:f_admin))
    current_user_is :f_admin
    get :edit, params: { id: mem_req.id}
    assert_redirected_to membership_requests_path
    assert_nil flash[:error]
  end

  def test_edit_answered_membership_request_redirects_to_new_membership_page_for_non_admin
    mem_req = membership_requests(:membership_request_0)
    mem_req.update_attributes!(status: MembershipRequest::Status::ACCEPTED, accepted_as: mem_req.role_names_str, admin: users(:f_admin))
    current_member_is mem_req.member
    get :edit, params: { id: mem_req.id }
    assert_redirected_to new_membership_request_path
    assert_nil flash[:error]
  end

  def test_edit_non_existing_membership_request_redirects_to_listing_page
    current_user_is :f_admin
    get :edit, params: { id: 0}
    assert_redirected_to membership_requests_path
    assert_equal "The membership request you are trying to access doesn't exist.", flash[:error]
  end

  def test_edit_non_existing_membership_request_redirects_to_new_for_non_admin
    current_member_is membership_requests(:membership_request_0).member
    get :edit, params: { id: 0 }
    assert_redirected_to new_membership_request_path
    assert_equal "The membership request you are trying to access doesn't exist.", flash[:error]
  end

  def test_edit_inaccessible_to_non_requestor
    mem_req = membership_requests(:membership_request_0)
    current_user_is :f_student
    assert_permission_denied do
      get :edit, params: { id: mem_req.id}
    end
  end

  def test_edit
    mem_req = membership_requests(:membership_request_0)
    role_questions(:role_questions_4).update_attributes!(admin_only_editable: true)
    role_questions(:role_questions_6).update_attributes!(required: true, available_for: RoleQuestion::AVAILABLE_FOR::BOTH)
    role_questions(:mentor_file_upload_role_q).update_attributes!(available_for: RoleQuestion::AVAILABLE_FOR::BOTH)
    experience_question = create_membership_profile_question(question_text: 'Question', role_names: [RoleConstants::MENTOR_NAME], question_type: ProfileQuestion::Type::EXPERIENCE)

    current_user_is :f_admin
    get :edit, params: { id: mem_req.id}
    assert_response :success
    assert_equal ["mentor"], assigns(:roles)
    assert assigns(:is_admin_view)
    assert_false assigns(:is_self_view)
    assert_equal [profile_questions(:profile_questions_1), profile_questions(:profile_questions_2), profile_questions(:profile_questions_6)].collect(&:id), assigns(:required_question_ids)
    assert_equal_unordered [profile_questions(:profile_questions_1), profile_questions(:profile_questions_2), profile_questions(:profile_questions_4), profile_questions(:profile_questions_6), profile_questions(:mentor_file_upload_q), experience_question], assigns(:section_id_questions_map).values.flatten
    assert_equal({}, assigns(:answer_map))
    assert_no_match 'Click here to import your experience from', response.body
    assert_template partial: "_membership_request_form"
  end

  def test_edit_for_requestor
    mem_req = membership_requests(:membership_request_0)
    role_questions(:role_questions_4).update_attributes!(admin_only_editable: true)
    role_questions(:role_questions_6).update_attributes!(required: true, available_for: RoleQuestion::AVAILABLE_FOR::BOTH)
    role_questions(:mentor_file_upload_role_q).update_attributes!(available_for: RoleQuestion::AVAILABLE_FOR::BOTH)
    experience_question = create_membership_profile_question(question_text: 'Question', role_names: [RoleConstants::MENTOR_NAME], question_type: ProfileQuestion::Type::EXPERIENCE)

    current_member_is mem_req.member
    get :edit, params: { id: mem_req.id }
    assert_response :success
    assert_equal ["mentor"], assigns(:roles)
    assert assigns(:is_self_view)
    assert_false assigns(:is_admin_view)
    assert_equal [profile_questions(:profile_questions_1), profile_questions(:profile_questions_2), profile_questions(:profile_questions_6)].collect(&:id), assigns(:required_question_ids)
    assert_equal_unordered [profile_questions(:profile_questions_1), profile_questions(:profile_questions_2), profile_questions(:profile_questions_6), profile_questions(:mentor_file_upload_q), experience_question], assigns(:section_id_questions_map).values.flatten
    assert_equal({}, assigns(:answer_map))
    assert_template partial: "_membership_request_form"
    assert_match 'Click here to import your experience from', response.body
    assert_match /Users.startLinkedIn.*, \&\#39;#{mem_req.member_id}\&\#39;, \&\#39;#{RoleConstants::MENTOR_NAME}\&\#39;/ , response.body
  end

  def test_update_of_answered_membership_request_redirects_to_listing_page
    mem_req = membership_requests(:membership_request_0)
    mem_req.update_attributes!(status: MembershipRequest::Status::ACCEPTED, accepted_as: mem_req.role_names_str, admin: users(:f_admin))
    current_user_is :f_admin
    assert_equal "student_a", mem_req.first_name
    assert_equal "example", mem_req.last_name
    assert_equal  "student_0@example.com", mem_req.email
    post :update, params: { id: mem_req.id, membership_request: { first_name: "FN", last_name: "LN", email: "student_zero@example.com" }}
    assert_redirected_to membership_requests_path
    assert_nil flash[:error]
    assert_equal "student_a", mem_req.reload.first_name
    assert_equal "example", mem_req.last_name
    assert_equal  "student_0@example.com", mem_req.email
  end

  def test_update_of_answered_membership_request_redirects_to_new_for_requestor
    mem_req = membership_requests(:membership_request_0)
    mem_req.update_attributes!(status: MembershipRequest::Status::ACCEPTED, accepted_as: mem_req.role_names_str, admin: users(:f_admin))
    current_member_is mem_req.member
    assert_equal "student_a", mem_req.first_name
    assert_equal "example", mem_req.last_name
    assert_equal  "student_0@example.com", mem_req.email
    post :update, params: { id: mem_req.id, membership_request: { first_name: "FN", last_name: "LN", email: "student_zero@example.com" }}
    assert_redirected_to new_membership_request_path
    assert_nil flash[:error]
    assert_equal "student_a", mem_req.reload.first_name
    assert_equal "example", mem_req.last_name
    assert_equal  "student_0@example.com", mem_req.email
  end

  def test_update_of_non_existing_membership_request_redirects_to_new_for_requestor
    mem_req = membership_requests(:membership_request_0)
    current_member_is mem_req.member
    post :update, params: {  id: 0, membership_request: { first_name: "FN", last_name: "LN", email: "student_zero@example.com" }}
    assert_redirected_to new_membership_request_path
    assert_equal "The membership request you are trying to access doesn't exist.", flash[:error]
  end

  def test_update_inaccessible_to_non_requestor
    mem_req = membership_requests(:membership_request_0)
    current_user_is :f_student
    assert_equal "student_a", mem_req.first_name
    assert_equal "example", mem_req.last_name
    assert_equal  "student_0@example.com", mem_req.email
    assert_permission_denied do
      post :update, params: { id: mem_req.id, membership_request: { first_name: "FN", last_name: "LN", email: "student_zero@example.com" }}
    end
    assert_equal "student_a", mem_req.reload.first_name
    assert_equal "example", mem_req.last_name
    assert_equal  "student_0@example.com", mem_req.email
  end

  def test_update
    phone_question = role_questions(:role_questions_4)
    edu_question = role_questions(:role_questions_6)
    mem_req = membership_requests(:membership_request_0)
    member = mem_req.member

    assert_empty member.profile_answers
    assert_equal "student_a", mem_req.first_name
    assert_equal "example", mem_req.last_name
    assert_equal  "student_0@example.com", mem_req.email
    assert_equal "student_a", member.first_name
    assert_equal "example", member.last_name
    assert_equal  "student_0@example.com", member.email

    role_questions(:role_questions_4).update_attributes!(admin_only_editable: true)
    role_questions(:role_questions_6).update_attributes!(required: true, available_for: RoleQuestion::AVAILABLE_FOR::BOTH)

    current_user_is :f_admin
    post :update, params: { id: mem_req.id, membership_request: { first_name: "FN", last_name: "LN", email: "student_zero@example.com" },
      profile_answers: {
        "#{phone_question.profile_question_id}" => "123456789",
        "#{edu_question.profile_question_id}" => {"hidden"=>"", "new_education_attributes"=>[{"1"=>{"school_name"=>"CEG", "degree"=>"BE", "major"=>"CSE", "graduation_year"=>"2016"}}]}
      }
    }

    assert_redirected_to membership_requests_path
    assert_flash_in_page("The membership request has been updated successfully.")
    assert_equal "FN", mem_req.reload.first_name
    assert_equal "LN", mem_req.last_name
    assert_equal  "student_zero@example.com", mem_req.email
    assert_equal "FN", member.reload.first_name
    assert_equal "LN", member.last_name
    assert_equal  "student_zero@example.com", member.email
    assert_equal 2, member.profile_answers.size
    assert_equal "123456789", member.profile_answers.find_by(profile_question_id: phone_question.profile_question_id).answer_text
    assert_equal "CEG, BE, CSE", member.profile_answers.find_by(profile_question_id: edu_question.profile_question_id).answer_text
  end

  def test_update_for_non_admin
    edu_question = role_questions(:role_questions_6)
    mem_req = membership_requests(:membership_request_0)
    member = mem_req.member

    assert_empty member.profile_answers
    assert_equal "student_a", mem_req.first_name
    assert_equal "example", mem_req.last_name
    assert_equal  "student_0@example.com", mem_req.email
    assert_equal "student_a", member.first_name
    assert_equal "example", member.last_name
    assert_equal  "student_0@example.com", member.email

    role_questions(:role_questions_6).update_attributes!(available_for: RoleQuestion::AVAILABLE_FOR::BOTH)

    current_member_is member
    post :update, params: { id: mem_req.id, membership_request: { first_name: "FN", last_name: "LN", email: "student_zero@example.com" },
      profile_answers: {
        "#{edu_question.profile_question_id}" => {"hidden"=>"", "new_education_attributes"=>[{"1"=>{"school_name"=>"CEG", "degree"=>"BE", "major"=>"CSE", "graduation_year"=>"2016"}}]}
      }}

    assert_redirected_to new_membership_request_path
    assert_flash_in_page("The membership request has been updated successfully.")
    assert_equal "FN", mem_req.reload.first_name
    assert_equal "LN", mem_req.last_name
    assert_equal  "student_zero@example.com", mem_req.email
    assert_equal "FN", member.reload.first_name
    assert_equal "LN", member.last_name
    assert_equal  "student_zero@example.com", member.email
    assert_equal 1, member.profile_answers.size
    assert_equal "CEG, BE, CSE", member.profile_answers.find_by(profile_question_id: edu_question.profile_question_id).answer_text
  end

  def test_update_for_non_admin_respects_required_question
    edu_question = role_questions(:role_questions_6)
    mem_req = membership_requests(:membership_request_0)
    member = mem_req.member

    edu_question.update_attributes!(required:true, available_for: RoleQuestion::AVAILABLE_FOR::BOTH)

    current_member_is member
    post :update, params: { id: mem_req.id, membership_request: { first_name: "FN", last_name: "LN", email: "student_zero@example.com" }, profile_answers: {
        "#{edu_question.profile_question_id}" => {"hidden"=>"", "new_education_attributes"=>[{"1"=>{"school_name"=>"", "degree"=>"", "major"=>"", "graduation_year"=>""}}]}}}

    assert_template :edit
    assert assigns(:profile_answers_updation_error)
  end

  def test_update_email_with_existing_email_is_handled
    mem_req = membership_requests(:membership_request_0)
    member = mem_req.member

    current_member_is member
    post :update, params: { id: mem_req.id, membership_request: { first_name: "FN", last_name: "LN", email: "ram@example.com" } }
    assert_equal ["Email has already been taken"], assigns(:membership_request).errors.full_messages
  end

  def test_mobile_app_login_finish_experiment_cross_server
    @controller.stubs(:is_mobile_app?).returns(true)
    APP_CONFIG[:mobile_app_origin_server] = false
    @controller.expects(:finished_chronus_ab_test_only_use_cookie).never
    Experiments::MobileAppLoginWorkflow.expects(:finish_cross_server_experiments).with("uniq_token")
    get :signup_instructions, params: { uniq_token: "uniq_token"}
    APP_CONFIG[:mobile_app_origin_server] = true
  end

  private

  def mark_requests_accepted(requests, admin = users(:f_admin))
    requests.each do |r|
      r.admin = admin
      r.status = MembershipRequest::Status::ACCEPTED
      r.accepted_role_names = r.role_names
      r.save!
    end
  end

  def mark_requests_rejected(requests, admin = users(:f_admin))
    requests.each do |r|
      r.admin = admin
      r.status = MembershipRequest::Status::REJECTED
      r.response_text = "Reason"
      r.save!
    end
  end

  def create_dummy_membership_requests(program)
    3.times { |i| create_membership_request(member: members("student_#{i+6}"), roles: [RoleConstants::MENTOR_NAME]) }
  end

  def sample_multi_field_question_attributes
    {
      education: { new_education_attributes: [{ school_name: "CEG", degree: 'BTECH' }] },
      experience: { new_experience_attributes: [{ company: "Chronus" }] },
      publication: { new_publication_attributes: [{ title: "title1" }] },
      manager: { new_manager_attributes: [{ first_name: "Manager", last_name: 'Manager', email: 'manager@example.com' }] },
    }
  end
end

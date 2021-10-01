require_relative './../test_helper.rb'

class LinkedinImportControllerTest < ActionController::TestCase

  def test_login_feature_disabled
    program = programs(:albers)
    program.enable_feature(FeatureName::LINKEDIN_IMPORTS, false)

    current_program_is program
    assert_permission_denied do
      get :login
    end
  end

  def test_login_import_not_allowed
    program = programs(:albers)
    organization = program.organization
    security_setting = organization.security_setting
    security_setting.update_attribute(:linkedin_token, nil)

    current_program_is program
    assert_permission_denied do
      get :login
    end
  end

  def test_login_with_access_token
    current_program_is programs(:albers)
    @request.session[:linkedin_access_token] = "access-token"
    LinkedinImporter.any_instance.expects(:is_access_token_valid?).once.returns(true)

    get :login
    assert_redirected_to linkedin_callback_path(existing: true)
    assert_equal "access-token", assigns(:linkedin_importer).access_token
  end

  def test_login
    program = programs(:albers)
    linkedin_oauth = program.organization.linkedin_oauth
    linkedin_oauth.update_attribute(:enabled, false)

    current_program_is program
    OAuth2::Client.any_instance.expects(:authorize_url).once.returns("https://linkedin.com/chronus")
    @controller.expects(:get_open_auth_callback_url).once.returns("https://chronus.com/linkedin")
    get :login
    assert_redirected_to "https://linkedin.com/chronus"
    assert assigns(:auth_config).linkedin_oauth?
    assert_nil assigns(:linkedin_importer).access_token
  end

  def test_callback_feature_disabled
    program = programs(:albers)
    program.enable_feature(FeatureName::LINKEDIN_IMPORTS, false)

    current_program_is program
    assert_permission_denied do
      get :callback
    end
  end

  def test_callback_import_not_allowed
    program = programs(:albers)
    organization = program.organization
    security_setting = organization.security_setting
    security_setting.update_attribute(:linkedin_token, nil)

    current_program_is program
    assert_permission_denied do
      get :callback
    end
  end

  def test_callback_with_existing_param
    user = users(:f_mentor)
    user.member.update_attribute(:linkedin_access_token, "li123")
    assert_nil @request.session[:linkedin_access_token]

    current_user_is user
    get :callback, params: { existing: true}
    assert_response :success
    assert_equal "li123", @request.session[:linkedin_access_token]
  end

  def test_callback_with_authorization_code
    program = programs(:albers)
    auth_obj = ProgramSpecificAuth.new(program.organization.auth_configs.first, "")
    auth_obj.linkedin_access_token = "li123"
    assert_nil @request.session[:linkedin_access_token]

    current_program_is program
    ProgramSpecificAuth.expects(:new).once.returns(auth_obj)
    OpenAuth.expects(:authenticate?).once.returns(true)
    @controller.expects(:is_open_auth_state_valid?).once.returns(true)

    get :callback, params: { code: "authorization-code"}
    assert_response :success
    assert_equal "li123", @request.session[:linkedin_access_token]
    assert assigns(:auth_config).linkedin_oauth?
  end

  def test_callback_with_invalid_authorization_code
    program = programs(:albers)

    current_program_is program
    @controller.expects(:is_open_auth_state_valid?).once.returns(true)
    @controller.expects(:is_authorization_code_valid?).once.returns(false)
    get :callback, params: { code: "authorization-code"}
    assert_response :success
  end

  def test_data_feature_disabled
    program = programs(:albers)
    program.enable_feature(FeatureName::LINKEDIN_IMPORTS, false)

    current_program_is program
    assert_permission_denied do
      post :data
    end
  end

  def test_data_import_not_allowed
    program = programs(:albers)
    organization = program.organization
    security_setting = organization.security_setting
    security_setting.update_attribute(:linkedin_token, nil)

    current_program_is program
    assert_permission_denied do
      post :data
    end
  end

  def test_data_invalid_program
    user = users(:f_mentor)
    importable_section = user.member.organization.sections.find_by(title: "Work and Education")

    current_user_is user
    LinkedinImporter.any_instance.expects(:import_data).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::IMPORT_FROM_LINKEDIN).never
    assert_permission_denied do
      post :data, xhr: true, params: { id: user.id, section: importable_section.id, program_id: 0}
    end
  end

  def test_data_linkedin_error
    user = users(:f_mentor)
    importable_section = user.member.organization.sections.find_by(title: "Work and Education")

    current_user_is user
    LinkedinImporter.any_instance.expects(:import_data).once
    LinkedinImporter.any_instance.expects(:formatted_data).once.returns({})
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::IMPORT_FROM_LINKEDIN).never
    post :data, xhr: true, params: { id: user.id, section: importable_section.id}
    assert_response :success
    assert_equal "Sorry, we are unable to import the experiences", assigns(:error_flash)
  end

  def test_data_empty_values
    user = users(:f_mentor)
    importable_section = user.member.organization.sections.find_by(title: "Work and Education")

    current_user_is user
    LinkedinImporter.any_instance.expects(:import_data).once
    LinkedinImporter.any_instance.expects(:formatted_data).once.returns(educations: [], experiences: [], publications: [])
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::IMPORT_FROM_LINKEDIN).never
    post :data, xhr: true, params: { id: user.id, section: importable_section.id}
    assert_response :success
    assert_equal "Your private profile does not have any experience.", assigns(:error_flash)
  end

  def test_data_current_user_check
    user = users(:f_student)
    importable_section = user.member.organization.sections.find_by(title: "Work and Education")

    current_user_is users(:f_mentor)
    LinkedinImporter.any_instance.expects(:import_data).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::IMPORT_FROM_LINKEDIN).never
    assert_permission_denied do
      post :data, xhr: true, params: { id: user.id, section: importable_section.id}
    end
  end

  def test_data_edit_profile_page
    user = users(:f_mentor)
    member = user.member
    organization = member.organization
    linkedin_oauth = organization.linkedin_oauth
    linkedin_oauth.disable!

    importable_section = organization.sections.find_by(title: "Work and Education")
    education_question = profile_questions(:multi_education_q)
    experience_question = profile_questions(:multi_experience_q)
    publication_question = profile_questions(:multi_publication_q)
    education_answer = user.answer_for(education_question)
    experience_answer = user.answer_for(experience_question)
    publication_answer = user.answer_for(publication_question)
    assert_equal 2, education_answer.educations.size
    assert_equal 2, experience_answer.experiences.size
    assert_equal 2, publication_answer.publications.size

    current_user_is user
    LinkedinImporter.any_instance.expects(:import_data).once
    LinkedinImporter.any_instance.expects(:formatted_data).once.returns(build_return_value)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::IMPORT_FROM_LINKEDIN).once
    post :data, xhr: true, params: { id: user.id, section: importable_section.id}
    assert_response :success
    assert_equal user.program, assigns(:program)
    assert_equal member, assigns(:member)
    assert_equal user, assigns(:user)
    assert_equal user.role_names, assigns(:role)
    assert_equal_unordered importable_section.profile_questions.select(&:linkedin_importable?).collect(&:id), assigns(:answer_map).keys
    assert_equal_unordered importable_section.profile_questions.select(&:linkedin_importable?), assigns(:questions)
    assert_equal 4, assigns(:answer_map)[experience_question.id].experiences.size
    assert_nil assigns(:answer_map)[education_question.id]
    assert_nil assigns(:answer_map)[publication_question.id]
    assert_equal "12345", member.login_identifiers.find_by(auth_config_id: linkedin_oauth.id).identifier

    # Making sure that the imported records are new
    new_experience_1 = assigns(:answer_map)[experience_question.id].experiences[-2]
    new_experience_2 = assigns(:answer_map)[experience_question.id].experiences[-1]

    [new_experience_1, new_experience_2].each { |record| assert record.new_record? }

    assert_equal "Chronus Corporation", new_experience_1.company
    assert_equal "Software Engineer", new_experience_1.job_title
    assert_equal 2008, new_experience_1.start_year
    assert_equal 7, new_experience_1.start_month
    assert_nil new_experience_1.end_year
    assert new_experience_1.current_job?

    assert_equal "Chronus Corporation", new_experience_2.company
    assert_equal "Intern", new_experience_2.job_title
    assert_equal 2007, new_experience_2.start_year
    assert_equal 5, new_experience_2.start_month
    assert_equal 2007, new_experience_2.end_year
    assert_equal 8, new_experience_2.end_month
    assert_false new_experience_2.current_job?
  end

  def test_data_membership_form
    program = programs(:albers)
    importable_section = program.organization.sections.find_by(title: "Work and Education")
    education_question = profile_questions(:multi_education_q)
    experience_question = profile_questions(:multi_experience_q)
    publication_question = profile_questions(:multi_publication_q)

    current_organization_is program.organization
    LinkedinImporter.any_instance.expects(:import_data).once
    LinkedinImporter.any_instance.expects(:formatted_data).once.returns(build_return_value)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::IMPORT_FROM_LINKEDIN).never

    post :data, xhr: true, params: { section: importable_section.id, id: "false", membership_request_role_name: RoleConstants::MENTOR_NAME, membership_request_member_id: "", program_id: program.id}
    assert_response :success
    assert_equal program, assigns(:program)
    assert_nil assigns(:member)
    assert assigns(:is_from_membership_request)
    assert_equal [RoleConstants::MENTOR_NAME], assigns(:roles)
    assert_equal_unordered importable_section.profile_questions.select(&:linkedin_importable?).collect(&:id), assigns(:answer_map).keys
    assert_equal 2, assigns(:answer_map)[experience_question.id].experiences.size
    assert_nil assigns(:answer_map)[education_question.id]
    assert_nil assigns(:answer_map)[publication_question.id]
    assert_equal "12345", @request.session[:linkedin_login_identifier]
  end

  def test_data_membership_form_for_non_logged_in_dormant_member
    program = programs(:albers)
    importable_section = program.organization.sections.find_by(title: "Work and Education")
    education_question = profile_questions(:multi_education_q)
    experience_question = profile_questions(:multi_experience_q)
    publication_question = profile_questions(:multi_publication_q)
    dormant_member = members(:assistant)

    current_organization_is program.organization
    LinkedinImporter.any_instance.expects(:import_data).once
    LinkedinImporter.any_instance.expects(:formatted_data).once.returns(build_return_value)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::IMPORT_FROM_LINKEDIN).never
    @controller.stubs(:wob_member).returns(nil)

    post :data, xhr: true, params: { section: importable_section.id, id: "false", membership_request_role_name: RoleConstants::MENTOR_NAME, membership_request_member_id: dormant_member.id.to_s, program_id: program.id}
    assert_response :success
    assert_equal program, assigns(:program)
    assert_nil assigns(:member)
    assert assigns(:is_from_membership_request)
    assert_equal [RoleConstants::MENTOR_NAME], assigns(:roles)
    assert_equal_unordered importable_section.profile_questions.select(&:linkedin_importable?).collect(&:id), assigns(:answer_map).keys
    assert_equal 2, assigns(:answer_map)[experience_question.id].experiences.size
    assert_nil assigns(:answer_map)[education_question.id]
    assert_nil assigns(:answer_map)[publication_question.id]
    assert_equal "12345", @request.session[:linkedin_login_identifier]
  end

  def test_data_membership_form_for_member_with_existing_answers
    user = users(:f_mentor)
    member = user.member
    program = programs(:albers)
    organization = member.organization
    linkedin_oauth = organization.linkedin_oauth
    linkedin_oauth.disable!

    importable_section = organization.sections.find_by(title: "Work and Education")
    education_question = profile_questions(:multi_education_q)
    experience_question = profile_questions(:multi_experience_q)
    experience_question_1 = profile_questions(:experience_q)
    experience_question_2 = profile_questions(:profile_questions_7)
    publication_question = profile_questions(:multi_publication_q)

    mentor_role = program.find_role(RoleConstants::MENTOR_NAME)
    [education_question, experience_question, experience_question_1, experience_question_2, publication_question].each { |question| question.role_questions.find_by(role_id: mentor_role.id).update_attribute(:available_for, RoleQuestion::AVAILABLE_FOR::BOTH) }

    education_answer = user.answer_for(education_question)
    experience_answer = user.answer_for(experience_question)
    publication_answer = user.answer_for(publication_question)
    assert_equal 2, education_answer.educations.size
    assert_equal 2, experience_answer.experiences.size
    assert_equal 2, publication_answer.publications.size

    current_user_is user

    LinkedinImporter.any_instance.expects(:import_data).once
    LinkedinImporter.any_instance.expects(:formatted_data).once.returns(build_return_value)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::IMPORT_FROM_LINKEDIN).once

    post :data, xhr: true, params: { section: importable_section.id, id: "false", membership_request_role_name: RoleConstants::MENTOR_NAME, membership_request_member_id: "#{member.id}", program_id: program.id}
    assert_response :success
    assert_equal program, assigns(:program)
    assert_nil assigns(:member)
    assert assigns(:is_from_membership_request)
    assert_equal [RoleConstants::MENTOR_NAME], assigns(:roles)
    assert_equal_unordered importable_section.profile_questions.select(&:linkedin_importable?).collect(&:id), assigns(:answer_map).keys
    assert_equal_unordered importable_section.profile_questions.select(&:linkedin_importable?), assigns(:questions)
    assert_equal 4, assigns(:answer_map)[experience_question.id].experiences.size
    assert_nil assigns(:answer_map)[education_question.id]
    assert_nil assigns(:answer_map)[publication_question.id]
    assert_equal "12345", member.login_identifiers.find_by(auth_config_id: linkedin_oauth.id).identifier

    # Making sure that the imported records are new
    new_experience_1 = assigns(:answer_map)[experience_question.id].experiences[-2]
    new_experience_2 = assigns(:answer_map)[experience_question.id].experiences[-1]

    [new_experience_1, new_experience_2].each { |record| assert record.new_record? }

    assert_equal "Chronus Corporation", new_experience_1.company
    assert_equal "Software Engineer", new_experience_1.job_title
    assert_equal 2008, new_experience_1.start_year
    assert_equal 7, new_experience_1.start_month
    assert_nil new_experience_1.end_year
    assert new_experience_1.current_job?

    assert_equal "Chronus Corporation", new_experience_2.company
    assert_equal "Intern", new_experience_2.job_title
    assert_equal 2007, new_experience_2.start_year
    assert_equal 5, new_experience_2.start_month
    assert_equal 2007, new_experience_2.end_year
    assert_equal 8, new_experience_2.end_month
    assert_false new_experience_2.current_job?
  end

  def test_permission_denied_on_data_membership_form_for_different_user
    user = users(:f_mentor)
    member = user.member
    importable_section = member.organization.sections.find_by(title: "Work and Education")

    current_user_is :f_admin
    assert_permission_denied do
      post :data, xhr: true, params: { section: importable_section.id, id: "false", membership_request_role_name: RoleConstants::MENTOR_NAME, membership_request_member_id: "#{member.id}", program_id: user.program_id}
    end
  end

  def test_callback_success_feature_disabled
    program = programs(:albers)
    program.enable_feature(FeatureName::LINKEDIN_IMPORTS, false)

    current_program_is program
    assert_permission_denied do
      get :callback_success
    end
  end

  def test_callback_success_import_not_allowed
    program = programs(:albers)
    organization = program.organization
    security_setting = organization.security_setting
    security_setting.update_attribute(:linkedin_token, nil)

    current_program_is program
    assert_permission_denied do
      get :callback_success
    end
  end

  def test_callback_success
    current_program_is programs(:albers)
    get :callback_success
    assert_response :success
  end

  private

  def build_return_value
    education = { school_name: "Chronus", degree: "BS", major: "Web technologies", graduation_year: 2008 }
    experience_1 = { job_title: "Software Engineer", company: "Chronus Corporation", start_year: 2008, start_month: 7, current_job: true }
    experience_2 = { job_title: "Intern", company: "Chronus Corporation", start_year: 2007, start_month: 5, end_year: 2007, end_month: 8, current_job: false }
    publication = { title: "Publication", url: "http://publication.c", day: 1, month: 5, year: 2007, publisher: 'Publisher', authors: 'Author', description: 'Super publication' }
    return { id: "12345", experiences: [experience_1, experience_2] }
  end
end
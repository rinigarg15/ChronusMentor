require_relative './../../test_helper.rb'

class MentorRequest::InstructionsControllerTest < ActionController::TestCase
  def test_only_superuser_allowed
    current_user_is :f_admin

    get :index
    assert_redirected_to super_login_path
  end

  def test_permission_check
    current_user_is :f_student
    login_as_super_user

    assert !users(:f_student).can_manage_mentor_requests?

    assert_permission_denied do
      get :index
    end
  end

  def test_index
    login_as_super_user
    current_user_is :f_admin

    get :index
    assert_response :success
    #instruction is not a new record. It gets created on program creation itself
    assert_false assigns(:mentor_request_instruction).new_record?
  end

  def test_update
    programs(:albers).organization.languages.destroy_all
    m = programs(:albers).mentor_request_instruction

    login_as_super_user
    current_user_is :f_admin

    post :update, params: { :id => m.id, :mentor_request_instruction => {:content => "hello"}}
    assert_equal "hello", m.reload.content
    assert_equal "The instructions have been succesfully updated", flash[:notice]
    assert_redirected_to mentor_request_instructions_path
  end

  def test_no_access_for_program_with_disabled_ongoing_mentoring
    login_as_super_user
    current_user_is :f_admin
    # changing engagement type of program to career based
    programs(:albers).update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    assert_permission_denied do
      get :index
    end
  end

  def test_instruction_update_with_vulnerable_content_with_version_v1
    login_as_super_user
    current_user_is :f_admin
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, ChronusSanitization::HelperMethods::SANITIZATION_VERSION_V1)
    instruction = programs(:albers).mentor_request_instruction

    assert_no_difference "VulnerableContentLog.count" do
      post :update, params: { id: instruction.id, mentor_request_instruction: {content: "This is the body<script>alert(10);</script>"}}
    end
  end

  def test_instruction_update_with_vulnerable_content_with_version_v2
    login_as_super_user
    current_user_is :f_admin
    instruction = programs(:albers).mentor_request_instruction

    assert_difference "VulnerableContentLog.count" do
      post :update, params: { id: instruction.id, mentor_request_instruction: {content: "This is the body<script>alert(10);</script>"}}
    end
  end
end

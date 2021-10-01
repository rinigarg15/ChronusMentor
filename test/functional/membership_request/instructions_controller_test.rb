require_relative './../../test_helper.rb'

class MembershipRequest::InstructionsControllerTest < ActionController::TestCase
  def test_update_instruction
    login_as_super_user
    current_user_is :f_student
    add_role_permission(fetch_role(:albers, :student), 'manage_membership_forms')
    prog = programs(:albers)
    current_program_is prog

    MembershipRequest::Instruction.create(:program_id => prog.id, :content => "Test content")

    post :update, xhr: true, params: { :id => prog.membership_instruction.id,
      :membership_request_instruction => {:content => "Test content"}
    }

    instruction = prog.membership_instruction.reload
    assert_equal "Test content", instruction.content
  end

  def test_only_superuser_allowed
    current_user_is :f_admin
    prog = programs(:albers)
    current_program_is prog

    # disabling allow to join for all roles
    disable_membership_request!(prog)

    assert_permission_denied do
      post :create, xhr: true, params: { :membership_request_instruction => {:content => "Test content"}}
    end
  end

  def test_only_for_feature_enable_admins
    # allowing atleast one role of one of the programs to join
    enable_membership_request!(programs(:org_primary))

    current_user_is :f_admin
    prog = programs(:albers)
    current_program_is prog

    post :create, xhr: true, params: { :membership_request_instruction => {:content => "Test content"}}
    assert_response :success
  end

  def test_permission_check
    current_user_is :f_student
    prog = programs(:albers)
    current_program_is prog
    assert !users(:f_student).can_manage_membership_forms?

    assert_permission_denied do
      post :create, xhr: true, params: {
        :membership_request_instruction => {:content => "Test content"}
      }
    end
  end

  def test_get_instruction_form
    current_user_is :f_admin
    program = programs(:albers)
    current_program_is program
    instruction = MembershipRequest::Instruction.create(program_id: program.id, content: "Test content")

    get :get_instruction_form, xhr: true
    assert_response :success
    assert_equal instruction, assigns[:membership_request_instruction]
  end

  def test_create_instruction
    login_as_super_user
    current_user_is :f_admin
    prog = programs(:albers)
    current_program_is prog

    post :create, xhr: true, params: { :membership_request_instruction => {:content => "Test content"}}
    assert_response :success

    instruction = prog.membership_instruction.reload
    assert_equal "Test content", instruction.content
  end
end

require_relative './../test_helper.rb'
require 'minitest'
require 'mocha/setup'

# This tests the edit profile, new user signup experience of a user who is both a mentor AND a mentee
class MentorMenteeUsersControllerTest < ActionController::TestCase
  tests MembersController
  
  def test_get_mentor_edit_answers_for_first_visit_should_redirect_to_mentee_profile_edit_if_there_are_no_mentor_profile_questions
    current_user_is :f_mentor_student
    current_program_is :albers
    create_student_question

    get :edit, params: { :id => members(:f_mentor_student), :first_visit => 'mentor' }
    assert_response :success
    assert_nil cookies[DISABLE_PROFILE_PROMPT]
  end

  def test_get_mentor_edit_answers_should_redirect_to_program_root_path_if_there_are_no_mentor_or_mentee_profile_questions
    current_user_is :f_mentor_student
    current_program_is :albers
    programs(:org_primary).profile_questions.destroy_all    
    programs(:org_primary).profile_questions.reload    

    get :edit, params: { :section => MembersController::EditSection::PROFILE, :id => members(:f_mentor_student) }
    assert_redirected_to program_root_path
  end

  def test_mentor_mentee_user_should_get_edit_mentor_questions_on_accessing_edit_answers_page_without_params
    current_user_is :f_mentor_student
    current_program_is :albers
    create_mentor_question

    get :edit, params: { :section => MembersController::EditSection::PROFILE, :id => members(:f_mentor_student)}
    assert_response :success    
  end

  def test_mentor_mentee_user_should_get_mentee_questions_with_student_role_params
    current_user_is :f_mentor_student
    current_program_is :albers
    create_student_question

    get :edit, params: { :section => MembersController::EditSection::PROFILE, :id => members(:f_mentor_student)}
    assert_response :success    
  end

  def test_create_mentor_profile_for_a_mentor_mentee_user_should_redirect_to_edit_student_answers
    current_user_is :f_mentor_student
    current_program_is :albers
    q = create_question(:role_names => [RoleConstants::MENTOR_NAME], :section => programs(:albers).sections.last)

    post :update_answers, params: { :id => members(:f_mentor_student), :profile_answers => { q.id => "This is the answer" }, :first_visit => 'mentor'}
    assert_redirected_to edit_member_path(members(:f_mentor_student), :first_visit => 'mentor', ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION, section: MembersController::EditSection::PROFILE)
  end

  def test_create_student_profile_for_a_mentor_mentee_user_should_redirect_to_program_root_path
    current_user_is :f_mentor_student
    current_program_is :albers
    q = create_question(:role_names => [RoleConstants::STUDENT_NAME], :section => programs(:albers).sections.last)

    post :update_answers, params: { :id => members(:f_mentor_student),
      :profile_answers => { q.id => "This is the answer" }, :first_visit => 'mentor',
      :last_section => true
    }
    assert_redirected_to edit_member_path(members(:f_mentor_student), :section => MembersController::EditSection::MENTORING_SETTINGS, :first_visit => 'mentor', ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION)
  end

  def test_should_not_render_similar_questions_but_render_answers_from_mentor_profile_for_mentor_mentee_in_student_profile
    programs(:org_primary).profile_questions.destroy_all
    current_user_is :f_mentor_student
    current_program_is :albers
    sq = create_student_question
    sq2 = create_student_question(:question_text => "What the time now?")
    mq = create_mentor_question
    
    ans = ProfileAnswer.create(:profile_question => mq.profile_question, :ref_obj => members(:f_mentor_student), :answer_text => "Abc")
    programs(:albers).reload
    users(:f_mentor_student).reload

    get :edit, params: { :id => members(:f_mentor_student).id}
    assert_response :success    

      # A similar question should not be rendered only once
      assert_select "input[type=text][name=?]", "profile_answers[#{sq.profile_question.id}]", :count => 1

      # A non-similar question should be rendered
      assert_select "input[type=text][name=?]", "profile_answers[#{sq2.profile_question.id}]"
  end
end
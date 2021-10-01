require_relative './../test_helper.rb'

class MembershipQuestionsControllerTest < ActionController::TestCase
  def setup
    super
    current_program_is :albers
    @questions = []
    @questions << create_membership_profile_question(:role_names => [RoleConstants::STUDENT_NAME])
    @questions << create_membership_profile_question(:role_names => [RoleConstants::MENTOR_NAME])
    @questions << create_membership_profile_question(:role_names => [RoleConstants::STUDENT_NAME])

    role = create_role(:name => 'membership_manager')
    programs(:albers).reload
    mem_admin = create_user(:role_names => ['membership_manager'])
    current_program_is :albers
    current_user_is mem_admin
    add_role_permission(role, 'manage_membership_forms')

    @questions_for_mentor = programs(:albers).role_questions_for(RoleConstants::MENTOR_NAME).membership_questions.collect(&:profile_question).uniq
    @questions_for_mentee = programs(:albers).role_questions_for(RoleConstants::STUDENT_NAME).membership_questions.collect(&:profile_question).uniq

  end

  # INDEX ----------------------------------------------------------------------

  def test_index_only_for_super_user
    # disabling allow to join for all roles
    disable_membership_request!(programs(:albers))
    
    update_profile_question_types_appropriately
    assert_permission_denied do
      get :index
    end
  end

  def test_index_only_for_feature_enable_admins
    # allowing atleast one role of one of the programs to join
    enable_membership_request!(programs(:org_primary))

    programs(:org_primary).enable_feature(FeatureName::MANAGER)
    update_profile_question_types_appropriately
    get :index, params: { :role => RoleConstants::STUDENT_NAME}
    assert_response :success
  end

  def test_index_only_for_admin
    login_as_super_user
    current_user_is :f_student

    assert_permission_denied do
      get :index
    end
  end

  def test_questions_index
    login_as_super_user
    update_profile_question_types_appropriately
    programs(:org_primary).enable_feature(FeatureName::MANAGER)
    get :index
    assert_response :success
    assert_template 'index'
    assert_select 'html'
    assert_equal programs(:albers).role_questions.collect(&:profile_question).uniq.sort_by(&:position), assigns(:membership_profile_questions)
  end

  # PREVIEW---------------------------------------------------------------------

  def test_preview_only_for_super_user
    assert_permission_denied do
      get :preview
    end
  end

  def test_preview_only_for_feature_enable_admins
    current_user_is :f_admin

    # allowing atleast one role of one of the programs to join
    enable_membership_request!(programs(:org_primary))

    get :preview
    assert_response :success
  end

  def test_preview_only_for_program_level_admins
    # allowing atleast one role of one of the programs to join
    enable_membership_request!(programs(:org_primary))

    user = users(:f_mentor)
    user.promote_to_role!([RoleConstants::ADMIN_NAME], users(:f_admin))
    current_user_is :f_mentor

    get :preview
    assert_response :success
  end

  def test_preview_questions_and_sections_non_ajax
    login_as_super_user
    questions = programs(:albers).membership_questions_for([])

    get :preview, params: { :program_id => programs(:albers).id}

    assert_equal programs(:albers), assigns(:preview_program)
    assert_empty assigns(:required_questions)
    assert_empty assigns(:grouped_role_questions)
    assert_equal questions.group_by(&:section_id), assigns(:membership_profile_questions)
    assert_equal questions.collect(&:section).uniq.sort_by(&:position), assigns(:sections)
  end

  def test_preview_questions_and_sections_ajax
    login_as_super_user
    mentor_role = programs(:albers).roles.find{|role| role.name == RoleConstants::MENTOR_NAME}
    student_role = programs(:albers).roles.find{|role| role.name == RoleConstants::STUDENT_NAME}

    get :preview, xhr: true, params: { :filter => {:program => programs(:albers), :role => [mentor_role.id]}}
    assert_equal programs(:albers), assigns(:preview_program)
    assert_equal [RoleConstants::MENTOR_NAME], assigns(:filter_role)
    assert_equal @questions_for_mentor.group_by(&:section_id), assigns(:membership_profile_questions)
    assert_equal @questions_for_mentor.collect(&:section).uniq.sort_by(&:position), assigns(:sections)

    required_questions = programs(:albers).role_questions_for([RoleConstants::MENTOR_NAME]).required.select([:required, :profile_question_id]).group_by(&:profile_question_id)
    required_questions.each do |key,value|
      assert_equal value.first.attributes, assigns(:required_questions)[key].first.attributes
    end

    grouped_role_questions = programs(:albers).role_questions_for([RoleConstants::MENTOR_NAME], fetch_all: true).group_by(&:profile_question_id)
    grouped_role_questions.each do |key,value|
      assert_equal value, assigns(:grouped_role_questions)[key]
    end

    get :preview, xhr: true, params: { :filter => {:program => programs(:albers), :role => [mentor_role.id, student_role.id]}}
    assert_equal programs(:albers), assigns(:preview_program)
    assert_equal [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], assigns(:filter_role)
    all_questions = (@questions_for_mentor+@questions_for_mentee).uniq.group_by(&:section_id)
    membership_profile_questions = assigns(:membership_profile_questions)
    all_questions.each do |section_id, questions|
      assert_equal_unordered questions, membership_profile_questions[section_id]
    end
    required_questions = programs(:albers).role_questions_for([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]).required.select([:required, :profile_question_id]).group_by(&:profile_question_id)
    required_questions.each do |key,value|
      assert_equal value.first.attributes, assigns(:required_questions)[key].first.attributes
    end

    grouped_role_questions = programs(:albers).role_questions_for([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], fetch_all: true).group_by(&:profile_question_id)
    grouped_role_questions.each do |key,value|
      assert_equal value, assigns(:grouped_role_questions)[key]
    end

    assert_equal_unordered (@questions_for_mentor+@questions_for_mentee).collect(&:section).uniq.sort_by(&:position), assigns(:sections)
  end

  # UPDATE_ROLE_QUESTIONS-------------------------------------------------------

  def test_update_role_questions
    login_as_super_user

    mentor_role_questions = programs(:albers).role_questions_for(RoleConstants::MENTOR_NAME).membership_questions
    mentor_role_id = mentor_role_questions.empty? ? "" : mentor_role_questions.first.role_id
    question_updated = @questions.first
    student_role_id = programs(:albers).role_questions_for(RoleConstants::STUDENT_NAME).membership_questions.first.role_id

    assert_equal question_updated.role_questions.count, 1
    User.expects(:es_reindex_for_profile_score).with(mentor_role_id).twice
    post :update_role_questions, xhr: true, params: { :role => RoleConstants::MENTOR_NAME, :profile_question_id => question_updated.id, :role_id => mentor_role_id}
    assert_equal question_updated.role_questions.count, 2

    post :update_role_questions, xhr: true, params: { :role => RoleConstants::MENTOR_NAME, :profile_question_id => question_updated.id, :role_id => mentor_role_id}
    assert_equal question_updated.role_questions.count, 1

    User.expects(:es_reindex_for_profile_score).with(student_role_id).once
    rq_also_for_profile = question_updated.role_questions.last
    rq_also_for_profile.update_attributes({:available_for => RoleQuestion::AVAILABLE_FOR::BOTH})
    post :update_role_questions, xhr: true, params: { :role => RoleConstants::STUDENT_NAME, :profile_question_id => question_updated.id, :role_id => mentor_role_id}
    assert_equal question_updated.role_questions.count, 1

  end
  
end

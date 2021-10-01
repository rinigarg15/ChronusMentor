require_relative './../test_helper.rb'

class ExplicitUserPreferencesControllerTest < ActionController::TestCase
	## NEW ##
  def test_new_permission_denied
    current_user_is :f_mentor_student
    assert_permission_denied do
      get :new, xhr: true, params: {format: :js}
    end
  end

  def test_new
    programs(:albers).enable_feature(FeatureName::EXPLICIT_USER_PREFERENCES, true)
    current_user_is :f_mentor_student
    get :new, xhr: true, params: {format: :js}
  end

  ## CREATE ##
  def test_create_permission_denied
    current_user_is :f_student
    assert_permission_denied do
      post :create, xhr: true, params: {format: :js, explicit_user_preference: {role_question_id: 1, question_choice_ids: "1,2,3", preference_weight: 1}}
    end
  end

  def test_create_explicit_preference
    role_question = role_questions(:student_multi_choice_role_q)
    question_choice = question_choices(:student_multi_choice_q_2)
    programs(:albers).enable_feature(FeatureName::EXPLICIT_USER_PREFERENCES, true)
    current_user_is :f_student
    assert_difference "ExplicitUserPreference.count" do
      post :create, xhr: true, params: {format: :js, explicit_user_preference: {role_question_id: role_question.id, question_choice_ids: question_choice.id.to_s, preference_weight: 1}}
    end
    assert_equal 3, assigns(:explicit_preference).preference_weight #Weight is always set as 3 while creating
    assert_equal users(:f_student), assigns(:explicit_preference).user
    assert_equal role_question, assigns(:explicit_preference).role_question
    assert_equal_unordered [question_choice], assigns(:explicit_preference).question_choices
  end

  def test_create_explicit_preference_with_preference_weight
    programs(:albers).enable_feature(FeatureName::EXPLICIT_USER_PREFERENCES, true)
    current_user_is :f_mentor_student
    role_question = users(:f_mentor_student).roles.first.role_questions.select{|role_que| role_que.profile_question.location?}.first
    assert_difference "ExplicitUserPreference.count" do
      post :create, xhr: true, params: {format: :js, explicit_user_preference: {role_question_id: role_question.id, preference_string: "Chennai, Tamilnadu, India"}}
    end
    assert_equal users(:f_mentor_student), assigns(:explicit_preference).user
    assert_equal role_question, assigns(:explicit_preference).role_question
    assert_equal "Chennai, Tamilnadu, India", assigns(:explicit_preference).preference_string
  end

  ## UPDATE ##
  def test_update_permission_denied
    explicit_preference = explicit_user_preferences(:explicit_user_preference_1)
    current_user_is :f_student
    assert_permission_denied do
      put :update, params: {format: :js, id: explicit_preference.id, explicit_user_preference: {role_question_id: 1, question_choice_ids: "1,2,3", preference_weight: 1}}
    end
  end

  def test_update_explicit_preference
    explicit_preference = explicit_user_preferences(:explicit_user_preference_1)
    question_choice = question_choices(:student_single_choice_q_3)
    current_user_is :arun_albers
    programs(:albers).enable_feature(FeatureName::EXPLICIT_USER_PREFERENCES, true)
    assert_no_difference "ExplicitUserPreference.count" do
      put :update, params: {format: :js, id: explicit_preference.id, explicit_user_preference: {question_choice_ids: question_choice.id.to_s, preference_weight: 3}}
    end
    assert_equal 5, assigns(:explicit_preference).preference_weight #Weignt shouldn't change in update  
    assert_equal_unordered [question_choice], assigns(:explicit_preference).question_choices
  end

  ## DESTROY ##
  def test_destroy_permission_denied
    explicit_preference = explicit_user_preferences(:explicit_user_preference_1)
    current_user_is :f_mentor_student
    assert_permission_denied do
      post :destroy, xhr: true, params: {format: :js, id: explicit_preference.id}
    end
  end

  def test_destroy_explicit_preference
    explicit_preference = explicit_user_preferences(:explicit_user_preference_1)
    programs(:albers).enable_feature(FeatureName::EXPLICIT_USER_PREFERENCES, true)
    current_user_is :arun_albers
    assert_difference "ExplicitUserPreference.count", -1 do
      post :destroy, xhr: true, params: {format: :js, id: explicit_preference.id}
    end
  end

   ## BULK DESTROY ##
  def test_bulk_destroy_explicit_preference
    current_user_is :arun_albers
    programs(:albers).enable_feature(FeatureName::EXPLICIT_USER_PREFERENCES, true)
    assert_difference "ExplicitUserPreference.count", -3 do
      post :bulk_destroy, xhr: true, params: {format: :js}
    end
    assert_empty users(:student_9).explicit_user_preferences.to_a
  end

  def test_change_weight_permission_denied
    explicit_preference = explicit_user_preferences(:explicit_user_preference_1)
    current_user_is :f_student
    assert_permission_denied do
      put :change_weight, params: {format: :js, id: explicit_preference.id, explicit_user_preference: {preference_weight: 1}}
    end
    assert_equal 5, explicit_preference.reload.preference_weight
  end

  def test_change_weight
    explicit_preference = explicit_user_preferences(:explicit_user_preference_1)
    programs(:albers).enable_feature(FeatureName::EXPLICIT_USER_PREFERENCES, true)
    current_user_is :arun_albers
    assert_no_difference "ExplicitUserPreference.count" do
      put :change_weight, params: {format: :js, id: explicit_preference.id, explicit_user_preference: {preference_weight: 1}}
    end
    assert_equal 1, assigns(:explicit_preference).preference_weight
  end
end

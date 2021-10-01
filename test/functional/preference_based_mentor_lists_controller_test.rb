require_relative './../test_helper.rb'

class PreferenceBasedMentorListsControllerTest < ActionController::TestCase

  def test_index
    current_user_is :f_admin

    assert_permission_denied do
      get :index, xhr: true
    end
    assert_nil assigns(:pbml_recommendations_service)

    User.any_instance.stubs(:can_view_preferece_based_mentor_lists?).returns(true)
    get :index, xhr: true
    assert_equal users(:f_admin), assigns(:pbml_recommendations_service).mentee
    assert_equal programs(:albers), assigns(:pbml_recommendations_service).program
  end

  def test_ignore
    current_user_is :f_admin
    qc = question_choices(:question_choices_5)

    assert_permission_denied do
      assert_no_difference 'PreferenceBasedMentorList.count' do
        get :ignore, xhr: true, params: {preference_based_mentor_list: {ref_obj_id: qc.id, ref_obj_type: QuestionChoice.name, profile_question_id: qc.ref_obj.id, weight: 0.54}}
      end
    end

    User.any_instance.stubs(:can_view_preferece_based_mentor_lists?).returns(true)
    assert_raise(Authorization::PermissionDenied, "Tried to constantize unsafe string Invalid") do
      assert_no_difference 'PreferenceBasedMentorList.count' do
        get :ignore, xhr: true, params: {preference_based_mentor_list: {ref_obj_id: qc.id, ref_obj_type: 'Invalid', profile_question_id: qc.ref_obj.id, weight: 0.54}}
      end
    end

    assert_difference 'PreferenceBasedMentorList.count' do
      get :ignore, xhr: true, params: {preference_based_mentor_list: {ref_obj_id: qc.id, ref_obj_type: QuestionChoice.name, profile_question_id: qc.ref_obj.id, weight: 0.54}}
    end
    pbml = PreferenceBasedMentorList.last
    assert_equal qc, assigns(:ref_obj)
    assert_equal 0.54, assigns(:weight)
    assert_equal users(:f_admin), pbml.user
    assert_equal qc, pbml.ref_obj
    assert pbml.ignored?

    assert_no_difference 'PreferenceBasedMentorList.count' do
      get :ignore, xhr: true, params: {preference_based_mentor_list: {ref_obj_id: qc.id, ref_obj_type: QuestionChoice.name, profile_question_id: qc.ref_obj.id, weight: 0.1}}
    end
    assert_equal qc, assigns(:ref_obj)
    assert_equal 0.1, assigns(:weight)
  end
end
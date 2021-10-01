require_relative "./../test_helper.rb"

class IgnorePreferencesControllerTest < ActionController::TestCase
  def test_create_ignore_preference_denied
    current_user_is :f_admin

    assert_permission_denied do
      post :create, xhr: true, params: { ignore_preference: { preference_marked_user_id: 2 } }
    end
  end

  def test_delete_ignore_preference_denied
    current_user_is :f_admin

    assert_permission_denied do
      delete :destroy, xhr: true, params: { id: abstract_preferences(:ignore_1).id }
    end
  end

  def test_create_ignore_preference
    Program.any_instance.stubs(:skip_and_favorite_profiles_enabled?).returns(true)
    current_user_is :f_student
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::MARK_AS_IGNORE, {context_place: AbstractPreference::Source::PROFILE}).once

    post :create, xhr: true, params: { ignore_preference: { preference_marked_user_id: users(:f_mentor_student) }, recommendations_view: AbstractPreference::Source::PROFILE }
    assert users(:f_mentor_student), assigns(:mentor)
    assert_equal_hash({users(:f_mentor).id=>abstract_preferences(:ignore_1).id, users(:ram).id=>abstract_preferences(:ignore_3).id, users(:f_mentor_student).id => users(:f_student).ignore_preferences.last.id}, assigns(:ignore_preferences_hash))
    assert_equal AbstractPreference::Source::PROFILE,  assigns(:recommendations_view)
    assert_equal users(:f_mentor_student).name_only, assigns(:mentor_name)
    assert_equal users(:f_student).ignore_preferences.last, assigns(:ignore_preference)
    assert_nil assigns(:mentors_list)
    assert_equal_hash({users(:f_mentor).id=>abstract_preferences(:favorite_1).id, users(:robert).id=>abstract_preferences(:favorite_3).id}, assigns(:favorite_preferences_hash))
  end

  def test_create_ignore_preference_from_admin_recos
    Program.any_instance.stubs(:skip_and_favorite_profiles_enabled?).returns(true)
    current_user_is :f_student
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::MARK_AS_IGNORE, {context_place: AbstractPreference::Source::ADMIN_RECOMMENDATIONS}).once

    post :create, xhr: true, params: { ignore_preference: { preference_marked_user_id: users(:f_mentor_student) }, recommendations_view: AbstractPreference::Source::ADMIN_RECOMMENDATIONS }
    assert users(:f_mentor_student), assigns(:mentor)
    assert_equal_hash({users(:f_mentor).id=>abstract_preferences(:ignore_1).id, users(:ram).id=>abstract_preferences(:ignore_3).id, users(:f_mentor_student).id => users(:f_student).ignore_preferences.last.id}, assigns(:ignore_preferences_hash))
    assert_equal AbstractPreference::Source::ADMIN_RECOMMENDATIONS,  assigns(:recommendations_view)
    assert_equal users(:f_mentor_student).name_only, assigns(:mentor_name)
    assert_equal users(:f_student).ignore_preferences.last, assigns(:ignore_preference)
    assert_nil assigns(:mentors_list)
    assert_equal_hash({users(:f_mentor).id=>abstract_preferences(:favorite_1).id, users(:robert).id=>abstract_preferences(:favorite_3).id}, assigns(:favorite_preferences_hash))
  end

  def test_delete_ignore_preference
    Program.any_instance.stubs(:skip_and_favorite_profiles_enabled?).returns(true)
    MentorRecommendationsService.any_instance.stubs(:get_recommendations).returns([{member: members(:f_admin), slots_availabile_for_mentoring: 3, max_score: 90, recommendation_score: 3.7, recommended_for: "ongoing"}, {member: members(:f_student), slots_availabile_for_mentoring: 3, max_score: 90, recommendation_score: 3.7, recommended_for: "ongoing"}])
    current_user_is :f_student
    User.any_instance.stubs(:get_student_cache_normalized).returns({users(:f_mentor).id => 23})
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UNMARK_AS_IGNORE, {context_place: AbstractPreference::Source::SYSTEM_RECOMMENDATIONS}).once

    delete :destroy, xhr: true, params: { id: abstract_preferences(:ignore_1).id, recommendations_view: AbstractPreference::Source::SYSTEM_RECOMMENDATIONS, slide_down: true }
    assert users(:f_mentor_student), assigns(:mentor)
    assert_equal_hash({users(:ram).id=>abstract_preferences(:ignore_3).id}, assigns(:ignore_preferences_hash))
    assert_equal AbstractPreference::Source::SYSTEM_RECOMMENDATIONS,  assigns(:recommendations_view)
    assert_equal [{member: members(:f_admin), slots_availabile_for_mentoring: 3, max_score: 90, recommendation_score: 3.7, recommended_for: "ongoing"}, {member: members(:f_student), slots_availabile_for_mentoring: 3, max_score: 90, recommendation_score: 3.7, recommended_for: "ongoing"}], assigns(:mentors_list)
    assert_equal_hash({users(:f_mentor).id=>abstract_preferences(:favorite_1).id, users(:robert).id=>abstract_preferences(:favorite_3).id}, assigns(:favorite_preferences_hash))
    assert_equal 23, assigns(:match_score)
    assert assigns(:slide_down)
  end

  def test_delete_ignore_preference_empty_student_cache_normalized
    Program.any_instance.stubs(:skip_and_favorite_profiles_enabled?).returns(true)
    MentorRecommendationsService.any_instance.stubs(:get_recommendations).returns([{member: members(:f_admin), slots_availabile_for_mentoring: 3, max_score: 90, recommendation_score: 3.7, recommended_for: "ongoing"}, {member: members(:f_student), slots_availabile_for_mentoring: 3, max_score: 90, recommendation_score: 3.7, recommended_for: "ongoing"}])
    current_user_is :f_student
    User.any_instance.stubs(:get_student_cache_normalized).returns({})
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UNMARK_AS_IGNORE, {context_place: AbstractPreference::Source::SYSTEM_RECOMMENDATIONS}).once

    delete :destroy, xhr: true, params: { id: abstract_preferences(:ignore_1).id, recommendations_view: AbstractPreference::Source::SYSTEM_RECOMMENDATIONS, slide_down: false }
    assert users(:f_mentor_student), assigns(:mentor)
    assert_equal_hash({users(:ram).id=>abstract_preferences(:ignore_3).id}, assigns(:ignore_preferences_hash))
    assert_equal AbstractPreference::Source::SYSTEM_RECOMMENDATIONS,  assigns(:recommendations_view)
    assert_nil assigns(:match_score)
    assert_false assigns(:slide_down)
  end

  def test_set_user_preferences_hash
    @controller.instance_variable_set(:@current_user, users(:f_student))
    assert_equal_hash({users(:f_mentor).id=>abstract_preferences(:ignore_1).id, users(:ram).id=>abstract_preferences(:ignore_3).id}, @controller.send(:set_user_preferences_hash))
  end
end
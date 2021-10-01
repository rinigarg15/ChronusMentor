require_relative "./../test_helper.rb"

class FavoritePreferencesControllerTest < ActionController::TestCase
  def test_create_favorite_preference_denied
    current_user_is :f_admin

    assert_permission_denied do
      post :create, xhr: true, params: { favorite_preference: { preference_marked_user_id: 2 } }
    end
  end

  def test_delete_favorite_preference_denied
    current_user_is :f_admin

    assert_permission_denied do
      delete :destroy, xhr: true, params: { id: abstract_preferences(:favorite_1).id }
    end
  end

  def test_create_favorite_preference
    Program.any_instance.stubs(:skip_and_favorite_profiles_enabled?).returns(true)
    current_user_is :f_student

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::MARK_AS_FAVORITE, {context_place: 'apple'}).once
    post :create, xhr: true, params: { favorite_preference: { preference_marked_user_id: users(:f_mentor_student).id }, src: 'apple' }
    assert users(:f_mentor_student).id, assigns(:mentor_id)
    assert users(:f_mentor_student).name_only, assigns(:mentor_name)
    assert_equal_hash({users(:f_mentor).id=>abstract_preferences(:favorite_1).id, users(:robert).id=>abstract_preferences(:favorite_3).id, users(:f_mentor_student).id => users(:f_student).favorite_preferences.last.id}, assigns(:favorite_preferences_hash))
  end

  def test_delete_favorite_preference
    Program.any_instance.stubs(:skip_and_favorite_profiles_enabled?).returns(true)
    current_user_is :f_student

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UNMARK_AS_FAVORITE, {context_place: 'apple'}).once
    delete :destroy, xhr: true, params: { id: abstract_preferences(:favorite_1).id, src: 'apple' }
    assert users(:f_mentor_student).id, assigns(:mentor_id)
    assert users(:f_mentor_student).name_only, assigns(:mentor_name)
    assert_equal_hash({users(:robert).id=>abstract_preferences(:favorite_3).id}, assigns(:favorite_preferences_hash))
  end

  def test_index
    current_user_is :f_student
    back_link = {link: nil}
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_FAVORITES).once
    get :index, params: { src: 'apple' }
    assert_equal back_link, assigns(:back_link)
    assert_equal_unordered [users(:f_mentor).id, users(:robert).id], assigns(:favorite_users).pluck(:id)
  end

  def test_index_with_a_back_url
    current_user_is :f_student
    session[:last_visit_url] = "/test_url"
    back_link = {link: "/test_url"}
    get :index
    assert_equal back_link, assigns(:back_link)
  end

  def test_index_permission_denied
    current_user_is :f_admin

    assert_permission_denied do
      get :index
    end
  end

end
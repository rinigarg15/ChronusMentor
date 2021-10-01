require_relative './../test_helper.rb'

class UserFavoritesControllerTest < ActionController::TestCase

  def setup
    super
    current_program_is :albers
  end

  # This is to test the access is only for student
  def test_only_student_can_access
    current_user_is :f_admin

    assert_permission_denied do
      post :create, xhr: true, params: { :favorite_id => users(:f_mentor).id}
    end

    current_user_is :f_mentor

    assert_permission_denied do
      post :create, xhr: true, params: { :favorite_id => users(:f_mentor).id}
    end
  end

  def test_create
    current_user_is :f_student

    assert_difference 'UserFavorite.count' do
      post :create, xhr: true, params: { :user_favorite => {:favorite_id => users(:f_mentor).id}}
    end
    assert_equal users(:f_mentor).id, assigns(:user_favorite).favorite_id
  end

  def test_multiple_create
    current_user_is :f_student

    assert_difference 'UserFavorite.count' do
      post :create, xhr: true, params: { :user_favorite => {:favorite_id => users(:f_mentor).id}}
    end
    assert_no_difference 'UserFavorite.count' do
      post :create, xhr: true, params: { :user_favorite => {:favorite_id => users(:f_mentor).id}}
    end
    assert_equal users(:f_mentor).id, assigns(:user_favorite).favorite_id
  end

  def test_destory
    current_user_is :f_student
    user_fav = users(:f_student).user_favorites.create(:favorite_id => users(:f_mentor).id)

    assert_difference 'UserFavorite.count', -1 do
      post :destroy, xhr: true, params: { :id => user_fav.id}
    end
  end

  def test_create_for_program_with_disabled_ongoing_mentoring
    current_user_is :f_student
    # changing engagement type of program to career based
    programs(:albers).update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    assert_permission_denied do
      post :create, xhr: true, params: { :favorite_id => users(:f_mentor).id}
    end
  end
end

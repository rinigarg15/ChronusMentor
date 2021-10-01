require_relative './../test_helper.rb'

class RequestFavoriteTest < ActiveSupport::TestCase

  def test_validate_mentor_request_presence
    assert_no_difference "RequestFavorite.count" do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :mentor_request do
        RequestFavorite.create!(:user => users(:f_student), :favorite => users(:f_mentor), :note => "Hi")
      end
    end
  end

  def test_validate_mentor_request_student
    req = create_mentor_request(:student => users(:f_student))
    assert_no_difference "RequestFavorite.count" do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :user do
        RequestFavorite.create!(:user => users(:f_mentor_student), :favorite => users(:f_mentor), :note => "Hi", :mentor_request_id => req.id)
      end
    end
  end

  def test_create
    req = create_mentor_request(:student => users(:f_student))
    assert_difference "RequestFavorite.count" do
      RequestFavorite.create!(:user => users(:f_student), :favorite => users(:f_mentor), :note => "Hi", :mentor_request_id => req.id)
    end
  end

  def test_should_destroy_req_favorite_when_a_favorited_mentor_is_destroyed
    req = create_mentor_request(:student => users(:f_student))
    mentor2 = create_user(:role_names => [RoleConstants::MENTOR_NAME])
    r1 = RequestFavorite.create!(:user => users(:f_student), :favorite => users(:f_mentor), :note => "Hi", :mentor_request_id => req.id)
    r2 = RequestFavorite.create!(:user => users(:f_student), :favorite => mentor2, :note => "Another mentor", :mentor_request_id => req.id)
    assert_equal_unordered([r1, r2], req.request_favorites)
    
    assert_difference "RequestFavorite.count", -1 do
      assert_difference("User.count", -1) do
        mentor2.destroy
      end
    end

    assert_equal_unordered([r1], req.reload.request_favorites)
  end
end

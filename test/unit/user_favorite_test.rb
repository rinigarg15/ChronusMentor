require_relative './../test_helper.rb'

class UserFavoriteTest < ActiveSupport::TestCase

  def test_user_is_required
    assert_no_difference 'UserFavorite.count' do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :user do
        UserFavorite.create!(:favorite => users(:f_mentor))
      end
    end
  end

  def test_mentor_is_required
    assert_no_difference 'UserFavorite.count' do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :favorite do
        UserFavorite.create!(:user => users(:f_student))
      end
    end
  end

  def test_create_success
    assert_difference 'UserFavorite.count' do
      UserFavorite.create!(:user => users(:f_student), :favorite => users(:f_mentor))
    end
  end

  def test_not_more_than_one_user_favorite_for_a_student_mentor_combination
    assert_difference 'UserFavorite.count' do
      UserFavorite.create!(:user => users(:f_student), :favorite => users(:f_mentor), :note => "He is the best")
    end

    # Try creating another user_favorite for the student with same mentor.
    assert_no_difference 'UserFavorite.count' do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :user do
        UserFavorite.create!(:user => users(:f_student), :favorite => users(:f_mentor), :note => "He is not the best")
      end
    end

    req = create_mentor_request
    assert_difference 'UserFavorite.count' do
      UserFavorite.create!(:user => users(:f_student), :favorite => users(:f_mentor), :note => "He is the best", :mentor_request_id => req.id)
    end

    assert_no_difference 'UserFavorite.count' do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :user do
        UserFavorite.create!(:user => users(:f_student), :favorite => users(:f_mentor), :note => "He is not the best", :mentor_request_id => req.id)
      end
    end

    # Try creating another user_favorite for the student with another mentor.
    assert_difference 'UserFavorite.count' do
      UserFavorite.create!(:user => users(:f_student), :favorite => create_user(:role_names => [RoleConstants::MENTOR_NAME], :program => programs(:albers)))
    end
  end

end

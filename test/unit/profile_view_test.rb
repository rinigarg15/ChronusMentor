require_relative './../test_helper.rb'

class ProfileViewTest < ActiveSupport::TestCase
  def test_validate_user
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :user do
      ProfileView.create!(viewed_by: users(:f_mentor))
    end
  end

  def test_validate_viewed_by
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :viewed_by do
      ProfileView.create!(user: users(:f_mentor))
    end
  end
end

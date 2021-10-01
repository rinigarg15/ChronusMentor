require_relative './../test_helper.rb'

class UserSettingTest < ActiveSupport::TestCase
  def test_validate_presence_of_user
    user_setting = UserSetting.new
    assert_false user_setting.valid?
    assert_equal(["can't be blank"], user_setting.errors[:user])
  end

  def test_belongs_to
    user_setting = user_settings(:f_mentor)
    assert_equal users(:f_mentor), user_setting.user
  end

  def test_update_limit_based_on_reason
    current_time = Time.now
    user_setting = user_settings(:f_mentor)
    User.any_instance.stubs(:get_meeting_limit_to_reset).returns(13)
    user_setting.update_attributes(max_meeting_slots: nil)
    user_setting.reload
    assert user_setting.update_limit_based_on_reason
    user_setting.reload
    assert_equal 13, user_setting.max_meeting_slots
    user_setting.update_attributes(max_meeting_slots: 14)
    user_setting.reload
    assert user_setting.update_limit_based_on_reason
    user_setting.reload
    assert_equal 13, user_setting.max_meeting_slots
  end
end

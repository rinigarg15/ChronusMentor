require_relative './../test_helper.rb'

class UserNotificationSettingTest < ActiveSupport::TestCase
  def test_belongs_to_user
    user = users(:f_admin)
    uns = UserNotificationSetting.create!(notification_setting_name: UserNotificationSetting::SettingNames::END_USER_COMMUNICATION, user_id: user.id)
    assert_equal user, uns.user
  end

  def test_validate_user_presence
    uns = UserNotificationSetting.new(notification_setting_name: UserNotificationSetting::SettingNames::END_USER_COMMUNICATION)
    assert_false uns.save
    assert_equal ["can't be blank"], uns.errors[:user]
  end

  def test_validate_notification_setting_name_valid
    user = users(:f_admin)
    uns = UserNotificationSetting.new(user_id: user.id)
    assert_false uns.save
    assert_equal ["is not included in the list"], uns.errors[:notification_setting_name]
    uns.notification_setting_name = 'something'
    assert_false uns.save
    assert_equal ["is not included in the list"], uns.errors[:notification_setting_name]
  end
end

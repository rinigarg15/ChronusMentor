require_relative './../test_helper.rb'

class NotificationSettingTest < ActiveSupport::TestCase
  def test_validate_program
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :program do
      NotificationSetting.create!
    end
  end

  def test_validate_messages_notification
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :messages_notification do
      NotificationSetting.create!(program: programs(:albers), messages_notification: 10)
    end
  end

  def test_belongs_to
    notification_setting = programs(:albers).notification_setting
    assert_equal programs(:albers), notification_setting.program
  end

  def test_unique_program_id
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :program_id do
      NotificationSetting.create!(program: programs(:albers))
    end
  end

end

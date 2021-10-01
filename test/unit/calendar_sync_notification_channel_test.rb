require_relative './../test_helper.rb'

class CalendarSyncNotificationChannelTest < ActiveSupport::TestCase
  
  def test_validations
    channel = CalendarSyncNotificationChannel.new

    assert_false channel.valid?
    assert_equal ["can't be blank"], channel.errors[:channel_id]
    assert_equal ["can't be blank"], channel.errors[:resource_id]
    assert_equal ["can't be blank"], channel.errors[:expiration_time]

    channel.expiration_time = Time.now + 1.week
    channel.resource_id = "resource_id"
    channel.channel_id = "aa"*32

    assert channel.valid?

    channel.channel_id = "aa"*32 + "a"

    assert_false channel.valid?

    assert_equal ["is too long (maximum is 64 characters)"], channel.errors[:channel_id]
  end

  def test_scheduling_account_association
    channel = CalendarSyncNotificationChannel.create!(channel_id: "channelId", resource_id: "resourceId", expiration_time: Time.now)
    assert_nil channel.scheduling_account

    scheduling_account = scheduling_accounts(:scheduling_account_1)

    channel.update_attribute(:scheduling_account_id, scheduling_account.id)
    assert_equal scheduling_account, channel.scheduling_account
  end
end
require_relative './../test_helper.rb'

class SchedulingAccountTest < ActiveSupport::TestCase

  def test_calendar_sync_notification_channels_association
    scheduling_account = scheduling_accounts(:scheduling_account_1)

    assert_equal [], scheduling_account.calendar_sync_notification_channels

    channel = CalendarSyncNotificationChannel.create!(channel_id: "channelId", resource_id: "resourceId", expiration_time: Time.now, scheduling_account_id: scheduling_account.id)

    assert_equal [channel], scheduling_account.reload.calendar_sync_notification_channels
  end

  def test_scopes
    sa1 = scheduling_accounts(:scheduling_account_1)
    sa2 = scheduling_accounts(:scheduling_account_2)
    sa3 = scheduling_accounts(:scheduling_account_3)
    sa4 = scheduling_accounts(:scheduling_account_4)
    sa5 = scheduling_accounts(:scheduling_account_5)

    assert_equal SchedulingAccount::Status::ACTIVE, sa1.status
    assert_equal SchedulingAccount::Status::ACTIVE, sa2.status
    assert_equal SchedulingAccount::Status::ACTIVE, sa3.status
    assert_equal SchedulingAccount::Status::INACTIVE, sa4.status
    assert_equal SchedulingAccount::Status::INACTIVE, sa5.status

    assert_equal_unordered [sa1, sa2, sa3], SchedulingAccount.active
    assert_equal_unordered [sa4, sa5], SchedulingAccount.inactive
  end
end
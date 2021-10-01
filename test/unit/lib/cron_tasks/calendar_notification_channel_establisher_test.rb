require_relative './../../../test_helper'

class CronTasks::CalendarNotificationChannelEstablisherTest < ActiveSupport::TestCase

  def test_perform
    # Number of SchedulingAccount: 5
    api = mock
    api.expects(:establish_new_notification_channel).with(instance_of(SchedulingAccount)).times(5)
    Calendar::GoogleApi.expects(:new).with(kind_of(String)).times(5).returns(api)
    CronTasks::CalendarNotificationChannelEstablisher.new.perform
  end

  def test_perform_when_channel_exists
    scheduling_account = scheduling_accounts(:scheduling_account_1)
    channel = scheduling_account.calendar_sync_notification_channels.create!(resource_id: "1", channel_id: "2", expiration_time: Time.now)
    api = mock

    api.expects(:establish_new_notification_channel).with(instance_of(SchedulingAccount)).times(5)
    Calendar::GoogleApi.expects(:new).with(kind_of(String)).times(5).returns(api)
    CronTasks::CalendarNotificationChannelEstablisher.new.perform

    channel.update_column(:expiration_time, 4.days.from_now)
    api.expects(:establish_new_notification_channel).with(instance_of(SchedulingAccount)).times(4)
    Calendar::GoogleApi.expects(:new).with(kind_of(String)).times(4).returns(api)
    CronTasks::CalendarNotificationChannelEstablisher.new.perform
  end
end
require_relative './../../../test_helper'

class CronTasks::MonitorTest < ActiveSupport::TestCase

  def test_perform
    assert_cron_monitor_task do
      CronTasksScheduler.expects(:tasks_off_schedule).once.returns([])
      Airbrake.expects(:notify).never
    end
  end

  def test_perform_when_tasks_are_off_schedule
    assert_cron_monitor_task do
      CronTasksScheduler.expects(:tasks_off_schedule).once.returns(["CronTasks::Example", "CronTasks::ExampleTwo"])
      Airbrake.expects(:notify).with("The following tasks are off schedule: CronTasks::Example, CronTasks::ExampleTwo").once
    end
  end

  private

  def assert_cron_monitor_task
    CronMonitor::Signal.expects(:new).never
    yield
    CronTasks::Monitor.new.perform

    cron_monitor_signal_value = SecureRandom.hex(3)
    CronMonitorConstants.const_set("CRON_TASKS_MONITOR", cron_monitor_signal_value)
    begin
      modify_const(:APP_CONFIG, should_trigger_cron_monitor_notification: true) do
        signal = mock
        signal.expects(:trigger).once
        CronMonitor::Signal.expects(:new).with(cron_monitor_signal_value).returns(signal)
        yield
        CronTasks::Monitor.new.perform
      end
    ensure
      CronMonitorConstants.send(:remove_const, "CRON_TASKS_MONITOR")
    end
  end
end
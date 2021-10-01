require_relative './../../../test_helper'

# This file is a conversion of https://github.com/amitree/delayed_job_recurring/blob/master/spec/lib/delayed/recurring_job_spec.rb to test-unit

class Delayed::RecurringJobTest < ActiveSupport::TestCase
  def startup
    Delayed::Job.delete_all
    Object.const_set(:MyTask, Class.new {
      include ::Delayed::RecurringJob

      run_every 1.day

      cattr_accessor :run_count

      def display_name
        "MyCoolTask"
      end

      def perform
        @@run_count ||= 0
        @@run_count += 1
      end
    })

    Object.const_set(:MyTas, Class.new {
      include ::Delayed::RecurringJob

      run_every 1.day

      def perform
      end
    })

    Object.const_set(:MyTaskThatFails, Class.new(MyTask) {
      run_every 1.day
      def perform
        raise 'fail'
      end
    })

    Object.const_set(:MyTaskWithExecuteNextJob, Class.new(MyTask) {
      run_at '5:00am'
      run_every 1.day
      priority 0
      execute_next_job true
    })

    Object.const_set(:MyTaskWithZone, Class.new(MyTask) {
      run_at '5:00am'
      run_every 1.day
      timezone 'US/Pacific'
      priority 0
    })

    Object.const_set(:SubTaskWithZone, Class.new(MyTaskWithZone) {
      run_at '6:00am'
    })

    Object.const_set(:MyTaskWithIVars, Class.new(MyTask) {
      def initialize
        @foo = 'bar'
      end
    })

    Object.const_set(:MyModule, Module.new() {})
    MyModule.const_set(:MySubTask, Class.new(MyTask) {})

    Object.const_set(:MyTask1, Class.new(MyTask) {})
    Object.const_set(:MyTask2, Class.new(MyTask) {})
    Object.const_set(:MyTask3, Class.new(MyTask) {})

    Object.const_set(:MyTaskWithPriority, Class.new(MyTask) {
      priority 2
    })

    Object.const_set(:MyTaskWithQueueName, Class.new(MyTask) {
      queue 'other-queue'
    })

    Object.const_set(:MySelfSchedulingTask, Class.new(MyTask) {
      def perform
        # Purpose of scheduling ourselves within the perform isn't a use case
        # but simply a method of testing the case where our job is scheduled
        # while we are processing an 'existing' job (of the same type).
        #
        # An example of such as case is (for ease of development/testing) having
        # a recurring job scheduled in an initializer. Using a process manager,
        # it is possible to have a situation where DJ spools up a previously
        # scheduled job, then (possibly due to a longer load time) another process
        # runs its initializer also scheduling up a new job. Then when the running
        # job finishes, it schedules itself resulting in two of the same job in DJ
        self.class.schedule!(run_at: Time.now + 1.second, timezone: 'US/Pacific')
      end
    })
  end

  def shutdown
    Object.send(:remove_const, :MySelfSchedulingTask)
    Object.send(:remove_const, :MyTaskWithQueueName)
    Object.send(:remove_const, :MyTaskWithPriority)
    Object.send(:remove_const, :MyTask3)
    Object.send(:remove_const, :MyTask2)
    Object.send(:remove_const, :MyTask1)
    MyModule.send(:remove_const, :MySubTask)
    Object.send(:remove_const, :MyModule)
    Object.send(:remove_const, :MyTaskWithIVars)
    Object.send(:remove_const, :SubTaskWithZone)
    Object.send(:remove_const, :MyTaskWithZone)
    Object.send(:remove_const, :MyTaskThatFails)
    Object.send(:remove_const, :MyTas)
    Object.send(:remove_const, :MyTask)
  end

  def test_job_not_executed_or_scheduled_when_dj_disabled
    begin
      Delayed::Worker.delay_jobs = false
      run_count = MyTask.run_count
      MyTask.schedule
      assert_dynamic_expected_nil_or_equal MyTask.run_count, run_count
      assert_false MyTask.scheduled?
    ensure
      Delayed::Worker.delay_jobs = true
    end
  end

  def test_run_at_spec_time_if_in_future
    at('2014-03-08T12:00:00') do
      job = MyTask.schedule(run_at: dt('2014-03-08T13:00:00'))
      assert_equal dt('2014-03-08T13:00:00'), job.run_at.to_datetime
    end
  end

  def test_run_at_next_occurrence_if_spec_time_in_past
    at '2014-03-08T12:00:00' do
      job = MyTask.schedule(run_at: dt('2014-03-08T11:00:00'))
      assert_equal dt('2014-03-09T11:00:00'), job.run_at.to_datetime
    end
  end

  def test_handle_dst_switch
    at '2014-03-08T12:00:00' do
      job = MyTask.schedule(run_at: dt('2014-03-08T11:00:00'), timezone: 'US/Pacific')
      assert_equal dt('2014-03-09T10:00:00'), job.run_at.to_datetime
    end
  end

  def test_timezone_accounted_if_spec_in_class
    at '2014-03-08T12:00:00' do
      job = MyTaskWithZone.schedule(run_at: dt('2014-03-08T11:00:00'))
      assert_equal dt('2014-03-09T10:00:00'), job.run_at.to_datetime
    end
  end

  def test_execute_next_job_if_time_passed
    job = nil
    at '2014-02-08T04:00:00' do
      assert_difference "Delayed::Job.count", 1 do
        job = MyTaskWithExecuteNextJob.schedule
      end
    end
    assert_equal dt('2014-02-08T05:00:00'), job.run_at.to_datetime

    at '2014-02-09T05:30:00' do
      assert_no_difference "Delayed::Job.count" do  # One DJ deleted and new one created
        # we do not call work_off method here because it would invoke the job which will create a new job with 0500 run_at time.
        # That job also will be invoked because the 0500 is past the Time.now which is 0530.
        # So that will end up creating a new job with 2014-02-10T05:00:00 time.
        job.invoke_job
      end
    end
    job = Delayed::Job.last
    assert_equal dt('2014-02-09T05:00:00'), job.run_at.to_datetime

  end

  def test_accept_days_of_the_week
    at '2014-06-30T07:00:00' do
      job = MyTask.schedule run_at: 'sunday 8:00am', timezone: 'US/Pacific', run_every: 1.week
      assert_equal dt('2014-07-06T15:00:00'), job.run_at.to_datetime
    end
  end

  def test_second_execution_schedules_correctly
    at '2014-03-07T12:00:00' do
      assert_difference "Delayed::Job.count", 1 do
        MyTask.schedule(run_at: dt('2014-03-08T11:00:00'), timezone: 'US/Pacific')
      end
    end

    job = Delayed::Job.last
    assert_equal dt('2014-03-08T11:00:00'), job.run_at.to_datetime

    at '2014-03-08T11:30:00' do
      assert_no_difference "Delayed::Job.count" do # One DJ deleted and new one created
        Delayed::Worker.new.work_off
      end
    end

    job = Delayed::Job.last
    assert_equal dt('2014-03-09T10:00:00'), job.run_at.to_datetime
  end

  def test_multiple_run_at_times_next_occurrence_same_day
    at '2014-03-08T12:00:00' do
      job = MyTask.schedule(run_at: [dt('2014-03-08T04:00:00'), dt('2014-03-08T13:00:00')], timezone: 'US/Pacific')
      assert_equal dt('2014-03-08T13:00:00'), job.run_at.to_datetime
    end
  end

  def test_multiple_run_at_times_next_occurrence_next_day
    at '2014-03-08T13:01:00' do
      job = MyTask.schedule(run_at: [dt('2014-03-08T04:00:00'), dt('2014-03-08T13:00:00')], timezone: 'US/Pacific')
      assert_equal dt('2014-03-09T04:00:00'), job.run_at.to_datetime
    end
  end

  def test_multiple_run_at_times_dst_accounted
    at '2014-03-09T04:01:00' do
      job = MyTask.schedule(run_at: [dt('2014-03-08T04:00:00'), dt('2014-03-08T13:00:00')], timezone: 'US/Pacific')
      assert_equal dt('2014-03-09T12:00:00'), job.run_at.to_datetime
    end
  end

  def test_multiple_run_at_times_parse_time_from_string
    at '2014-03-09T04:01:00' do
      job = MyTask.schedule(run_at: ['8:00pm', '5:00am'], timezone: 'US/Pacific')
      assert_equal dt('2014-03-09T12:00:00'), job.run_at.to_datetime
    end
  end

  def test_second_execution_schedules_job_correctly
    at '2014-03-08T13:01:00' do
      assert_difference "Delayed::Job.count", 1 do
        MyTask.schedule(run_at: [dt('2014-03-08T04:00:00'), dt('2014-03-08T13:00:00')], timezone: 'US/Pacific')
      end
    end

    job = Delayed::Job.last
    assert_equal dt('2014-03-09T04:00:00'), job.run_at.to_datetime

    at '2014-03-09T04:30:00' do
      assert_no_difference "Delayed::Job.count" do  # One DJ deleted and new one created
        Delayed::Worker.new.work_off
      end
    end

    job = Delayed::Job.last
    assert_equal dt('2014-03-09T12:00:00'), job.run_at.to_datetime
  end

  def test_failing_jobs_all_attempts_exhausted
    begin
      schedule_failing_task(1)
      job = Delayed::Job.last
      assert_equal 0, job.attempts
      assert_equal dt('2014-03-09T11:00:00'), job.run_at.to_datetime
    ensure
      reset_max_attempts
    end
  end

  def test_failing_jobs_with_retries_remaining
    begin
      schedule_failing_task(2)
      job = Delayed::Job.last
      assert_equal 1, job.attempts
      assert_equal dt('2014-03-08T12:00:06'), job.run_at.to_datetime # delayed_job reschedules the job for (N**4 + 5) seconds in the future, N=1
    ensure
      reset_max_attempts
    end
  end

  def test_additional_jobs_should_not_get_created_while_current_one_is_running
    at '2014-03-08T11:59:59' do
      MySelfSchedulingTask.schedule(run_at: dt('2014-03-08T12:00:00'), timezone: 'US/Pacific')
    end
    at '2014-03-08T12:00:00' do
      Delayed::Worker.new.work_off
    end

    assert_equal 1, MySelfSchedulingTask.jobs.count
  end

  def test_schedule_bang_reschedules_job
    at '2014-03-08T01:00:00' do
      assert_difference "Delayed::Job.count", 1 do
        MyTask.schedule!(run_at: '3:00am', timezone: 'UTC')
        MyTask.schedule!(run_at: '2:00am', timezone: 'UTC')
      end
    end
    job = Delayed::Job.last
    assert_equal dt('2014-03-08T02:00:00'), job.run_at.to_datetime
  end

  def test_run_at_setting
    MyTask1.run_at '1:00'
    assert_equal ['1:00'], MyTask1.run_at

    MyTask2.run_at '1:00', '2.00'
    assert_equal ['1:00', '2.00'], MyTask2.run_at

    MyTask3.run_at '1:00'
    MyTask3.run_at '2:00'
    assert_equal "1:00", MyTask3.run_at.first
    assert_equal "2:00", MyTask3.run_at.second
  end

  def test_priority_setting
    delay_jobs do
      assert_difference "Delayed::Job.count", 1 do
        MyTaskWithPriority.schedule!
      end
      job = Delayed::Job.last
      assert_equal 2, job.priority
      job.destroy

      assert_difference "Delayed::Job.count", 1 do
        MyTaskWithPriority.schedule!(priority: 3)
      end
      job = Delayed::Job.last
      assert_equal 3, job.priority
      job.destroy
    end
  end

  def test_queue_name
    delay_jobs do
      assert_difference "Delayed::Job.count", 1 do
        MyTaskWithQueueName.schedule!
      end
      job = Delayed::Job.last
      assert_equal 'other-queue', job.queue
      job.destroy

      assert_difference "Delayed::Job.count", 1 do
        MyTaskWithQueueName.schedule!(queue: 'blarg')
      end
      job = Delayed::Job.last
      assert_equal 'blarg', job.queue
      job.destroy

      assert_difference "Delayed::Job.count", 1 do
        MyTask.schedule!
      end
      job = Delayed::Job.last
      assert_nil job.queue # Use default queue name
      job.destroy
    end
  end

  def test_scheduled_initial
    assert_false MyTask.scheduled?
  end

  def test_scheduled_after_schedule
    delay_jobs do
      MyTask.schedule
      assert MyTask.scheduled?
    end
  end

  def test_scheduled_after_similar_named_task_is_scheudled
    delay_jobs do
      MyTas.schedule
      assert_false MyTask.scheduled?
      assert MyTas.scheduled?
    end
  end

  def test_scheduled_behaves_correctly_for_classes_with_instance_variables
    delay_jobs do
      MyTaskWithIVars.schedule
      assert MyTaskWithIVars.scheduled?
    end
  end

  def test_scheduled_behaves_correctly_for_classes_inside_modules
    delay_jobs do
      MyModule::MySubTask.schedule
      assert MyModule::MySubTask.scheduled?
    end
  end

  def test_inheritance
    assert_equal 1.day, SubTaskWithZone.run_every
    assert_equal 'US/Pacific', SubTaskWithZone.timezone
    assert_equal 0, SubTaskWithZone.priority

    assert_equal ['6:00am'], SubTaskWithZone.run_at
    assert_equal ['5:00am'], MyTaskWithZone.run_at
  end

  def test_schedule_multiple_times
    delay_jobs do
      assert_difference("Delayed::Job.count") { MyTask.schedule }
      assert_no_difference("Delayed::Job.count") { MyTask.schedule }
      assert_difference("Delayed::Job.count") { MyTask.schedule(job_matching_param: 'schedule_id', schedule_id: 2) }
      assert_no_difference("Delayed::Job.count") { MyTask.schedule(job_matching_param: 'schedule_id', schedule_id: 2) }
      assert_difference("Delayed::Job.count") { MyTask.schedule(job_matching_param: 'schedule_id', schedule_id: 3) }
    end
  end

  private

  def schedule_failing_task(max_attempts)
    @prev_max_attempts = Delayed::Worker.max_attempts
    Delayed::Worker.max_attempts = max_attempts

    at '2014-03-08T11:59:59' do
      MyTaskThatFails.schedule(run_at: dt('2014-03-08T12:00:00'), timezone: 'US/Pacific')
    end
    at '2014-03-08T12:00:00' do
      Delayed::Worker.new.work_off
    end
  end

  def reset_max_attempts
    Delayed::Worker.max_attempts = @prev_max_attempts
  end
end
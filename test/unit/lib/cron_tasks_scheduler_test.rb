require_relative './../../test_helper.rb'

class CronTasksSchedulerTest < ActiveSupport::TestCase

  def startup
    [:Task1, :Task2].each do |klass_name|
      Object.const_set(klass_name, Class.new {
        include Delayed::RecurringJob

        def perform
        end
      } )
    end
  end

  def shutdown
    [:Task1, :Task2].each { |klass_name| Object.send(:remove_const, klass_name) }
  end

  def test_schedule_and_tasks_off_schedule
    CronTasksScheduler.stubs(:schedule_map).returns(temp_schedule_map)

    delay_jobs do
      assert_difference "Delayed::Job.count", 3 do
        CronTasksScheduler.schedule
      end

      task1_job = Task1.jobs.first
      task21_job = Task2.jobs(job_matching_param: "schedule_id", schedule_id: 1).first
      task22_job = Task2.jobs(job_matching_param: "schedule_id", schedule_id: 2).first
      assert_equal DjSourcePriority::CRON_HIGH, task1_job.source_priority
      assert_equal DjSourcePriority::CRON, task21_job.source_priority
      assert_equal DjSourcePriority::CRON, task22_job.source_priority
      assert_equal DjQueues::HIGH_PRIORITY, task1_job.queue
      assert_nil task21_job.queue
      assert_nil task22_job.queue

      assert_no_difference "Delayed::Job.count" do
        CronTasksScheduler.schedule
      end
    end
  end

  def test_tasks_off_schedule
    CronTasksScheduler.stubs(:schedule_map).returns(temp_schedule_map)
    assert_equal_unordered ["Task1", "Task2 - schedule_id: 1", "Task2 - schedule_id: 2"], CronTasksScheduler.tasks_off_schedule

    CronTasksScheduler.stubs(:schedule_map).returns(temp_schedule_map.pick("Task1"))
    delay_jobs do
      assert_difference "Delayed::Job.count" do
        CronTasksScheduler.schedule
      end
    end
    assert_empty CronTasksScheduler.tasks_off_schedule

    job = Task1.jobs.first
    dup_job = job.dup
    dup_job.save!
    assert_equal ["Task1"], CronTasksScheduler.tasks_off_schedule
  end

  # For coverage
  def test_schedule_map
    assert_instance_of Hash, CronTasksScheduler.schedule_map
  end

  private

  def temp_schedule_map
    {
      "Task1" => {
        "run_every" => 86400,
        "run_at" => "5:30",
        "queue" => DjQueues::HIGH_PRIORITY
      },
      "Task2" => [
        {
          "run_every" => 86400,
          "run_at" => "23:30",
          "use_region_specific_tz" => true,
          "job_matching_param" => "schedule_id",
          "schedule_id" => 1
        },
        {
          "run_every" => 604800,
          "run_at" => "wednesday 1:00",
          "use_region_specific_tz" => true,
          "job_matching_param" => "schedule_id",
          "schedule_id" => 2
        }
      ]
    }
  end
end
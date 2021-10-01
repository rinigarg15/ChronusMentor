require_relative './../../test_helper.rb'

class DjNotifierTest < ActiveSupport::TestCase

  def setup
    @dj_notifier = DjNotifier.new
    super
  end

  def test_initialize
    job_1 = Delayed::Job.create(priority: 1)
    job_2 = Delayed::Job.create(priority: 2)
    assert_equal [job_2, job_1], @dj_notifier.jobs
    assert_time_is_equal_with_delta Time.now, @dj_notifier.current_time, 30
    assert_equal_hash( { DjNotifier::JobCategory::FAILED => [], DjNotifier::JobCategory::STUCK => [] }, @dj_notifier.job_stats)
    assert_equal_hash( { DjNotifier::JobCategory::FAILED => {}, DjNotifier::JobCategory::STUCK => {} }, @dj_notifier.queue_stats)
  end

  def test_is_failed_job_and_is_stuck_job
    job = Delayed::Job.new(run_at: Time.now)
    assert_false @dj_notifier.send(:is_failed_job?, job)
    assert_false @dj_notifier.send(:is_stuck_job?, job)

    job.run_at = 5.days.ago
    assert_false @dj_notifier.send(:is_failed_job?, job)
    assert @dj_notifier.send(:is_stuck_job?, job)

    job.queue = DjQueues::AWS_ELASTICSEARCH_SERVICE
    assert_false @dj_notifier.send(:is_failed_job?, job)
    assert_false @dj_notifier.send(:is_stuck_job?, job)

    job.last_error = "error"
    assert @dj_notifier.send(:is_failed_job?, job)
    assert_false @dj_notifier.send(:is_stuck_job?, job)
  end

  def test_get_job_category
    job = Delayed::Job.new
    @dj_notifier.stubs(:is_failed_job?).with(job).returns(true)
    @dj_notifier.stubs(:is_stuck_job?).with(job).returns(true)
    assert_equal DjNotifier::JobCategory::FAILED, @dj_notifier.send(:get_job_category, job)

    @dj_notifier.stubs(:is_failed_job?).with(job).returns(false)
    assert_equal DjNotifier::JobCategory::STUCK, @dj_notifier.send(:get_job_category, job)

    @dj_notifier.stubs(:is_stuck_job?).with(job).returns(false)
    assert_nil @dj_notifier.send(:get_job_category, job)
  end

  def test_compute_stats
    job_1 = Delayed::Job.create
    job_2 = Delayed::Job.create(queue: DjQueues::HIGH_PRIORITY)
    job_3 = Delayed::Job.create

    @dj_notifier.jobs = [job_1, job_2, job_3]
    @dj_notifier.stubs(:is_failed_job?).with(job_1).returns(true)
    @dj_notifier.stubs(:is_failed_job?).with(job_2).returns(false)
    @dj_notifier.stubs(:is_failed_job?).with(job_3).returns(false)
    @dj_notifier.stubs(:is_stuck_job?).with(job_1).returns(false)
    @dj_notifier.stubs(:is_stuck_job?).with(job_2).returns(true)
    @dj_notifier.stubs(:is_stuck_job?).with(job_3).returns(false)

    @dj_notifier.send(:compute_stats)
    assert_equal [ { "Job ID" => job_1.id, "Job Handler" => "" } ], @dj_notifier.job_stats[DjNotifier::JobCategory::FAILED]
    assert_equal [ { "Job ID" => job_2.id, "Job Handler" => "" } ], @dj_notifier.job_stats[DjNotifier::JobCategory::STUCK]
    assert_equal_hash( { DjQueues::NORMAL => 1 }, @dj_notifier.queue_stats[DjNotifier::JobCategory::FAILED])
    assert_equal_hash( { DjQueues::HIGH_PRIORITY => 1 }, @dj_notifier.queue_stats[DjNotifier::JobCategory::STUCK])
  end

  def test_job_info_of_recurring_job
    delay_jobs { CronTasks::Monitor.schedule(run_at: '12:00', run_every: 1.day) }
    job = Delayed::Job.last
    assert_equal_hash( {
      "Job ID" => job.id,
      "Job Handler" => {
        "Class" => "CronTasks::Monitor",
        "Run At" => job.run_at
      }
    }, @dj_notifier.send(:job_info, job))
  end

  def test_job_info_of_unserializable_job
    job = Delayed::Job.create(handler: "handler")
    assert_equal_hash( {
      "Job ID" => job.id,
      "Job Handler" => "handler"
    }, @dj_notifier.send(:job_info, job))
  end

  def test_job_info_of_instance_method_based_job
    user = User.first
    delay_jobs { user.delay.name(name_only: true) }
    job = Delayed::Job.last
    assert_equal_hash( {
      "Job ID" => job.id,
      "Job Handler" => {
        "Class" => "User",
        "Object ID" => user.id,
        "Method" => :name,
        "Args" => [ { name_only: true } ]
      }
    }, @dj_notifier.send(:job_info, job))
  end

  def test_job_info_of_class_method_based_job
    delay_jobs { Member.delay.member_ids_of_users(option_1: "1") }
    job = Delayed::Job.last
    assert_equal_hash( {
      "Job ID" => job.id,
      "Job Handler" => {
        "Class" => "Member",
        "Object ID" => nil,
        "Method" => :member_ids_of_users,
        "Args" => [ { option_1: "1" } ]
      }
    }, @dj_notifier.send(:job_info, job))
  end

  def test_notify_status
    mail_mock = mock
    mail_mock.expects(:deliver_now).once
    @dj_notifier.expects(:compute_stats).twice
    InternalMailer.expects(:notify_dj_status).never
    @dj_notifier.notify_status

    @dj_notifier.job_stats = { DjNotifier::JobCategory::FAILED => ["1"] }
    InternalMailer.expects(:notify_dj_status).with(@dj_notifier).once.returns(mail_mock)
    @dj_notifier.notify_status
  end
end
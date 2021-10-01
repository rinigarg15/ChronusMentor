require_relative './../test_helper.rb'

class NewrelicOverridesTest < ActionController::TestCase
  def setup
    super
    Object.send :alias_method, :send_later, :old_send_later
    @old_delayed_job_config = Delayed::Worker.delay_jobs
    Delayed::Worker.delay_jobs = true
  end

  def teardown
    super
    Object.send :alias_method, :send_later, :send
    Delayed::Worker.delay_jobs = @old_delayed_job_config
  end

  def self.success_function
    return 1
  end

  def test_record_not_yet_completed_and_count_jobs_delayed_greaterthan_x
    Delayed::Worker.new
    Delayed::Job.stubs(:source_priority).returns(DjSourcePriority::WEB)
    NewrelicOverridesTest.delay(priority: 3, queue: 'high_priority').success_function
    NewrelicOverridesTest.delay(priority: 5, queue: 'high_priority').success_function
    NewrelicOverridesTest.delay.success_function
    NewrelicOverridesTest.delay(priority: 3, queue: 'high_priority').success_function
    first_job = Delayed::Job.first
    first_job.run_at = Delayed::Job.db_time_now - 10.minutes
    first_job.save!
    last_job = Delayed::Job.last
    last_job.run_at = Delayed::Job.db_time_now - 60.minutes
    last_job.save!
    b = NewRelic::Agent::Samplers::DelayedJobSampler.new.count_jobs_delayed_greaterthan_x("high_priority", DjQueues::SLA["high_priority"][DjSourcePriority::WEB], DjSourcePriority::WEB)
    assert_equal 2, b
    change_const_of(DjQueues, :SLA, "high_priority" => {DjSourcePriority::WEB => 15.minutes}) do
      NewRelic::Agent.expects(:record_metric).with("Workers/DelayedJob/not_yet_completed_sla_violations/name/high_priority/#{DjSourcePriority::WEB}", 1)
      NewRelic::Agent::Samplers::DelayedJobSampler.new.record_not_yet_completed
    end
  end

  def test_record_queue_length_metrics
    Delayed::Worker.new
    NewRelic::Agent::Samplers::DelayedJobSampler.any_instance.stubs(:record_not_yet_completed).returns(true)
    NewRelic::Agent.stubs(:record_metric).returns(false)
    assert_false NewRelic::Agent::Samplers::DelayedJobSampler.new.record_queue_length_metrics
  end

  def test_newrelic_overrides_validity
    assert_equal "f4717af7f84ae8af4cbb5d4b2fa62bf8f26d623103357cc2a9e6eebe2043317c",
    Digest::SHA256.hexdigest(File.read($".find{|path| path.match(/lib\/new_relic\/agent\/samplers\/delayed_job_sampler\.rb/)})),
    'please see if the override in newrelic_overrides.rb is still needed or should be changed. If other modifications are there instead of function:record_queue_length_metrics \
    in delayed_job_sampler.rb present in NewRelic gems then just used that Digest function to generate a hash and put it in place of assert equal first argument to run the test'
  end
end
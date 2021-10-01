require_relative './../../test_helper.rb'

class DelayedJobOverridesTest < ActiveSupport::TestCase

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

  def test_deserialization_error
    assert_difference 'Delayed::Job.count', +1 do
      User.first.delay.name
    end
    dj = Delayed::Job.last
    worker = Delayed::Worker.new
    User.first.destroy
    worker.expects(:log_job_with_deserialization_error).with(dj, instance_of(Delayed::DeserializationError)).once
    worker.run(dj)
    assert_match /ActiveRecord::RecordNotFound, class: User, primary key: 1/, dj.last_error
  end

  def test_log_job_with_deserialization_error
    assert_difference 'Delayed::Job.count', +1 do
      User.first.delay.name
    end
    dj = Delayed::Job.last
    worker = Delayed::Worker.new
    worker.expects(:job_say).with(dj, regexp_matches(/- failed with Exception: Test Exception/), 3)
    worker.log_job_with_deserialization_error(dj, Exception.new("Test Exception"))
  end

  def test_non_named_queue_workers_should_not_pick_named_queue_jobs
    Delayed::Job.delete_all
    assert_difference 'Delayed::Job.count', +2 do
      User.first.delay.name
      User.first.delay(queue: 'test').name
    end
    assert_difference 'Delayed::Job.count', -1 do
      Delayed::Worker.new.work_off
    end
    assert_equal 1, Delayed::Job.where(queue: 'test').size
  end

  # Test to ensure Web djs are picked above Bulk djs
  def test_web_over_bulk_djs
    # Enqueue Jobs with BULK Level Priority
    Delayed::Job.stubs(:source_priority).returns(DjSourcePriority::BULK)
    User.first.delay.name
    User.first.delay.name
    assert_difference 'Delayed::Job.where(source_priority: DjSourcePriority::BULK).count', -1 do
      # Picks the Job enqueued with BULK level priority
      Delayed::Worker.new.work_off(1)
    end
    # Enqueue Jobs with WEB Level Priority
    Delayed::Job.stubs(:source_priority).returns(DjSourcePriority::WEB)
    User.first.delay.name
    assert_difference 'Delayed::Job.where(source_priority: DjSourcePriority::WEB).count', -1 do
      # Picks the Job enqueued with WEB level priority
      Delayed::Worker.new.work_off(1)
    end
  end

  def test_work_off_with_job_group_id
    program = programs(:albers)
    student = users(:f_student)
    mentor = users(:f_mentor)
    student_ids = program.get_user_ids_based_on_roles(RoleConstants::STUDENT_NAME)
    mentor_ids = [mentor.id]
    queue_name = "queue1"
    mentor_hash = Matching::Database::Score.new.get_mentor_hash(student.id)
    mentor_count = mentor_hash.count

    match_client = Matching::Client.new(program)

    DjSplit.any_instance.stubs(:wait_check_and_execute_delayed_jobs).returns(true)

    split_count = (mentor_count/10.0).ceil

    assert_difference "Delayed::Job.where(queue: 'queue1').count", split_count do
      DjSplit.new(queue_options: {queue: 'queue1'}, split_options: {size: 10, by: 2}).enqueue(DelayedJobOverridesTest, "testing_function", student_ids, mentor_ids)
    end

    job_group_id = Delayed::Job.where(queue: 'queue1').first.job_group_id
    worker_object = Delayed::Worker.new
    worker_object.job_group_id = job_group_id
    worker_object.work_off(1)

    assert_equal (split_count - 1), Delayed::Job.where(queue: 'queue1').count
    Delayed::Job.where(queue: 'queue1').delete_all
  end

  def self.testing_function(student_ids, mentor_ids)
    # Testing Delayed Jobs
  end

  def test_dj_split_max_workers
    DjSplit.any_instance.stubs(:wait_check_and_execute_delayed_jobs).returns(true)
    student_ids = Array(1..20)
    mentor_ids = [1]
    assert_difference 'Delayed::Job.count', 2 do
      DjSplit.new(queue_options: {queue: nil, max_workers: 1}, split_options: {size: 10, by: 2}).enqueue(DelayedJobOverridesTest, "testing_function", student_ids, mentor_ids)
    end
    Delayed::Job.last.update(locked_at: Time.now)
    # As max workers is 1 and one dj is already locked, it shouldnt allow other workers to pick other dj in this group.
    assert_difference 'Delayed::Job.count', 0 do
      Delayed::Worker.new.work_off
    end
    Delayed::Job.last.update(failed_at: Time.now)
    assert_difference 'Delayed::Job.count', -1 do
      Delayed::Worker.new.work_off
    end
  end

  # Test to ensure Bulk djs are picked above API djs
  def test_bulk_over_api_djs
    # Enqueue Jobs with API Level Priority
    Delayed::Job.stubs(:source_priority).returns(DjSourcePriority::API)
    User.first.delay.name
    User.first.delay.name
    assert_difference 'Delayed::Job.where(source_priority: DjSourcePriority::API).count', -1 do
      # Picks the Job enqueued with API level priority
      Delayed::Worker.new.work_off(1)
    end
    # Enqueue Jobs with BULK Level Priority
    Delayed::Job.stubs(:source_priority).returns(DjSourcePriority::BULK)
    User.first.delay.name
    assert_difference 'Delayed::Job.where(source_priority: DjSourcePriority::BULK).count', -1 do
      # Picks the Job enqueued with BULK level priority
      Delayed::Worker.new.work_off(1)
    end
  end

  # Test to ensure API djs are picked above Cron djs
  def test_api_over_cron_djs
    # Enqueue Jobs with Cron Level Priority
    Delayed::Job.stubs(:source_priority).returns(DjSourcePriority::CRON)
    User.first.delay.name
    User.first.delay.name
    assert_difference 'Delayed::Job.where(source_priority: DjSourcePriority::CRON).count', -1 do
      # Picks the Job enqueued with Cron level priority
      Delayed::Worker.new.work_off(1)
    end
    # Enqueue Jobs with API Level Priority
    Delayed::Job.stubs(:source_priority).returns(DjSourcePriority::API)
    User.first.delay.name
    assert_difference 'Delayed::Job.where(source_priority: DjSourcePriority::API).count', -1 do
      # Picks the Job enqueued with API level priority
      Delayed::Worker.new.work_off(1)
    end
  end

  # Test to ensure the Inner Delayed Jobs have the same source priority
  def test_inner_dj_source_priority
    Delayed::Job.delete_all
    Delayed::Job.stubs(:source_priority).returns(DjSourcePriority::WEB)
    u =  User.where(state: User::Status::PENDING).first
    # Enqueue user state update with WEB level priority
    u.delay.update(state: User::Status::ACTIVE)
    Delayed::Job.unstub(:source_priority)
    Delayed::Worker.new.work_off
    # The user state update creates new Delayed Jobs with the same WEB level priority
    assert_equal Delayed::Job.last.source_priority, DjSourcePriority::WEB
  end
end
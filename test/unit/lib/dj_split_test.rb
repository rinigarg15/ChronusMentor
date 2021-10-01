require_relative './../../test_helper.rb'

class DjSplitTest < ActiveSupport::TestCase
  def setup
    super
    Delayed::Worker.delay_jobs = true
  end

  def teardown
    super
    Delayed::Worker.delay_jobs = false
  end

  def test_enqueue
    program = programs(:albers)
    student = users(:f_student)
    mentor = users(:f_mentor)
    student_ids = program.get_user_ids_based_on_roles(RoleConstants::STUDENT_NAME)
    mentor_ids = [mentor.id]
    queue_name = "queue1"
    mentor_hash = Matching::Database::Score.new.get_mentor_hash(student.id)
    mentor_count = mentor_hash.count

    match_client = Matching::Client.new(program)
    assert_difference "Delayed::Job.where(queue: 'queue1').count", 0 do
      DjSplit.new(queue_options: {queue: queue_name}, split_options: {size: 10, by: 2}).enqueue(DjSplitTest, "testing_function_1", student_ids, mentor_ids)
    end

    assert_difference "Delayed::Job.where(queue: 'queue1').count", 0 do
      DjSplit.new(queue_options: {queue: queue_name}, split_options: {size: 10, by: 3}).enqueue(DjSplitTest, "testing_function_2", mentor_ids, student_ids)
    end

    # Insert failed Job for testing handling failed jobs case:
    self.class.delay({queue: queue_name}).testing_function_1(student_ids, mentor_ids)
    Delayed::Job.where(queue: queue_name).update_all(run_at: Time.now, locked_at: Time.now, failed_at: Time.now, job_group_id: "99")
    begin
      DjSplit.any_instance.stubs(:get_random_job_group_id).returns("99")
      DjSplit.new(queue_options: {queue: queue_name}, split_options: {size: 10, by: 2}).enqueue(DjSplitTest, "testing_function_1", student_ids, mentor_ids)
    rescue => e
      assert_equal true, e.message.starts_with?("Failed Delayed Jobs of Group Id(99):")
    end
    Delayed::Job.where(queue: queue_name).delete_all

    # Insert stale Job for testing handling failed jobs case:
    self.class.delay({queue: queue_name}).testing_function_1(student_ids, mentor_ids)
    Delayed::Job.where(queue: queue_name).update_all(run_at: Time.now, locked_at: Time.now, locked_by:"host:CHR-036 pid:XXXX", job_group_id: "99")
    begin
      DjSplit.any_instance.stubs(:get_delayed_jobs_pids).returns([])
      DjSplit.any_instance.stubs(:check_stale_jobs?).returns(true)
      DjSplit.new(queue_options: {queue: queue_name}, split_options: {size: 10, by: 2}).enqueue(DjSplitTest, "testing_function_1", student_ids, mentor_ids)
    rescue => e
      assert_equal true, e.message.starts_with?("Stale Delayed Jobs of Group Id(99):")
    end
    Delayed::Job.where(queue: queue_name).delete_all

    DjSplit.new(queue_options: {queue: queue_name}, split_options: {size: 10, by: 3}).enqueue(DjSplitTest, "testing_function_2", mentor_ids, student_ids)

    DjSplit.any_instance.stubs(:wait_check_and_execute_delayed_jobs).returns(true)
    split_count = (mentor_count/10.0).ceil

    assert_difference "Delayed::Job.where(queue: 'queue1').count", split_count do
      DjSplit.new(queue_options: {queue: 'queue1'}, split_options: {size: 10, by: 2}).enqueue(DjSplitTest, "testing_function_1", student_ids, mentor_ids)
    end

    assert_difference "Delayed::Job.where(queue: 'queue2').count", split_count do
      DjSplit.new(queue_options: {queue: "queue2"}, split_options: {size: 10, by: 3}).enqueue(DjSplitTest, "testing_function_2", mentor_ids, student_ids)
    end

    assert_difference "Delayed::Job.where(queue: 'queue3').count", 1 do
      DjSplit.new(queue_options: {queue: "queue3"}, split_options: {by: 3}).enqueue(DjSplitTest, "testing_function_2", mentor_ids, student_ids)
    end
  end

  def self.testing_function_1(student_ids, mentor_ids)
    #dummy functions
  end

  def self.testing_function_2(mentor_ids, student_ids)
    #dummy functions
  end
end
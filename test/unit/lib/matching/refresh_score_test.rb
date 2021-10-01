require_relative './../../../test_helper'

class RefreshScoreTest < ActiveSupport::TestCase

  def setup
    super
    @reindex_mongodb = true
  end

  def test_refresh_score_initialize
    partition = 1
    refresh_score_object = Matching::RefreshScore.new(partition)
    assert_equal refresh_score_object.dynamic_partitioning, false
    assert_equal refresh_score_object.partition, partition
    refresh_score_object = Matching::RefreshScore.new(partition, true)
    assert_equal refresh_score_object.dynamic_partitioning, true
    assert_equal refresh_score_object.partition, partition
  end

  def test_refresh_score_documents_wrt_mentor_update
    program = programs(:albers)
    Matching.perform_program_delta_index_and_refresh(program.id)
    mentor = users(:f_mentor)
    mentor_id = mentor.id
    partition = 1
    student_user_ids = program.student_users.pluck(:id)
    mentee_hash = {}
    student_user_ids.each do |student_id|
      mentee_hash[student_id] = Matching::Database::Score.new.get_mentor_hash(student_id)[mentor_id.to_s]
    end
    student_ids_array = mentee_hash.keys
    refresh_score_object = Matching::RefreshScore.new(partition)
    Matching::Database::BulkScore.any_instance.stubs(:execute).returns(true)
    refresh_score_object.expects(:update_records_wrt_mentor_update).returns([student_ids_array.first])
    refresh_score_object.refresh_score_documents_wrt_mentor_update!(mentor_id, mentee_hash)
  end

  def test_refresh_score_documents_wrt_mentor_update_with_update_records
    program = programs(:albers)
    Matching.perform_program_delta_index_and_refresh(program.id)
    mentor = users(:f_mentor)
    mentor_id = mentor.id
    partition = 1
    student_user_ids = program.student_users.pluck(:id)
    mentee_hash = {}
    dummy_mentor_hash_score_to_update = [0.5, true]
    student_user_ids.each do |student_id|
      mentee_hash[student_id] =  dummy_mentor_hash_score_to_update
    end
    student_ids_array = mentee_hash.keys

    mentor_hash_score_before_update = Matching::Database::Score.new.get_mentor_hash(student_ids_array.first)[mentor_id.to_s]
    assert_not_equal mentor_hash_score_before_update, dummy_mentor_hash_score_to_update
    refresh_score_object = Matching::RefreshScore.new(partition)
    refresh_score_object.refresh_score_documents_wrt_mentor_update!(mentor_id, mentee_hash)
    mentor_hash_score_after_update = Matching::Database::Score.new.get_mentor_hash(student_ids_array.first)[mentor_id.to_s]
    assert_equal mentor_hash_score_after_update, dummy_mentor_hash_score_to_update
  end

  def test_refresh_score_documents_wrt_mentor_update_with_insert_records
    program = programs(:albers)
    Matching.perform_program_delta_index_and_refresh(program.id)
    partition = 1
    student_user_ids = program.student_users.pluck(:id)
    mentee_hash = {}
    dummy_mentor_id = 12350
    dummy_mentor_hash_score_to_update = [0.5, true]
    student_user_ids.each do |student_id|
      mentee_hash[student_id] =  dummy_mentor_hash_score_to_update
    end
    student_ids_array = mentee_hash.keys

    mentor_hash_score_before_update = Matching::Database::Score.new.get_mentor_hash(student_ids_array.first)[dummy_mentor_id.to_s]
    assert_nil mentor_hash_score_before_update
    refresh_score_object = Matching::RefreshScore.new(partition)
    refresh_score_object.refresh_score_documents_wrt_mentor_update!(dummy_mentor_id, mentee_hash)
    mentor_hash_score_after_update = Matching::Database::Score.new.get_mentor_hash(student_ids_array.first)[dummy_mentor_id.to_s]
    assert_equal mentor_hash_score_after_update, dummy_mentor_hash_score_to_update

    #insert into new partition
    partitions = 2
    new_dummy_mentor_id = dummy_mentor_id + 1
    refresh_score_object2 = Matching::RefreshScore.new(partitions)

    new_record = Matching::Persistence::Score.where(student_id: student_ids_array.first, p_id: partitions-1)
    assert_nil new_record.first
    refresh_score_object2.refresh_score_documents_wrt_mentor_update!(new_dummy_mentor_id, mentee_hash)
    assert_equal dummy_mentor_hash_score_to_update, new_record.first.mentor_hash["#{new_dummy_mentor_id}"]
  end

  def test_refresh_score_documents
    program = programs(:albers)
    Matching.perform_program_delta_index_and_refresh(program.id)
    student = users(:f_student)
    student_id = student.id
    partition = 1
    mentor_hash_object = Matching::Interface::MentorHash.new(student_id, partition)
    mentor_user_ids = program.mentor_users.pluck(:id)
    mentor_hash = Matching::Database::Score.new.get_mentor_hash(student_id)
    mentor_user_ids.each do |mentor_id|
      mentor_hash_object.add_to_mentor_hash(mentor_id, mentor_hash[mentor_id.to_s])
    end
    refresh_score_object = Matching::RefreshScore.new(partition)
    Matching::Database::BulkScore.any_instance.stubs(:execute).returns(true)
    refresh_score_object.expects(:update_exiting_records).returns([mentor_hash_object.mentor_hash_with_partition.keys.first])
    Matching::RefreshScore.any_instance.expects(:insert_remaining_records)
    refresh_score_object.refresh_score_documents!(mentor_hash_object)
    refresh_score_object.dynamic_partitioning = true
    Matching::RefreshScore.any_instance.expects(:insert_remaining_records)
    Matching::RefreshScore.any_instance.expects(:removing_old_documents).with(student_id).once
    refresh_score_object.refresh_score_documents!(mentor_hash_object)
  end
end
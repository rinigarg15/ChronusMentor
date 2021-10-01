require_relative './../../../test_helper'

class CacheTest < ActiveSupport::TestCase

  def setup
    super
    @reindex_mongodb = true
  end

  def test_delta_indexing
    program = programs(:albers)
    admin = users(:f_admin)
    mentor = users(:f_mentor)
    student = users(:f_student)
    student2 = users(:rahim)
    mentor_student = users(:f_mentor_student)
    partition = program.get_partition_size_for_program
    
    Matching::Cache::Refresh.perform_users_delta_refresh([mentor.id, student.id, student2.id, mentor_student.id], program.id)

    mentors_size = program.mentor_users.size
    assert_equal mentors_size, student2.student_cache_normalized.keys.size

    #Admin Record removal will not decrease count of score
    assert_no_difference 'Matching::Persistence::Score.count' do
      Matching::Cache::Refresh.remove_user_cache(admin.id, program.id)
    end
    assert_equal mentors_size, student2.reload.student_cache_normalized.keys.size

    #Student Record removal will decrease count of score
    assert_difference 'Matching::Persistence::Score.count', -1 * partition do
      Matching::Cache::Refresh.remove_user_cache(student.id, program.id)
    end
    assert_equal mentors_size, student2.reload.student_cache_normalized.keys.size

    #Mentor Record removal will not decrease count of score
    assert_no_difference 'Matching::Persistence::Score.count' do
      Matching::Cache::Refresh.remove_user_cache(mentor.id, program.id)
    end
    assert_equal mentors_size-1, student2.reload.student_cache_normalized.keys.size

    #Mentor Student Record removal will decrease count of score
    assert_difference 'Matching::Persistence::Score.count', -1 * partition do
      Matching::Cache::Refresh.remove_user_cache(mentor_student.id, program.id)
    end
    assert_equal mentors_size-2, student2.reload.student_cache_normalized.keys.size

    #Indexing Admin cache will not increase count of Score
    assert_no_difference 'Matching::Persistence::Score.count' do
      Matching::Cache::Refresh.perform_users_delta_refresh([admin.id], program.id)
    end
    assert_equal mentors_size-2, student2.reload.student_cache_normalized.keys.size

    #Indexing Student cache will increase count of Score
    assert_difference 'Matching::Persistence::Score.count', 1 * partition do
      Matching::Cache::Refresh.perform_users_delta_refresh([student.id], program.id)
    end
    assert_equal mentors_size-2, student2.reload.student_cache_normalized.keys.size

    #Indexing Mentor Student cache will increase count of Score
    assert_difference 'Matching::Persistence::Score.count', 1 * partition do
      Matching::Cache::Refresh.perform_users_delta_refresh([mentor_student.id], program.id)
    end
    assert_equal mentors_size-1, student2.reload.student_cache_normalized.keys.size

    #Indexing Mentor cache will not increase count of Score
    assert_no_difference 'Matching::Persistence::Score.count' do
      Matching::Cache::Refresh.perform_users_delta_refresh([mentor.id], program.id)
    end
    assert_equal mentors_size, student2.reload.student_cache_normalized.keys.size
  end

  def test_remove_student_mentor
    program = programs(:albers)
    student = users(:f_student)
    mentor = users(:f_mentor)
    Matching::Cache::Refresh.perform_program_delta_refresh(program.id)
    Program.any_instance.expects(:update_program_match_scores_range_wrt_old_scores).with(0.0, 0.0)
    Matching::Cache::Refresh.remove_student(student.id, program.id)
    set_mentor_cache(users(:rahim).id, users(:f_mentor).id, 0.9)
    Program.any_instance.expects(:update_program_match_scores_range_wrt_old_scores).with(0.0, 0.9)
    Matching::Cache::Refresh.remove_mentor(mentor.id, program.id)
    Matching::Cache::Refresh.perform_program_delta_refresh(program.id)
  end

  def test_prevent_refresh_for_portal
    Matching::Client.expects(:new).never
    assert_nil Matching::Cache::Refresh.perform_program_delta_refresh(programs(:primary_portal).id)
  end

  def test_prevent_refresh_for_portal_user
    user = users(:portal_employee)
    Matching::Cache::Refresh.expects(:remove_user_cache).never
    assert_nil Matching::Cache::Refresh.perform_users_delta_refresh([user.id], user.program_id)
  end
end
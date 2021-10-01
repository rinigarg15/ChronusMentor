require_relative './../../../test_helper'

class MatchingDatabaseTest < ActiveSupport::TestCase
  def setup
    @skip_stubbing_match_index = true
    super
  end

  def test_get_min_max_by_mentee_id
    program = programs(:albers)
    Matching.perform_program_delta_index_and_refresh(program.id)
    update_attribute(program)
    student_id = users(:f_student).id
    assert_equal [0.0, 0.0], Matching::Database::Score.new.get_min_max_by_mentee_id(student_id)
    set_mentor_cache(users(:f_student).id, users(:f_mentor).id, 0.8)
    assert_equal [0.0, 0.8], Matching::Database::Score.new.get_min_max_by_mentee_id(student_id)
  end

  def test_find_by_mentee_id
    program = programs(:albers)
    update_attribute(program)
    student_id = users(:f_student).id
    Mongo::Collection.any_instance.expects(:find).with({:student_id => student_id})
    Matching::Database::Score.new.find_by_mentee_id(student_id)
  end

  def test_find_by_mentee_array_and_partition_id
    mentees_array = [1, 2]
    partition_id = 0
    Mongo::Collection.any_instance.expects(:find).with({:student_id =>  {"$in" => mentees_array }, :p_id => partition_id})
    Matching::Database::Score.new.find_by_mentee_array_and_partition_id([1, 2], partition_id)
  end

  def test_find_and_update
    program = programs(:albers)
    update_attribute(program)
    student_id = users(:f_student).id
    assert_equal Matching::Persistence::Score.where(student_id: student_id).count, Matching::Database::Score.new.find({"student_id": student_id}).count
    Matching::Database::Score.new.update({student_id: student_id}, {t_s: "test"})
    assert_equal "test", Matching::Persistence::Score.where(student_id: student_id).first.t_s
    Matching::Database::Score.new.update({student_id: student_id}, {t_s: "0"})
    assert_equal "0", Matching::Persistence::Score.where(student_id: student_id).first.t_s
  end

  def test_database_setting
    program = programs(:albers)
    setting_collection = Matching::Database::Setting.new
    assert_equal program.id, setting_collection.find("program_id": program.id).first["program_id"]
  end

  private

  def update_attribute(program)
    match_setting = program.match_setting
    match_setting.update_attributes!({min_match_score: 0.0, max_match_score: 0.0, partition: 1, dynamic_p: false})
  end
end
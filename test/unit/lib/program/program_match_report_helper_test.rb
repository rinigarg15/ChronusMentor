require_relative './../../../test_helper'
class ProgramMatchReportHelperTest < ActiveSupport::TestCase
  def test_set_current_status_graph_data
    program = programs(:albers)
    time_now = Time.now
    Time.stubs(:now).returns(time_now)
    mentee_role = program.roles.find_by(name: RoleConstants::STUDENT_NAME)
    total_active_mentee_ids = program.student_users.active.pluck(:id)
    query_params = [program, program.created_at, time_now, role: mentee_role, ids: total_active_mentee_ids]
    Program.any_instance.expects(:get_graph_data_for_program).with(total_active_mentee_ids, query_params).once
    program.set_current_status_graph_data(program.created_at, time_now, program)
  end

  def test_get_graph_data_for_program
    program = programs(:albers)
    time_now = Time.now
    Time.stubs(:now).returns(time_now)
    mentee_role = program.roles.find_by(name: RoleConstants::STUDENT_NAME)
    total_active_mentee_ids = program.student_users.active.pluck(:id)
    query_params = [program, program.created_at, time_now, role: mentee_role, ids: total_active_mentee_ids]

    #Ongoing - Self Match 
    program.stubs(:only_career_based_ongoing_mentoring_enabled?).returns(true)
    program.stubs(:matching_by_mentee_alone?).returns(true)
    program.expects(:get_data_for_ongoing_self_match_and_preferred_mentoring).with(total_active_mentee_ids, query_params).once.returns("hi")
    assert_equal "hi", program.get_graph_data_for_program(total_active_mentee_ids, query_params)

    #Ongoing - Preferred Mentoring
    program.stubs(:only_career_based_ongoing_mentoring_enabled?).returns(true)
    program.stubs(:matching_by_mentee_alone?).returns(false)
    program.stubs(:matching_by_mentee_and_admin_with_preference?).returns(true)
    program.expects(:get_data_for_ongoing_self_match_and_preferred_mentoring).with(total_active_mentee_ids, query_params).once.returns("hello")
    assert_equal "hello", program.get_graph_data_for_program(total_active_mentee_ids, query_params)

    #Ongoing - Admin Match
    program.stubs(:only_career_based_ongoing_mentoring_enabled?).returns(false)
    program.stubs(:matching_by_mentee_alone?).returns(true)
    program.stubs(:matching_by_mentee_and_admin_with_preference?).returns(false)
    program.stubs(:is_ongoing_carrer_based_matching_by_admin_alone?).returns(true)
    program.expects(:get_data_for_ongoing_admin_match).with(total_active_mentee_ids, query_params).once.returns("Bonjour")
    assert_equal "Bonjour", program.get_graph_data_for_program(total_active_mentee_ids, query_params)

    #Flash alone
    program.stubs(:only_career_based_ongoing_mentoring_enabled?).returns(false)
    program.stubs(:matching_by_mentee_alone?).returns(true)
    program.stubs(:matching_by_mentee_and_admin_with_preference?).returns(false)
    program.stubs(:is_ongoing_carrer_based_matching_by_admin_alone?).returns(false)
    program.stubs(:calendar_enabled?).returns(true)
    program.expects(:get_data_for_flash_only_program).with(total_active_mentee_ids).once.returns("Hola")
    assert_equal "Hola", program.get_graph_data_for_program(total_active_mentee_ids, query_params)

    #ongoing/flash not enabled
    program.stubs(:only_career_based_ongoing_mentoring_enabled?).returns(false)
    program.stubs(:matching_by_mentee_alone?).returns(true)
    program.stubs(:matching_by_mentee_and_admin_with_preference?).returns(false)
    program.stubs(:is_ongoing_carrer_based_matching_by_admin_alone?).returns(false)
    program.stubs(:calendar_enabled?).returns(false)
    assert_nil program.get_graph_data_for_program(total_active_mentee_ids, query_params)
  end

  def test_get_graph_data_for_ongoing_program
    program = programs(:albers)
    time_now = Time.now
    Time.stubs(:now).returns(time_now)
    mentee_role = program.roles.find_by(name: RoleConstants::STUDENT_NAME)
    total_active_mentee_ids = program.student_users.active.pluck(:id)
    query_params = [program, program.created_at, time_now, role: mentee_role, ids: total_active_mentee_ids]
    assert_equal_hash({first:71, second:0, third:24}, program.get_graph_data_for_program(total_active_mentee_ids, query_params))
  end

  def test_get_graph_data_for_ongoing_program_with_no_active_mentees
    program = programs(:albers)
    time_now = Time.now
    Time.stubs(:now).returns(time_now)
    mentee_role = program.roles.find_by(name: RoleConstants::STUDENT_NAME)
    total_active_mentee_ids = []
    query_params = [program, program.created_at, time_now, role: mentee_role, ids: total_active_mentee_ids]
    assert_equal_hash({first:0, second:0, third:0}, program.get_graph_data_for_program(total_active_mentee_ids, query_params))
  end


  def test_get_graph_data_for_ongoing_admin_match_program
    program = programs(:albers)
    time_now = Time.now
    Time.stubs(:now).returns(time_now)
    program.stubs(:only_career_based_ongoing_mentoring_enabled?).returns(false)
    program.stubs(:matching_by_mentee_alone?).returns(true)
    program.stubs(:matching_by_mentee_and_admin_with_preference?).returns(false)
    program.stubs(:is_ongoing_carrer_based_matching_by_admin_alone?).returns(true)

    mentee_role = program.roles.find_by(name: RoleConstants::STUDENT_NAME)
    total_active_mentee_ids = program.student_users.active.pluck(:id)
    query_params = [program, program.created_at, time_now, role: mentee_role, ids: total_active_mentee_ids]
    assert_equal_hash({first:24, second:14, third:76}, program.get_graph_data_for_program(total_active_mentee_ids, query_params))
  end

  def test_get_graph_data_for_ongoing_admin_match_program_with_no_active_mentees
    program = programs(:albers)
    time_now = Time.now
    Time.stubs(:now).returns(time_now)
    program.stubs(:only_career_based_ongoing_mentoring_enabled?).returns(false)
    program.stubs(:matching_by_mentee_alone?).returns(true)
    program.stubs(:matching_by_mentee_and_admin_with_preference?).returns(false)
    program.stubs(:is_ongoing_carrer_based_matching_by_admin_alone?).returns(true)

    mentee_role = program.roles.find_by(name: RoleConstants::STUDENT_NAME)
    total_active_mentee_ids = []
    query_params = [program, program.created_at, time_now, role: mentee_role, ids: total_active_mentee_ids]
    assert_equal_hash({first:0, second:0, third:0}, program.get_graph_data_for_program(total_active_mentee_ids, query_params))
  end


   def test_get_graph_data_for_flash_program
    program = programs(:albers)
    time_now = Time.now
    Time.stubs(:now).returns(time_now)
    program.stubs(:only_career_based_ongoing_mentoring_enabled?).returns(false)
    program.stubs(:matching_by_mentee_alone?).returns(true)
    program.stubs(:matching_by_mentee_and_admin_with_preference?).returns(false)
    program.stubs(:is_ongoing_carrer_based_matching_by_admin_alone?).returns(false)
    program.stubs(:calendar_enabled?).returns(true)
    mentee_role = program.roles.find_by(name: RoleConstants::STUDENT_NAME)
    total_active_mentee_ids = program.student_users.active.pluck(:id)
    query_params = [program, program.created_at, time_now, role: mentee_role, ids: total_active_mentee_ids]

    assert_equal_hash({first:19, second:25, third:5}, program.get_graph_data_for_program(total_active_mentee_ids, query_params))
    program.meetings.each do |m|
      m.false_destroy!
    end
    assert_equal_hash({first:19, second:25, third:5}, program.get_graph_data_for_program(total_active_mentee_ids, query_params))
  end

  def test_get_graph_data_for_flash_program_with_no_active_mentees
    program = programs(:albers)
    time_now = Time.now
    Time.stubs(:now).returns(time_now)
    program.stubs(:only_career_based_ongoing_mentoring_enabled?).returns(false)
    program.stubs(:matching_by_mentee_alone?).returns(true)
    program.stubs(:matching_by_mentee_and_admin_with_preference?).returns(false)
    program.stubs(:is_ongoing_carrer_based_matching_by_admin_alone?).returns(false)
    program.stubs(:calendar_enabled?).returns(true)

    mentee_role = program.roles.find_by(name: RoleConstants::STUDENT_NAME)
    total_active_mentee_ids = []
    query_params = [program, program.created_at, time_now, role: mentee_role, ids: total_active_mentee_ids]
    assert_equal_hash({first:0, second:0, third:0}, program.get_graph_data_for_program(total_active_mentee_ids, query_params))
  end

end
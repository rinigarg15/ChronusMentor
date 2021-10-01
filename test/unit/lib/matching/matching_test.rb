require_relative './../../../test_helper'

class MatchingTest < ActiveSupport::TestCase
  def setup
    @skip_stubbing_match_index = true
    super
  end

  def test_name_from_field_spec
    field_mapping = Matching::Configuration
    assert_equal 'user_abc',
        field_mapping.name_from_field_spec([User, 'abc'])
    assert_equal 'user_role_question_xyz',
        field_mapping.name_from_field_spec([User, RoleQuestion, 'xyz'])
    # Multiword
    assert_equal 'user_years_of_experience',
        field_mapping.name_from_field_spec([User, 'years of experience'])
    # Case mix.round(4)
    assert_equal 'user_years_of_experience',
        field_mapping.name_from_field_spec([User, 'yeaRs of Experience'])
    # Multispace
    assert_equal 'user_years___of_experience',
        field_mapping.name_from_field_spec([User, 'years   of experience'])
  end

  def test_field_mapping
    field_mapping_cls = Matching::Configuration
    mapping = field_mapping_cls.new
    field_1 = field_mapping_cls.name_from_field_spec([User, ProfileQuestion, 'abc'])
    field_2 = field_mapping_cls.name_from_field_spec([User, ProfileAnswer, 'xyz'])
    mapping.add_mapping([User, ProfileQuestion, 'abc'], [User, ProfileAnswer, 'xyz'], [1, 0, MatchConfig::Operator.lt, {}])

    arr = []
    mapping.field_mappings.each_pair do |fields, w|
      arr << [fields[0], fields[1], w]
    end

    assert arr.include?([field_1, field_2, [1, 0, MatchConfig::Operator.lt, {}]])

    mapping = field_mapping_cls.new
    mapping.add_mapping([User, ProfileQuestion, 'abc'], [User, ProfileAnswer, 'xyz'], [0.123, 1, MatchConfig::Operator.lt, {}])

    arr = []
    mapping.field_mappings.each_pair do |fields, w|
      arr << [fields[0], fields[1], w]
    end

    assert arr.include?([field_1, field_2, [0.123, 1, MatchConfig::Operator.lt, {}]])
  end

  def test_zero_and_negative_matches
    configuration = Matching::Configuration.new
    mapping = [-1, 0, MatchConfig::Operator.lt, {}]
    configuration.add_mapping([RoleQuestion, "sq"], [RoleQuestion, "mq"], mapping)
    
    sq = Matching::Persistence::DataField.construct_from_field_spec([RoleQuestion, "sq"], Matching::ChronusArray.new(%w[1 2 3 4]))

    mentor_questions = [
      Matching::Persistence::DataField.construct_from_field_spec([RoleQuestion, "mq"], Matching::ChronusArray.new(%w[5])),
      Matching::Persistence::DataField.construct_from_field_spec([RoleQuestion, "mq"], Matching::ChronusArray.new(%w[1 2 5 6])),
      Matching::Persistence::DataField.construct_from_field_spec([RoleQuestion, "mq"], Matching::ChronusArray.new(%w[1 2 3 5])),
      Matching::Persistence::DataField.construct_from_field_spec([RoleQuestion, "mq"], Matching::ChronusArray.new(%w[1 2 3 4]))
    ]
    results = [ 0.0, -0.5, -0.75, -1.0 ]
    mentor_questions.each_with_index do |mq, i|
      assert_equal [results[i], false], service_object.match_single_config(mq, sq, false, 0, mapping)
    end
  end

  def test_configuration
    configuration = Matching::Configuration.new

    configuration.add_mapping([RoleQuestion, 'aaa'], [RoleQuestion, 'aaa'], [1, 0, MatchConfig::Operator.lt, {}])
    assert_equal 1, configuration.max_hits

    configuration.add_mapping([RoleQuestion, 'bbb'], [RoleQuestion, 'bbb'], [-0.2, 0, MatchConfig::Operator.lt, {}])
    assert_equal 1.2, configuration.max_hits

    configuration.add_mapping([RoleQuestion, 'ccc'], [RoleQuestion, 'ccc'], [0.1, 0, MatchConfig::Operator.gt, {}])
    assert_equal 1.3, configuration.max_hits
  end

  def test_perform_full_index_and_refresh
    Delayed::Worker.delay_jobs = true
    program = programs(:albers)
    mentor = users(:f_mentor)
    assert_difference "Delayed::Job.count", 3 do
      Matching.perform_program_delta_index_and_refresh_later(program)
      Matching.delay.perform_program_delta_index_and_refresh(program.id) #moved this to normal queue
      Matching.perform_users_delta_index_and_refresh_later(mentor.id, program)
    end
    Matching.expects(:perform_program_delta_index_and_refresh).times(Program.active.count)
    assert_difference "Delayed::Job.count", -1 do # only the matching DJ queue is cleared
      Matching.perform_full_index_and_refresh
    end
  ensure
    Delayed::Worker.delay_jobs = false
  end

  def test_perform_clear_and_full_index_and_refresh
    MatchingDocument.expects(:destroy_all).once
    Matching::Persistence::Score.expects(:destroy_all).once
    Matching::Persistence::Setting.expects(:destroy_all).once
    Matching.expects(:perform_full_index_and_refresh).once
    Matching.perform_clear_and_full_index_and_refresh
  end

  def test_perform_program_delta_index_and_refresh_later
    program = programs(:albers)
    Matching.expects(:perform_program_delta_index_and_refresh).with(program.id).once
    Matching.perform_program_delta_index_and_refresh_later(program)
  end

  def test_perform_program_delta_index_and_refresh
    program = programs(:albers)
    mentor = users(:f_mentor)
    student = users(:f_student)
    mentor_user_ids = program.mentor_users.pluck(:id)
    student_user_ids = program.student_users.pluck(:id)

    Matching::Indexer.stubs(:perform_program_delta_index).with(program.id).returns([mentor_user_ids - [mentor.id], student_user_ids - [student.id]])
    Matching::Cache::Refresh.expects(:perform_program_delta_refresh).with(program.id).once
    assert_difference "MatchingDocument.count", -2 do
      assert_difference "Matching::Persistence::Score.count", -1 do
        Matching.perform_program_delta_index_and_refresh(program.id)
      end
    end

    # For consistency!
    Matching.perform_users_delta_index_and_refresh([mentor.id, student.id], program.id)
  end

  def test_perform_organization_delta_index_and_refresh
    organization = programs(:org_primary)
    Matching.expects(:perform_program_delta_index_and_refresh_with_error_handler).times(5)
    Matching.perform_organization_delta_index_and_refresh(organization.id)
    assert_equal 5, organization.programs.count

    # For inactive org
    organization.update_attributes!(active: false)
    Matching.expects(:perform_program_delta_index_and_refresh_with_error_handler).times(0)
    Matching.perform_organization_delta_index_and_refresh(organization.id)
  end

  def test_perform_organization_delta_index_and_refresh_later
    organization = programs(:org_primary)
    Matching.expects(:perform_organization_delta_index_and_refresh).once
    Matching.perform_organization_delta_index_and_refresh_later(organization)

    # For inactive org
    organization.update_attributes!(active: false)
    Matching.expects(:perform_organization_delta_index_and_refresh).times(0)
    Matching.perform_organization_delta_index_and_refresh_later(organization)
  end

  def test_perform_users_delta_index_and_refresh_later
    user = users(:f_mentor)
    Matching.expects(:perform_users_delta_index_and_refresh).with([user.id], user.program_id, {}).once
    Matching.perform_users_delta_index_and_refresh_later([user.id], user.program)
  end

  def test_perform_users_delta_index_and_refresh
    user = users(:f_mentor)
    Matching::Indexer.expects(:perform_users_delta_index).with([user.id], user.program_id, { profile_question_ids: [] } ).returns(['a']).once
    Matching::Cache::Refresh.expects(:perform_users_delta_refresh).with(['a'], user.program_id).once
    Matching.perform_users_delta_index_and_refresh([user.id], user.program_id, { profile_question_ids: [] } )
  end

  def test_remove_user_later
    user = users(:f_mentor)
    Matching.expects(:remove_user).with(user.id, user.program_id).once
    Matching.remove_user_later(user.id, user.program)
  end

  def test_remove_user
    user = users(:f_mentor)
    Matching::Cache::Refresh.expects(:remove_user_cache).with(user.id, user.program_id).once
    Matching.remove_user(user.id, user.program_id)
  end

  def test_remove_user_cache_mentor
    user = users(:f_mentor)
    student_ids = user.program.get_user_ids_based_on_roles(RoleConstants::STUDENT_NAME)
    current_prog_score_docs = Matching::Persistence::Score.where(:student_id.in => student_ids)
    current_prog_mentor_hash_count = current_prog_score_docs.first["mentor_hash"].count
    other_score_docs = Matching::Persistence::Score.where(:student_id.nin => student_ids)
    other_mentor_hash_count = other_score_docs.first["mentor_hash"].count

    assert current_prog_score_docs.first["mentor_hash"]["#{user.id}"] != nil
    assert_nil other_score_docs.first["mentor_hash"]["#{user.id}"]
   
    Matching::Cache::Refresh.remove_user_cache(user.id, user.program_id)
    assert_nil current_prog_score_docs.first["mentor_hash"]["#{user.id}"]
    assert_equal current_prog_mentor_hash_count - 1, current_prog_score_docs.first["mentor_hash"].count
    assert_equal other_mentor_hash_count, other_score_docs.first["mentor_hash"].count
  end

  def test_remove_mentor_later
    mentor = users(:f_mentor)
    Matching::Cache::Refresh.expects(:remove_mentor).with(mentor.id, mentor.program_id).once
    Matching.remove_mentor_later(mentor.id, mentor.program)
  end

  def test_remove_student_later
    student = users(:f_student)
    Matching::Cache::Refresh.expects(:remove_student).with(student.id, student.program_id).once
    Matching.remove_student_later(student.id, student.program)
  end

  def test_fetch_program
    program = programs(:albers)
    assert_equal program, Matching.fetch_program(program.id)
    assert_nil Matching.fetch_program(0)

    Program.any_instance.stubs(:active?).returns(false)
    assert_nil Matching.fetch_program(program.id)

    Program.any_instance.stubs(:active?).returns(true)
    Program.any_instance.stubs(:matching_enabled?).returns(false)
    assert_nil Matching.fetch_program(program.id)
  end

  def test_fetch_program_and_users
    user = users(:f_mentor)
    program, users = Matching.fetch_program_and_users([user.id], user.program_id)
    assert_equal user.program, program
    assert_equal [user.id], users.pluck(:id)

    Matching.expects(:fetch_program).returns(nil).once
    program, users = Matching.fetch_program_and_users([user.id], user.program_id)
    assert_nil program
    assert_nil users
  end

  private

  def service_object
    configuration = Matching::Configuration.new
    Matching::Service.new(configuration, { program: programs(:albers) })    
  end
end
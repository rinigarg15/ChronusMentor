require_relative './../../../test_helper'

class ServiceTest < ActiveSupport::TestCase

  def setup
    @skip_stubbing_match_index = true
    super
  end

  def test_bulk_match_complete_dynamic_partitioning
    program = programs(:albers)
    update_attribute(program)
    Matching.perform_program_delta_index_and_refresh(program.id)
    student = users(:f_student)
    match_client = Matching::Client.new(program)
    student_user_ids = program.student_users.pluck(:id)
    mentor_user_ids = program.mentor_users.pluck(:id)
    number_of_docs = student_user_ids.count
    mentor_hash = Matching::Database::Score.new.get_mentor_hash(student.id)
    Matching::Service.any_instance.stubs(:get_partition_size).returns(10)
    match_client.bulk_match(student_user_ids)
    assert_equal mentor_hash, Matching::Database::Score.new.get_mentor_hash(student.id)
    assert_equal (mentor_hash.size/10 + 1), Matching::Database::Score.new.find_by_mentee_id(student.id).count
    assert_equal program.match_setting.partition, (mentor_hash.size/10 + 1)
    new_count = 0
    student_user_ids.each{|student_id| new_count += Matching::Database::Score.new.find_by_mentee_id(student_id).count }
    assert_equal (number_of_docs*program.match_setting.partition), new_count
    Matching::Service.any_instance.stubs(:get_partition_size).returns(Matching::Service::PARTITION_BASE)
    Matching.perform_program_delta_index_and_refresh(program.id)
    assert_equal mentor_hash, Matching::Database::Score.new.get_mentor_hash(student.id)
    assert_equal (mentor_hash.size/Matching::Service::PARTITION_BASE + 1), Matching::Database::Score.new.find_by_mentee_id(student.id).count
    assert_equal program.match_setting.partition, (mentor_hash.size/Matching::Service::PARTITION_BASE + 1)
  end

  def test_dynamic_partitioning_reduced_mentor
    program = programs(:albers)
    update_attribute(program)
    Matching.perform_program_delta_index_and_refresh(program.id)
    student = users(:f_student)
    mentor_hash = Matching::Database::Score.new.get_mentor_hash(student.id)
    mentor_count = mentor_hash.size
    match_client = Matching::Client.new(program)
    student_user_ids = program.student_users.pluck(:id)
    mentor_user_ids = program.mentor_users.pluck(:id)
    number_of_docs = student_user_ids.count  
    Matching::Service.any_instance.stubs(:get_partition_size).returns(10)
    Matching.perform_program_delta_index_and_refresh(program.id)
    new_count_1 = 0
    student_user_ids.each{|student_id| new_count_1 += Matching::Database::Score.new.find_by_mentee_id(student_id).count }
    Matching::Service.any_instance.stubs(:get_partition_size).returns(15)
    Matching.perform_program_delta_index_and_refresh(program.id)
    new_count_2 = 0
    student_user_ids.each{|student_id| new_count_2 += Matching::Database::Score.new.find_by_mentee_id(student_id).count }
    Matching::Service.any_instance.stubs(:get_partition_size).returns(Matching::Service::PARTITION_BASE)
    Matching.perform_program_delta_index_and_refresh(program.id)
    assert_equal (mentor_count/10 + 1)*student_user_ids.size, new_count_1
    assert_equal (mentor_count/15 + 1)*student_user_ids.size, new_count_2
  end

  def test_delta_mentor_match
    program = programs(:albers)
    update_attribute(program)
    Matching.perform_program_delta_index_and_refresh(program.id)
    mentor = users(:f_mentor)
    mentor_id = mentor.id
    match_client = Matching::Client.new(program)
    student_user_ids = program.student_users.pluck(:id)
    mentee_hash = {}
    student_user_ids.each do |student_id|
      mentee_hash[student_id] = Matching::Database::Score.new.get_mentor_hash(student_id)[mentor_id.to_s]
    end
    Matching::RefreshScore.any_instance.expects(:refresh_score_documents_wrt_mentor_update!).with(mentor_id, mentee_hash)
    Matching::Service.any_instance.expects(:update_match_score_range_for_mentor_update!).with(program, 0.0, 0.0)
    match_client.bulk_mentor_match(student_user_ids, Array(mentor_id))
  end

  def test_delta_mentee_match
    program = programs(:albers)
    update_attribute(program)
    Matching.perform_program_delta_index_and_refresh(program.id)
    student = users(:f_student)
    student_id = student.id
    match_client = Matching::Client.new(program)
    mentor_user_ids = program.mentor_users.pluck(:id)
    Matching::RefreshScore.any_instance.expects(:refresh_score_documents!)
    match_client.bulk_mentee_match(Array(student_id), mentor_user_ids)
  end

  def test_update_match_score_range_for_mentor_update
    program = programs(:albers)
    match_client = Matching::Client.new(program)
    min_score, max_score = [0.0, 1.0]
    Program.any_instance.expects(:update_match_scores_range_for_min_max!).with(min_score, max_score)
    match_client.service.update_match_score_range_for_mentor_update!(program, min_score, max_score)
    Program.any_instance.expects(:update_match_scores_range_for_min_max!).never
    min_score, max_score = [Float::INFINITY, Float::INFINITY*-1]
    match_client.service.update_match_score_range_for_mentor_update!(program, min_score, max_score)
  end

  def test_get_ids_hash_based_on_modulo
    program = programs(:albers)
    match_client = Matching::Client.new(program)
    student_user_ids = program.get_user_ids_based_on_roles(RoleConstants::STUDENT_NAME)
    get_ids_hash = match_client.service.get_ids_hash_based_on_modulo(student_user_ids, 2)
    assert_equal 2, get_ids_hash.size
  end

  def test_mentor_hash
    student_id = 1
    partition = 3
    mentor_hash = Matching::Interface::MentorHash.new(student_id, partition)
    assert_equal mentor_hash.mentor_hash_with_partition.size, partition
    assert_equal mentor_hash.mentee_id, student_id
    assert_equal mentor_hash.partition, partition
    mentor_hash.add_to_mentor_hash(10, [0.1, false])
    assert_equal mentor_hash.mentor_hash_with_partition[10 % 3][10.to_s], [0.1, false]
    assert_equal mentor_hash.mentor_hash_with_partition[0].present?, false
  end

  def test_mentee_hash
    mentor_id = 1
    number_of_mentees = 300
    mentee_hash = Matching::Interface::MenteeHash.new(mentor_id, number_of_mentees)
    divisor = number_of_mentees/MAX_BULK_SIZE + 1
    assert_equal mentee_hash.mentee_hash.size, divisor
    assert_equal mentee_hash.mentor_id, 1
    assert_equal mentee_hash.min_score, Float::INFINITY
    assert_equal mentee_hash.max_score, Float::INFINITY * -1
    mentee_hash.add_to_mentee_hash(10, [0.1, false])
    assert_equal [0.1, false], mentee_hash.mentee_hash[10 % divisor][10]
    assert_equal mentee_hash.min_score, 0.1
    assert_equal mentee_hash.max_score, 0.1
    mentee_hash.add_to_mentee_hash(11, [0.8, false])
    assert_equal [0.8, false], mentee_hash.mentee_hash[11 % divisor][11]
    assert_equal mentee_hash.min_score, 0.1
    assert_equal mentee_hash.max_score, 0.8
    mentee_hash.add_to_mentee_hash(20, [0.7, false])
    assert_equal [0.7, false], mentee_hash.mentee_hash[20 % divisor][20]
    assert_equal mentee_hash.min_score, 0.1
    assert_equal mentee_hash.max_score, 0.8
  end

  def test_construct_config_for_details
    program = programs(:albers)
    prof_q = create_profile_question(question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "Choice Field1", question_choices: ["Choice 1", "Choice 2"], organization: programs(:org_primary))
    prog_mentor_question = create_role_question(program: program, role_names: [RoleConstants::MENTOR_NAME], profile_question: prof_q)
    prog_student_question = create_role_question(program: program, role_names: [RoleConstants::STUDENT_NAME], profile_question: prof_q)
    match_config = MatchConfig.create!(
        program: program,
        mentor_question: prog_mentor_question,
        student_question: prog_student_question)

    match_client = Matching::Client.new(program)
    config = match_client.service.configuration
    assert_equal "role_question_choice_field1", config.field_mappings.first[0][0]
    assert_equal "role_question_choice_field1", config.field_mappings.first[0][1]

    match_client = Matching::Client.new(program, true)
    config = match_client.service.configuration
    assert_equal({}, config.field_mappings)

    match_config.update_attribute(:show_match_label, true)
    match_client = Matching::Client.new(program, true)
    config = match_client.service.configuration
    assert_equal "role_question_choice_field1", config.field_mappings.first[0][0]
    assert_equal "role_question_choice_field1", config.field_mappings.first[0][1]
    assert_equal [1.0, 0.0, "lt", nil, match_config.id], config.field_mappings.values[0]
  end

  def test_match_single_config
    program = programs(:albers)
    match_client = Matching::Client.new(program)
    configuration = Matching::Configuration.new
    mapping = [-1, 0, MatchConfig::Operator.lt, {}]
    configuration.add_mapping([RoleQuestion, "sq"], [RoleQuestion, "mq"], mapping)
    
    sq = Matching::Persistence::DataField.construct_from_field_spec([RoleQuestion, "sq"], Matching::ChronusArray.new(%w[1 2 3 4]))

    mentor_question = Matching::Persistence::DataField.construct_from_field_spec([RoleQuestion, "mq"], Matching::ChronusArray.new(%w[5]))

    data = match_client.service.match_single_config(mentor_question, nil, false, 0.0, [1.0, 0.1, "lt", nil, 1610])
    assert_equal [Matching::EMPTY_WEIGHT, true], data

    data = match_client.service.match_single_config(mentor_question, nil, false, 0.0, [1.0, 0.0, "lt", nil, 1610])
    assert_equal [Matching::EMPTY_WEIGHT, false], data

    data = match_client.service.match_single_config(nil, nil, false, 0.0, [1.0, 0.1, "lt", nil, 1610])
    assert_equal [Matching::EMPTY_WEIGHT, true], data

    data = match_client.service.match_single_config(nil, mentor_question, false, 0.0, [1.0, 0.1, "lt", nil, 1610])
    assert_equal [Matching::EMPTY_WEIGHT, true], data

    data = match_client.service.match_single_config(nil, mentor_question, false, 0.0, [1.0, 0.0, "lt", nil, 1610])
    assert_equal [Matching::EMPTY_WEIGHT, false], data

    data = match_client.service.match_single_config(nil, mentor_question, false, 0.0, [1.0, 0.1, "lt", nil, 1610])
    assert_equal [Matching::EMPTY_WEIGHT, true], data


    data = match_client.service.match_single_config(mentor_question, nil, false, 0.0, [1.0, 0.1, "lt", nil, 1610], get_common_data: true)
    assert_equal [Matching::EMPTY_WEIGHT, true, []], data

    data = match_client.service.match_single_config(mentor_question, nil, false, 0.0, [1.0, 0.0, "lt", nil, 1610], get_common_data: true)
    assert_equal [Matching::EMPTY_WEIGHT, false, []], data

    data = match_client.service.match_single_config(nil, nil, false, 0.0, [1.0, 0.1, "lt", nil, 1610], get_common_data: true)
    assert_equal [Matching::EMPTY_WEIGHT, true, []], data
  end

  private

  def update_attribute(program)
    match_setting = program.match_setting
    match_setting.update_attributes!({min_match_score: 0.0, max_match_score: 0.0, partition: 1})
  end
end
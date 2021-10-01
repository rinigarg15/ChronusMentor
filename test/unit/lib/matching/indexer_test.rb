require_relative './../../../test_helper'

class IndexerTest < ActiveSupport::TestCase

  def setup
    @skip_stubbing_match_index = true
    super
  end

  def test_validation_mongoid
    new_matching_setting = Matching::Persistence::Setting.create(min_match_score: 0.7)
    assert_false new_matching_setting.valid?
  end

  def test_default_mongoid
    student = users(:f_student)
    new_matching_score = Matching::Persistence::Score.new(student_id: student.id)
    assert_equal 0, new_matching_score.p_id
    assert_equal "0", new_matching_score.t_s
  end

  def test_indexes_created_mongoid
    score_index_keys = Matching::Persistence::Score.collection.indexes.to_a.map{|q| q[:key]}
    assert_equal_unordered [{"_id" => 1}, {"student_id" => 1, "p_id" => 1}, {"student_id" => 1}], score_index_keys
  end

  def test_delta_indexing
    program = programs(:albers)
    mentor = users(:f_mentor)
    student = users(:f_student)
    admin = users(:f_admin)
    mentor_student = users(:f_mentor_student)
    student_role = program.get_role(RoleConstants::STUDENT_NAME)

    assert_difference "program.match_configs.count", 2 do
      @q1 = create_question(question_text: "Hello1", role_names: [RoleConstants::MENTOR_NAME])
      q2 = create_question(question_text: "Hello2", role_names: [RoleConstants::MENTOR_NAME])
      q11 = @q1.role_questions.create!(role: student_role)
      q22 = q2.role_questions.create!(role: student_role)
      program.reload
      MatchConfig.create!(program: program, mentor_question: @q1.role_questions.first, student_question: q11)
      MatchConfig.create!(program: program, mentor_question: q2.role_questions.first, student_question: q22)
    end

    document = MatchingDocument.where(record_id: mentor.id, program_id: program.id, mentor: true).first
    assert document.present?

    Matching::Cache::Refresh.perform_users_delta_refresh([mentor.id, student.id], program.id)
    mentors_size = program.mentor_users.size
    assert_equal mentors_size, student.student_cache_normalized.keys.size

    assert_no_difference 'Matching::Persistence::Score.count' do
      assert_difference 'MatchingDocument.count', -1 do
        Matching.remove_user(mentor.id, program.id)
      end
    end
    assert_equal mentors_size-1, student.reload.student_cache_normalized.keys.size

    assert_no_difference 'Matching::Persistence::Score.count' do
      assert_no_difference 'MatchingDocument.count' do
        Matching.remove_user(mentor.id, program.id)
      end
    end
    assert_equal mentors_size-1, student.reload.student_cache_normalized.keys.size

    mentor.member.profile_answers.destroy_all
    assert_no_difference 'Matching::Persistence::Score.count' do
      assert_difference 'MatchingDocument.count' do
        Matching.perform_users_delta_index_and_refresh([mentor.id], program.id)
      end
    end
    assert_equal mentors_size, student.reload.student_cache_normalized.keys.size

    # No documents should be available for this user as all the profile_answers are deleted.
    document = MatchingDocument.where(record_id: mentor.id, program_id: program.id, mentor: true).first
    assert_equal 0, document.data_fields.size

    ProfileAnswer.create!(ref_obj: mentor.member, profile_question: @q1, answer_value: 'good')
    assert_equal 1, mentor.reload.member.profile_answers.size
    assert_no_difference 'Matching::Persistence::Score.count' do
      assert_no_difference 'MatchingDocument.count' do
        assert_difference 'document.reload.data_fields.size' do
          Matching.perform_users_delta_index_and_refresh([mentor.id], program.id)
        end
      end
    end
    assert_equal mentors_size, student.reload.student_cache_normalized.keys.size

    assert_difference 'Matching::Persistence::Score.count', -1 do
      assert_difference 'MatchingDocument.count', -2 do
        Matching.remove_user(mentor_student.id, program.id)
      end
    end
    assert_equal (mentors_size - 1), student.reload.student_cache_normalized.keys.size

    assert_difference 'Matching::Persistence::Score.count', 1 do
      assert_difference 'MatchingDocument.count', 2 do
        Matching.perform_users_delta_index_and_refresh([mentor_student.id], program.id)
      end
    end
    assert_equal mentors_size, student.reload.student_cache_normalized.keys.size

    ProfileAnswer.create!(ref_obj: mentor_student.member, profile_question: @q1, answer_value: 'good')
    documents = MatchingDocument.where(record_id: mentor_student.id)
    doc1 = documents[0]
    doc2 = documents[1]
    # Even one answer is created both the student and mentor records are updated
    # as they are simillar questions
    assert_difference 'doc1.reload.data_fields.size' do
      assert_difference 'doc2.reload.data_fields.size' do
        Matching::Indexer.perform_users_delta_index([mentor_student.id], program.id)
      end
    end

    Matching.expects(:remove_user).with(admin.id, program.id).once
    Matching::Indexer.perform_users_delta_index([admin.id], program.id)
  end

  def test_delta_index_during_group_closure
    program = programs(:albers)
    mentor1 = users(:f_mentor)
    student1 = users(:mkr_student)
    assert_equal mentor1.groups.first, student1.groups.first
    group = mentor1.groups.first
    assert group.active?
    program.update_attributes!(prevent_past_mentor_matching: true)

    Matching.perform_program_delta_index_and_refresh(program.id)
    mentor_doc = MatchingDocument.where(record_id: mentor1.id, program_id: program.id, mentor: true).first
    student_doc = MatchingDocument.where(record_id: student1.id, program_id: program.id, mentor: false).first
    mentor_doc_value = Matching::AbstractType.from_mysql_type(mentor_doc.data_fields.select { |df| df["name"] == "user_past_mentors_question_mentor" }.first["value"])
    student_doc_value = Matching::AbstractType.from_mysql_type(student_doc.data_fields.select { |df| df["name"] == "user_past_mentors_question_mentee" }.first["value"])
    assert_equal [], student_doc_value.store

    group.terminate!(users(:f_admin), 'this is the reason', group.program.permitted_closure_reasons.first.id)
    Matching::Indexer.perform_users_delta_index(group.member_ids, program.id)
    mentor_doc = MatchingDocument.where(record_id: mentor1.id, program_id: program.id, mentor: true).first
    student_doc = MatchingDocument.where(record_id: student1.id, program_id: program.id, mentor: false).first
    mentor_doc_value = Matching::AbstractType.from_mysql_type(mentor_doc.data_fields.select { |df| df["name"] == "user_past_mentors_question_mentor" }.first["value"])
    student_doc_value = Matching::AbstractType.from_mysql_type(student_doc.data_fields.select { |df| df["name"] == "user_past_mentors_question_mentee" }.first["value"])
    assert student_doc_value.store.include?(mentor_doc_value.store)
  end

  def test_delta_index_during_group_reactivation
    program = programs(:albers)
    admin = users(:f_admin)
    mentor1 = users(:f_mentor)
    student1 = users(:mkr_student)
    assert_equal mentor1.groups.first, student1.groups.first
    group = mentor1.groups.first
    group.terminate!(admin, "test", group.program.permitted_closure_reasons.first.id)
    assert group.closed?
    program.update_attributes!(prevent_past_mentor_matching: true)

    Matching.perform_program_delta_index_and_refresh(program.id)
    mentor_doc = MatchingDocument.where(record_id: mentor1.id, program_id: program.id, mentor: true).first
    student_doc = MatchingDocument.where(record_id: student1.id, program_id: program.id, mentor: false).first
    mentor_doc_value = Matching::AbstractType.from_mysql_type(mentor_doc.data_fields.select { |df| df["name"] == "user_past_mentors_question_mentor" }.first["value"])
    student_doc_value = Matching::AbstractType.from_mysql_type(student_doc.data_fields.select { |df| df["name"] == "user_past_mentors_question_mentee" }.first["value"])

    assert student_doc_value.store.include?(mentor_doc_value.store)

    group.change_expiry_date(admin, Time.now + 2.months, "Test Reason")
    Matching::Indexer.perform_users_delta_index(group.member_ids, program.id)
    mentor_doc = MatchingDocument.where(record_id: mentor1.id, program_id: program.id, mentor: true).first
    student_doc = MatchingDocument.where(record_id: student1.id, program_id: program.id, mentor: false).first
    mentor_doc_value = Matching::AbstractType.from_mysql_type(mentor_doc.data_fields.select { |df| df["name"] == "user_past_mentors_question_mentor" }.first["value"])
    student_doc_value = Matching::AbstractType.from_mysql_type(student_doc.data_fields.select { |df| df["name"] == "user_past_mentors_question_mentee" }.first["value"])
    assert_equal [], student_doc_value.store
  end

  def test_program_delta_indexer_returns_user_ids
    program = programs(:albers)
    mentor_ids, student_ids = Matching::Indexer.perform_program_delta_index(program.id)
    assert_not_empty mentor_ids
    assert_not_empty student_ids
    assert_equal program.mentor_users.active_or_pending.size, mentor_ids.size
    assert_equal program.student_users.active_or_pending.size, student_ids.size
  end

  def test_prevent_manager_matching
    program = programs(:albers)
    # Creating second level manager 11 -> 7 -> 3
    mentor1 = users(:f_mentor)
    student1 = users(:student_1)
    muser1 = users(:rahim)
    manager1 = managers(:manager_3)
    assert_equal manager1.managee, student1.member
    assert_equal manager1.member, muser1.member
    mgr_ques = profile_questions(:manager_q)
    mgr_ques.role_questions.create(role_id: program.roles.find_by(name: "student").id)
    manager2 = create_manager(muser1, mgr_ques, { email: mentor1.email } )
    assert_equal manager2.member, mentor1.member

    program.enable_feature(FeatureName::MANAGER, true)
    Matching::Indexer.perform_program_delta_index(program.id)
    ment_doc = MatchingDocument.where(record_id: mentor1.id, program_id: program.id, mentor: true).first
    stud_doc = MatchingDocument.where(record_id: student1.id, program_id: program.id, mentor: false).first
    assert_false ment_doc.data_fields.collect{|x| x["name"]}.include?("manager_manager_question_mentor")
    assert_false stud_doc.data_fields.collect{|x| x["name"]}.include?("manager_manager_question_mentee")

    program.update_attributes(prevent_manager_matching: true)
    program.update_attributes(manager_matching_level: -1)
    Matching.perform_program_delta_index_and_refresh(program.id)
    ment_doc = MatchingDocument.where(record_id: mentor1.id, program_id: program.id, mentor: true).first
    stud_doc = MatchingDocument.where(record_id: student1.id, program_id: program.id, mentor: false).first

    assert ment_doc.data_fields.collect{|x| x["name"]}.include?("manager_manager_question_mentor")
    assert stud_doc.data_fields.collect{|x| x["name"]}.include?("manager_manager_question_mentee")
    ment_mgr = Matching::AbstractType.from_mysql_type(ment_doc.data_fields.select { |df| df["name"] == "manager_manager_question_mentor" }.first["value"])
    stud_mgr = Matching::AbstractType.from_mysql_type(stud_doc.data_fields.select { |df| df["name"] == "manager_manager_question_mentee" }.first["value"])
    assert_false stud_mgr.match(ment_mgr)

    program.update_attributes(manager_matching_level: 1)
    Matching.perform_program_delta_index_and_refresh(program.id)
    ment_doc = MatchingDocument.where(record_id: mentor1.id, program_id: program.id, mentor: true).first
    muser_doc = MatchingDocument.where(record_id: muser1.id, program_id: program.id, mentor: false).first
    stud_doc = MatchingDocument.where(record_id: student1.id, program_id: program.id, mentor: false).first
    assert ment_doc.data_fields.collect{|x| x["name"]}.include?("manager_manager_question_mentor")
    assert muser_doc.data_fields.collect{|x| x["name"]}.include?("manager_manager_question_mentee")
    assert stud_doc.data_fields.collect{|x| x["name"]}.include?("manager_manager_question_mentee")
    ment_mgr = Matching::AbstractType.from_mysql_type(ment_doc.data_fields.select { |df| df["name"] == "manager_manager_question_mentor" }.first["value"])
    muser_mgr = Matching::AbstractType.from_mysql_type(muser_doc.data_fields.select { |df| df["name"] == "manager_manager_question_mentee" }.first["value"])
    stud_mgr = Matching::AbstractType.from_mysql_type(stud_doc.data_fields.select { |df| df["name"] == "manager_manager_question_mentee" }.first["value"])
    assert_false muser_mgr.match(ment_mgr)
    assert stud_mgr.match(ment_mgr)
  end

  def test_prevent_past_mentor_matching
    program = programs(:albers)
    mentor1 = users(:f_mentor)
    student1 = users(:mkr_student)
    assert_equal mentor1.groups.first, student1.groups.first
    group = mentor1.groups.first
    assert group.active?
    program.update_attributes!(prevent_past_mentor_matching: true)

    Matching::Indexer.perform_program_delta_index(program.id)
    ment_doc = MatchingDocument.where(record_id: mentor1.id, program_id: program.id, mentor: true).first
    stud_doc = MatchingDocument.where(record_id: student1.id, program_id: program.id, mentor: false).first
    assert ment_doc.data_fields.collect{|x| x["name"]}.include?("user_past_mentors_question_mentor")
    assert stud_doc.data_fields.collect{|x| x["name"]}.include?("user_past_mentors_question_mentee")

    group.terminate!(users(:f_admin), 'this is the reason', group.program.permitted_closure_reasons.first.id)
    Matching.perform_program_delta_index_and_refresh(program.id)
    mentor_doc = MatchingDocument.where(record_id: mentor1.id, program_id: program.id, mentor: true).first
    student_doc = MatchingDocument.where(record_id: student1.id, program_id: program.id, mentor: false).first
    mentor_doc_value = Matching::AbstractType.from_mysql_type(mentor_doc.data_fields.select { |df| df["name"] == "user_past_mentors_question_mentor" }.first["value"])
    student_doc_value = Matching::AbstractType.from_mysql_type(student_doc.data_fields.select { |df| df["name"] == "user_past_mentors_question_mentee" }.first["value"])
    assert student_doc_value.store.include?(mentor_doc_value.store)
  end

  def test_prevent_user_indexing_unless_profile_question_invloves_matching
    user = users(:f_mentor)
    program = programs(:albers)
    profile_question = profile_questions(:profile_questions_9)
    student_question = profile_question.role_questions.where(role: program.roles.with_name(:student)).first
    mentor_question = profile_question.role_questions.where(role: program.roles.with_name(:mentor)).first

    assert program.matching_enabled?
    MatchConfig.create!(program: program, mentor_question: mentor_question, student_question: student_question)

    ProfileAnswer.create!(ref_obj: user.member, profile_question: profile_question, answer_value: 'Male')
    document = MatchingDocument.where(record_id: user.id).first
    assert_difference 'document.reload.data_fields.size', 1 do
      Matching::Indexer.perform_users_delta_index([user.id], program.id)
    end

    ProfileAnswer.create!(ref_obj: user.member, profile_question: profile_questions(:profile_questions_10), answer_value: 'Accounting')
    assert_no_difference 'document.reload.data_fields.size' do
      Matching::Indexer.perform_users_delta_index([user.id], program.id)
    end
  end

  def test_matching_needed_when_prevent_manager_matching_enabled
    program = programs(:albers)
    user = users(:f_mentor)
    match_configs = program.match_configs
    mentor_questions = match_configs.collect(&:mentor_question).collect(&:profile_question)
    manager_question_id = program.organization.profile_questions.manager_questions.first.id

    assert_false program.prevent_manager_matching
    assert_false Matching::Indexer.send(:matching_needed?, program, mentor_questions, [manager_question_id])
    Matching::Indexer.expects(:refresh_user).never
    Matching::Indexer.perform_users_delta_index([user.id], program.id, profile_question_ids: [manager_question_id])

    program.update_attributes!(prevent_manager_matching: true)

    assert Matching::Indexer.send(:matching_needed?, program, mentor_questions, [manager_question_id])
    Matching::Indexer.expects(:refresh_user).once
    Matching::Indexer.perform_users_delta_index([user.id], program.id, profile_question_ids: [manager_question_id])
  end

  def test_perform_program_delta_index_for_portal
    MatchingDocument.expects(:all).never
    Matching::Indexer.expects(:index_users).never
    assert_equal [[], []], Matching::Indexer.perform_program_delta_index(programs(:primary_portal).id)
  end

  def test_get_index_by_answer
    # [user_id, profile_answer_id, answer_text, question_type, question_text, question_info, lat, lng, school_name, major, job_title, company, men_que_id, stu_que_id, member_id, ques_choice_text]
    # any number will work here as the aim is to test if they are grouped by answer id
    input_data = []
    input_data << [1515, 4348, "English,French", 3, "Language", "English,French,Hindi", nil, nil, nil, nil, nil, nil, 1584, 1599, 448, "English"]
    input_data << [1515, 4348, "English,French", 3, "Language", "English,French,Hindi", nil, nil, nil, nil, nil, nil, 1584, 1599, 448, "French"]
    index_by_answer = Matching::Indexer.get_index_by_answer(input_data)
    assert index_by_answer.keys.include?(4348)
    assert_equal 2, index_by_answer[4348].size
  end

  def test_process_each_pair
    input_data = []
    input_data << [1515, 4348, "English,French", 3, "Language", "English,French,Hindi", nil, nil, nil, nil, nil, nil, 1584, 1599, 448, "English"]
    input_data << [1515, 4348, "English,French", 3, "Language", "English,French,Hindi", nil, nil, nil, nil, nil, nil, 1584, 1599, 448, "French"]
    index_by_answer = Matching::Indexer.get_index_by_answer(input_data)
    data_fields = []
    Matching::Indexer.process_each_pair!(index_by_answer, data_fields)
    assert_equal 1, data_fields.size
    assert_equal "role_question_language", data_fields.first.name
    assert_equal Matching::ChronusArray, data_fields.first.value.class
    assert_equal ["english", "french"], data_fields.first.value.collection
  end

  def test_perform_user_delta_index_for_portal
    user = users(:portal_employee)
    Matching.expects(:remove_user).never
    assert_nil Matching::Indexer.perform_users_delta_index([user.id], user.program_id)
  end
end
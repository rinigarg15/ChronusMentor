require_relative './../test_helper.rb'

class PreferenceBasedMentorListTest < ActiveSupport::TestCase
  def test_belongs_to
    user = users(:f_admin)
    ref_obj = Location.first
    pq = ProfileQuestion.first
    pbml = PreferenceBasedMentorList.new(user: user, ref_obj: ref_obj, profile_question: pq)
    assert_equal user, pbml.user
    assert_equal ref_obj, pbml.ref_obj
    assert_equal pq, pbml.profile_question
  end

  def test_validations
    pbml = PreferenceBasedMentorList.new
    assert_false pbml.valid?

    assert_equal ["can't be blank"], pbml.errors[:user]
    assert_equal ["can't be blank"], pbml.errors[:ref_obj]
    assert_equal ["can't be blank"], pbml.errors[:profile_question]
    assert_equal ["can't be blank", "is not a number"], pbml.errors[:weight]
  end

  def test_ignored_scope
    user = users(:f_admin)
    ref_obj1 = Location.first
    ref_obj2 = Location.last
    ref_obj3 = QuestionChoice.first
    pq = ProfileQuestion.first
    assert PreferenceBasedMentorList.ignored.all.empty?

    pbml1 = PreferenceBasedMentorList.create!(user: user, ref_obj: ref_obj1, profile_question: pq, weight: 0, ignored: true)
    PreferenceBasedMentorList.create!(user: user, ref_obj: ref_obj2, profile_question: pq, weight: 0)
    pbml2 = PreferenceBasedMentorList.create!(user: user, ref_obj: ref_obj3, profile_question: pq, weight: 0, ignored: true)

    assert_equal_unordered [pbml1, pbml2].collect(&:id), PreferenceBasedMentorList.ignored.pluck(:id)
  end

  def test_initialize
    prof_q = create_profile_question(question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "single choice same question", question_choices: ["Choice 1", "Choice 2"], organization: programs(:org_primary))
    qc1 = prof_q.question_choices.first

    pbml = PreferenceBasedMentorList.new(ref_obj: qc1, weight: 0.5, profile_question: prof_q)
    assert_equal qc1, pbml.ref_obj
    assert_equal 0.5, pbml.weight
    assert_equal prof_q, pbml.profile_question
  end

  def test_type
    prof_q = create_profile_question(question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "single choice same question", question_choices: ["Choice 1", "Choice 2"], organization: programs(:org_primary))
    qc1 = prof_q.question_choices.first

    pbml = PreferenceBasedMentorList.new(ref_obj: qc1, weight: 0.5, profile_question: prof_q)
    assert_equal QuestionChoice.name, pbml.type

    pbml.ref_obj = Location.first
    assert_equal Location.name, pbml.type
  end

  def test_meets_number_of_choices_creteria
    prof_q = create_profile_question(question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "single choice same question", question_choices: ["Choice 1", "Choice 2"], organization: programs(:org_primary))
    qc1 = prof_q.question_choices.first
    location = Location.first

    pbml = PreferenceBasedMentorList.new(ref_obj: location, weight: 0.5, profile_question: prof_q)
    assert pbml.meets_number_of_choices_creteria?

    pbml.ref_obj = qc1
    assert_false pbml.meets_number_of_choices_creteria?

    prof_q.stubs(:question_choices).returns([1,2,3,4])
    assert pbml.meets_number_of_choices_creteria?
  end

  def test_meets_number_of_mentors_answered_creteria
    location = locations(:chennai)
    program = programs(:albers)
    mentor_member_ids = program.mentor_users.pluck(:member_id)
    pql = programs(:org_primary).profile_questions.where(question_type: ProfileQuestion::Type::LOCATION).first

    pbml = PreferenceBasedMentorList.new(ref_obj: location, weight: 0.5, profile_question: pql)
    location.stubs(:get_other_locations_in_the_city).returns(Location.where(id: location.id))
    assert_false pbml.meets_number_of_mentors_answered_creteria?(mentor_member_ids)

    pql.profile_answers.destroy_all
    program.mentor_users.active.first(10).each do |mentor|
      ProfileAnswer.create!(ref_obj: mentor.member, profile_question: pql, location_id: location.id)
    end

    assert pbml.meets_number_of_mentors_answered_creteria?(mentor_member_ids)
    assert_false pbml.meets_number_of_mentors_answered_creteria?([])
    location.stubs(:get_other_locations_in_the_city).returns(Location.where.not(id: location.id))
    assert_false pbml.meets_number_of_mentors_answered_creteria?(mentor_member_ids)

    pqc = create_profile_question(question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "single choice same question", question_choices: ["Choice 1", "Choice 2"], organization: programs(:org_primary))
    qc = pqc.question_choices.first
    pbml = PreferenceBasedMentorList.new(ref_obj: qc, weight: 0.5, profile_question: pqc)
    assert_false pbml.meets_number_of_mentors_answered_creteria?(mentor_member_ids)

    program.mentor_users.active.first(10).each do |mentor|
      ProfileAnswer.create!(ref_obj: mentor.member, profile_question: pqc, answer_value: "Choice 1")
    end

    assert pbml.meets_number_of_mentors_answered_creteria?(mentor_member_ids)
    assert_false pbml.meets_number_of_mentors_answered_creteria?([])
  end

  def test_select_mentor_lists_meeting_criteria
    pbml2 = PreferenceBasedMentorList.new(ref_obj: QuestionChoice.first, weight: 0.1, profile_question: ProfileQuestion.first)
    pbml1 = PreferenceBasedMentorList.new(ref_obj: QuestionChoice.first, weight: 0.2, profile_question: ProfileQuestion.first)
    pbml3 = PreferenceBasedMentorList.new(ref_obj: QuestionChoice.first, weight: 0.3, profile_question: ProfileQuestion.first)
    pbml1.stubs(:meets_number_of_choices_creteria?).returns(true)
    pbml2.stubs(:meets_number_of_choices_creteria?).returns(true)
    pbml3.stubs(:meets_number_of_choices_creteria?).returns(false)

    pbml1.stubs(:meets_number_of_mentors_answered_creteria?).with('ids').returns(false)
    pbml2.stubs(:meets_number_of_mentors_answered_creteria?).with('ids').returns(true)
    pbml3.stubs(:meets_number_of_mentors_answered_creteria?).with('ids').returns(true)

    assert_equal [pbml2], PreferenceBasedMentorList.select_mentor_lists_meeting_criteria([pbml1, pbml2, pbml3], 'ids')
  end
end
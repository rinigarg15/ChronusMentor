require_relative "./../../test_helper.rb"

class PreferenceBasedMentorListsRecommendationServiceTest < ActiveSupport::TestCase
  def test_initialize
    mentee = User.first
    PreferenceBasedMentorListsRecommendationService.any_instance.stubs(:build_mentor_lists).once
    pbmls = PreferenceBasedMentorListsRecommendationService.new(mentee)
    assert_equal mentee, pbmls.mentee
    assert_equal mentee.program, pbmls.program
    assert_equal [], pbmls.mentor_lists
    assert_equal [], pbmls.ignored_mentor_lists

    ml1 = mentee.preference_based_mentor_lists.create!(ref_obj: Location.first, profile_question: ProfileQuestion.first, weight: 0.2)
    ml2 = mentee.preference_based_mentor_lists.create!(ref_obj: Location.last, profile_question: ProfileQuestion.first, weight: 0.2, ignored: true)
    PreferenceBasedMentorListsRecommendationService.any_instance.stubs(:build_mentor_lists).once
    pbmls2 = PreferenceBasedMentorListsRecommendationService.new(mentee)
    assert_equal [ml2], pbmls2.ignored_mentor_lists
  end

  def test_has_recommendations
    mentee = User.first
    pbmls = PreferenceBasedMentorListsRecommendationService.new(mentee)
    assert_equal [], pbmls.mentor_lists
    assert_false pbmls.has_recommendations?

    pbmls.mentor_lists = ['something']
    assert pbmls.has_recommendations?
  end

  def test_get_ordered_lists
    mentee = User.first
    pbmls = PreferenceBasedMentorListsRecommendationService.new(mentee)
    assert_equal [], pbmls.get_ordered_lists
    pq = ProfileQuestion.first
    qc = QuestionChoice.first

    pbml1 = PreferenceBasedMentorList.new(ref_obj: qc, weight: 0.5, profile_question: pq)
    pbml2 = PreferenceBasedMentorList.new(ref_obj: qc, weight: 0.2, profile_question: pq)
    pbml3 = PreferenceBasedMentorList.new(ref_obj: qc, weight: 0.9, profile_question: pq)
    pbmls.mentor_lists = [pbml1, pbml2, pbml3]
    assert_equal [pbml3, pbml1, pbml2], pbmls.get_ordered_lists

    pbml4 = PreferenceBasedMentorList.new(ref_obj: qc, weight: 0.1, profile_question: pq)
    pbmls.mentor_lists = pbmls.mentor_lists + [pbml4]*100
    assert_equal [pbml3, pbml1, pbml2] + [pbml4]*7, pbmls.get_ordered_lists    
  end

  def test_build_mentor_lists
    mentee = User.first
    pbmls = PreferenceBasedMentorListsRecommendationService.new(mentee)

    pbmls.mentor_lists = ['something']
    PreferenceBasedMentorList.stubs(:select_mentor_lists_meeting_criteria).with(['something'], mentee.program.mentor_users.active.pluck(:member_id)).returns(['something else'])

    mentee.stubs(:explicit_preferences_configured?).returns(true)
    pbmls.stubs(:set_mentor_lists_from_explicit_preferences).once
    pbmls.stubs(:set_mentor_lists_from_match_configs).never
    pbmls.stubs(:is_ignored?).with('something else').returns(false)
    pbmls.send(:build_mentor_lists)
    assert_equal ['something else'], pbmls.mentor_lists

    PreferenceBasedMentorList.stubs(:select_mentor_lists_meeting_criteria).with(['something else'], mentee.program.mentor_users.active.pluck(:member_id)).returns(['nothing else'])
    mentee.stubs(:explicit_preferences_configured?).returns(false)
    pbmls.stubs(:set_mentor_lists_from_explicit_preferences).never
    pbmls.stubs(:set_mentor_lists_from_match_configs).once
    pbmls.stubs(:is_ignored?).with('nothing else').returns(true)
    pbmls.send(:build_mentor_lists)
    assert_equal [], pbmls.mentor_lists
  end

  def test_set_mentor_lists_from_explicit_preferences
    mentee = users(:arun_albers)
    assert_equal 3, mentee.explicit_user_preferences.count
    pbmls = PreferenceBasedMentorListsRecommendationService.new(mentee)
    pbmls.stubs(:add_location_to_mentor_lists).never
    pbmls.stubs(:add_question_choices_to_mentor_lists).times(3)
    pbmls.send(:set_mentor_lists_from_explicit_preferences)

    mentee = users(:drafted_group_user)
    assert_equal 1, mentee.explicit_user_preferences.count
    pbmls = PreferenceBasedMentorListsRecommendationService.new(mentee)
    pbmls.stubs(:add_location_to_mentor_lists).once
    pbmls.stubs(:add_question_choices_to_mentor_lists).never
    pbmls.send(:set_mentor_lists_from_explicit_preferences)
  end

  def test_set_mentor_lists_from_match_configs
    mentee = User.first
    program = mentee.program
    pbmls = PreferenceBasedMentorListsRecommendationService.new(mentee)

    prof_q = create_profile_question(question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "single choice same question", question_choices: ["Choice 1", "Choice 2"], organization: programs(:org_primary))
    prog_mentor_question = create_role_question(program: program, role_names: [RoleConstants::MENTOR_NAME], profile_question: prof_q)
    prog_student_question = create_role_question(program: program, role_names: [RoleConstants::STUDENT_NAME], profile_question: prof_q)
    mc = MatchConfig.create!(program: program, mentor_question: prog_mentor_question, student_question: prog_student_question, weight: 0.2)

    prof_q2 = create_profile_question(question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "single choice same question2", question_choices: ["Choice 1", "Choice 2"], organization: programs(:org_primary))
    prog_mentor_question2 = create_role_question(program: program, role_names: [RoleConstants::MENTOR_NAME], profile_question: prof_q2)
    prog_student_question2 = create_role_question(program: program, role_names: [RoleConstants::STUDENT_NAME], profile_question: prof_q2)
    mc2 = MatchConfig.create!(program: program, mentor_question: prog_mentor_question2, student_question: prog_student_question2, weight: 0.4)

    MatchConfig.stubs(:get_match_configs_of_filterable_mentor_questions_for_mentee).with(mentee, program).returns([mc, mc2])
    mc.stubs(:get_mentor_location_or_questions_choices_for).with(mentee).returns('location')
    mc2.stubs(:get_mentor_location_or_questions_choices_for).with(mentee).returns(['question choices'])

    pbmls.stubs(:add_location_to_mentor_lists).once
    pbmls.stubs(:add_question_choices_to_mentor_lists).once
    pbmls.send(:set_mentor_lists_from_match_configs)
  end

  def test_add_location_to_mentor_lists
    mentee = User.first
    program = mentee.program
    pbmls = PreferenceBasedMentorListsRecommendationService.new(mentee)
    pbmls.mentor_lists = []
    pq = ProfileQuestion.first
    Location.stubs(:find_first_reliable_location_with).with(nil, 's', 'C').returns(nil)
    pbmls.send(:add_location_to_mentor_lists, 's,C', 0.3, pq)
    assert_equal [], pbmls.mentor_lists

    location = Location.first
    Location.stubs(:find_first_reliable_location_with).with('c', 's', 'C').returns(location)
    PreferenceBasedMentorList.stubs(:new).with(ref_obj: location, weight: 0.2, profile_question: pq).returns('something')
    pbmls.send(:add_location_to_mentor_lists, 'c,s,C', 0.2, pq)
    assert_equal ['something'], pbmls.mentor_lists
  end

  def test_add_question_choices_to_mentor_lists
    mentee = User.first
    program = mentee.program
    pbmls = PreferenceBasedMentorListsRecommendationService.new(mentee)
    pbmls.mentor_lists = []
    pq = ProfileQuestion.first
    qc1 = QuestionChoice.first
    qc2 = QuestionChoice.last

    PreferenceBasedMentorList.stubs(:new).with(ref_obj: qc1, weight: 0.1, profile_question: pq).returns('something1')
    PreferenceBasedMentorList.stubs(:new).with(ref_obj: qc2, weight: 0.1, profile_question: pq).returns('something2')
    pbmls.send(:add_question_choices_to_mentor_lists, [qc1, qc2], 0.1, pq)
    assert_equal ['something1', 'something2'], pbmls.mentor_lists
  end

  def test_is_ignored
    mentee = User.first
    pbmls = PreferenceBasedMentorListsRecommendationService.new(mentee)
    pq1 = ProfileQuestion.first
    pq2 = ProfileQuestion.last
    qc1 = QuestionChoice.first
    qc2 = QuestionChoice.last
    l1 = locations(:chennai)
    l2 = l1.dup
    l2.stubs(:full_city).returns('something else')
    mentor_list = mentee.preference_based_mentor_lists.new(profile_question: pq1, ref_obj: qc1)
    pbmls.stubs(:ignored_mentor_lists).returns([])
    assert_false pbmls.send(:is_ignored?, mentor_list)

    pbmls.stubs(:ignored_mentor_lists).returns([mentee.preference_based_mentor_lists.new(profile_question: pq1, ref_obj: qc1)])
    assert pbmls.send(:is_ignored?, mentor_list)

    pbmls.stubs(:ignored_mentor_lists).returns([mentee.preference_based_mentor_lists.new(profile_question: pq2, ref_obj: qc1)])
    assert_false pbmls.send(:is_ignored?, mentor_list)

    pbmls.stubs(:ignored_mentor_lists).returns([mentee.preference_based_mentor_lists.new(profile_question: pq1, ref_obj: qc2)])
    assert_false pbmls.send(:is_ignored?, mentor_list)

    pbmls.stubs(:ignored_mentor_lists).returns([mentee.preference_based_mentor_lists.new(profile_question: pq2, ref_obj: qc2)])
    assert_false pbmls.send(:is_ignored?, mentor_list)

    pbmls.stubs(:ignored_mentor_lists).returns([mentee.preference_based_mentor_lists.new(profile_question: pq1, ref_obj: l1)])
    mentor_list = mentee.preference_based_mentor_lists.new(profile_question: pq1, ref_obj: l2)
    assert_false pbmls.send(:is_ignored?, mentor_list)
    l2.stubs(:full_city).returns(l1.full_city)
    assert pbmls.send(:is_ignored?, mentor_list)
  end
end

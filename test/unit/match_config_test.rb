require_relative './../test_helper.rb'

class MatchConfigTest < ActiveSupport::TestCase
  def setup
    super
    @program = programs(:albers)
    prof_q = create_profile_question(organization: programs(:org_primary))
    @mentor_question = create_role_question(program: @program, role_names: [RoleConstants::MENTOR_NAME], profile_question: prof_q)
    @student_question = create_role_question(program: @program, role_names: [RoleConstants::STUDENT_NAME], profile_question: prof_q)
  end

  # ----------------------------------------------------------------------------
  # RELATIONSHIPS
  # ----------------------------------------------------------------------------

  def test_belongs_to_relationships
    MatchConfig.destroy_all
    assert_nothing_raised do
      assert_difference 'MatchConfig.count' do
        @matchable_pair = MatchConfig.create!(
          program: @program,
          mentor_question: @mentor_question,
          student_question: @student_question)
      end
    end

    assert_equal @program, @matchable_pair.program
    assert_equal @mentor_question, @matchable_pair.mentor_question
    assert_equal @student_question, @matchable_pair.student_question
  end

  def test_student_profile_question
    mc = MatchConfig.create!(program: @program, mentor_question: @mentor_question, student_question: @student_question)
    assert_equal @student_question.profile_question, mc.student_profile_question
  end

  def test_mentor_profile_question
    mc = MatchConfig.create!(program: @program, mentor_question: @mentor_question, student_question: @student_question)
    assert_equal @mentor_question.profile_question, mc.mentor_profile_question
  end

  # ----------------------------------------------------------------------------
  # CONTENT
  # ----------------------------------------------------------------------------

  def test_default_weight
    MatchConfig.destroy_all
    assert_difference 'MatchConfig.count' do
      @matchable_pair = MatchConfig.create!(
        program: @program,
        mentor_question: @mentor_question,
        student_question: @student_question)
    end

    assert_equal Matching::Configuration::DEFAULT_WEIGHT,
        @matchable_pair.weight
  end

  # ----------------------------------------------------------------------------
  # VALIDATIONS
  # ----------------------------------------------------------------------------

  def test_fields_and_program_are_required
    m = MatchConfig.new
    assert !m.valid?

    assert_equal ["can't be blank"], m.errors[:program]
  end

  def test_no_duplicate_pairs
    prof_q = create_profile_question(organization: programs(:org_primary))
    prog_mentor_question = role_questions(:string_role_q)
    prog_student_question = create_role_question(profile_question: prof_q, role_names: [RoleConstants::STUDENT_NAME])

    assert_difference 'MatchConfig.count' do
      MatchConfig.create!(
        program: programs(:albers),
        mentor_question: prog_mentor_question,
        student_question: prog_student_question)
    end

    m = MatchConfig.new(
      program: programs(:albers),
      mentor_question: prog_mentor_question,
      student_question: prog_student_question)

    assert_false m.valid?
    assert_equal ["is already being matched with another field"], m.errors[:student_question_id]

    prog_mentor_question.role = programs(:nwen).roles.with_name([RoleConstants::MENTOR_NAME])[0]
    prog_mentor_question.save!
    prog_student_question.role = programs(:nwen).roles.with_name([RoleConstants::STUDENT_NAME])[0]
    prog_student_question.save!
    m.program = programs(:nwen)
    assert m.valid?
  end

  def test_fields_belong_to_the_same_organization_and_program
    prof_q = create_profile_question(organization: programs(:org_primary))
    org_student_question = create_role_question(profile_question: prof_q, role_names: [RoleConstants::STUDENT_NAME])

    m = MatchConfig.new
    m.program = programs(:albers)
    m.student_question = @student_question
    m.mentor_question = role_questions(:string_role_q)
    assert m.valid?

    m.student_question = org_student_question
    m.mentor_question = role_questions(:string_role_q)
    assert m.valid?

    m.student_question = org_student_question
    m.mentor_question = role_questions(:string_role_q)
    assert m.valid?
  end

  def test_match_config_scope
    p = programs(:ceg)
    assert_equal(0, p.match_configs.size)
  end

  def test_question_should_be_of_matchable_type
    stud_prof_q = create_profile_question(organization: programs(:org_primary), question_type: CommonQuestion::Type::RATING_SCALE,
      question_choices: ["1","2","3"])
    prof_q = create_profile_question(organization: programs(:org_primary))
    student_q = create_role_question(profile_question: stud_prof_q,
      role_names: [RoleConstants::STUDENT_NAME]
    )

    mentor_q = create_role_question(profile_question: prof_q,
      role_names: [RoleConstants::MENTOR_NAME]
    )

    assert_false student_q.matchable_type?
    assert mentor_q.matchable_type?

    m = MatchConfig.new(
      student_question: student_q,
      mentor_question: mentor_q
    )

    assert_false m.valid?
    assert_equal ["is of a type that cannot be used for matching"], m.errors[:student_question]

    assert m.errors[:mentor_question].blank?

    prof_q.question_type = CommonQuestion::Type::RATING_SCALE
    prof_q.save!
    ["1","2","3"].each_with_index{|text, pos| prof_q.question_choices.create!(text: text, position: pos+1, ref_obj: prof_q)}
    assert_false mentor_q.reload.matchable_type?

    assert_false m.valid?
    assert_equal ["is of a type that cannot be used for matching"], m.errors[:student_question]
    assert_equal ["is of a type that cannot be used for matching"], m.errors[:mentor_question]
  end

  def test_operators
    assert_equal ['gt', 'lt'], MatchConfig::Operator.all
  end

  def test_operator_validation
    prof_q = create_profile_question(organization: programs(:org_primary))
    prog_mentor_question = role_questions(:string_role_q)
    prog_student_question = create_role_question(profile_question: prof_q, role_names: [RoleConstants::STUDENT_NAME])

    m = MatchConfig.new(program: programs(:albers), mentor_question: prog_mentor_question, student_question: prog_student_question, operator: nil)

    assert_false m.valid?
    assert_false m.errors[:operator].empty?
    assert m.errors[:operator].include?("can't be blank")

    m = MatchConfig.new(program: programs(:albers), mentor_question: prog_mentor_question, student_question: prog_student_question, operator: 'gte')

    assert_false m.valid? 
    assert_false m.errors[:operator].empty?
    assert m.errors[:operator].include?('is not included in the list')
  end

  def test_with_label
    prof_q = create_profile_question(question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "Choice Field1", question_choices: ["Choice 1", "Choice 2"], organization: programs(:org_primary))
    prog_mentor_question = create_role_question(program: @program, role_names: [RoleConstants::MENTOR_NAME], profile_question: prof_q)
    prog_student_question = create_role_question(program: @program, role_names: [RoleConstants::STUDENT_NAME], profile_question: prof_q)
    config = MatchConfig.create!(
        program: programs(:albers),
        mentor_question: prog_mentor_question,
        student_question: prog_student_question)
    assert_equal [], MatchConfig.with_label
    config.update_attribute(:show_match_label, true)
    assert_equal [config.reload], MatchConfig.with_label
  end

  def test_reset_match_label
    prof_q = create_profile_question(question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "Choice Field1", question_choices: ["Choice 1", "Choice 2"], organization: programs(:org_primary))
    prog_mentor_question = create_role_question(program: @program, role_names: [RoleConstants::MENTOR_NAME], profile_question: prof_q)
    prog_student_question = create_role_question(program: @program, role_names: [RoleConstants::STUDENT_NAME], profile_question: prof_q)
    config = MatchConfig.create!(
        program: programs(:albers),
        mentor_question: prog_mentor_question,
        student_question: prog_student_question,
        show_match_label: true,
        prefix: "abc")

    assert_equal "abc", config.prefix
    assert config.show_match_label

    config.mentor_question = @mentor_question
    config.save!

    assert_equal "", config.prefix
    assert_false config.show_match_label

    mentor_location_question = @program.role_questions_for([RoleConstants::MENTOR_NAME], fetch_all: true).role_profile_questions.joins(:profile_question).where("profile_questions.question_type IN (?)", [ProfileQuestion::Type::LOCATION]).first
    student_location_question = @program.role_questions_for([RoleConstants::STUDENT_NAME], fetch_all: true).role_profile_questions.joins(:profile_question).where("profile_questions.question_type IN (?)", [ProfileQuestion::Type::LOCATION]).first

    config = MatchConfig.create!(
        program: programs(:albers),
        mentor_question: mentor_location_question,
        student_question: student_location_question,
        show_match_label: true,
        prefix: "abc")


    assert_equal "abc", config.prefix
    assert config.show_match_label

    config.mentor_question = @mentor_question
    assert_raise ActiveRecord::RecordInvalid, "activerecord.custom_errors.answer.invalid_question_choice".translate do
      config.save!
    end

    assert_equal "abc", config.prefix
    assert config.show_match_label
  end

  def test_questions_choice_based
    prof_q = create_profile_question(question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "Choice Field1", question_choices: ["Choice 1", "Choice 2"], organization: programs(:org_primary))
    prog_mentor_question = create_role_question(program: @program, role_names: [RoleConstants::MENTOR_NAME], profile_question: prof_q)
    prog_student_question = create_role_question(program: @program, role_names: [RoleConstants::STUDENT_NAME], profile_question: prof_q)
    config = MatchConfig.create!(
        program: programs(:albers),
        mentor_question: prog_mentor_question,
        student_question: prog_student_question,
        show_match_label: true,
        prefix: "abc")

    config.mentor_question.profile_question.stubs(:with_question_choices?).returns(true)
    config.student_question.profile_question.stubs(:with_question_choices?).returns(true)
    assert config.questions_choice_based?

    config.mentor_question.profile_question.stubs(:with_question_choices?).returns(true)
    config.student_question.profile_question.stubs(:with_question_choices?).returns(false)
    assert_false config.questions_choice_based?

    config.mentor_question.profile_question.stubs(:with_question_choices?).returns(true)
    config.student_question.profile_question.stubs(:with_question_choices?).returns(false)
    assert_false config.questions_choice_based?

    config.mentor_question.profile_question.stubs(:with_question_choices?).returns(false)
    config.student_question.profile_question.stubs(:with_question_choices?).returns(false)
    assert_false config.questions_choice_based?
  end

  def test_match_config_discrepancy_caches_association
    prof_q = create_profile_question(question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "Choice Field1", question_choices: ["Choice 1", "Choice 2"], organization: programs(:org_primary))
    prog_mentor_question = create_role_question(program: @program, role_names: [RoleConstants::MENTOR_NAME], profile_question: prof_q)
    prog_student_question = create_role_question(program: @program, role_names: [RoleConstants::STUDENT_NAME], profile_question: prof_q)
    config = MatchConfig.create!(
        program: programs(:albers),
        mentor_question: prog_mentor_question,
        student_question: prog_student_question,
        show_match_label: true,
        prefix: "abc")

    match_config_discrepancy_cache = MatchConfigDiscrepancyCache.find_by(match_config_id: config.id)
    assert_equal match_config_discrepancy_cache, config.reload.match_config_discrepancy_cache
    assert_difference "MatchConfigDiscrepancyCache.count", -1 do
      config.destroy
    end
  end

  def test_refresh_match_config_discrepancy_cache
    program = programs(:albers)
    prof_q = create_profile_question(question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "Choice Field1", question_choices: ["Choice 1", "Choice 2"], organization: programs(:org_primary))
    prog_mentor_question = create_role_question(program: @program, role_names: [RoleConstants::MENTOR_NAME], profile_question: prof_q)
    prog_student_question = create_role_question(program: @program, role_names: [RoleConstants::STUDENT_NAME], profile_question: prof_q)
    config = MatchConfig.create!(
        program: program,
        mentor_question: prog_mentor_question,
        student_question: prog_student_question,
        show_match_label: true,
        prefix: "abc")

    MatchReport::Sections::SectionClasses[MatchReport::Sections::MentorDistribution].constantize.any_instance.stubs(:calculate_data_discrepancy).returns([{"discrepancy"=>4, "student_need_count"=>8, "mentor_offer_count"=>4, "student_answer_choice"=>"20+ years"}, {"discrepancy"=>2, "student_need_count"=>6, "mentor_offer_count"=>4, "student_answer_choice"=>"6-10 years"}])

    assert_no_difference "MatchConfigDiscrepancyCache.count" do
      config.refresh_match_config_discrepancy_cache
    end
    match_config_discrepancy_cache = config.reload.match_config_discrepancy_cache
    assert_equal [{"discrepancy"=>4, "student_need_count"=>8, "mentor_offer_count"=>4, "student_answer_choice"=>"20+ years"}, {"discrepancy"=>2, "student_need_count"=>6, "mentor_offer_count"=>4, "student_answer_choice"=>"6-10 years"}], match_config_discrepancy_cache.top_discrepancy

    config.match_config_discrepancy_cache.destroy!

    MatchReport::Sections::SectionClasses[MatchReport::Sections::MentorDistribution].constantize.any_instance.stubs(:calculate_data_discrepancy).returns([{"discrepancy"=>4, "student_need_count"=>8, "mentor_offer_count"=>4, "student_answer_choice"=>"30+ years"}, {"discrepancy"=>3, "student_need_count"=>6, "mentor_offer_count"=>4, "student_answer_choice"=>"10-16 years"}])
    assert_difference "MatchConfigDiscrepancyCache.count", 1 do
      config.refresh_match_config_discrepancy_cache
    end
    
    match_config_discrepancy_cache = config.reload.match_config_discrepancy_cache
    assert_equal [{"discrepancy"=>4, "student_need_count"=>8, "mentor_offer_count"=>4, "student_answer_choice"=>"30+ years"}, {"discrepancy"=>3, "student_need_count"=>6, "mentor_offer_count"=>4, "student_answer_choice"=>"10-16 years"}], match_config_discrepancy_cache.top_discrepancy
  end

  def test_can_create_match_config_discrepancy_cache
    prof_q = create_profile_question(question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "Choice Field1", question_choices: ["Choice 1", "Choice 2"], organization: programs(:org_primary))
    prog_mentor_question = create_role_question(program: @program, role_names: [RoleConstants::MENTOR_NAME], profile_question: prof_q)
    prog_student_question = create_role_question(program: @program, role_names: [RoleConstants::STUDENT_NAME], profile_question: prof_q)
    config = MatchConfig.create!(
        program: programs(:albers),
        mentor_question: prog_mentor_question,
        student_question: prog_student_question,
        show_match_label: true,
        prefix: "abc")

    config.stubs(:questions_choice_based?).returns(false)
    assert_false config.can_create_match_config_discrepancy_cache?

    Program.any_instance.stubs(:can_have_match_report?).returns(true)
    assert_false config.can_create_match_config_discrepancy_cache?

    config.stubs(:questions_choice_based?).returns(true)
    assert config.can_create_match_config_discrepancy_cache?

    Program.any_instance.stubs(:can_have_match_report?).returns(false)
    assert_false config.can_create_match_config_discrepancy_cache?

    MatchConfigDiscrepancyCache.create!(match_config: config)
    assert_false config.can_create_match_config_discrepancy_cache?

    config.stubs(:questions_choice_based?).returns(false)
    assert_false config.can_create_match_config_discrepancy_cache?

    Program.any_instance.stubs(:can_have_match_report?).returns(false)
    assert_false config.can_create_match_config_discrepancy_cache?
  end

  def test_update_match_config_discrepancy_cache
    program = programs(:albers)
    prof_q = create_profile_question(question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "Choice Field1", question_choices: ["Choice 1", "Choice 2"], organization: programs(:org_primary))
    prog_student_question = create_role_question(program: program, role_names: [RoleConstants::STUDENT_NAME], profile_question: prof_q)
    match_config = program.match_configs.create(
        mentor_question: role_questions(:single_choice_role_q),
        student_question: prog_student_question,
        show_match_label: true,
        prefix: "abc")

    match_config.stubs(:can_create_match_config_discrepancy_cache?).returns(false)
    assert_false match_config.update_match_config_discrepancy_cache?

    match_config.stubs(:saved_change_to_mentor_question_id?).returns(false)
    assert_false match_config.update_match_config_discrepancy_cache?

    match_config.stubs(:saved_change_to_student_question_id?).returns(false)
    assert_false match_config.update_match_config_discrepancy_cache?

    match_config.stubs(:saved_change_to_matching_details_for_display?).returns(false)
    assert_false match_config.update_match_config_discrepancy_cache?

    match_config.stubs(:can_create_match_config_discrepancy_cache?).returns(true)
    assert_false match_config.update_match_config_discrepancy_cache?

    match_config.stubs(:saved_change_to_matching_details_for_display?).returns(true)
    assert match_config.update_match_config_discrepancy_cache?

    match_config.stubs(:saved_change_to_mentor_question_id?).returns(true)
    assert match_config.update_match_config_discrepancy_cache?

    match_config.stubs(:saved_change_to_student_question_id?).returns(true)
    assert match_config.update_match_config_discrepancy_cache?
  end

  def test_get_mentor_location_or_questions_choices_for
    program = programs(:nwen)
    mentee = users(:f_mentor_nwen_student)

    prof_q = create_profile_question(question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "single choice same question", question_choices: ["Choice 1", "Choice 2"], organization: programs(:org_primary))
    prog_mentor_question = create_role_question(program: program, role_names: [RoleConstants::MENTOR_NAME], profile_question: prof_q)
    prog_student_question = create_role_question(program: program, role_names: [RoleConstants::STUDENT_NAME], profile_question: prof_q)
    ProfileAnswer.create!(:ref_obj => mentee.member, :profile_question => prof_q, :answer_value => "Choice 1")
    mc = MatchConfig.create!(program: program, mentor_question: prog_mentor_question, student_question: prog_student_question)

    prof_q.stubs(:location?).returns(true)
    mc.stubs(:mentor_profile_question).returns(prof_q)
    ProfileAnswer.any_instance.stubs(:location).returns(nil)
    assert_nil mc.get_mentor_location_or_questions_choices_for(mentee)

    location = Location.first
    location.stubs(:reliable?).returns(false)
    ProfileAnswer.any_instance.stubs(:location).returns(location)
    assert_nil mc.get_mentor_location_or_questions_choices_for(mentee)

    location.stubs(:reliable?).returns(true)
    assert_equal location.full_city, mc.get_mentor_location_or_questions_choices_for(mentee)

    prof_q.stubs(:location?).returns(false)
    mc.stubs(:student_profile_question).returns(prof_q)
    prof_q.stubs(:get_answered_question_choices_for_user).returns("choices")
    mc.stubs(:get_mentor_question_choices_matching_with).with("choices").returns("something")
    assert_equal "something", mc.get_mentor_location_or_questions_choices_for(mentee)    
  end

  def test_get_mentor_question_choices_matching_with
    program = programs(:nwen)
    prof_q = create_profile_question(question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "single choice same question", question_choices: ["Choice 1", "Choice 2", "Choice 3", "Choice 4"], organization: programs(:org_primary))
    qcs = prof_q.question_choices
    prog_mentor_question = create_role_question(program: program, role_names: [RoleConstants::MENTOR_NAME], profile_question: prof_q)
    prog_student_question = create_role_question(program: program, role_names: [RoleConstants::STUDENT_NAME], profile_question: prof_q)
    mc = MatchConfig.create!(program: program, mentor_question: prog_mentor_question, student_question: prog_student_question)

    mc.stubs(:matching_type).returns(MatchConfig::MatchingType::DEFAULT)
    assert_equal [qcs[0], qcs[2]].collect(&:id), mc.get_mentor_question_choices_matching_with([qcs[0], qcs[2]]).collect(&:id)

    mc.stubs(:matching_type).returns(MatchConfig::MatchingType::SET_MATCHING)
    mc.stubs(:matching_details_for_matching).returns({"choice 1" => ["choice 1"], "choice 2" => ["choice 2", "choice 3"], "choice 3" => ["choice 4"], "choice 4" => []})
    assert_equal [qcs[0], qcs[3]].collect(&:id), mc.get_mentor_question_choices_matching_with([qcs[0], qcs[2]]).collect(&:id)
    assert_equal [qcs[1], qcs[2]].collect(&:id), mc.get_mentor_question_choices_matching_with([qcs[1], qcs[3]]).collect(&:id)
  end

  def test_get_match_configs_of_filterable_mentor_questions_for_mentee
    program = programs(:nwen)
    mentee = users(:f_mentor_nwen_student)

    prof_q = create_profile_question(question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "single choice same question", question_choices: ["Choice 1", "Choice 2"], organization: programs(:org_primary))
    prog_mentor_question = create_role_question(program: program, role_names: [RoleConstants::MENTOR_NAME], profile_question: prof_q)
    prog_student_question = create_role_question(program: program, role_names: [RoleConstants::STUDENT_NAME], profile_question: prof_q)
    mc = MatchConfig.create!(program: program, mentor_question: prog_mentor_question, student_question: prog_student_question)
    assert MatchConfig.get_match_configs_of_filterable_mentor_questions_for_mentee(mentee, program).empty?

    ProfileAnswer.create!(:ref_obj => mentee.member, :profile_question => prof_q, :answer_value => "Choice 1")
    assert_equal [mc.id], MatchConfig.get_match_configs_of_filterable_mentor_questions_for_mentee(mentee, program).all.collect(&:id)

    program.stubs(:get_valid_role_questions_for_explicit_preferences).returns(RoleQuestion.where(id: 0))
    assert MatchConfig.get_match_configs_of_filterable_mentor_questions_for_mentee(mentee, program).empty?
  end

end

require_relative './../../../test_helper'

class MentorDistributionTest < ActiveSupport::TestCase

  def test_fetch_default_mentor_view
    program = programs(:albers)
    assert_equal AbstractView::DefaultType::AVAILABLE_MENTORS, MatchReport::MentorDistribution.fetch_default_mentor_view(program)

    program.stubs(:only_one_time_mentoring_enabled?).returns(true)
    assert_equal AbstractView::DefaultType::MENTORS, MatchReport::MentorDistribution.fetch_default_mentor_view(program)
  end

  def test_fetch_default_mentee_view
    program = programs(:albers)
    program.stubs(:only_one_time_mentoring_enabled?).returns(true)
    assert_equal AbstractView::DefaultType::NEVER_CONNECTED_MENTEES, MatchReport::MentorDistribution.fetch_default_mentee_view(program)

    program.stubs(:only_one_time_mentoring_enabled?).returns(false)
    assert_equal AbstractView::DefaultType::CURRENTLY_NOT_CONNECTED_MENTEES, MatchReport::MentorDistribution.fetch_default_mentee_view(program)
  end

  def test_get_answer_text_hash
    answer_texts_array = ["opt_1", "opt_3", "opt_1", "opt_3", "opt_2", "opt_3", "opt_2", "opt_3"]
    assert_equal_hash({"opt_1" => 2, "opt_3" => 4, "opt_2" => 2}, MatchReport::MentorDistribution.get_answer_text_hash(answer_texts_array))

    assert_equal_hash({}, MatchReport::MentorDistribution.get_answer_text_hash({}))
  end

  def test_get_user_answer_texts
    program = programs(:albers)
    assert_equal ["opt_1", "opt_3"], MatchReport::MentorDistribution.new(program).get_user_answer_texts(program.users.pluck(:id), profile_questions(:single_choice_q))

    assert_equal ["Stand", "Run", "Walk"], MatchReport::MentorDistribution.new(program).get_user_answer_texts(program.users.pluck(:id), profile_questions(:multi_choice_q))
  end

  def test_get_filtered_answer_texts
    program = programs(:albers)

    assert_equal [["opt_1"], {"opt_1"=>"opt_1", "opt_2" => "opt_2", "opt_3" => "opt_3"}], MatchReport::MentorDistribution.new(program).get_filtered_answer_texts(program.users.pluck(:id), profile_questions(:single_choice_q), ["opt_1"])

    assert_equal [[], {"opt_1"=>"opt_1", "opt_2" => "opt_2", "opt_3" => "opt_3"}], MatchReport::MentorDistribution.new(program).get_filtered_answer_texts(program.users.pluck(:id), profile_questions(:single_choice_q), ["opt_2"])
  end

  def test_get_match_report_admin_view_user_ids
    program = programs(:albers)
    assert_equal program.admin_views.where(default_view: AbstractView::DefaultType::CURRENTLY_NOT_CONNECTED_MENTEES, program_id: program.id).first.get_user_ids_for_match_report, MatchReport::MentorDistribution.new(program).get_match_report_admin_view_user_ids(RoleConstants::STUDENT_NAME)


    assert_equal program.admin_views.where(default_view: AbstractView::DefaultType::AVAILABLE_MENTORS, program_id: program.id).first.get_user_ids_for_match_report, MatchReport::MentorDistribution.new(program).get_match_report_admin_view_user_ids(RoleConstants::MENTOR_NAME)
  end

  def test_get_needs_offers_discrepancy_for_default_type
    program = programs(:albers)
    answer_texts = ["opt_1", "opt_2", "opt_3"]
    student_answer_text_hash = {"opt_1" => 2, "opt_3" => 4, "opt_2" => 2}
    mentor_answer_text_hash = {"opt_1" => 1, "opt_3" => 2, "opt_2" => 2}
    match_config = program.match_configs.create(
      student_question: role_questions(:role_questions_1),
      mentor_question: role_questions(:role_questions_1),
      operator: MatchConfig::Operator::lt,
      threshold: 0.1,
      :matching_type => MatchConfig::MatchingType::DEFAULT
    )
    assert_equal [{discrepancy: 2, student_need_count: 4, mentor_offer_count: 2, student_answer_choice: "opt_3", match_config_id: match_config.id}, {discrepancy: 1, student_need_count: 2, mentor_offer_count: 1, student_answer_choice: "opt_1", match_config_id: match_config.id}, {discrepancy: 0, student_need_count: 2, mentor_offer_count: 2, student_answer_choice: "opt_2", match_config_id: match_config.id}], MatchReport::MentorDistribution.new(program, {match_config: match_config}).get_needs_offers_discrepancy_for_default_type(answer_texts, mentor_answer_text_hash, student_answer_text_hash)

    student_answer_text_hash = {"opt_1" => 2, "opt_3" => 4, "opt_2" => 2}
    mentor_answer_text_hash = {"opt_1" => 1, "opt_3" => 2}
    assert_equal [{discrepancy: 2, student_need_count: 4, mentor_offer_count: 2, student_answer_choice: "opt_3", match_config_id: match_config.id}, {discrepancy: 2, student_need_count: 2, mentor_offer_count: 0, student_answer_choice: "opt_2", match_config_id: match_config.id}, {discrepancy: 1, student_need_count: 2, mentor_offer_count: 1, student_answer_choice: "opt_1", match_config_id: match_config.id}], MatchReport::MentorDistribution.new(program, {match_config: match_config}).get_needs_offers_discrepancy_for_default_type(answer_texts, mentor_answer_text_hash, student_answer_text_hash)

    student_answer_text_hash = {"opt_1" => 2, "opt_3" => 4}
    mentor_answer_text_hash = {"opt_1" => 1, "opt_3" => 2, "opt_2" => 2}
    assert_equal [{discrepancy: 2, student_need_count: 4, mentor_offer_count: 2, student_answer_choice: "opt_3", match_config_id: match_config.id}, {discrepancy: 1, student_need_count: 2, mentor_offer_count: 1, student_answer_choice: "opt_1", match_config_id: match_config.id}, {discrepancy: -2, student_need_count: 0, mentor_offer_count: 2, student_answer_choice: "opt_2", match_config_id: match_config.id}], MatchReport::MentorDistribution.new(program, {match_config: match_config}).get_needs_offers_discrepancy_for_default_type(answer_texts, mentor_answer_text_hash, student_answer_text_hash)
  end

  def test_get_needs_offers_discrepancy_for_set_type
    program = programs(:albers)
    student_answer_text_hash = {"e" => 5, "b" => 4, "c" => 2}
    mentor_answer_text_hash = {"e" => 1, "b" => 1, "c" => 1}
    answer_texts = ["e", "b", "c"]
    match_config = program.match_configs.create(
      student_question: role_questions(:role_questions_1),
      mentor_question: role_questions(:role_questions_1),
      operator: MatchConfig::Operator::lt,
      threshold: 0.1,
      :matching_type => MatchConfig::MatchingType::DEFAULT
    )
    md = MatchReport::MentorDistribution.new(program, {match_config: match_config})
    md.instance_variable_set(:@student_answers_downcase_hash, {"e" => "E", "b" => "B", "c" => "C"})

    discrepancy_data = [{:student_answer_choice=>"E", discrepancy: 3, student_need_count: 5, mentor_answer_choices: {"b" => 1, "c" => 1}, mentor_offer_count: 2, match_config_id: match_config.id}, {student_answer_choice: "B", discrepancy: 2, student_need_count: 4, mentor_answer_choices: {"e" => 1, "c" => 1}, mentor_offer_count: 2, match_config_id: match_config.id}]

    assert_equal discrepancy_data, md.get_needs_offers_discrepancy_for_set_type(answer_texts, mentor_answer_text_hash, student_answer_text_hash, {matching_details: {"e"=>["b", "c"], "b" => ["e", "c"]}})

    mentor_answer_text_hash = {"e" => 1, "b" => 1}
    discrepancy_data = [{:student_answer_choice=>"E", discrepancy: 4, student_need_count: 5, mentor_answer_choices: {"b" => 1, "c"=>0}, mentor_offer_count: 1, match_config_id: match_config.id}, {student_answer_choice: "B", discrepancy: 3, student_need_count: 4, mentor_answer_choices: {"e" => 1, "c"=>0}, mentor_offer_count: 1, match_config_id: match_config.id}]

    assert_equal discrepancy_data, md.get_needs_offers_discrepancy_for_set_type(answer_texts, mentor_answer_text_hash, student_answer_text_hash, {matching_details: {"e"=>["b", "c"], "b" => ["e", "c"]}})
  end

  def test_get_mentor_choice_hash
    program = programs(:albers)
    mentor_answer_text_hash = {"e" => 1, "b" => 1, "c" => 1}
    mentor_choices = ["e", "b"]
    assert_equal [{"e" => 1, "b" => 1}, 2], MatchReport::MentorDistribution.new(program).get_mentor_choice_hash(mentor_answer_text_hash, mentor_choices)

    mentor_answer_text_hash = {"b" => 1, "c" => 1}
    assert_equal [{"e" => 0, "b" => 1}, 1], MatchReport::MentorDistribution.new(program).get_mentor_choice_hash(mentor_answer_text_hash, mentor_choices)
  end

  def test_get_series_data_for_default_type
    program = programs(:albers)
    match_config = program.match_configs.create(
      student_question: role_questions(:role_questions_1),
      mentor_question: role_questions(:role_questions_1),
      operator: MatchConfig::Operator::lt,
      threshold: 0.1,
      :matching_type => MatchConfig::MatchingType::DEFAULT
    )
    discrepancy_data = [{student_answer_choice: "Male", discrepancy: 2, student_need_count: 4, mentor_offer_count: 9}, {student_answer_choice: "Female", discrepancy: 2, student_need_count: 4, mentor_offer_count: 6}]

    assert_equal [["Male", "Female"], [{name: "Students", data: [4, 0], stack: "Students", color:  MatchReport::MentorDistribution::MENTEE_COLOR}, {name: "Mentors", data: [9, 0], stack: "Mentors", color: MatchReport::MentorDistribution::MENTOR_COLOR}, {name: "Students", data: [0, 4], stack: "Students", color:  MatchReport::MentorDistribution::MENTEE_COLOR, showInLegend: false}, {name: "Mentors", data: [0, 6], stack: "Mentors", color: MatchReport::MentorDistribution::MENTOR_COLOR, showInLegend: false}], -3, 2], MatchReport::MentorDistribution.new(program, {match_config: match_config}).get_series_data(discrepancy_data)
  end

  def test_get_series_data_for_set_type
    program = programs(:albers)
    prof_q = create_question(:question_type => ProfileQuestion::Type::SINGLE_CHOICE, :question_text => "Pick one", :question_info => "opt_1, opt_2, opt_3")
    student_question = prof_q.role_questions.first
    mentor_question = prof_q.role_questions.new
    mentor_question.role = program.get_role(RoleConstants::MENTOR_NAME)
    mentor_question.save!

    matching_hash = {"opt_1" => [["opt_2", "opt_3"], ["opt_1"]], "opt_2" => [[]], "opt_3" => [["opt_1"]], "non_existing_choice4" => [["non_existing_choice2"]]}
    match_config = program.match_configs.create(
          :mentor_question_id => mentor_question.id.to_s,
          :student_question_id => student_question.id.to_s,
          :weight => "0.25",
          :matching_type => MatchConfig::MatchingType::SET_MATCHING, :matching_details_for_matching => matching_hash)
    md = MatchReport::MentorDistribution.new(program, {match_config: match_config})
    md.instance_variable_set(:@student_answers_downcase_hash, {"male" => "Male", "female" => "Female"})
    md.instance_variable_set(:@mentor_answers_downcase_hash, {"d" => "d", "e" => "e"})

    discrepancy_data = [{:student_answer_choice=>"Male", discrepancy: 2, student_need_count: 4, mentor_answer_choices: {"d" => 3, "e" => 4}}, {student_answer_choice: "Female", discrepancy: 2, student_need_count: 4, mentor_answer_choices: {"d" => 1, "e" => 5}}]

    assert_equal [["Male", "Female"], [{:name=>"Students", :data=>[4, 0], :stack=>"Students", :color=> MatchReport::MentorDistribution::MENTEE_COLOR}, {:name=>"d", :data=>[3, 0], :stack=>"Mentors", :color=>MatchReport::MentorDistribution::MENTOR_COLOR, :borderColor=>"#f3f3f4", :borderWidth=>1}, {:name=>"e", :data=>[4, 0], :stack=>"Mentors", :color=>MatchReport::MentorDistribution::MENTOR_COLOR, :borderColor=>"#f3f3f4", :borderWidth=>1, :showInLegend=>false}, {:name=>"Students", :data=>[0, 4], :stack=>"Students", :color=> MatchReport::MentorDistribution::MENTEE_COLOR, :showInLegend=>false}, {:name=>"d", :data=>[0, 1], :stack=>"Mentors", :color=>MatchReport::MentorDistribution::MENTOR_COLOR, :borderColor=>"#f3f3f4", :borderWidth=>1, :showInLegend=>false}, {:name=>"e", :data=>[0, 5], :stack=>"Mentors", :color=>MatchReport::MentorDistribution::MENTOR_COLOR, :borderColor=>"#f3f3f4", :borderWidth=>1, :showInLegend=>false}], -3, 2], md.get_series_data(discrepancy_data)
  end

  def test_get_mentee_discrepancy_hash
    program = programs(:albers)
    assert_equal_hash({
      name: "Students",
      data: 4,
      stack: "Students",
      color:  MatchReport::MentorDistribution::MENTEE_COLOR
    }, MatchReport::MentorDistribution.new(program).get_mentee_discrepancy_hash(4, true))

    assert_equal_hash({
      name: "Students",
      data: 4,
      stack: "Students",
      color:  MatchReport::MentorDistribution::MENTEE_COLOR, 
      showInLegend: false
    }, MatchReport::MentorDistribution.new(program).get_mentee_discrepancy_hash(4, false))
  end

  def test_calculate_data_discrepancy
    program = programs(:albers)

    match_config = program.match_configs.create(
      student_question: role_questions(:role_questions_1),
      mentor_question: role_questions(:role_questions_1),
      operator: MatchConfig::Operator::lt,
      threshold: 0.1,
      :matching_type => MatchConfig::MatchingType::DEFAULT
    )
    mentor_user_ids = [2,3,4,6]
    mentor_distibution = MatchReport::MentorDistribution.new(program, {match_config: match_config})
    mentor_distibution.stubs(:get_match_report_admin_view_user_ids).with(RoleConstants::MENTOR_NAME).returns(mentor_user_ids)
    student_user_ids = [1,8,9,3]
    mentor_distibution.stubs(:get_match_report_admin_view_user_ids).with(RoleConstants::STUDENT_NAME).returns(student_user_ids)
    mentor_distibution.expects(:get_data_discrepancy_for_default_type).with(mentor_user_ids, student_user_ids).once
    mentor_distibution.expects(:get_data_discrepancy_for_set_type).with(mentor_user_ids, student_user_ids).never
    mentor_distibution.calculate_data_discrepancy
  end

  def test_calculate_data_discrepancy_set_matching
    program = programs(:albers)

    prof_q = create_question(:question_type => ProfileQuestion::Type::SINGLE_CHOICE, :question_text => "Pick one", :question_info => "opt_1, opt_2, opt_3")
    student_question = prof_q.role_questions.first
    mentor_question = prof_q.role_questions.new
    mentor_question.role = program.get_role(RoleConstants::MENTOR_NAME)
    mentor_question.save!

    matching_hash = {"opt_1" => [["opt_2", "opt_3"], ["opt_1"]], "opt_2" => [[]], "opt_3" => [["opt_1"]], "non_existing_choice4" => [["non_existing_choice2"]]}
    match_config = program.match_configs.create(
          :mentor_question_id => mentor_question.id.to_s,
          :student_question_id => student_question.id.to_s,
          :weight => "0.25",
          :matching_type => MatchConfig::MatchingType::SET_MATCHING, :matching_details_for_matching => matching_hash)

    mentor_distibution = MatchReport::MentorDistribution.new(program, {match_config: match_config})

    mentor_user_ids = [2,3,4,6]
    mentor_distibution.stubs(:get_match_report_admin_view_user_ids).with(RoleConstants::MENTOR_NAME).returns(mentor_user_ids)
    student_user_ids = [1,8,9,3]
    mentor_distibution.stubs(:get_match_report_admin_view_user_ids).with(RoleConstants::STUDENT_NAME).returns(student_user_ids)
    mentor_distibution.expects(:get_data_discrepancy_for_default_type).with(mentor_user_ids, student_user_ids).never
    mentor_distibution.expects(:get_data_discrepancy_for_set_type).with(mentor_user_ids, student_user_ids).once
    mentor_distibution.calculate_data_discrepancy
  end

  def test_get_data_discrepancy_for_default_type
    program = programs(:albers)
    answer_texts = ["opt_1", "opt_2", "opt_3"]
    match_config = program.match_configs.create(
      student_question: role_questions(:role_questions_1),
      mentor_question: role_questions(:role_questions_1),
      operator: MatchConfig::Operator::lt,
      threshold: 0.1
    )
    mentor_user_ids = [2,3,4,6]
    student_user_ids = [1,8,9,3]
    mentor_distibution = MatchReport::MentorDistribution.new(program, {match_config: match_config})

    mentor_distibution.stubs(:get_user_answer_texts).with(mentor_user_ids, match_config.mentor_question.profile_question).returns(["opt_1", "opt_3","opt_1", "opt_3"])
    mentor_distibution.stubs(:get_user_answer_texts).with(student_user_ids, match_config.student_question.profile_question).returns(["opt_1", "opt_3", "opt_2", "opt_3"])

    MatchReport::MentorDistribution.stubs(:get_answer_text_hash).with(["opt_1", "opt_3","opt_1", "opt_3"]).returns({"opt_1" => 2, "opt_3" => 4})
    MatchReport::MentorDistribution.stubs(:get_answer_text_hash).with(["opt_1", "opt_3", "opt_2", "opt_3"]).returns({"opt_1" => 2, "opt_3" => 4, "opt_2" => 2})
    MatchReport::MentorDistribution.any_instance.stubs(:get_needs_offers_discrepancy_for_default_type).with([], {"opt_1" => 2, "opt_3" => 4}, {"opt_1" => 2, "opt_3" => 4, "opt_2" => 2}).returns("get_needs_offers_discrepancy_for_default_type")
    assert_equal "get_needs_offers_discrepancy_for_default_type", mentor_distibution.get_data_discrepancy_for_default_type(mentor_user_ids, student_user_ids)
  end

  def test_get_data_discrepancy_for_set_type
    program = programs(:albers)

    prof_q = create_question(:question_type => ProfileQuestion::Type::SINGLE_CHOICE, :question_text => "Pick one", :question_info => "opt_1, opt_2, opt_3")
    student_question = prof_q.role_questions.first
    mentor_question = prof_q.role_questions.new
    mentor_question.role = program.get_role(RoleConstants::MENTOR_NAME)
    mentor_question.save!

 
    matching_hash = {"opt_1" => [["opt_2", "opt_3"], ["opt_1"]], "opt_2" => [[]], "opt_3" => [["opt_1"]], "non_existing_choice4" => [["non_existing_choice2"]]}
    match_config = program.match_configs.create(
          :mentor_question_id => mentor_question.id.to_s,
          :student_question_id => student_question.id.to_s,
          :weight => "0.25",
          :matching_type => MatchConfig::MatchingType::SET_MATCHING, :matching_details_for_matching => matching_hash)
    mentor_user_ids = [2,3,4,6]
    student_user_ids = [1,8,9,3]
    matching_details = match_config.matching_details_for_matching 
    student_choice_texts = matching_details.keys & get_formatted_choices(match_config.student_question.profile_question.question_choices.collect(&:text))
    mentor_choice_texts = matching_details.values.flatten.uniq & get_formatted_choices(match_config.mentor_question.profile_question.question_choices.collect(&:text))
    mentor_distibution = MatchReport::MentorDistribution.new(program, {match_config: match_config})
    mentor_distibution.instance_variable_set(:@student_answers_downcase_hash, {"opt_1" => "opt_1", "opt_2" => "opt_2"})
    mentor_distibution.instance_variable_set(:@mentor_answers_downcase_hash, {"opt_1" => "opt_1", "opt_2" => "opt_2"})

    mentor_distibution.stubs(:get_filtered_answer_texts).with(mentor_user_ids, match_config.mentor_question.profile_question, mentor_choice_texts).returns([["opt_1", "opt_3","opt_1", "opt_3"], @mentor_answers_downcase_hash])
    mentor_distibution.stubs(:get_filtered_answer_texts).with(student_user_ids, match_config.student_question.profile_question, student_choice_texts).returns([["opt_1", "opt_3", "opt_2", "opt_3"], @student_answers_downcase_hash])

    MatchReport::MentorDistribution.stubs(:get_answer_text_hash).with(["opt_1", "opt_3","opt_1", "opt_3"]).returns({"opt_1" => 2, "opt_3" => 4})
    MatchReport::MentorDistribution.stubs(:get_answer_text_hash).with(["opt_1", "opt_3", "opt_2", "opt_3"]).returns({"opt_1" => 2, "opt_3" => 4, "opt_2" => 2})
    MatchReport::MentorDistribution.any_instance.stubs(:get_needs_offers_discrepancy_for_set_type).with([], {"opt_1" => 2, "opt_3" => 4}, {"opt_1" => 2, "opt_3" => 4, "opt_2" => 2}, {matching_details: matching_details}).returns("get_needs_offers_discrepancy_for_set_type")
    assert_equal "get_needs_offers_discrepancy_for_set_type", mentor_distibution.get_data_discrepancy_for_set_type(mentor_user_ids, student_user_ids)
  end

  def test_handle_series_in_legend
    discrepancy_hash = {"a" => "c"}
    assert_equal_hash({"a" => "c"}, MatchReport::MentorDistribution.handle_series_in_legend(discrepancy_hash, true))

    assert_equal_hash({"a" => "c", showInLegend: false}, MatchReport::MentorDistribution.handle_series_in_legend(discrepancy_hash, false))
  end

  def test_initialise_series_data_array
    categories = ["1", "2"]
    discrepancy_data = 1
    index = 0 
    assert_equal [1, 0], MatchReport::MentorDistribution.initialise_series_data_array(categories, discrepancy_data, index)

    index = 1
    assert_equal [0, 1], MatchReport::MentorDistribution.initialise_series_data_array(categories, discrepancy_data, index)

    categories = ["1", "2", "3", "4", "5", "6"]
    assert_equal [0, 1, 0,0,0,0], MatchReport::MentorDistribution.initialise_series_data_array(categories, discrepancy_data, index)
  end

  def test_handle_categories_and_discrepancy_size
    discrepancy_data = [{:student_answer_choice=>"Male"}, {student_answer_choice: "Female"}, {student_answer_choice: "random1"}, {student_answer_choice: "random2"}, {student_answer_choice: "random3"}, {student_answer_choice: "random4"}]

    assert_equal [["Male", "Female", "random1", "random2", "random3"], [{:student_answer_choice=>"Male"}, {student_answer_choice: "Female"}, {student_answer_choice: "random1"}, {student_answer_choice: "random2"}, {student_answer_choice: "random3"}], 1], MatchReport::MentorDistribution.handle_categories_and_discrepancy_size(discrepancy_data)

    discrepancy_data = [{:student_answer_choice=>"Male"}, {student_answer_choice: "Female"}, {student_answer_choice: "random1"}, {student_answer_choice: "random2"}, {student_answer_choice: "random3"}]

    assert_equal [["Male", "Female", "random1", "random2", "random3"], discrepancy_data, 0], MatchReport::MentorDistribution.handle_categories_and_discrepancy_size(discrepancy_data)

  end

  def test_get_mentor_series_for_default_type
    program = programs(:albers)
    discrepancy_data = {student_answer_choice: "Male", discrepancy: 2, student_need_count: 4, mentor_offer_count: 9}

    assert_equal_hash({name: "Mentors", data: [9, 0], stack: "Mentors", color: MatchReport::MentorDistribution::MENTOR_COLOR, showInLegend: false}, MatchReport::MentorDistribution.new(program).get_mentor_series_for_default_type(discrepancy_data, ["Male", "Female"], 0, false))

    assert_equal_hash({name: "Mentors", data: [9, 0], stack: "Mentors", color: MatchReport::MentorDistribution::MENTOR_COLOR}, MatchReport::MentorDistribution.new(program).get_mentor_series_for_default_type(discrepancy_data, ["Male", "Female"], 0, true))

    assert_equal_hash({name: "Mentors", data: [0, 9], stack: "Mentors", color: MatchReport::MentorDistribution::MENTOR_COLOR}, MatchReport::MentorDistribution.new(program).get_mentor_series_for_default_type(discrepancy_data, ["Male", "Female"], 1, true))
  end

  def test_get_mentor_series_for_set_type
    program = programs(:albers)
    mentor_distibution = MatchReport::MentorDistribution.new(program)
    mentor_distibution.instance_variable_set(:@student_answers_downcase_hash, {"opt_1" => "opt_1", "opt_2" => "opt_2"})
    mentor_distibution.instance_variable_set(:@mentor_answers_downcase_hash, {"d" => "d", "e" => "e"})

    discrepancy_data = {:student_answer_choice=>"Male", discrepancy: 2, student_need_count: 4, mentor_answer_choices: {"d" => 3, "e" => 4}}

    assert_equal [{:name=>"d", :data=>[3, 0], :stack=>"Mentors", :color=>MatchReport::MentorDistribution::MENTOR_COLOR, :borderColor=>"#f3f3f4", :borderWidth=>1, :showInLegend=>false}, {:name=>"e", :data=>[4, 0], :stack=>"Mentors", :color=>MatchReport::MentorDistribution::MENTOR_COLOR, :borderColor=>"#f3f3f4", :borderWidth=>1, :showInLegend=>false}], mentor_distibution.get_mentor_series_for_set_type(discrepancy_data, ["Male", "Female"], 0, false)

    assert_equal [{:name=>"d", :data=>[3, 0], :stack=>"Mentors", :color=>MatchReport::MentorDistribution::MENTOR_COLOR, :borderColor=>"#f3f3f4", :borderWidth=>1}, {:name=>"e", :data=>[4, 0], :stack=>"Mentors", :color=>MatchReport::MentorDistribution::MENTOR_COLOR, :borderColor=>"#f3f3f4", :borderWidth=>1, :showInLegend=>false}], mentor_distibution.get_mentor_series_for_set_type(discrepancy_data, ["Male", "Female"], 0, true)

    assert_equal [{:name=>"d", :data=>[0, 3], :stack=>"Mentors", :color=>MatchReport::MentorDistribution::MENTOR_COLOR, :borderColor=>"#f3f3f4", :borderWidth=>1}, {:name=>"e", :data=>[0, 4], :stack=>"Mentors", :color=>MatchReport::MentorDistribution::MENTOR_COLOR, :borderColor=>"#f3f3f4", :borderWidth=>1, :showInLegend=>false}], mentor_distibution.get_mentor_series_for_set_type(discrepancy_data, ["Male", "Female"], 1, true)
  end

  private

  def get_formatted_choices(array)
    array.map{|choice| choice.remove_braces_and_downcase }
  end

end
require_relative './../../test_helper.rb'

class SurveyResponsesHelperTest < ActionView::TestCase
  include CampaignManagement::CampaignsHelper
  include KendoHelper

  def test_survey_responses_header_wrapper
    content = survey_responses_header_wrapper("some title", something: 'nothing', class: 'mango')
    assert_select_helper_function "span.mango.cjs_sr_header", content, text: "some title", something: 'nothing', count: 1
  end

  def test_survey_responses_actions
    content = survey_responses_actions(surveys(:progress_report), 1)
    assert_select_helper_function_block "div.strong.cjs_actions_1", content do
      assert_select "a.cjs_actions_email_1", count: 1
      assert_select "a.cjs_actions_xls_1", count: 1
    end
  end

  def test_survey_responses_additional_survey_information
    survey = surveys(:one)
    group = groups(:mygroup)
    meeting = meetings(:f_mentor_mkr_student)
    assert_nil survey_responses_additional_survey_information(survey, {})

    survey.stubs(:engagement_survey?).returns(true)
    content = survey_responses_additional_survey_information(survey, group: group)
    assert_select_helper_function "a", content, text: group.name

    survey.stubs(:engagement_survey?).returns(false)
    survey.stubs(:meeting_feedback_survey?).returns(true)
    current_occurrence_time = CGI.escape(meeting.first_occurrence.to_s)
    assert_match "<a href=\"/meetings/#{meeting.id}?current_occurrence_time=#{current_occurrence_time}\">something</a>", survey_responses_additional_survey_information(survey, meeting_name: "something", meeting: meeting)

    meeting.stubs(:active?).returns(false)
    assert_match "something", survey_responses_additional_survey_information(survey, meeting_name: "something", meeting: meeting)
  end

  def test_survey_responses_primary_columns
    survey = surveys(:progress_report)
    stubs(:current_program).returns(survey.program)

    columns = survey_responses_primary_columns(survey)
    assert_equal ["check_box", "actions", "name", "date", "surveySpecific", "roles"], columns.collect { |h| h[:field] }
  end

  def test_survey_responses_survey_answer_columns
    survey = surveys(:progress_report)
    questions = [common_questions(:q3_name), common_questions(:q3_from)]
    create_columns_for_questions(survey, questions)
    choices_map = get_choices_map_for_survey(survey)

    survey.expects(:get_questions_from_response_columns_for_display).once.returns(questions)
    self.expects(:get_kendo_filterable_options).times(questions.size).returns( { "filter_option" => "value" } )
    output = survey_responses_survey_answer_columns(survey, choices_map)
    assert_equal 2, output.size
    questions.each_with_index do |question, index|
      assert_equal_hash( {
        field: "answers#{question.id}",
        width: "300px",
        headerTemplate: "<span class=\" cjs_sr_header\">#{question.question_text}</span>",
        encoded: false,
        filterable: { "filter_option" => "value" },
        headerAttributes: { class: "text-center" },
        attributes: { class: "text-center" }
      }, output[index])
    end
  end

  def test_profile_questions_based_columns
    survey = surveys(:progress_report)
    profile_questions = [profile_questions(:string_q), profile_questions(:single_choice_q), profile_questions(:mentor_file_upload_q)]
    create_columns_for_questions(survey, profile_questions)
    choices_map = get_choices_map_for_survey(survey)

    survey.expects(:profile_questions_to_display).once.returns(profile_questions.last(2))
    self.expects(:get_kendo_filterable_options).times(2).returns( { "filter_option" => "value" } )
    output = profile_questions_based_columns(survey, choices_map)
    assert_equal 2, output.size
    profile_questions.last(2).each_with_index do |question, index|
      assert_equal_hash( {
        field: "column#{question.id}",
        width: "300px",
        headerTemplate: "<span class=\" cjs_sr_header\">#{question.question_text}</span>",
        encoded: false,
        filterable: { "filter_option" => "value" },
        headerAttributes: { class: "text-center" },
        attributes: { class: "text-center" }
      }, output[index])
    end
  end

  def test_survey_responses_kendo_fields
    assert_equal_hash( {
      id: { type: :string },
      name: { type: :string },
      date: { type: :date }
    }, survey_responses_kendo_fields)
  end

  def test_survey_responses_kendo_options
    survey = surveys(:one)

    self.expects(:survey_responses_kendo_fields).once.returns('something')
    self.expects(:survey_responses_columns).once.with(survey).returns(['something else'])
    self.expects(:kendo_operator_messages).once.returns("messages")
    self.expects(:kendo_custom_accessibilty_messages).once.returns( { filterBy: "Filter By!"} )
    output = survey_responses_kendo_options(survey)
    assert_equal 21, output.size
    assert_equal 'something', output[:fields]
    assert_equal ['something else'], output[:columns]
    assert_equal data_survey_responses_path(survey, format: :json), output[:dataSource]
    assert_equal "cjs_survey_responses_listing_kendogrid", output[:grid_id]
    assert_false output[:selectable]
    [:serverPaging, :serverFiltering, :serverSorting].each { |option| assert_equal true, output[option] }
    assert_equal_hash( { allowUnsort: false }, output[:sortable])
    assert_equal SurveyResponseColumn::Columns::ResponseDate, output[:sortField]
    assert_equal "desc", output[:sortDir]
    assert_equal_hash( { messages: { display: "{0} - {1} of {2} items", empty: "There are no responses to display." } }, output[:pageable])
    assert_equal SurveyResponsesDataService::DEFAULT_PAGE_SIZE, output[:pageSize]
    assert_equal_hash( { messages: "messages" }, output[:filterable])
    assert_equal "From", output[:fromPlaceholder]
    assert_equal "To", output[:toPlaceholder]
    assert_equal [SurveyResponseColumn::Columns::SenderName], output[:autoCompleteFields]
    assert_equal [SurveyResponseColumn::Columns::ResponseDate], output[:dateFields]
    assert_empty output[:numericFields]
    assert_equal auto_complete_for_name_users_path(format: :json, show_all_users: true), output[:autoCompleteUrl]
    assert_equal_hash( { filterBy: "Filter By!"}, output[:customAccessibilityMessages])
  end

  def test_initialize_survey_responses_script
    survey = surveys(:one)

    self.expects(:survey_responses_kendo_options).with(survey).once.returns( { something: "something else" } )
    content = initialize_survey_responses_script(survey, 77)
    assert_equal "<script>\n//<![CDATA[\nProgressReports.initializeBulkActions('Select at least one item');CommonSelectAll.initializeSelectAll(77, cjs_survey_responses_listing_kendogrid);ProgressReports.initializeKendo({\"something\":\"something else\"})\n//]]>\n</script>", content
  end

  def test_get_choices_map_for_survey
    survey = surveys(:progress_report)
    matrix_question = create_matrix_survey_question(survey: survey, program: survey.program)
    assert_equal 3, matrix_question.rating_questions.size
    profile_questions = [profile_questions(:single_choice_q), profile_questions(:string_q), profile_questions(:mentor_file_upload_q)]
    survey_questions = [common_questions(:q3_name), common_questions(:q3_from), matrix_question]
    columns = create_columns_for_questions(survey, (profile_questions + survey_questions))

    survey.expects(:profile_questions_to_display).once.returns(profile_questions)
    choices_map = get_choices_map_for_survey(survey)
    assert_equal 5, choices_map.size
    assert_equal [ { title: "Smallville", value: question_choices(:q3_from_1).id.to_s }, { title: "Krypton", value:  question_choices(:q3_from_2).id.to_s  }, { title: "Earth", value:  question_choices(:q3_from_3).id.to_s  } ], choices_map[common_questions(:q3_from).kendo_column_field]
    assert_equal [ { title: "opt_1", value: question_choices(:single_choice_q_1).id.to_s }, { title: "opt_2", value: question_choices(:single_choice_q_2).id.to_s }, { title: "opt_3", value: question_choices(:single_choice_q_3).id.to_s } ], choices_map[columns[0].kendo_column_field]
    matrix_question.rating_questions.each do |rating_question|
      assert_equal [ { title: "Very Good", value: matrix_question.question_choices.first.id.to_s }, { title: "Good", value: matrix_question.question_choices.second.id.to_s }, { title: "Average", value: matrix_question.question_choices.third.id.to_s }, { title: "Poor", value: matrix_question.question_choices.last.id.to_s } ], choices_map[rating_question.kendo_column_field]
    end
  end

  def test_survey_responses_columns
    survey = surveys(:progress_report)

    choices_map = { "1" => "2", "3" => "5" }
    self.expects(:get_choices_map_for_survey).with(survey).once.returns(choices_map)
    self.expects(:survey_responses_primary_columns).with(survey).once.returns(["a"])
    self.expects(:survey_responses_survey_answer_columns).with(survey, choices_map).once.returns(["m", "n"])
    self.expects(:profile_questions_based_columns).with(survey, choices_map).once.returns(["x", "y", "z"])
    assert_equal ["a", "m", "n", "x", "y", "z"], survey_responses_columns(survey)
  end

  def test_format_user_roles
    user = users(:f_mentor_student)
    program = user.program
    self.stubs(:current_program).returns(program)

    result = format_user_roles(user, nil, nil)
    assert_select_helper_function_block "ul.unstyled.no-margin", result do
      assert_select "li", text: "Mentor"
      assert_select "li", text: "Student"
    end

    group = create_group(mentor: user)
    result = format_user_roles(user, group, program.find_role(RoleConstants::MENTOR_NAME).id)
    assert_select_helper_function_block "ul.unstyled.no-margin", result do
      assert_select "li", text: "Mentor"
    end

    Group.any_instance.stubs(:membership_of).returns(nil)
    # For the user removed from group
    result = format_user_roles(user, group, nil)
    assert_select_helper_function_block "ul.unstyled.no-margin", result do
      assert_select "li", text: "-"
    end
  end

  def test_get_data_hash_for_survey_response_link
    answer = common_answers(:q3_from_answer_2)
    assert_equal_hash({ user_id: users(:no_mreq_student).id, response_id: 2, survey_id: surveys(:progress_report).id, format: :js }, get_data_hash_for_survey_response_link(answer))

    answer = common_answers(:q3_from_answer_draft)
    assert_equal_hash({ user_id: users(:no_mreq_student).id, response_id: 3, survey_id: surveys(:progress_report).id, format: :js }, get_data_hash_for_survey_response_link(answer))
  end


  private

  def j(something)
    something
  end

  def _Mentoring_Connection
    "Engagement"
  end

  def _Meeting
    "Session"
  end

  def create_columns_for_questions(survey, questions)
    current_maximum_position = survey.survey_response_columns.maximum(:position)

    columns = []
    questions.each_with_index do |question, index|
      attrs = { position: (current_maximum_position + index + 1) }
      if question.is_a? ProfileQuestion
        attrs[:ref_obj_type] = SurveyResponseColumn::ColumnType::USER
        attrs[:profile_question_id] = question.id
      else
        attrs[:ref_obj_type] = SurveyResponseColumn::ColumnType::SURVEY
        attrs[:survey_question_id] = question.id
      end
      columns << survey.survey_response_columns.create!(attrs)
    end
    columns
  end
end
require_relative './../test_helper.rb'

class SurveyTest < ActiveSupport::TestCase

  class DummyGroupedAnswerClass
    attr_accessor :text, :answers_count

    def initialize(text, count)
      @text = text
      @answers_count = count
    end
  end

  def test_default_scope
    s1 = MeetingFeedbackSurvey.create!(program_id: Program.first.id, name: "Something 1", role_name: RoleConstants::MENTOR_NAME)
    s2 = EngagementSurvey.create!(program_id: Program.first.id, name: "Something 2")
    s3 = create_program_survey

    assert Survey.all.pluck(:id).include?(s1.id)
    assert Survey.all.pluck(:id).include?(s2.id)
    assert Survey.all.pluck(:id).include?(s3.id)

    s1.update_attribute(:role_name, nil)
    assert_false Survey.all.pluck(:id).include?(s1.id)
  end

  def test_required_fields
    assert_multiple_errors([{:field => :program}, {:field => :name}, {:field => :type}]) do
      Survey.create!
    end
  end

  def test_select_options
    program = programs(:albers)
    assert_equal Survey.select_options(program), ["EngagementSurvey", "ProgramSurvey"]
  end

  def test_select_options_when_ongoing_mentoring_disabled
    program = programs(:albers)
    program.update_attribute("engagement_type", Program::EngagementType::CAREER_BASED)
    program.reload

    assert_equal Survey.select_options(program), ["ProgramSurvey"]
  end

  def test_by_type
    program = programs(:albers)
    program_survey = surveys(:one)
    engagement_survey = surveys(:two)
    feedback_survey = program.feedback_survey
    meeting_feedback_survey = program.get_meeting_feedback_survey_for_role(RoleConstants::MENTOR_NAME)

    assert_false program.mentoring_connections_v2_enabled?
    assert_false program.calendar_enabled?
    assert program.ongoing_mentoring_enabled?

    program.stubs(:surveys).returns(Survey.where(id: [program_survey.id, engagement_survey.id, feedback_survey.id, meeting_feedback_survey.id]))
    surveys_by_type = Survey.by_type(program)
    assert_equal_unordered [program_survey, feedback_survey], surveys_by_type[ProgramSurvey.name]
    assert_nil surveys_by_type[EngagementSurvey.name]
    assert_nil surveys_by_type[MeetingFeedbackSurvey.name]

    program.stubs(:ongoing_mentoring_enabled?).returns(false)
    surveys_by_type = Survey.by_type(program)
    assert_equal_unordered [program_survey], surveys_by_type[ProgramSurvey.name]
    assert_nil surveys_by_type[EngagementSurvey.name]
    assert_nil surveys_by_type[MeetingFeedbackSurvey.name]

    program.stubs(:ongoing_mentoring_enabled?).returns(true)
    program.stubs(:mentoring_connections_v2_enabled?).returns(true)
    surveys_by_type = Survey.by_type(program)
    assert_equal [program_survey], surveys_by_type[ProgramSurvey.name]
    assert_equal_unordered [engagement_survey, feedback_survey], surveys_by_type[EngagementSurvey.name]
    assert_nil surveys_by_type[MeetingFeedbackSurvey.name]

    program.stubs(:calendar_enabled?).returns(true)
    surveys_by_type = Survey.by_type(program)
    assert_equal_unordered [program_survey], surveys_by_type[ProgramSurvey.name]
    assert_equal_unordered [engagement_survey, feedback_survey], surveys_by_type[EngagementSurvey.name]
    assert_equal [meeting_feedback_survey], surveys_by_type[MeetingFeedbackSurvey.name]
  end

  def test_program_survey
    assert surveys(:one).program_survey?
    assert_false surveys(:two).program_survey?
  end

  def test_engagement_survey
    assert surveys(:two).engagement_survey?
    assert_false surveys(:one).engagement_survey?
  end

  def test_scope_of_meeting_feedback_type
    assert_equal_unordered MeetingFeedbackSurvey.all, Survey.of_meeting_feedback_type
  end

  def test_meeting_feedback_survey
    assert MeetingFeedbackSurvey.first.meeting_feedback_survey?
    assert_false EngagementSurvey.first.meeting_feedback_survey?
    assert_false ProgramSurvey.first.meeting_feedback_survey?
  end

  def test_responses
    survey = create_program_survey
    q1 = create_survey_question(
      {question_type: CommonQuestion::Type::SINGLE_CHOICE,
        question_choices: "get,set,go", survey: survey})
    q2 = create_survey_question({
        question_type: CommonQuestion::Type::RATING_SCALE,
        question_choices: "bad,good,better,best", survey: survey})
    q3 = create_survey_question({survey: survey})

    result = survey.get_answers_and_user_names(survey.survey_questions.pluck(:id), " ", " ", survey.program_id)
    assert result.empty?

    mentor = users(:f_mentor)
    options1 = {:user_id => mentor.id}
    question_answer_map1 = {q1.id => "set", q2.id => "good", q3.id => "text"}
    survey.update_user_answers(question_answer_map1, options1)

    student = users(:f_student)
    options2 = {:user_id => student.id}
    question_answer_map2 = {q1.id => "set", q3.id => "text"}
    survey.update_user_answers(question_answer_map2, options2)

    mentor_student = users(:f_mentor_student)
    options3 = {:user_id => mentor_student.id}
    question_answer_map3 = {q1.id => "set", q2.id => "good"}
    survey.update_user_answers(question_answer_map3, options3)

    responses_hash = survey.responses.collect do |response_id, answers|
      answers.inject({}) do |qam, ans|
        qam[ans.common_question_id] = ans.selected_choices_to_str
        qam
      end
    end
    assert_equal [question_answer_map1, question_answer_map2, question_answer_map3], responses_hash
  end

  def test_create_survey_questions_from_csv_import
    survey = create_program_survey
    csv_questions_stream = fixture_file_upload("/files/solution_pack_import/survey_question_survey.csv", "text/csv")
    questions_content = csv_questions_stream.read
    questions = survey.create_survey_questions(questions_content)
    assert_equal 61,questions.count

    questions_content = nil
    questions = survey.create_survey_questions(questions_content)
    assert_nil questions
  end

  def test_create_survey_questions_from_valid_csv_stream_only_matrix_questions
    survey = create_program_survey
    csv_questions_stream = fixture_file_upload("/files/solution_pack_import/survey_question_matrix_question.csv", "text/csv")
    questions_content = csv_questions_stream.read
    questions = survey.create_survey_questions(questions_content)
    assert_equal 3,questions.count
  end

  def test_create_survey_questions_from_valid_csv_stream
    survey = create_program_survey
    csv_questions_stream_two = fixture_file_upload("/files/solution_pack_import/survey_question_without_matrix_question.csv", "text/csv")
    questions_content = csv_questions_stream_two.read
    questions = survey.create_survey_questions(questions_content)
    assert_equal 8,questions.count
  end

  def test_create_survey_questions_from_csv_stream_containing_only_headers
    survey = create_program_survey
    csv_questions_stream_two = fixture_file_upload("/files/solution_pack_import/survey_question_containing_only_headers.csv", "text/csv")
    questions_content = csv_questions_stream_two.read
    questions = survey.create_survey_questions(questions_content)
    assert_equal 0,questions.count
  end

  def test_populate_survey_questions
    survey = create_program_survey
    csv_questions_stream = fixture_file_upload("/files/solution_pack_import/survey_question_mix.csv", "text/csv")
    questions_content = csv_questions_stream.read
    questions_content = CSV.parse(questions_content)
    column_names = questions_content[0]
    id_mappings = {}
    matrix_id_mappings = {}
    survey.populate_survey_questions(questions_content, column_names, id_mappings, matrix_id_mappings)

    assert_not_nil id_mappings
    assert_not_nil matrix_id_mappings

    assert_equal id_mappings[837], survey.survey_questions.where(question_text:"Will you continue remaining in contact with your mentoring partner?").first.id
    assert_equal id_mappings[838], survey.survey_questions.where(question_text:"Do you have any additional comments?").first.id
    assert_equal id_mappings[900], survey.survey_questions.where(question_text:"How effective is your partnership in helping to reach your goals").first.id
    assert_equal id_mappings[901], survey.survey_questions_with_matrix_rating_questions.where(question_text:"What is going well in your mentoring partnership?").first.id
    assert_equal id_mappings[902], survey.survey_questions_with_matrix_rating_questions.where(question_text:"What could be better in your mentoring partnership?").first.id

    assert_equal matrix_id_mappings[901], 900
    assert_equal matrix_id_mappings[902], 900
    assert_nil matrix_id_mappings[837]
  end

  def test_populate_matrix_question_id
    survey = create_program_survey
    csv_questions_stream = fixture_file_upload("/files/solution_pack_import/survey_question_mix.csv", "text/csv")
    questions_content = csv_questions_stream.read
    questions_content = CSV.parse(questions_content)
    column_names = questions_content[0]
    id_mappings = {}
    matrix_id_mappings = {}
    survey.populate_survey_questions(questions_content, column_names, id_mappings, matrix_id_mappings)
    survey.populate_matrix_question_id(id_mappings, matrix_id_mappings)
    rating_questions = []
    rating_questions = survey.matrix_rating_questions

    assert_equal id_mappings[matrix_id_mappings[901]], rating_questions[0].matrix_question_id
    assert_equal id_mappings[matrix_id_mappings[902]], rating_questions[1].matrix_question_id

  end

  def test_validate_survey_questions
    survey = create_program_survey
    csv_questions_stream = fixture_file_upload("/files/solution_pack_import/survey_question_mix.csv", "text/csv")
    questions_content = csv_questions_stream.read
    questions_content = CSV.parse(questions_content)
    column_names = questions_content[0]
    id_mappings = {}
    matrix_id_mappings = {}
    survey.populate_survey_questions(questions_content, column_names, id_mappings, matrix_id_mappings)
    survey.populate_matrix_question_id(id_mappings, matrix_id_mappings)
    survey.validate_survey_questions

    assert_not_nil survey.survey_questions.where(question_text:"Will you continue remaining in contact with your mentoring partner?").first.id
  end

  def test_calculate_response_rate
    total_responses = nil
    responses_count = 0
    response_rate = Survey.calculate_response_rate(responses_count, total_responses)

    assert_nil response_rate

    total_responses = 0
    responses_count = 0
    response_rate = Survey.calculate_response_rate(responses_count, total_responses)

    assert_nil response_rate

    total_responses = 3
    responses_count = 3
    response_rate = Survey.calculate_response_rate(responses_count, total_responses)
    assert_equal 100.0, response_rate
  end

  def test_percentage_error
    survey = surveys(:two)
    total_responses = nil
    responses_count = 2
    percentage_error = Survey.percentage_error(responses_count, total_responses)
    assert_nil percentage_error

    total_responses = 2
    responses_count = 0
    percentage_error = Survey.percentage_error(responses_count, total_responses)
    assert_nil percentage_error


    total_responses = 1
    responses_count = 1
    percentage_error = Survey.percentage_error(responses_count, total_responses)
    assert_nil percentage_error

    total_responses = 10
    responses_count = 2
    percentage_error = Survey.percentage_error(responses_count, total_responses)
    assert_equal 66.00, percentage_error
  end

  def test_find_users_who_responded
    program =  programs(:no_mentor_request_program)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, true)
    survey = surveys(:progress_report)
    group = groups(:no_mreq_group)
    mentoring_model = program.default_mentoring_model
    mentoring_model.update_attribute(:should_sync, true)
    group.update_attribute(:mentoring_model_id, mentoring_model.id)

    options = {:due_date => 2.weeks.ago, :created_at => "July 04, 2016", :action_item_type => MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, :required => true, :action_item_id => survey.id, :group_id => group.id,:user => users(:no_mreq_mentor), :group => groups(:no_mreq_group)}

    task1 = create_mentoring_model_task(options)

    options.merge!(:user => users(:no_mreq_mentor))
    options.merge!(:group => groups(:no_mreq_group))
    task2 = create_mentoring_model_task(options)

    common_answer_1 = common_answers(:q3_name_answer_1)
    common_answer_2 = common_answers(:q3_from_answer_1)
    common_answer_1.update_attribute(:task_id, task1.id)
    common_answer_2.update_attribute(:task_id, task1.id)
    SurveyAnswer.expects(:get_es_survey_answers).with({filter: {survey_id: survey.id, is_draft: false, user_id: [67, 68, 69], response_id: [1]}, source_columns: ["response_id"]}).returns([Elasticsearch::Model::HashWrapper.new(response_id: 1), Elasticsearch::Model::HashWrapper.new(response_id: 1)])

    filter_params = {"0"=>{"field"=>"roles", "value"=>"mentor"}}
    srds = SurveyResponsesDataService.new(survey, {:filter => {:filters => filter_params}})

    users_responded_count, users_responded_groups_count = survey.find_users_who_responded(srds.response_ids)
    assert_equal 1, users_responded_count
    assert_equal 1, users_responded_groups_count
  end

  def test_calculate_overdue_responses
    program =  programs(:no_mentor_request_program)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, true)
    survey = surveys(:progress_report)
    group = groups(:no_mreq_group)
    mentoring_model = program.default_mentoring_model
    mentoring_model.update_attribute(:should_sync, true)
    group.update_attribute(:mentoring_model_id, mentoring_model.id)

    options = {:due_date => 3.weeks.ago, :created_at => "July 04, 2016", :action_item_type => MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, :required => true, :action_item_id => survey.id, :group_id => group.id,:user => users(:no_mreq_mentor), :group => groups(:no_mreq_group)}

    task1 = create_mentoring_model_task(options)

    options.merge!(:user => users(:no_mreq_mentor))
    options.merge!(:group => groups(:no_mreq_group))
    task2 = create_mentoring_model_task(options)

    common_answer_1 = common_answers(:q3_name_answer_1)
    common_answer_2 = common_answers(:q3_from_answer_1)
    common_answer_1.update_attribute(:task_id, task1.id)
    common_answer_2.update_attribute(:task_id, task1.id)

    filter_params = {"0"=>{"field"=>"roles", "value"=>"mentor"}, "1"=>{"field"=>"date", "operator"=>"eq", "value"=>"July 06, 2016"}, "2"=>{"field"=>"date", "operator"=>"eq", "value"=>2.weeks.ago}, "3"=>{"field"=>"column6", "operator"=>"answered", "value"=>""}, "4"=>{"field"=>"answers469", "operator"=>"answered", "value"=>""}}

    srds = SurveyResponsesDataService.new(survey, {:filter => {:filters => filter_params}})
    dynamic_filter_params = SurveyResponsesDataService::FilterResponses.dynamic_filter_params({:filter => {:filters => filter_params}})

    overdue_responses_count, overdue_task_ids = survey.calculate_overdue_responses(srds.user_ids, dynamic_filter_params)
    assert_nil overdue_responses_count
    assert_nil overdue_task_ids

    filter_params = {"0"=>{"field"=>"roles", "value"=>"mentor"}, "1"=>{"field"=>"date", "operator"=>"eq", "value"=>"July 06, 2016"}, "2"=>{"field"=>"date", "operator"=>"eq", "value"=>2.weeks.ago}, "3"=>{"field"=>"column3", "operator"=>"answered", "value"=>""}}

    srds = SurveyResponsesDataService.new(survey, {:filter => {:filters => filter_params}})
    dynamic_filter_params = SurveyResponsesDataService::FilterResponses.dynamic_filter_params({:filter => {:filters => filter_params}})
    overdue_responses_count, overdue_task_ids = survey.calculate_overdue_responses(srds.user_ids, dynamic_filter_params)

    assert_equal 1, overdue_responses_count
    assert_equal [task2.id], overdue_task_ids

    filter_params = {"0"=>{"field"=>"date", "operator"=>"eq", "value"=>"July 06, 2016"}, "1"=>{"field"=>"date", "operator"=>"eq", "value"=>Time.now.utc}}
    srds = SurveyResponsesDataService.new(survey, {:filter => {:filters => filter_params}})
    dynamic_filter_params = SurveyResponsesDataService::FilterResponses.dynamic_filter_params({:filter => {:filters => filter_params}})
    overdue_responses_count, overdue_task_ids = survey.calculate_overdue_responses(srds.user_ids, dynamic_filter_params)

    assert_equal 1, overdue_responses_count
    assert_equal [task2.id], overdue_task_ids
  end

  def test_calculate_overdue_meeting_responses_mentor
    program = programs(:albers)
    survey = MeetingFeedbackSurvey.create!(program_id: program.id, name: "Something", role_name: RoleConstants::MENTOR_NAME)
    filter_params = {"0"=>{"field"=>"date", "operator"=>"eq", "value"=>"July 06, 2016"}, "1"=>{"field"=>"date", "operator"=>"eq", "value"=>1.minute.ago}}
    filter_params = SurveyResponsesDataService::FilterResponses.dynamic_filter_params({:filter => {:filters => filter_params}})
    time = 4.weeks.ago.change(:usec => 0)
    m1 = create_meeting({:program => program, :topic => "Arbit Topic", :start_time => time, :end_time => (time + 30.minutes), :location => "Chennai", :members => [members(:f_mentor), members(:mkr_student)], :owner_id => members(:f_mentor).id, :force_non_group_meeting => true})
    m1.meeting_request.update_attributes!(:status => AbstractRequest::Status::ACCEPTED)
    time = 5.weeks.ago.change(:usec => 0)
    user2 = members(:not_requestable_mentor).user_in_program(programs(:albers))
    m2 = create_meeting({:program => programs(:albers), :topic => "Arbit Topic2", :start_time => time, :end_time => (time + 30.minutes), :members => [members(:student_2), members(:not_requestable_mentor)], :requesting_student => users(:student_2), :requesting_mentor => user2, :force_non_group_meeting => true, owner_id: members(:student_2).id})

    filter_params = {"0"=>{"field"=>"date", "operator"=>"eq", "value"=>"July 06, 2016"}, "1"=>{"field"=>"date", "operator"=>"eq", "value"=>2.weeks.ago}, "2"=>{"field"=>"column6", "operator"=>"answered", "value"=>""}, "3"=>{"field"=>"answers469", "operator"=>"answered", "value"=>""}}

    m2.meeting_request.update_attributes!(:status => AbstractRequest::Status::ACCEPTED)
    start_time = Date.parse("July 06, 2016").to_datetime.change(offset: Time.current.strftime("%z")).strftime(ElasticsearchConstants::DATE_RANGE_FORMATS::FORMATS_HASH["yyyy-MM-dd HH:mm:ss ZZ"])
    end_time = 2.weeks.ago.to_datetime.end_of_day.change(offset: Time.current.strftime("%z")).strftime(ElasticsearchConstants::DATE_RANGE_FORMATS::FORMATS_HASH["yyyy-MM-dd HH:mm:ss ZZ"])
    SurveyAnswer.expects(:get_es_survey_answers).with({filter: {survey_id: survey.id, is_draft: false, last_answered_at: start_time..end_time, es_range_formats: {last_answered_at: "yyyy-MM-dd HH:mm:ss ZZ"}, user_id: program.all_user_ids, response_id: []}, source_columns: ["response_id"]}).returns([])

    srds = SurveyResponsesDataService.new(survey, {:filter => {:filters => filter_params}})
    dynamic_filter_params = SurveyResponsesDataService::FilterResponses.dynamic_filter_params({:filter => {:filters => filter_params}})

    pending_responses_count, pending_member_meeting_ids = survey.calculate_overdue_responses(srds.user_ids, dynamic_filter_params)
    assert_nil pending_responses_count
    assert_nil pending_member_meeting_ids

    filter_params = {"0"=>{"field"=>"date", "operator"=>"eq", "value"=>"July 06, 2016"}, "1"=>{"field"=>"date", "operator"=>"eq", "value"=>2.weeks.ago}}

    srds = SurveyResponsesDataService.new(survey, {:filter => {:filters => filter_params}})
    dynamic_filter_params = SurveyResponsesDataService::FilterResponses.dynamic_filter_params({:filter => {:filters => filter_params}})
    pending_responses_count, pending_member_meeting_ids = survey.calculate_overdue_responses(srds.user_ids, dynamic_filter_params)
    assert_equal 5, pending_responses_count
    assert_equal_unordered [meetings(:past_calendar_meeting).member_meetings.where(:member_id => members(:f_mentor).id).first.id,meetings(:completed_calendar_meeting).member_meetings.where(:member_id => members(:f_mentor).id).first.id, meetings(:cancelled_calendar_meeting).member_meetings.where(:member_id => members(:f_mentor).id).first.id, m1.member_meetings.where(:member_id => members(:f_mentor).id).first.id, m2.member_meetings.where(:member_id => members(:not_requestable_mentor).id).first.id], pending_member_meeting_ids

    question = create_survey_question({allow_other_option: true, :question_type => CommonQuestion::Type::MULTI_STRING, :question_text => "What is your name?", :survey => survey})
    create_survey_answer({:answer_text => "remove mentee", :response_id => 2, :user => users(:not_requestable_mentor), :last_answered_at => 3.weeks.ago, :member_meeting_id => m2.member_meetings.where(:member_id => members(:not_requestable_mentor).id).first.id, :survey_id => survey.id, :survey_question => question})
    pending_responses_count, pending_member_meeting_ids = survey.calculate_overdue_responses(srds.user_ids, dynamic_filter_params)
    assert_equal 4, pending_responses_count
    assert_equal_unordered [meetings(:past_calendar_meeting).member_meetings.where(:member_id => members(:f_mentor).id).first.id,meetings(:completed_calendar_meeting).member_meetings.where(:member_id => members(:f_mentor).id).first.id, meetings(:cancelled_calendar_meeting).member_meetings.where(:member_id => members(:f_mentor).id).first.id, m1.member_meetings.where(:member_id => members(:f_mentor).id).first.id], pending_member_meeting_ids


    create_survey_answer({:answer_text => "remove mentee1", :response_id => 3, :user => users(:f_mentor), :last_answered_at => Time.now.utc - 1.minute, :member_meeting_id => m1.member_meetings.where(:member_id => members(:f_mentor).id).first.id, :survey_id => survey.id, :survey_question => question})
    pending_responses_count, pending_member_meeting_ids = survey.calculate_overdue_responses(srds.user_ids, dynamic_filter_params)
    assert_equal 3, pending_responses_count
    assert_equal_unordered [meetings(:past_calendar_meeting).member_meetings.where(:member_id => members(:f_mentor).id).first.id,meetings(:completed_calendar_meeting).member_meetings.where(:member_id => members(:f_mentor).id).first.id, meetings(:cancelled_calendar_meeting).member_meetings.where(:member_id => members(:f_mentor).id).first.id], pending_member_meeting_ids
  end

  def test_calculate_overdue_meeting_responses_mentee
    program = programs(:albers)
    survey = MeetingFeedbackSurvey.create!(program_id: program.id, name: "Something", role_name: RoleConstants::STUDENT_NAME)
    filter_params = {"0"=>{"field"=>"date", "operator"=>"eq", "value"=>"July 06, 2016"}, "1"=>{"field"=>"date", "operator"=>"eq", "value"=>1.minute.ago}}
    filter_params = SurveyResponsesDataService::FilterResponses.dynamic_filter_params({:filter => {:filters => filter_params}})
    time = 4.weeks.ago.change(:usec => 0)
    m1 = create_meeting({:program => program, :topic => "Arbit Topic", :start_time => time, :end_time => (time + 30.minutes), :location => "Chennai", :members => [members(:f_mentor), members(:mkr_student)], :owner_id => members(:f_mentor).id, :force_non_group_meeting => true})
    m1.meeting_request.update_attributes!(:status => AbstractRequest::Status::ACCEPTED)
    time = 5.weeks.ago.change(:usec => 0)
    user2 = members(:not_requestable_mentor).user_in_program(programs(:albers))
    m2 = create_meeting({:program => programs(:albers), :topic => "Arbit Topic2", :start_time => time, :end_time => (time + 30.minutes), :members => [members(:student_2), members(:not_requestable_mentor)], :requesting_student => users(:student_2), :requesting_mentor => user2, :force_non_group_meeting => true, owner_id: members(:student_2).id})
    m2.meeting_request.update_attributes!(:status => AbstractRequest::Status::ACCEPTED)
    filter_params = {"0"=>{"field"=>"date", "operator"=>"eq", "value"=>"July 06, 2016"}, "1"=>{"field"=>"date", "operator"=>"eq", "value"=>2.weeks.ago}, "2"=>{"field"=>"column6", "operator"=>"answered", "value"=>""}, "3"=>{"field"=>"answers469", "operator"=>"answered", "value"=>""}}
    start_time = Date.parse("July 06, 2016").to_datetime.change(offset: Time.current.strftime("%z")).strftime(ElasticsearchConstants::DATE_RANGE_FORMATS::FORMATS_HASH["yyyy-MM-dd HH:mm:ss ZZ"])
    end_time = 2.weeks.ago.to_datetime.end_of_day.change(offset: Time.current.strftime("%z")).strftime(ElasticsearchConstants::DATE_RANGE_FORMATS::FORMATS_HASH["yyyy-MM-dd HH:mm:ss ZZ"])

    SurveyAnswer.expects(:get_es_survey_answers).with({filter: {survey_id: survey.id, is_draft: false, last_answered_at: start_time..end_time, es_range_formats: {last_answered_at: "yyyy-MM-dd HH:mm:ss ZZ"}, user_id: program.all_user_ids, response_id: []}, source_columns: ["response_id"]}).returns([])

    srds = SurveyResponsesDataService.new(survey, {:filter => {:filters => filter_params}})
    dynamic_filter_params = SurveyResponsesDataService::FilterResponses.dynamic_filter_params({:filter => {:filters => filter_params}})

    pending_responses_count, pending_member_meeting_ids = survey.calculate_overdue_responses(srds.user_ids, dynamic_filter_params)
    assert_nil pending_responses_count
    assert_nil pending_member_meeting_ids

    filter_params = {"0"=>{"field"=>"date", "operator"=>"eq", "value"=>"July 06, 2016"}, "1"=>{"field"=>"date", "operator"=>"eq", "value"=>2.weeks.ago}}

    srds = SurveyResponsesDataService.new(survey, {:filter => {:filters => filter_params}})
    dynamic_filter_params = SurveyResponsesDataService::FilterResponses.dynamic_filter_params({:filter => {:filters => filter_params}})
    pending_responses_count, pending_member_meeting_ids = survey.calculate_overdue_responses(srds.user_ids, dynamic_filter_params)

    assert_equal 5, pending_responses_count
    assert_equal_unordered [meetings(:past_calendar_meeting).member_meetings.where(:member_id => members(:mkr_student).id).first.id,meetings(:completed_calendar_meeting).member_meetings.where(:member_id => members(:mkr_student).id).first.id, meetings(:cancelled_calendar_meeting).member_meetings.where(:member_id => members(:mkr_student).id).first.id, m1.member_meetings.where(:member_id => members(:mkr_student).id).first.id, m2.member_meetings.where(:member_id => members(:student_2).id).first.id], pending_member_meeting_ids

    question = create_survey_question({allow_other_option: true, :question_type => CommonQuestion::Type::MULTI_STRING, :question_text => "What is your name?", :survey => survey})
    create_survey_answer({:answer_text => "remove mentee", :response_id => 2, :user => users(:student_2), :last_answered_at => 3.weeks.ago, :member_meeting_id => m2.member_meetings.where(:member_id => members(:student_2).id).first.id, :survey_id => survey.id, :survey_question => question})
    pending_responses_count, pending_member_meeting_ids = survey.calculate_overdue_responses(srds.user_ids, dynamic_filter_params)
    assert_equal 4, pending_responses_count
    assert_equal_unordered [meetings(:past_calendar_meeting).member_meetings.where(:member_id => members(:mkr_student).id).first.id,meetings(:completed_calendar_meeting).member_meetings.where(:member_id => members(:mkr_student).id).first.id, meetings(:cancelled_calendar_meeting).member_meetings.where(:member_id => members(:mkr_student).id).first.id, m1.member_meetings.where(:member_id => members(:mkr_student).id).first.id], pending_member_meeting_ids

    create_survey_answer({:answer_text => "remove mentee1", :response_id => 3, :user => users(:mkr_student), :last_answered_at => Time.now.utc - 1.minute, :member_meeting_id => m1.member_meetings.where(:member_id => members(:mkr_student).id).first.id, :survey_id => survey.id, :survey_question => question})
    pending_responses_count, pending_member_meeting_ids = survey.calculate_overdue_responses(srds.user_ids, dynamic_filter_params)
    assert_equal 3, pending_responses_count
    assert_equal_unordered [meetings(:past_calendar_meeting).member_meetings.where(:member_id => members(:mkr_student).id).first.id,meetings(:completed_calendar_meeting).member_meetings.where(:member_id => members(:mkr_student).id).first.id, meetings(:cancelled_calendar_meeting).member_meetings.where(:member_id => members(:mkr_student).id).first.id], pending_member_meeting_ids
  end

  def test_profile_field_filter_task
    program =  programs(:no_mentor_request_program)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, true)
    survey = surveys(:progress_report)
    group = groups(:no_mreq_group)
    mentoring_model = program.default_mentoring_model
    mentoring_model.update_attribute(:should_sync, true)
    group.update_attribute(:mentoring_model_id, mentoring_model.id)

    options = {:created_at => "July 04, 2016", :action_item_type => MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, :required => true, :action_item_id => survey.id, :group_id => group.id,:user => users(:no_mreq_mentor), :group => groups(:no_mreq_group)}

    task1 = create_mentoring_model_task(options)

    options.merge!(:user => users(:no_mreq_mentor))
    options.merge!(:group => groups(:no_mreq_group))
    task2 = create_mentoring_model_task(options)

    common_answer_1 = common_answers(:q3_name_answer_1)
    common_answer_2 = common_answers(:q3_from_answer_1)
    common_answer_1.update_attribute(:task_id, task1.id)
    common_answer_2.update_attribute(:task_id, task1.id)

    filter_params = {"0"=>{"field"=>"column3", "operator"=>"answered", "value"=>""}}

    srds = SurveyResponsesDataService.new(survey, {:filter => {:filters => filter_params}})

    task_ids_after_profile_field_filter = survey.profile_field_filter_applied(srds.user_ids)

    assert_equal task_ids_after_profile_field_filter, [task1.id, task2.id]
  end

  def test_profile_field_filter_meeting
    program =  programs(:no_mentor_request_program)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, true)
    survey = MeetingFeedbackSurvey.create!(program_id: program.id, name: "Something", role_name: RoleConstants::MENTOR_NAME)
    time = 4.weeks.ago.change(:usec => 0)
    m1 = create_meeting({:program => program, :topic => "Arbit Topic", :start_time => time, :end_time => (time + 30.minutes), :location => "Chennai", :members => [members(:f_mentor), members(:mkr_student)], :owner_id => members(:f_mentor).id, :force_non_group_meeting => true})
    time = 3.weeks.ago.change(:usec => 0)
    user2 = members(:no_mreq_mentor).user_in_program(programs(:albers))
    m2 = create_meeting({:program => programs(:albers), :topic => "Arbit Topic2", :start_time => time, :end_time => (time + 30.minutes), :members => [members(:student_2),members(:no_mreq_mentor)], :requesting_student => users(:student_2), :requesting_mentor => user2, :force_non_group_meeting => true, owner_id: members(:student_2).id})
    filter_params = {"0"=>{"field"=>"column3", "operator"=>"answered", "value"=>""}}
    SurveyAnswer.expects(:get_es_survey_answers).with({filter: {survey_id: survey.id, is_draft: false, user_id: [68, 69], response_id: []}, source_columns: ["response_id"]}).returns([])
    srds = SurveyResponsesDataService.new(survey, {:filter => {:filters => filter_params}})
    member_meeting_ids_after_profile_field_filter = survey.profile_field_filter_applied(srds.user_ids)
    assert_equal member_meeting_ids_after_profile_field_filter, []
  end

  def test_date_filter_task
    program =  programs(:no_mentor_request_program)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, true)
    survey = surveys(:progress_report)
    group = groups(:no_mreq_group)
    mentoring_model = program.default_mentoring_model
    mentoring_model.update_attribute(:should_sync, true)
    group.update_attribute(:mentoring_model_id, mentoring_model.id)
    tem_task1 = create_mentoring_model_engagement_survey_task_template(role_id: program.roles.find{|r| r.name == RoleConstants::MENTOR_NAME }.id, :action_item_id => survey.id, :mentoring_model_id => mentoring_model.id)

    options = {:due_date => 3.weeks.ago, :created_at => "July 04, 2016", :action_item_type => MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, :required => true, :mentoring_model_task_template_id => tem_task1.id, :action_item_id => survey.id, :group_id => group.id }

    task1 = create_mentoring_model_task(options)
    task2 = create_mentoring_model_task(options)

    filter_params = {"0"=>{"field"=>"date", "operator"=>"eq", "value"=>"July 06, 2016"}, "1"=>{"field"=>"date", "operator"=>"eq", "value"=>2.weeks.ago}}

    dynamic_filter_params = SurveyResponsesDataService::FilterResponses.dynamic_filter_params({:filter => {:filters => filter_params}})

    task_ids_after_date_filter = survey.date_filter(dynamic_filter_params)
    assert_equal task_ids_after_date_filter, [task1.id, task2.id]
  end

  def test_date_filter_meeting
    program = programs(:albers)
    survey = MeetingFeedbackSurvey.create!(program_id: program.id, name: "Something", role_name: RoleConstants::MENTOR_NAME)

    time = 4.weeks.ago.change(:usec => 0)
    m1 = create_meeting({:program => program, :topic => "Arbit Topic", :start_time => time, :end_time => (time + 30.minutes), :location => "Chennai", :members => [members(:f_mentor), members(:mkr_student)], :owner_id => members(:f_mentor).id, :force_non_group_meeting => true})
    m1.meeting_request.update_attributes!(:status => AbstractRequest::Status::ACCEPTED)
    time = 3.weeks.ago.change(:usec => 0)
    user2 = members(:not_requestable_mentor).user_in_program(programs(:albers))
    m2 = create_meeting({:program => programs(:albers), :topic => "Arbit Topic2", :start_time => time, :end_time => (time + 30.minutes), :members => [members(:student_2), members(:not_requestable_mentor)], :requesting_student => users(:student_2), :requesting_mentor => user2, :force_non_group_meeting => true, owner_id: members(:student_2).id})
    m2.meeting_request.update_attributes!(:status => AbstractRequest::Status::ACCEPTED)
    filter_params = {"0"=>{"field"=>"date", "operator"=>"eq", "value"=>"July 06, 2016"}, "1"=>{"field"=>"date", "operator"=>"eq", "value"=>""}}
    dynamic_filter_params = SurveyResponsesDataService::FilterResponses.dynamic_filter_params({:filter => {:filters => filter_params}})

    member_meeting_ids_after_date_filter = survey.date_filter(dynamic_filter_params)
    assert_equal member_meeting_ids_after_date_filter, [meetings(:past_calendar_meeting).member_meetings.where(:member_id => members(:f_mentor).id).first.id,meetings(:completed_calendar_meeting).member_meetings.where(:member_id => members(:f_mentor).id).first.id, meetings(:cancelled_calendar_meeting).member_meetings.where(:member_id => members(:f_mentor).id).first.id, m1.member_meetings.where(:member_id => members(:f_mentor).id).first.id, m2.member_meetings.where(:member_id => members(:not_requestable_mentor).id).first.id]
  end

  def test_engagement_role_filter
    program =  programs(:no_mentor_request_program)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, true)
    survey = surveys(:progress_report)
    group = groups(:no_mreq_group)
    mentoring_model = program.default_mentoring_model
    mentoring_model.update_attribute(:should_sync, true)
    group.update_attribute(:mentoring_model_id, mentoring_model.id)

    options = {:created_at => "July 04, 2016", :action_item_type => MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, :required => true, :action_item_id => survey.id, :group_id => group.id,:user => users(:no_mreq_mentor), :group => groups(:no_mreq_group)}

    task1 = create_mentoring_model_task(options)

    options.merge!(:user => users(:no_mreq_mentor))
    options.merge!(:group => groups(:no_mreq_group))
    task2 = create_mentoring_model_task(options)

    common_answer_1 = common_answers(:q3_name_answer_1)
    common_answer_2 = common_answers(:q3_from_answer_1)
    common_answer_1.update_attribute(:task_id, task1.id)
    common_answer_2.update_attribute(:task_id, task1.id)


    filter_params = {"0"=>{"field"=>"roles", "value"=>"mentor"}}
    SurveyAnswer.expects(:get_es_survey_answers).with({filter: {survey_id: survey.id, is_draft: false, user_id: [67, 68, 69], response_id: [1]}, source_columns: ["response_id"]}).returns([Elasticsearch::Model::HashWrapper.new(response_id: 1), Elasticsearch::Model::HashWrapper.new(response_id: 1)])

    srds = SurveyResponsesDataService.new(survey, {:filter => {:filters => filter_params}})
    dynamic_filter_params = SurveyResponsesDataService::FilterResponses.dynamic_filter_params({:filter => {:filters => filter_params}})
    task_ids_after_role_filter = survey.engagement_role_filter(dynamic_filter_params)

    assert_equal [task1.id, task2.id], task_ids_after_role_filter
  end

  def test_find_users_groups_with_overdue_responses
    program =  programs(:no_mentor_request_program)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, true)
    survey = surveys(:progress_report)
    group = groups(:no_mreq_group)
    mentoring_model = program.default_mentoring_model
    mentoring_model.update_attribute(:should_sync, true)
    group.update_attribute(:mentoring_model_id, mentoring_model.id)

    options = {:due_date => 3.weeks.ago, :created_at => "July 04, 2016", :action_item_type => MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, :required => true, :action_item_id => survey.id, :group_id => group.id,:user => users(:no_mreq_mentor), :group => groups(:no_mreq_group)}

    task1 = create_mentoring_model_task(options)

    options.merge!(:user => users(:no_mreq_mentor))
    options.merge!(:group => groups(:no_mreq_group))
    task2 = create_mentoring_model_task(options)

    filter_params = {"0"=>{"field"=>"roles", "value"=>"mentor"}, "1"=>{"field"=>"date", "operator"=>"eq", "value"=>"July 06, 2016"}, "2"=>{"field"=>"date", "operator"=>"eq", "value"=> 2.weeks.ago}, "3"=>{"field"=>"column3", "operator"=>"answered", "value"=>""}}

    start_time = Date.parse("July 06, 2016").to_datetime.change(offset: Time.current.strftime("%z")).strftime(ElasticsearchConstants::DATE_RANGE_FORMATS::FORMATS_HASH["yyyy-MM-dd HH:mm:ss ZZ"])
    end_time = 2.weeks.ago.to_datetime.end_of_day.change(offset: Time.current.strftime("%z")).strftime(ElasticsearchConstants::DATE_RANGE_FORMATS::FORMATS_HASH["yyyy-MM-dd HH:mm:ss ZZ"])
    SurveyAnswer.expects(:get_es_survey_answers).with({filter: {survey_id: survey.id, is_draft: false, last_answered_at: start_time..end_time, es_range_formats: {last_answered_at: "yyyy-MM-dd HH:mm:ss ZZ"}, user_id: [68, 69], response_id: [1]}, source_columns: ["response_id"]}).returns([])

    srds = SurveyResponsesDataService.new(survey, {:filter => {:filters => filter_params}})
    dynamic_filter_params = SurveyResponsesDataService::FilterResponses.dynamic_filter_params({:filter => {:filters => filter_params}})
    overdue_responses_count, overdue_task_ids = survey.calculate_overdue_responses(srds.user_ids, dynamic_filter_params)

    user_ids_count, group_ids_count = survey.find_users_groups_with_overdue_responses(overdue_task_ids)

    assert_equal 1, group_ids_count
    assert_equal 1, user_ids_count
    assert_equal 2, overdue_responses_count
  end

  def test_find_total_member_meeting_ids
    program = programs(:albers)
    survey = MeetingFeedbackSurvey.create!(program_id: program.id, name: "Something", role_name: RoleConstants::STUDENT_NAME)
    time = 4.weeks.ago.change(:usec => 0)
    m1 = create_meeting({:program => program, :topic => "Arbit Topic", :start_time => time, :end_time => (time + 30.minutes), :location => "Chennai", :members => [members(:f_mentor), members(:mkr_student)], :owner_id => members(:f_mentor).id, :force_non_group_meeting => true})
    time = 5.weeks.ago.change(:usec => 0)
    user2 = members(:not_requestable_mentor).user_in_program(program)
    m2 = create_meeting({:program => program, :topic => "Arbit Topic2", :start_time => time, :end_time => (time + 30.minutes), :members => [members(:student_2), members(:not_requestable_mentor)], :requesting_student => users(:student_2), :requesting_mentor => user2, :force_non_group_meeting => true, owner_id: members(:student_2).id})

    meeting_ids = [m1.id, m2.id]
    total_member_meetings = MemberMeeting.where(:meeting_id => meeting_ids)
    total_member_meeting_ids = survey.find_total_member_meeting_ids(total_member_meetings)
    assert_equal_unordered [m1.member_meetings.where(:member_id => members(:mkr_student).id).first.id, m2.member_meetings.where(:member_id => members(:student_2).id).first.id], total_member_meeting_ids
  end

  def test_show_response_rates
    program = programs(:albers)
    survey = MeetingFeedbackSurvey.create!(program_id: program.id, name: "Something", role_name: RoleConstants::STUDENT_NAME)
    assert_equal true, survey.show_response_rates?

    survey = surveys(:two)
    assert_equal true, survey.show_response_rates?

    survey = surveys(:one)
    assert_false survey.show_response_rates?
  end

  def test_compact_choices_allow_other_option
    survey = create_program_survey
    q1 = create_survey_question(
      {question_type: CommonQuestion::Type::MULTI_CHOICE, allow_other_option: true,
        question_choices: "A,B,C", survey: survey})

    a = create_survey_answer({answer_value: {answer_text: "A, B,c,F, G,H,K", question: q1, from_import: true}, user: users(:f_student), survey_question: q1})

    assert_equal "A, B, c, F, G, H, K", a.selected_choices_to_str
  end

  def test_get_answers_and_user_names
    survey = create_program_survey
    q1 = create_survey_question(
      {question_type: CommonQuestion::Type::SINGLE_CHOICE,
        question_choices: "get,set,go", survey: survey})
    q2 = create_survey_question({
        question_type: CommonQuestion::Type::RATING_SCALE,
        question_choices: "bad,good,better,best", survey: survey})
    q3 = create_survey_question({survey: survey})

    result = survey.get_answers_and_user_names(survey.survey_questions.pluck(:id), " ", " ", survey.program_id)
    assert result.empty?

    response_ids = []
    mentor = users(:f_mentor)
    options1 = {:user_id => mentor.id}
    question_answer_map1 = {q1.id => "set", q2.id => "good", q3.id => "text"}
    survey.update_user_answers(question_answer_map1, options1)
    response_id = SurveyAnswer.last.response_id
    response_ids << response_id

    student = users(:f_student)
    options2 = {:user_id => student.id}
    question_answer_map2 = {q1.id => "set", q3.id => "text"}
    survey.update_user_answers(question_answer_map2, options2)
    response_ids << SurveyAnswer.last.response_id

    mentor_student = users(:f_mentor_student)
    options3 = {:user_id => mentor_student.id}
    question_answer_map3 = {q1.id => "set", q2.id => "good"}
    survey.update_user_answers(question_answer_map3, options3)
    response_ids << SurveyAnswer.last.response_id

    combined_answer_string = {}
    ques_id_ans_sep = "---"
    ans_sep = "~~~"
    combined_answer_string[mentor.email] = q1.id.to_s + ques_id_ans_sep + question_answer_map1[q1.id] + ans_sep +
                                            q2.id.to_s + ques_id_ans_sep + question_answer_map1[q2.id]  + ans_sep +
                                            q3.id.to_s + ques_id_ans_sep + question_answer_map1[q3.id]

    combined_answer_string[student.email] = q1.id.to_s + ques_id_ans_sep + question_answer_map2[q1.id]  + ans_sep +
                                            q3.id.to_s + ques_id_ans_sep + question_answer_map2[q3.id]

    combined_answer_string[mentor_student.email] = q1.id.to_s + ques_id_ans_sep + question_answer_map3[q1.id]  + ans_sep +
                                            q2.id.to_s + ques_id_ans_sep + question_answer_map3[q2.id]

    name = {}
    name[mentor.email] = mentor.name
    name[student.email] = student.name
    name[mentor_student.email] = mentor_student.name

    result = survey.get_answers_and_user_names(survey.survey_questions.pluck(:id), ques_id_ans_sep, ans_sep, survey.program_id, is_engagement_survey: false, response_ids: response_ids)
    result.each do |user_ans|
      assert_equal name[user_ans.email], user_ans.name
      assert_equal combined_answer_string[user_ans.email], user_ans.answers
    end

    result = survey.get_answers_and_user_names([], ques_id_ans_sep, ans_sep, survey.program_id)
    all_responses = ActiveRecord::Base.connection.select_all(result)
    assert_false all_responses.columns.include?("answers")
    assert_equal_unordered ["email", "name", "member_id", "timestamp", "response_id", "user_roles"], all_responses.columns

    results = survey.get_answers_and_user_names(survey.survey_questions.pluck(:id), ques_id_ans_sep, ans_sep, survey.program_id, is_engagement_survey: false, response_ids: [])
    assert results.empty?
    results = survey.get_answers_and_user_names(survey.survey_questions.pluck(:id), ques_id_ans_sep, ans_sep, survey.program_id, is_engagement_survey: false, response_ids: [response_id])
    assert_equal "#{q1.id}---set~~~#{q2.id}---good~~~#{q3.id}---text", results.first.answers
    assert_equal response_id, results.first["response_id"] #checking response id is returned as part of the result
  end

  def test_get_answers_and_user_names_meeting_feedback_survey
    program = programs(:albers)
    survey = program.get_meeting_feedback_survey_for_role(RoleConstants::MENTOR_NAME)
    time = 2.days.ago
    meeting = create_meeting(:recurrent => true, :repeat_every => 1, :schedule_rule => Meeting::Repeats::DAILY, :members => [members(:f_admin), members(:mkr_student)], :owner_id => members(:mkr_student).id, :program_id => programs(:albers).id, :repeats_end_date => time + 4.days, :start_time => time, :end_time => time + 5.hours)
    member_meeting = meeting.member_meetings.find_by(member_id: members(:mkr_student))
    question_id = survey.survey_questions.pluck(:id)
    assert_equal [], meeting.survey_answers
    survey.update_user_answers({question_id[0] => "Slightly satisfying", question_id[1] => "Poor use of time", question_id[2] => "Attendee no-show", question_id[3] => "text"}, {user_id: users(:mkr_student).id, :meeting_occurrence_time => meeting.occurrences.first.start_time, member_meeting_id: member_meeting.id})
    ques_id_ans_sep = "---"
    ans_sep = "~~~"
    response_id = SurveyAnswer.last.response_id
    result = survey.get_answers_and_user_names(survey.survey_questions.pluck(:id), ques_id_ans_sep, ans_sep, survey.program_id, is_engagement_survey: false, response_ids: [response_id])
    result.each do |user_ans|
      assert user_ans["member_meeting_id"].present?
    end
  end

  def test_update_total_responses
    #TODO: move to fixtures
    survey = surveys(:one)
    assert_equal 0, survey.total_responses
    q1 = create_survey_question(
      {:question_type => CommonQuestion::Type::SINGLE_CHOICE,
        :question_choices => "get,set,go", :survey => survey})
    q2 = create_survey_question({
        :question_type => CommonQuestion::Type::RATING_SCALE,
        :question_choices => "bad,good,better,best", :survey => survey})
    q3 = create_survey_question({:survey => survey})

    result = survey.get_answers_and_user_names(survey.survey_questions.pluck(:id), " ", " ", survey.program_id)
    assert result.empty?

    mentor = users(:f_mentor)
    options1 = {:user_id => mentor.id}
    question_answer_map1 = {q1.id => "set", q2.id => "good", q3.id => "text"}
    survey.update_user_answers(question_answer_map1, options1)
    student = users(:f_student)
    options2 = {:user_id => student.id}
    question_answer_map2 = {q1.id => "set", q3.id => "text"}
    survey.update_user_answers(question_answer_map2, options2)

    assert_equal 2, survey.total_responses
    survey.update_attributes(:total_responses => 0)
    survey.update_total_responses!
    assert_equal 2, survey.total_responses
  end

  def test_update_total_responses_for_survey
    survey = surveys(:one)
    assert_equal 0, survey.total_responses
    q1 = create_survey_question(
      {:question_type => CommonQuestion::Type::SINGLE_CHOICE,
        :question_choices => "get,set,go", :survey => survey})

    result = survey.get_answers_and_user_names(survey.survey_questions.pluck(:id), " ", " ", survey.program_id)
    assert result.empty?

    mentor = users(:f_mentor)
    options1 = {:user_id => mentor.id}
    question_answer_map1 = {q1.id => "set"}
    survey.update_user_answers(question_answer_map1, options1)
    assert_equal 1, survey.total_responses
    survey.survey_answers.first.destroy
    assert_equal 0, survey.reload.total_responses
  end

  def test_update_total_responses_for_survey_when_survey_is_not_found
    survey = surveys(:one)
    assert_equal 0, survey.total_responses
    q1 = create_survey_question(
      {:question_type => CommonQuestion::Type::SINGLE_CHOICE,
        :question_choices => "get,set,go", :survey => survey})

    result = survey.get_answers_and_user_names(survey.survey_questions.pluck(:id), " ", " ", survey.program_id)
    assert result.empty?

    mentor = users(:f_mentor)
    options1 = {:user_id => mentor.id}
    question_answer_map1 = {q1.id => "set"}
    survey.update_user_answers(question_answer_map1, options1)
    assert_equal 1, survey.total_responses
    survey_answer = survey.survey_answers.first
    Survey.expects(:find_by).with({id: survey.id}).returns(nil)
    survey_answer.destroy
  end


  def test_has_many_survey_questions
    s = surveys(:one)
    assert s.survey_questions.empty?

    q1 = create_survey_question({:survey => s})
    q2 = create_survey_question({:survey => s})
    q3 = create_survey_question({:survey => s})
    q1.insert_at 5
    q2.insert_at 3
    q3.insert_at 7

    assert_equal [q2, q1, q3], s.survey_questions.reload
  end

  def test_dependent_destroy_questions
    s = surveys(:one)

    q1 = create_survey_question({:survey => s})
    q2 = create_survey_question({:survey => s})
    q3 = create_survey_question({:survey => s})

    assert_equal [q1, q2, q3], s.survey_questions.reload
    assert_difference 'SurveyQuestion.count', -3 do
      s.destroy
    end
  end

  def test_update_user_answers_failure
    s = surveys(:one)

    q1 = create_survey_question({:survey => s})
    q2 = create_survey_question(
      {:question_type => CommonQuestion::Type::SINGLE_CHOICE,
        :question_choices => "get,set,go", :survey => s})

    assert q1.survey_answers.empty?
    assert q2.survey_answers.empty?

    # XXX Though not the right experience, q1 answer is saved though q2 answer
    # has error.
    assert_difference 'SurveyAnswer.count', 1 do
      assert_difference "s.reload.total_responses", 1 do
        options = {:user_id => users(:f_mentor).id}
        assert_equal [false, q2, options],
          s.update_user_answers({q1.id => "First answer", q2.id => "wrong answer"}, options)
      end
    end

    assert_false q1.survey_answers.reload.empty?
    assert q2.survey_answers.reload.empty?
  end

  def test_update_user_answers_failure_required_field_blank
    s = surveys(:one)

    q1 = create_survey_question({:required => true, :survey => s})
    q2 = create_survey_question(
      {:question_type => CommonQuestion::Type::SINGLE_CHOICE,
        :question_choices => "get,set,go", :survey => s})
    q3 = create_survey_question({:survey => s})

    assert q1.required?
    assert q1.survey_answers.empty?
    assert q2.survey_answers.empty?

    assert_no_difference 'SurveyAnswer.count' do
      options = {:user_id => users(:f_mentor).id}
      assert_equal [false, q1,options], s.update_user_answers(
        {q1.id => "",
         q2.id => "get",
         q3.id => 'Good answer'}, options)
    end
  end

  def test_update_user_answers_success
    s = surveys(:one)

    q1 = create_survey_question({:survey => s})
    q2 = create_survey_question({:survey => s})
    q3 = create_survey_question(
      {:question_type => CommonQuestion::Type::SINGLE_CHOICE,
        :question_choices => "get,set,go", :survey => s})
    q4 = create_survey_question(
      {:question_type => CommonQuestion::Type::SINGLE_CHOICE,
        :question_choices => "yes,but,no", :survey => s})
    q5 = create_survey_question({:survey => s})

    assert q1.survey_answers.empty?
    assert q2.survey_answers.empty?
    assert q3.survey_answers.empty?

    assert_difference 'SurveyAnswer.count', 3 do
      options = {:user_id => users(:f_mentor).id}
      assert s.update_user_answers(
        {q1.id => "First answer",
         q2.id => "Second answer",
         q3.id => "get",
         q4.id => "",
         q5.id => ""}, options)
    end

    assert_equal 1, q1.survey_answers.reload.count
    assert_equal 1, q2.survey_answers.reload.count
    assert_equal 1, q3.survey_answers.reload.count
    assert q4.survey_answers.reload.empty?
    assert q5.survey_answers.reload.empty?

    q1_answer = q1.survey_answers.first
    q2_answer = q2.survey_answers.first
    q3_answer = q3.survey_answers.first

    assert_equal "First answer", q1_answer.answer_text

    assert_equal users(:f_mentor), q1_answer.user

    assert_equal "Second answer", q2_answer.answer_text
    assert_equal users(:f_mentor), q2_answer.user

    assert_equal "get", q3_answer.answer_text
    assert_equal users(:f_mentor), q3_answer.user
  end

  def test_has_many_answers
    survey = surveys(:one)
    assert survey.survey_answers.empty?

    questions = []
    questions << create_survey_question({:survey => survey})
    questions << create_survey_question({:survey => survey})

    questions << create_survey_question({
        :question_type => CommonQuestion::Type::RATING_SCALE,
        :question_choices => "bad,good,better,best", :survey => survey})

    answers = []
    answers << create_survey_answer({:answer_text => "the", :user => users(:f_student), :survey_question => questions[0]})
    answers << create_survey_answer({:answer_text => "sand", :user => users(:f_mentor), :survey_question => questions[0]})
    answers << create_survey_answer({:answer_text => "the", :user => users(:f_student), :survey_question => questions[1]})

    survey.survey_answers.reload
    assert_equal answers, survey.survey_answers
  end

  def test_program_survey_response
    survey = surveys(:one)
    q1 = create_survey_question(
      {:question_type => CommonQuestion::Type::SINGLE_CHOICE,
        :question_choices => "get,set,go", :survey => survey})
    q2 = create_survey_question({
        :question_type => CommonQuestion::Type::RATING_SCALE,
        :question_choices => "bad,good,better,best", :survey => survey})
    q3 = create_survey_question({:survey => survey})
    q4 = survey.survey_questions.new(:question_type => CommonQuestion::Type::MATRIX_RATING, :matrix_setting => CommonQuestion::MatrixSetting::FORCED_RANKING, :program_id => survey.program.id, :question_text => "Matrix Question")
    "Bad,Average,Good".split(",").each_with_index{|text, i| q4.question_choices.build(text: text, position: i+1, ref_obj: q4)}
    q4.row_choices_for_matrix_question = "Ability,Confidence,Talent"
    q4.create_survey_question
    q4.save

    mq = q4.rating_questions.first

    survey_response = Survey::SurveyResponse.new(survey, {:user_id => users(:f_student).id})
    assert_equal survey_response.survey, survey
    assert_nil survey_response.id
    assert_equal [q1,q2,q3,q4], survey_response.instance_variable_get("@questions")
    assert_equal ({:user_id => users(:f_student).id}), survey_response.instance_variable_get("@options")
    assert_equal [nil,nil,nil,nil], survey_response.instance_variable_get("@question_answer_map").values.collect(&:answer_text)
    assert_equal  [nil,nil, nil], survey_response.instance_variable_get("@matrix_question_answers_map").values.collect(&:answer_text)
    r_id = SurveyAnswer.unscoped.maximum(:response_id).to_i+1

    survey_response.save_answers({q1.id => "set", q2.id => "good", q3.id => "text", mq.id => "average"})
    assert_equal r_id, survey_response.id
    assert_equal [q1,q2,q3,q4], survey_response.instance_variable_get("@questions")
    assert_equal ({:user_id => users(:f_student).id, :response_id => r_id}), survey_response.instance_variable_get("@options")
    assert_equal  ["set","good", "text", nil], survey_response.instance_variable_get("@question_answer_map").values.collect(&:answer_text)
    assert_equal  ["average",nil, nil], survey_response.instance_variable_get("@matrix_question_answers_map").values.collect(&:answer_text)
    assert_equal survey.total_responses, 1

    survey_response2 = Survey::SurveyResponse.new(survey, {:user_id => users(:f_student).id})
    assert_difference "SurveyAnswer.count", 3 do
      survey_response2.save_answers({q1.id => "get", q2.id => "bad", q3.id => "text2"})
    end
    assert_equal survey.total_responses, 2
    assert_equal [], SurveyAnswer.where(is_draft: nil)
  end

  def test_draft_survey_response
    survey = surveys(:one)
    q1 = create_survey_question(
      {question_type: CommonQuestion::Type::SINGLE_CHOICE,
        question_choices: "get,set,go", survey: survey})
    q2 = create_survey_question({
        question_type: CommonQuestion::Type::RATING_SCALE,
        question_choices: "bad,good,better,best", survey: survey})
    q3 = create_survey_question({survey: survey})

    survey_response = Survey::SurveyResponse.new(survey, {:user_id => users(:f_student).id, is_draft: true})
    assert_equal survey_response.survey, survey
    assert_nil survey_response.id
    assert_equal [q1,q2,q3], survey_response.instance_variable_get("@questions")
    assert_equal ({:user_id => users(:f_student).id}), survey_response.instance_variable_get("@options")
    assert survey_response.instance_variable_get("@is_draft")
    assert_false survey_response.instance_variable_get("@was_draft")
    assert_equal [nil,nil,nil], survey_response.instance_variable_get("@question_answer_map").values.collect(&:answer_text)

    r_id = SurveyAnswer.unscoped.maximum(:response_id).to_i+1
    d_a_c = SurveyAnswer.drafted.count
    survey_response.save_answers({q1.id => "set", q2.id => "good", q3.id => "text"})
    assert_equal r_id, survey_response.id
    assert_equal [q1,q2,q3], survey_response.instance_variable_get("@questions")
    assert_equal ({:user_id => users(:f_student).id, :response_id => r_id}), survey_response.instance_variable_get("@options")
    assert_equal  ["set","good", "text"], survey_response.instance_variable_get("@question_answer_map").values.collect(&:answer_text)
    assert survey_response.instance_variable_get("@question_answer_map").values.all?(&:persisted?)
    assert_equal 0, survey.total_responses
    assert_equal d_a_c+3, SurveyAnswer.drafted.count

    survey_response2 = Survey::SurveyResponse.new(survey, {:user_id => users(:f_student).id, response_id: survey_response.id})
    assert_equal ({:user_id => users(:f_student).id, :response_id => survey_response.id}), survey_response2.instance_variable_get("@options")
    assert_false survey_response2.instance_variable_get("@is_draft")
    assert survey_response2.instance_variable_get("@was_draft")
    d_a_c = SurveyAnswer.drafted.count
    survey_response2.save_answers({q1.id => "get", q2.id => "bad", q3.id => "not text"})
    assert_equal [q1,q2,q3], survey_response2.instance_variable_get("@questions")
    assert_equal ({:user_id => users(:f_student).id, :response_id => survey_response.id}), survey_response2.instance_variable_get("@options")
    assert_equal  ["get","bad", "not text"], survey_response2.instance_variable_get("@question_answer_map").values.collect(&:answer_text)
    assert survey_response2.instance_variable_get("@question_answer_map").values.all?(&:persisted?)
    assert_equal 1, survey.total_responses
    assert_equal d_a_c-3, SurveyAnswer.drafted.count
  end


  def test_engagement_survey_response
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, true)
    survey = surveys(:two)
    group = groups(:group_5)
    mentoring_model = program.default_mentoring_model
    mentoring_model.update_attribute(:should_sync, true)
    group.update_attribute(:mentoring_model_id, mentoring_model.id)
    tem_task1 = create_mentoring_model_engagement_survey_task_template(role_id: program.roles.find{|r| r.name == RoleConstants::STUDENT_NAME }.id, :action_item_id => survey.id)
    task = group.mentoring_model_tasks.reload.where(:action_item_type => MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY).first

    q1,q2,q3 = common_questions(:q2_name),common_questions(:q2_location),common_questions(:q2_from)
    survey_response = Survey::SurveyResponse.new(survey, {:user_id => users(:f_student).id, :task_id => task.id})
    assert_equal survey_response.survey, survey
    assert_nil survey_response.id
    assert_equal [q1,q2,q3], survey_response.instance_variable_get("@questions")
    assert_equal ({:user_id => users(:f_student).id, :task_id => task.id}), survey_response.instance_variable_get("@options")
    assert_equal [nil,nil,nil], survey_response.instance_variable_get("@question_answer_map").values.collect(&:answer_text)
    r_id = SurveyAnswer.unscoped.maximum(:response_id).to_i+1

    survey_response.save_answers({q1.id => ["Clark Kent", "Superman", "Kal-El"], q2.id => "Smallville", q3.id => "Krypton"})
    assert_equal r_id, survey_response.id
    assert_equal ({:user_id => users(:f_student).id, :task_id => task.id,  :response_id => r_id}), survey_response.instance_variable_get("@options")
    assert_equal  ["Clark Kent\n Superman\n Kal-El", "Smallville", "Krypton"], survey_response.instance_variable_get("@question_answer_map").values.collect(&:answer_text)
    assert survey_response.instance_variable_get("@question_answer_map").values.all?(&:persisted?)
    assert_equal 1, survey.total_responses

    survey_response2 = Survey::SurveyResponse.new(survey, {:user_id => users(:f_student).id, :task_id => task.id})
    assert_no_difference "SurveyAnswer.count" do
      survey_response2.save_answers({q1.id => ["Bruce Wayne", "Batman"], q2.id => "Gotham", q3.id => "Earth"})
    end
    assert_equal 1, survey.total_responses
    assert_equal "Earth", SurveyAnswer.last.answer_text
  end

  def test_meeting_feedback_survey_response
    program = programs(:albers)
    survey = program.get_meeting_feedback_survey_for_role(RoleConstants::MENTOR_NAME)
    meeting = meetings(:f_mentor_mkr_student)
    member_meeting = meeting.get_member_meeting_for_role(RoleConstants::MENTOR_NAME)
    meeting.update_attribute(:state, Meeting::State::COMPLETED)
    user = users(:f_mentor)

    q_always = survey.survey_questions.find_by(condition: SurveyQuestion::Condition::ALWAYS)
    q_completed = survey.survey_questions.find_by(condition: SurveyQuestion::Condition::COMPLETED)
    q_cancelled = survey.survey_questions.find_by(condition: SurveyQuestion::Condition::CANCELLED)
    q_always.update_attribute(:required, true)
    q_completed.update_attribute(:required, true)
    q_cancelled.update_attribute(:required, true)
    survey.survey_questions.where.not(id: [q_always.id, q_completed.id, q_cancelled.id]).destroy_all
    survey_response = Survey::SurveyResponse.new(survey, {:user_id => user.id, :member_meeting_id => member_meeting.id, meeting_occurrence_time: meeting.first_occurrence})
    assert_equal survey_response.survey, survey
    assert_nil survey_response.id
    assert_equal ({:user_id => user.id, :member_meeting_id => member_meeting.id, meeting_occurrence_time: meeting.first_occurrence}), survey_response.instance_variable_get("@options")
    r_id = SurveyAnswer.unscoped.maximum(:response_id).to_i+1
    sa_count = SurveyAnswer.count

    result = survey_response.save_answers({q_always.id => "Feedback"})
    assert_equal r_id, survey_response.id
    assert_equal 0, survey.total_responses
    assert_false result[0]
    assert_equal q_completed.id, result[1].id
    assert_equal sa_count, SurveyAnswer.count

    survey_response = Survey::SurveyResponse.new(survey, {:user_id => user.id, :member_meeting_id => member_meeting.id, meeting_occurrence_time: meeting.first_occurrence})
    result = survey_response.save_answers({q_completed.id => "Extremely satisfying"})
    assert_equal r_id, survey_response.id
    assert_equal 1, survey.total_responses
    assert_false result[0]
    assert_equal q_always.id, result[1].id
    assert_equal sa_count + 1, SurveyAnswer.count
    assert_equal 1, survey.survey_answers.count

    survey_response = Survey::SurveyResponse.new(survey, {:user_id => user.id, :member_meeting_id => member_meeting.id, meeting_occurrence_time: meeting.first_occurrence})
    result = survey_response.save_answers({q_completed.id => "Extremely satisfying", q_always.id => "Feedback", q_cancelled.id => "Meeting never scheduled"})
    assert_equal r_id, survey_response.id
    assert_equal 1, survey.total_responses
    assert result
    assert_equal sa_count + 2, SurveyAnswer.count
    assert_equal 2, survey.survey_answers.count
  end

  def test_get_report_multichoice_score
    survey = surveys(:one)
    question = create_survey_question(
      question_type: CommonQuestion::Type::MULTI_CHOICE,
      allow_other_option: true,
      question_choices: "A,B,C",
      survey: survey
    )
    create_survey_answer(answer_value: {answer_text: ["A","B","something","something"], question: question}, user: users(:f_student), survey_question: question)
    create_survey_answer(answer_value: {answer_text: ["B","C","Anything"], question: question}, user: users(:f_mentor), survey_question: question)
    choices_hash = question.question_choices.index_by(&:text)
    report_data = survey.get_report
    assert_floats_equal 50.0, report_data.get_response(question).data[choices_hash["A"].id]
    assert_floats_equal 100.0, report_data.get_response(question).data[choices_hash["B"].id]
    assert_floats_equal 50.0, report_data.get_response(question).data[choices_hash["C"].id]
    assert_floats_equal 100.0, report_data.get_response(question).data["other"]
  end

  def test_get_report_should_generate_report_in_corresponding_locale
    # No questions
    survey = surveys(:one)
    assert survey.survey_questions.empty?
    report_data = survey.get_report
    assert report_data.empty?

    # Questions without answers
    questions = []
    questions << create_survey_question(survey: survey)
    questions << create_survey_question(survey: survey)
    questions << create_survey_question(
      question_type: CommonQuestion::Type::SINGLE_CHOICE,
      allow_other_option: true,
      question_choices: "get,set,go",
      survey: survey
    )
    questions << create_survey_question(
      question_type: CommonQuestion::Type::RATING_SCALE,
      question_choices: "bad,good,better,best",
      survey: survey
    )
    run_in_another_locale(:'fr-CA') do
      q2_texts = ["Fget","Fset","Fgo"]
      questions[2].question_choices.each {|qc| qc.update_attributes!(text: q2_texts.shift)}
      q3_texts = ["Fbad","Fgood","Fbetter","Fbest"]
      questions[3].question_choices.each {|qc| qc.update_attributes!(text: q3_texts.shift)}
    end
    survey.survey_questions.reload
    report_data = survey.get_report
    assert_equal(0, report_data.get_response(questions[0]).count)
    assert report_data.get_response(questions[0]).data.empty?
    assert_equal(0, report_data.get_response(questions[1]).count)
    assert report_data.get_response(questions[1]).data.empty?
    assert_equal(0, report_data.get_response(questions[2]).count)
    choices_hash = questions[2].question_choices.index_by(&:text)
    assert_equal( { choices_hash["get"].id => 0.0, choices_hash["set"].id => 0.0, choices_hash["go"].id => 0.0, "other" => 0.0 }, report_data.get_response(questions[2]).data)
    assert_equal(0, report_data.get_response(questions[3]).count)
    choices_hash = questions[3].question_choices.index_by(&:text)

    assert_equal( { choices_hash["good"].id => 0.0, choices_hash["best"].id => 0.0, choices_hash["better"].id => 0.0, choices_hash["bad"].id => 0.0 }, report_data.get_response(questions[3]).data)
    run_in_another_locale(:'fr-CA') do
      report_data = survey.get_report
      assert_equal(0, report_data.get_response(questions[0]).count)
      assert report_data.get_response(questions[0]).data.empty?
      assert_equal(0, report_data.get_response(questions[1]).count)
      assert report_data.get_response(questions[1]).data.empty?
      assert_equal(0, report_data.get_response(questions[2]).count)
      choices_hash = questions[2].question_choices.index_by(&:text)
      assert_equal( { choices_hash["Fget"].id => 0.0, choices_hash["Fset"].id => 0.0, choices_hash["Fgo"].id => 0.0, "other" => 0.0 }, report_data.get_response(questions[2]).data)
      choices_hash = questions[3].question_choices.index_by(&:text)
      assert_equal(0, report_data.get_response(questions[3]).count)
      assert_equal( { choices_hash["Fgood"].id => 0.0, choices_hash["Fbest"].id => 0.0, choices_hash["Fbetter"].id => 0.0, choices_hash["Fbad"].id => 0.0 }, report_data.get_response(questions[3]).data)
    end

    # With answers
    create_survey_answer(answer_text: "the", user: users(:f_student), survey_question: questions[0])
    create_survey_answer(answer_text: "sand", user: users(:f_mentor), survey_question: questions[0])
    create_survey_answer(answer_text: "great", user: users(:f_student), survey_question: questions[1])
    create_survey_answer(answer_text: "water", user: users(:f_mentor), survey_question: questions[1])
    create_survey_answer(answer_value: {answer_text: "get", question: questions[2]}, user: users(:f_student), survey_question: questions[2])
    create_survey_answer(answer_value: {answer_text: "set", question: questions[2]}, user: users(:robert), survey_question: questions[2])
    create_survey_answer(answer_value: {answer_text: "go", question: questions[2]}, user: users(:student_1), survey_question: questions[2])
    create_survey_answer(answer_value: {answer_text: "set", question: questions[2]}, user: users(:mentor_1), survey_question: questions[2])
    create_survey_answer(answer_value: {answer_text: "random,no,random", question: questions[2], from_import: true}, user: users(:f_mentor), survey_question: questions[2])
    create_survey_answer(answer_value: {answer_text: "good", question: questions[3]}, user: users(:mentor_3), survey_question: questions[3])
    create_survey_answer(answer_value: {answer_text: "good", question: questions[3]}, user: users(:robert), survey_question: questions[3])
    create_survey_answer(answer_value: {answer_text: "best", question: questions[3]}, user: users(:student_1), survey_question: questions[3])
    create_survey_answer(answer_value: {answer_text: "good", question: questions[3]}, user: users(:mentor_1), survey_question: questions[3])
    survey.survey_answers.reload
    report_data = survey.get_report
    assert_equal(2, report_data.get_response(questions[0]).count)
    assert_equal(["the", "sand"], report_data.get_response(questions[0]).data)
    assert_equal(2, report_data.get_response(questions[1]).count)
    assert_equal(["great", "water"], report_data.get_response(questions[1]).data)
    assert_equal(5, report_data.get_response(questions[2]).count)
    choices_hash = questions[2].question_choices.index_by(&:text)
    assert_equal( { choices_hash["get"].id => 1 / 5.0 * 100.0, choices_hash["set"].id => 2 / 5.0 * 100.0, choices_hash["go"].id => 1 / 5.0 * 100.0, "other" => 1 / 5.0 * 100.0 }, report_data.get_response(questions[2]).data)
    assert_equal(4, report_data.get_response(questions[3]).count)
    choices_hash = questions[3].question_choices.index_by(&:text)
    assert_equal( { choices_hash["good"].id => 3 / 4.0 * 100.0, choices_hash["best"].id => 1 / 4.0 * 100.0, choices_hash["better"].id => 0.0, choices_hash["bad"].id => 0.0 }, report_data.get_response(questions[3]).data)
    run_in_another_locale(:'fr-CA') do
      report_data = survey.get_report
      assert_equal(2, report_data.get_response(questions[0]).count)
      assert_equal(["the", "sand"], report_data.get_response(questions[0]).data)
      assert_equal(2, report_data.get_response(questions[1]).count)
      assert_equal(["great", "water"], report_data.get_response(questions[1]).data)
      assert_equal(5, report_data.get_response(questions[2]).count)
      choices_hash = questions[2].question_choices.index_by(&:text)
      assert_equal( { choices_hash["Fget"].id => 1 / 5.0 * 100.0, choices_hash["Fset"].id => 2 / 5.0 * 100.0, choices_hash["Fgo"].id => 1 / 5.0 * 100.0, "other" => 1 / 5.0 * 100.0 }, report_data.get_response(questions[2]).data)
      assert_equal(4, report_data.get_response(questions[3]).count)
      choices_hash = questions[3].question_choices.index_by(&:text)
      assert_equal( { choices_hash["Fgood"].id => 3 / 4.0 * 100.0, choices_hash["Fbest"].id => 1 / 4.0 * 100.0, choices_hash["Fbetter"].id => 0.0, choices_hash["Fbad"].id => 0.0 }, report_data.get_response(questions[3]).data)
    end

    report_data = survey.get_report(export: true)
    data = report_data.question_responses
    data.each do |survey_question, report|
      assert_equal ["Please refer next sheet for more details"], report.data unless survey_question.choice_based?
    end

    report_data = survey.get_report(export: true, response_ids: [])
    data = report_data.question_responses
    data.each do |survey_question, report|
      assert_equal [], report.data unless survey_question.choice_based?
      assert_equal [0], report.data.values.uniq if survey_question.choice_based?
    end
  end

  def test_allowed_to_attend_engagement_survey
    survey = surveys(:two)
    task = create_mentoring_model_task(action_item_id: surveys(:two).id, action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY)
    user = users(:f_mentor)
    group = user.groups.active.first

    assert_false survey.allowed_to_attend?(user)
    assert_false survey.allowed_to_attend?(users(:f_admin), task)
    assert_false survey.allowed_to_attend?(users(:mkr_student), task)
    assert survey.allowed_to_attend?(user, task)
    assert survey.allowed_to_attend?(user, nil, group)
    assert_false survey.allowed_to_attend?(user, nil, Group.last)
  end

  def test_is_feedback_survey
    survey = surveys(:two)
    assert_false survey.is_feedback_survey?

    survey.program.feedback_survey.update_attribute(:form_type, nil)
    survey.update_attribute(:form_type, Survey::FormType::FEEDBACK)
    assert survey.is_feedback_survey?
  end

  def test_allowed_to_attend_feedback_survey
    survey = programs(:albers).feedback_survey
    group = groups(:mygroup)

    assert_false survey.allowed_to_attend?(users(:mkr_student))
    assert_false survey.allowed_to_attend?(users(:f_student), nil, group)
    assert survey.allowed_to_attend?(users(:f_mentor), nil, group)
  end

  def test_allowed_to_attend_meeting_feedback_survey
    mentor_survey = programs(:albers).get_meeting_feedback_survey_for_role(RoleConstants::MENTOR_NAME)
    mentee_survey = programs(:albers).get_meeting_feedback_survey_for_role(RoleConstants::STUDENT_NAME)
    time = 2.days.ago
    meeting = create_meeting(:recurrent => true, :repeat_every => 1, :schedule_rule => Meeting::Repeats::DAILY, :members => [members(:f_admin), members(:mkr_student)], :owner_id => members(:mkr_student).id, :program_id => programs(:albers).id, :repeats_end_date => time + 4.days, :start_time => time, :end_time => time + 5.hours)
    member_meeting = meeting.member_meetings.find_by(member_id: members(:mkr_student))
    assert mentee_survey.allowed_to_attend?(users(:mkr_student), nil, nil, nil, {member_meeting: member_meeting, meeting_timing: meeting.occurrences.first})
    assert_false mentor_survey.allowed_to_attend?(users(:mkr_student), nil, nil, nil, {member_meeting: member_meeting, meeting_timing: meeting.occurrences.first})
    assert_false mentee_survey.allowed_to_attend?(users(:f_mentor), nil, nil, nil, {member_meeting: member_meeting, meeting_timing: meeting.occurrences.first})
    assert_false mentee_survey.allowed_to_attend?(users(:mkr_student), nil, nil, nil, {member_meeting: member_meeting, meeting_timing: meeting.occurrences.last})
    assert_false mentee_survey.allowed_to_attend?(users(:mkr_student), nil, nil, nil, {member_meeting: meetings(:f_mentor_mkr_student).member_meetings.first, meeting_timing: meeting.occurrences.first})
  end

  def test_validate_feedback_survey
    program = programs(:albers)
    assert program.feedback_survey
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :form_type, "The program can have only one feedback survey." do
      surveys(:two).update_attributes!(form_type: Survey::FormType::FEEDBACK)
    end
    program.feedback_survey.update_attribute(:form_type, nil)
    assert_nothing_raised do
      surveys(:two).update_attributes!(form_type: Survey::FormType::FEEDBACK)
    end
  end

  def test_survey_answer_last_answered_at
    survey = surveys(:one)
    q1 = create_survey_question(
      {question_type: CommonQuestion::Type::SINGLE_CHOICE,
        question_choices: "one,two,three", survey: survey})
    r_id = SurveyAnswer.unscoped.maximum(:response_id).to_i+1

    survey_response = Survey::SurveyResponse.new(survey, {:user_id => users(:f_student).id})
    assert_equal survey_response.survey, survey
    assert_nil survey_response.id
    survey_response.save_answers({q1.id => "one"})
    survey_answer = q1.survey_answers.last
    assert_equal r_id, survey_response.id
    assert_not_nil survey_answer.last_answered_at
    time_traveller(1.day.from_now) do
      survey_answer.update_attributes!(answer_text: "three")
    end
    survey_answer.reload
    assert_not_equal survey_answer.updated_at, survey_answer.last_answered_at
  end

  def test_create_default_survey_response_columns
    survey = surveys(:progress_report)
    assert_equal survey.get_default_survey_response_column_keys.size, survey.survey_response_columns.of_default_columns.size
    survey.survey_response_columns.destroy_all

    assert_difference "SurveyResponseColumn.count", survey.get_default_survey_response_column_keys.count do
      survey.create_default_survey_response_columns
    end
  end

  def test_get_default_survey_response_column_keys
    survey = surveys(:progress_report)
    assert_equal SurveyResponseColumn::Columns.default_columns, survey.get_default_survey_response_column_keys

    survey.stubs(:engagement_survey?).returns(false)
    assert_equal SurveyResponseColumn::Columns.default_columns - SurveyResponseColumn::Columns.survey_specific, survey.get_default_survey_response_column_keys

    survey.stubs(:meeting_feedback_survey?).returns(true)
    assert_equal SurveyResponseColumn::Columns.default_columns - [SurveyResponseColumn::Columns::Roles], survey.get_default_survey_response_column_keys
  end

  def test_survey_questions_to_display
    survey = surveys(:progress_report)

    assert survey.survey_response_columns.of_survey_questions.present?
    assert_equal_unordered survey.survey_response_columns.of_survey_questions.pluck(:survey_question_id), survey.survey_questions_to_display.collect(&:id)

    survey.survey_response_columns.of_survey_questions.destroy_all
    assert_equal [], survey.survey_questions_to_display.collect(&:id)
  end

  def test_get_updated_report_filter_params
    oldparams = {"0" => {:field => "column1", :operator => "eq", :value => "value1"}, "1" => {:field => "roles", :operator => "eq", :value => "mentor"}, "2" => {:field => "answers1", :operator => "eq", :value => "answer1"}, "3" => {:field => "date", :operator => "eq", :value => "date1"}}
    newparams = {"0" => {:field => "column2", :operator => "eq", :value => "value2"}, "1" => {:field => "column3", :operator => "eq", :value => ""}, "2" => {:field => "column4", :operator => "eq", :value => "value4"}}
    filtertype = "profile"
    format = FORMAT::HTML

    expected_updated_params = {"0" => {:field => "roles", :operator => "eq", :value => "mentor"}, "1" => {:field => "answers1", :operator => "eq", :value => "answer1"}, "2" => {:field => "date", :operator => "eq", :value => "date1"}, "3" => {:field => "column2", :operator => "eq", :value => "value2"}, "5" => {:field => "column4", :operator => "eq", :value => "value4"}}

    assert_equal_hash expected_updated_params, Survey::Report.get_updated_report_filter_params(newparams, oldparams, filtertype, format)

    oldparams = {"0" => {:field => "column1", :operator => "eq", :value => "value1"}, "1" => {:field => "roles", :operator => "eq", :value => "mentor"}, "2" => {:field => "answers1", :operator => "eq", :value => "answer1"}, "3" => {:field => "date", :operator => "eq", :value => "date1"}}
    newparams = {"0" => {:field => "answers2", :operator => "eq", :value => "value2"}, "1" => {:field => "answers3", :operator => "eq", :value => ""}, "2" => {:field => "answers4", :operator => "eq", :value => "value4"}}
    filtertype = "survey"
    format = FORMAT::HTML

    expected_updated_params = {"0" => {:field => "column1", :operator => "eq", :value => "value1"}, "1" => {:field => "roles", :operator => "eq", :value => "mentor"}, "2" => {:field => "date", :operator => "eq", :value => "date1"}, "3" => {:field => "answers2", :operator => "eq", :value => "value2"}, "5" => {:field => "answers4", :operator => "eq", :value => "value4"}}

    assert_equal_hash expected_updated_params, Survey::Report.get_updated_report_filter_params(newparams, oldparams, filtertype, format)

    oldparams = {"0" => {:field => "column1", :operator => "eq", :value => "value1"}, "1" => {:field => "roles", :operator => "eq", :value => "mentor"}, "2" => {:field => "answers1", :operator => "eq", :value => "answer1"}, "3" => {:field => "date", :operator => "eq", :value => "date1"}}
    newparams = {"0" => {:field => "roles", :operator => "eq", :value => "mentee"}}
    filtertype = "roles"
    format = FORMAT::HTML

    expected_updated_params = {"0" => {:field => "column1", :operator => "eq", :value => "value1"}, "1" => {:field => "answers1", :operator => "eq", :value => "answer1"}, "2" => {:field => "date", :operator => "eq", :value => "date1"}, "3" => {:field => "roles", :operator => "eq", :value => "mentee"}}

    assert_equal_hash expected_updated_params, Survey::Report.get_updated_report_filter_params(newparams, oldparams, filtertype, format)

    oldparams = {"0" => {:field => "column1", :operator => "eq", :value => "value1"}, "1" => {:field => "roles", :operator => "eq", :value => "mentor"}, "2" => {:field => "answers1", :operator => "eq", :value => "answer1"}, "3" => {:field => "date", :operator => "eq", :value => "date1"}}
    newparams = {"0" => {:field => "date", :operator => "eq", :value => "date2"}}
    filtertype = "date"
    format = FORMAT::HTML

    expected_updated_params = {"0" => {:field => "column1", :operator => "eq", :value => "value1"}, "1" => {:field => "roles", :operator => "eq", :value => "mentor"}, "2" => {:field => "answers1", :operator => "eq", :value => "answer1"}, "3" => {:field => "date", :operator => "eq", :value => "date2"}}

    assert_equal_hash expected_updated_params, Survey::Report.get_updated_report_filter_params(newparams, oldparams, filtertype, format)

    empty_hash = {}

    oldparams = {"0" => {:field => "column1", :operator => "eq", :value => "value1"}, "1" => {:field => "roles", :operator => "eq", :value => "mentor"}, "2" => {:field => "answers1", :operator => "eq", :value => "answer1"}, "3" => {:field => "date", :operator => "eq", :value => "date1"}}
    newparams = {"0" => {:field => "date", :operator => "eq", :value => "date2"}}
    filtertype = ""
    format = FORMAT::HTML

    assert_equal_hash empty_hash, Survey::Report.get_updated_report_filter_params(newparams, oldparams, filtertype, format)

    newparams = {"0" => {:field => "date", :operator => "eq", :value => "date2"}}
    assert_equal_hash newparams, Survey::Report.get_updated_report_filter_params(newparams, {}, nil, format, only_new_params: true)
  end

  def test_remove_incomplete_report_filters
    params = {"0" => {:field => "column1", :operator => "", :value => "value1"}, "1" => {:field => "column2", :operator => "eq", :value => ""}, "2" => {:field => "column3", :operator => "not_eq", :value => ""}, "3" => {:field => "column4", :operator => "filled", :value => "value2"}, "4" => {:field => "answers1", :operator => "", :value => "value1"}, "5" => {:field => "answers2", :operator => "eq", :value => ""}, "6" => {:field => "answers3", :operator => "not_eq", :value => ""}, "7" => {:field => "answers4", :operator => "filled", :value => "value2"}, "8" => {:field => "", :operator => "filled", :value => "value2"}}

    expected_filtered_hash = {"3" => {:field => "column4", :operator => "filled", :value => "value2"}, "7" => {:field => "answers4", :operator => "filled", :value => "value2"}}

    assert_equal_hash expected_filtered_hash, Survey::Report.remove_incomplete_report_filters(params)
  end

  def test_get_applied_date_range
    program = programs(:albers)
    filter_values1 = [{"field" => "answers1", "operator" => "eq", "value" => "answer1"}]
    filter_values2 = [{"field" => "answers1", "operator" => "eq", "value" => "answer1"}, {"field" => "date", "operator" => "eq", "value" => "1 June 2016"}]
    filter_values3 = [{"field" => "answers1", "operator" => "eq", "value" => "answer1"}, {"field" => "date", "operator" => "eq", "value" => "1 June 2016"}, {"field" => "date", "operator" => "eq", "value" => "5 June 2016"}]

    Timecop.freeze do
      start_date, end_date = Survey::Report.get_applied_date_range(filter_values1, program)
      assert_equal program.created_at.to_date, start_date.to_date
      assert_equal Time.current.to_date, end_date.to_date

      start_date, end_date = Survey::Report.get_applied_date_range(filter_values2, program)
      assert_equal "1 June 2016".to_time.to_date, start_date.to_date
      assert_equal Time.current.to_date, end_date.to_date
    end
    start_date, end_date = Survey::Report.get_applied_date_range(filter_values3, program)
    assert_equal "1 June 2016".to_time.to_date, start_date.to_date
    assert_equal "5 June 2016".to_time.to_date, end_date.to_date
  end

  def test_profile_questions_to_display
    survey = surveys(:progress_report)

    assert_equal 0, survey.survey_response_columns.of_profile_questions.size

    assert_blank survey.profile_questions_to_display

    profile_questions = survey.program.profile_questions_for(survey.survey_answers.collect(&:user).map{|u| u.role_names}.flatten.uniq, {default: true, skype: false, fetch_all: true})
    profile_question = profile_questions.first

    survey.survey_response_columns.create!(:survey_id => survey.id, :position => survey.survey_response_columns.collect(&:position).max+1, :profile_question_id => profile_question.id, :ref_obj_type => SurveyResponseColumn::ColumnType::USER)

    assert_equal 1, survey.survey_response_columns.of_profile_questions.size
    assert_equal [profile_question], survey.profile_questions_to_display
  end

  def test_survey_response_columns_association
    survey = surveys(:progress_report)
    assert_equal 6, survey.survey_response_columns.size

    assert_difference "SurveyResponseColumn.count", -(survey.survey_response_columns.size) do
      survey.destroy
    end
  end

  def test_survey_questions_association
    survey = surveys(:surveys_1)
    assert_equal 7, survey.survey_questions.size
    assert_equal 9, survey.survey_questions_with_matrix_rating_questions.size

    assert_difference "SurveyQuestion.count", -9 do
      survey.destroy
    end
  end

  def test_save_survey_response_columns
    survey = surveys(:progress_report)
    profile_questions = survey.program.profile_questions_for(survey.survey_answers.collect(&:user).map{|u| u.role_names}.flatten.uniq, {default: true, skype: false, fetch_all: true})
    profile_question = profile_questions.first

    assert_equal ["name", "date", "surveySpecific", "roles"] + survey.survey_questions.pluck(:id).map { |id| id.to_s }, survey.survey_response_columns.collect(&:key)

    columns_array = {"default" => ["name", "date", "roles"], "survey" => [survey.survey_questions.first.id.to_s], "profile" => [profile_question.id.to_s]}

    survey.save_survey_response_columns(columns_array)
    assert_equal ["name", "date", "roles", profile_question.id.to_s, survey.survey_questions.first.id.to_s], survey.reload.survey_response_columns.collect(&:key)
  end

  def test_has_the_default_column
    survey = surveys(:one)
    assert survey.has_the_default_column?(SurveyResponseColumn::Columns::SenderName)
    assert survey.has_the_default_column?(SurveyResponseColumn::Columns::ResponseDate)
    assert_false survey.has_the_default_column?(SurveyResponseColumn::Columns::SurveySpecific)

    survey.survey_response_columns.where(column_key: SurveyResponseColumn::Columns::SenderName).destroy_all
    survey.survey_response_columns.where(column_key: SurveyResponseColumn::Columns::ResponseDate).destroy_all
    survey.survey_response_columns.create!(column_key: SurveyResponseColumn::Columns::SurveySpecific, ref_obj_type: SurveyResponseColumn::ColumnType::DEFAULT)
    assert_false survey.has_the_default_column?(SurveyResponseColumn::Columns::SenderName)
    assert_false survey.has_the_default_column?(SurveyResponseColumn::Columns::ResponseDate)
    assert survey.has_the_default_column?(SurveyResponseColumn::Columns::SurveySpecific)
  end

  def test_matrix_rating_questions
    survey = surveys(:one)

    q = survey.survey_questions.new(:question_type => CommonQuestion::Type::MATRIX_RATING, :matrix_setting => CommonQuestion::MatrixSetting::FORCED_RANKING, :program_id => survey.program.id, :question_text => "Matrix Question")
    qc_params = {existing_question_choices_attributes: [{"101"=>{"text" => "Bad"}, "102"=>{"text" => "Average"}, "103"=>{"text" => "Good"}}], question_choices: {new_order: "101,102,103"}}
    matrix_params = {existing_rows_attributes: [{"101"=>{"text" => "Ability"}, "102"=>{"text" => "Confidence"}, "103"=>{"text" => "Talent"} }], rows: {new_order: "101,102,103"} }
    q.create_survey_question(qc_params, matrix_params)
    q.save

    q1 = survey.survey_questions.new(:question_type => CommonQuestion::Type::MATRIX_RATING, :matrix_setting => CommonQuestion::MatrixSetting::FORCED_RANKING, :program_id => survey.program.id, :question_text => "Matrix Question")
    q1.create_survey_question(qc_params, matrix_params)
    q1.save

    assert_equal_unordered q.rating_questions+q1.rating_questions, survey.reload.matrix_rating_questions
  end

  def test_survey_report_add_question
    sq = create_survey_question
    mq = create_matrix_survey_question
    survey = surveys(:one)

    report = Survey::Report.new(survey)
    report.add_question(sq)
    report.add_question(mq)

    assert report.question_responses[sq].is_a?(Survey::Report::QuestionResponse)
    assert report.question_responses[mq].is_a?(Survey::Report::MatrixQuestionResponse)
  end

  def test_question_response_add_answers_info
    survey = programs(:albers).surveys.find_by(name: "Meeting Feedback Survey For Mentees")
    ques = common_questions(:common_questions_1)
    qr = Survey::Report::QuestionResponse.new(ques)
    qr.stubs(:add_data).never
    qr.add_answers_info({}, 0, 0)
    assert qr.count.zero?

    qr = Survey::Report::QuestionResponse.new(ques)
    qr.stubs(:add_data).with(["Good", "Good", "Poor"], "some count").once
    qr.add_answers_info( { ques.id => DummyGroupedAnswerClass.new("Good---Good---Poor", 100) }, "some count", 0)
    assert_equal 100, qr.count
  end

  def test_question_response_add_data
    survey = programs(:albers).surveys.find_by(name: "Meeting Feedback Survey For Mentees")
    ques = common_questions(:common_questions_1)
    ques.stubs(:allow_other_option?).returns(true)
    assert ques.choice_based?
    choices_hash = ques.question_choices.index_by(&:text)
    a1 = create_survey_answer({answer_value: {answer_text: "Very useful", question: ques}, survey_question: ques, response_id: 1})
    a2 = create_survey_answer({answer_value: {answer_text: "Very useful", question: ques}, survey_question: ques, response_id: 2})
    a3 = create_survey_answer({answer_value: {answer_text: "Very useful", question: ques}, survey_question: ques, response_id: 3})
    a4 = create_survey_answer({answer_value: {answer_text: "Not at all useful", question: ques}, survey_question: ques, response_id: 4})
    qr = Survey::Report::QuestionResponse.new(ques)
    qr.add_data([a1.id, a2.id, a3.id, a4.id], {ques.id => 4})
    assert_equal 0.0, qr.data[choices_hash["Extremely useful"].id]
    assert_equal 75.0, qr.data[choices_hash["Very useful"].id]
    assert_equal 25.0, qr.data[choices_hash["Not at all useful"].id]
    assert_equal 0.0, qr.data["other"]

    ques.stubs(:allow_other_option?).returns(false)
    qr = Survey::Report::QuestionResponse.new(ques)
    qr.add_data([a1.id, a2.id, a3.id, a4.id], {ques.id => 4})
    assert_equal 0.0, qr.data[choices_hash["Extremely useful"].id]
    assert_equal 75.0, qr.data[choices_hash["Very useful"].id]
    assert_equal 25.0, qr.data[choices_hash["Not at all useful"].id]
    assert_nil qr.data["other"]

    ques.update_attributes!(allow_other_option: true)
    ques.stubs(:allow_other_option?).returns(true)
    a2.destroy
    a3.destroy
    a2 = create_survey_answer({answer_value: {answer_text: "something", question: ques}, survey_question: ques, response_id: 2})
    a3 = create_survey_answer({answer_value: {answer_text: "something else", question: ques}, survey_question: ques, response_id: 3})
    qr.add_data([a1.id, a2.id, a3.id, a4.id], {ques.id => 4})
    assert_equal 0.0, qr.data[choices_hash["Extremely useful"].id]
    assert_equal 25.0, qr.data[choices_hash["Very useful"].id]
    assert_equal 25.0, qr.data[choices_hash["Not at all useful"].id]
    assert_equal 50.0, qr.data["other"]

    ques.stubs(:choice_based?).returns(false)
    qr = Survey::Report::QuestionResponse.new(ques)
    qr.add_data(["Soemthing", "anything"], "a number")
    assert_equal ["Soemthing", "anything"], qr.data
  end

  def test_tied_to_health_report
    program = programs(:albers)
    feedback_survey = program.feedback_survey
    engagement_survey = surveys(:two)
    assert feedback_survey.is_feedback_survey?
    assert_false engagement_survey.is_feedback_survey?
    assert feedback_survey.survey_questions.non_editable.present?
    assert_false engagement_survey.survey_questions.non_editable.present?

    assert feedback_survey.tied_to_health_report?
    assert_false engagement_survey.tied_to_health_report?

    feedback_survey.stubs(:is_feedback_survey?).returns(false)
    assert_false feedback_survey.tied_to_health_report?

    feedback_survey.stubs(:is_feedback_survey?).returns(true)
    SurveyQuestion.stubs(:non_editable).returns([])
    assert_false feedback_survey.tied_to_health_report?
  end

  def test_destroyable
    program = programs(:albers)
    program_survey = surveys(:one)
    engagement_survey = surveys(:two)
    meeting_feedback_survey = program.get_meeting_feedback_survey_for_role(RoleConstants::MENTOR_NAME)
    surveys = [program_survey, engagement_survey, meeting_feedback_survey]

    engagement_survey.stubs(:tied_to_outcomes_report?).returns(false)
    engagement_survey.stubs(:has_associated_tasks_in_active_groups_or_templates?).returns(false)
    assert program_survey.destroyable?
    assert engagement_survey.destroyable?
    assert_false meeting_feedback_survey.destroyable?

    engagement_survey.stubs(:tied_to_outcomes_report?).returns(false)
    engagement_survey.stubs(:has_associated_tasks_in_active_groups_or_templates?).returns(true)
    assert_false engagement_survey.destroyable?
  end

  def test_campaign
    survey = programs(:psg).surveys.find_by(name: "Mentoring Connection Activity Feedback")
    campaign = survey.campaign
    assert campaign.is_a?(CampaignManagement::SurveyCampaign)

    assert_difference "CampaignManagement::SurveyCampaign.count", -1 do
      survey.destroy
    end
  end

  def test_create_default_campaign
    survey = programs(:psg).surveys.find_by(name: "Mentoring Connection Activity Feedback")

    assert_no_difference "CampaignManagement::SurveyCampaign.count" do
      survey.stubs(:build_default_campaign_messages).never
      survey.create_default_campaign
    end

    survey.campaign.destroy
    survey.reload

    assert_difference "CampaignManagement::SurveyCampaign.count", 1 do
      survey.stubs(:build_default_campaign_messages).never
      survey.create_default_campaign(false)
    end

    survey.campaign.destroy
    survey.reload

    assert_difference "CampaignManagement::SurveyCampaign.count", 1 do
      survey.stubs(:build_default_campaign_messages).once
      survey.create_default_campaign
    end
  end

  def test_build_default_campaign_messages
    survey = programs(:psg).surveys.find_by(name: "Mentoring Connection Activity Feedback")
    campaign = survey.campaign
    assert_equal 2, campaign.campaign_messages.size
    assert_no_difference "CampaignManagement::SurveyCampaignMessage.count" do
      survey.build_default_campaign_messages(campaign)
    end
    assert_equal 4, campaign.campaign_messages.size
    assert_equal "{{receiver_first_name}} - Help improve {{subprogram_name}}", campaign.campaign_messages.last.email_template.subject
    assert_equal 7, campaign.campaign_messages.last.duration

    assert_difference "CampaignManagement::SurveyCampaignMessage.count", 2 do
      assert_difference "Mailer::Template.count", 2 do
        campaign.save!
      end
    end

    ms = MeetingFeedbackSurvey.first
    ms.campaign.campaign_messages.destroy
    assert_no_difference "CampaignManagement::SurveyCampaignMessage.count" do
      ms.reload.build_default_campaign_messages(ms.campaign)
    end
    assert_difference "CampaignManagement::SurveyCampaignMessage.count", 2 do
      assert_difference "Mailer::Template.count", 2 do
        ms.campaign.save!
      end
    end
    assert_equal "We're still waiting for your feedback on your {{customized_meeting_term}}", ms.campaign.campaign_messages.last.email_template.subject
    assert_equal 5, ms.campaign.campaign_messages.last.duration
  end

  def test_can_have_campaigns
    es = EngagementSurvey.first
    ms = MeetingFeedbackSurvey.first
    ps = ProgramSurvey.first
    assert es.can_have_campaigns?
    assert ms.can_have_campaigns?
    assert_false ps.can_have_campaigns?
  end

  def test_reminders_count
    survey = programs(:psg).surveys.find_by(name: "Mentoring Connection Activity Feedback")
    assert_equal 2, survey.reminders_count

    survey.campaign.campaign_messages.destroy_all
    assert_equal 0, survey.reminders_count

    survey.stubs(:can_have_campaigns?).returns(false)
    assert_nil survey.reminders_count
  end

  def test_last_question_for_meeting_cancelled_or_completed_scenario
    assert_false EngagementSurvey.first.last_question_for_meeting_cancelled_or_completed_scenario?("something", "something else")
    assert_false ProgramSurvey.first.last_question_for_meeting_cancelled_or_completed_scenario?("something", "something else")

    survey = MeetingFeedbackSurvey.where(role_name: RoleConstants::MENTOR_NAME).last
    survey.survey_questions.first(2).each {|q| q.destroy}
    survey.reload
    q1 = survey.survey_questions.first
    q2 = survey.survey_questions.last
    assert q2.send(:show_always?)
    assert q1.send(:show_only_if_meeting_cancelled?)

    assert_false survey.last_question_for_meeting_cancelled_or_completed_scenario?(q1, nil)
    assert_false survey.last_question_for_meeting_cancelled_or_completed_scenario?(q1, SurveyQuestion::Condition::COMPLETED)
    assert_false survey.last_question_for_meeting_cancelled_or_completed_scenario?(q1, SurveyQuestion::Condition::CANCELLED)
    assert_false survey.last_question_for_meeting_cancelled_or_completed_scenario?(q1, SurveyQuestion::Condition::ALWAYS)

    assert_equal SurveyQuestion::Condition::COMPLETED, survey.last_question_for_meeting_cancelled_or_completed_scenario?(q2, nil)
    assert_false survey.last_question_for_meeting_cancelled_or_completed_scenario?(q2, SurveyQuestion::Condition::COMPLETED)
    assert_equal SurveyQuestion::Condition::COMPLETED, survey.last_question_for_meeting_cancelled_or_completed_scenario?(q2, SurveyQuestion::Condition::CANCELLED)
    assert_false survey.last_question_for_meeting_cancelled_or_completed_scenario?(q2, SurveyQuestion::Condition::ALWAYS)

    q1.update_attribute(:condition, SurveyQuestion::Condition::COMPLETED)
    survey.reload
    assert_equal SurveyQuestion::Condition::CANCELLED, survey.last_question_for_meeting_cancelled_or_completed_scenario?(q2, nil)
    assert_false survey.last_question_for_meeting_cancelled_or_completed_scenario?(q2, SurveyQuestion::Condition::CANCELLED)
    assert_equal SurveyQuestion::Condition::CANCELLED, survey.last_question_for_meeting_cancelled_or_completed_scenario?(q2, SurveyQuestion::Condition::COMPLETED)
    assert_false survey.last_question_for_meeting_cancelled_or_completed_scenario?(q2, SurveyQuestion::Condition::ALWAYS)
  end

  def test_get_survey_questions_for_outcomes
    survey = create_engagement_survey
    q1 = create_survey_question(
      {:question_type => CommonQuestion::Type::SINGLE_CHOICE,
        :question_info => "get,set,go", :survey => survey})
    choices_hash = q1.question_choices.index_by(&:text)
    q1.update_attributes!(positive_outcome_options: choices_hash["get"].id.to_s)
    assert_equal [{:id=>q1.id, :text=>"Whats your age?", :choices=>[{:id=>choices_hash["get"].id, :text=>"get"}, {:id=>choices_hash["set"].id, :text=>"set"}, {:id=>choices_hash["go"].id, :text=>"go"}], :selected=>[choices_hash["get"].id.to_s]}], survey.get_survey_questions_for_outcomes

    survey1 = create_engagement_survey
    create_survey_question({:survey => survey1})
    assert_equal [], survey1.get_survey_questions_for_outcomes

    survey2 = create_engagement_survey
    assert_equal [], survey2.get_survey_questions_for_outcomes
  end

  def test_tied_to_outcomes_report
    survey = surveys(:two)
    program = survey.program
    assert_false program.program_outcomes_report_enabled?
    assert_false survey.tied_to_outcomes_report?

    program.enable_feature(FeatureName::PROGRAM_OUTCOMES_REPORT)
    assert_false survey.reload.survey_questions_with_matrix_rating_questions.map(&:positive_outcome_options).compact.any?
    assert_false survey.tied_to_outcomes_report?

    survey_question = survey.survey_questions.first
    survey_question.update_attribute(:positive_outcome_options, "Good")
    assert survey.reload.tied_to_outcomes_report?
    Survey.any_instance.stubs(:engagement_survey?).returns(false)
    assert_false survey.tied_to_outcomes_report?
  end

  def test_progress_report_validations
    survey = surveys(:progress_report)
    program = survey.program
    assert_false program.share_progress_reports_enabled?
    assert survey.valid?
    survey.progress_report = true
    assert_false survey.valid?
    expected_hash = {progress_report: ["can be enabled only for mentoring connection survey."] }
    assert_equal expected_hash, survey.errors.messages

    program.enable_feature(FeatureName::SHARE_PROGRESS_REPORTS)
    assert survey.valid?

    survey.progress_report = false
    assert survey.valid?

    survey.progress_report = true
    survey.type = "ProgramSurvey"
    assert_false survey.valid?
    assert_equal expected_hash, survey.errors.messages
  end

  def test_can_share_progress_report
    survey = surveys(:two)
    group = groups(:mygroup)
    program = group.program
    mentoring_model = program.default_mentoring_model
    mentoring_model.update_columns(allow_messaging: true)
    mentoring_model.reload
    group.update_attributes!(mentoring_model_id: mentoring_model.id)

    assert_false program.share_progress_reports_enabled?
    # share progress reports features is disabled
    assert_false survey.can_share_progress_report?(group)

    program.enable_feature(FeatureName::SHARE_PROGRESS_REPORTS)
    survey.update_attributes!(progress_report: true)
    assert survey.reload.can_share_progress_report?(group.reload)
    survey.update_attributes!(progress_report: false)
    assert_false survey.reload.can_share_progress_report?(group.reload)
    survey.update_attributes!(progress_report: true)
    group.stubs(:active?).returns(false)
    assert_false survey.can_share_progress_report?(group.reload)

    group.stubs(:active?).returns(true)
    # messaging disabled for group
    mentoring_model.update_columns(allow_messaging: false)
    mentoring_model.reload
    assert_false survey.can_share_progress_report?(group.reload)
  end

end
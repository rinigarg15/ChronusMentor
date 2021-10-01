require_relative './../../test_helper.rb'

class SurveyResponsesDataServiceTest < ActiveSupport::TestCase

  def setup
    super
    @survey = surveys(:progress_report)
    @question1 = common_questions(:q3_name)
    @question2 = common_questions(:q3_from)
    @profile_question = programs(:org_primary).profile_questions.select{|ques| ques.location?}.first
    @mentor_answer_one = common_answers(:q3_name_answer_1)
    @mentor_answer_two = common_answers(:q3_from_answer_1)
    @student_answer_one = common_answers(:q3_name_answer_2)
    @student_answer_two = common_answers(:q3_from_answer_2)
    @response1 = {:user => users(:no_mreq_mentor), :group => groups(:no_mreq_group), connection_role_id: nil, :date => @mentor_answer_one.last_answered_at, :answers => {@mentor_answer_one.common_question_id => @mentor_answer_one.answer_text, @mentor_answer_two.common_question_id => @mentor_answer_two.answer_text}, :profile_answers => {@profile_question.id =>"Chennai, Tamil Nadu, India"}}
    @response2 = {:user => users(:no_mreq_student), :group => groups(:no_mreq_group), connection_role_id: nil, :date => @student_answer_one.last_answered_at, :answers => {@student_answer_one.common_question_id => @student_answer_one.answer_text, @student_answer_two.common_question_id => @student_answer_two.answer_text}, :profile_answers => {@profile_question.id => "New Delhi, Delhi, India"}}
    @survey.survey_response_columns.create!(:survey_id => @survey.id, :position => @survey.survey_response_columns.collect(&:position).max+1, :profile_question_id => @profile_question.id, :ref_obj_type => SurveyResponseColumn::ColumnType::USER)
  end

  def test_responses_ids
    srds = SurveyResponsesDataService.new(surveys(:one), {})
    assert srds.response_ids.empty?

    srds = SurveyResponsesDataService.new(@survey, {})
    responses_ids = srds.response_ids
    assert_equal 2, responses_ids.size
    assert_equal_unordered [@mentor_answer_one.response_id, @student_answer_one.response_id], responses_ids

    #Don't filter responses if sorted response ids are already provided
    SurveyResponsesDataService::FilterResponses.any_instance.expects(:apply_filters).never
    srds = SurveyResponsesDataService.new(@survey, {:response_ids => [1, 2]})
    assert_equal [1, 2], srds.response_ids
  end

  def test_sorted_response_ids
    program = users(:no_mreq_admin).program
    survey = surveys(:progress_report)
    responses = [common_answers(:q3_name_answer_1), common_answers(:q3_name_answer_2)]
    response_ids = responses.collect(&:response_id)

    common_answers(:q3_name_answer_1).update_attributes(last_answered_at: Time.now - 1.day)
    common_answers(:q3_name_answer_2).update_attributes(last_answered_at: Time.now)

    assert_equal response_ids.reverse, SurveyResponsesDataService.new(@survey, {:response_ids => response_ids, sort: {0=>{"field"=>"date", "dir"=>"desc"}}}).sorted_response_ids
    assert_equal response_ids, SurveyResponsesDataService.new(@survey, {:response_ids => response_ids, sort: {0=>{"field"=>"date", "dir"=>"asc"}}}).sorted_response_ids
  end

  def test_responses_hash
    srds = SurveyResponsesDataService.new(surveys(:one), {})
    srds.get_page_data
    assert srds.responses_hash.empty?

    srds = SurveyResponsesDataService.new(@survey, {})
    srds.get_page_data
    responses_hash = srds.responses_hash
    assert_equal 2, responses_hash.size
    assert_equal_unordered [@mentor_answer_one.response_id, @student_answer_one.response_id], responses_hash.keys
    assert_equal @mentor_answer_one.user, responses_hash[@mentor_answer_one.response_id][:user]
    assert_equal @mentor_answer_one.group, responses_hash[@mentor_answer_one.response_id][:group]
    assert_nil responses_hash[@mentor_answer_one.response_id][:meeting_name]
    assert_equal @mentor_answer_one.last_answered_at, responses_hash[@mentor_answer_one.response_id][:date]
    assert_equal 2, responses_hash[@mentor_answer_one.response_id][:answers].size
    assert_equal @mentor_answer_one.answer_text, responses_hash[@mentor_answer_one.response_id][:answers][@mentor_answer_one.common_question_id]
  end

  def test_responses_hash_for_meeting_survey
    survey =  Program.first.get_meeting_feedback_survey_for_role(RoleConstants::STUDENT_NAME)
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    member_meeting = meeting.member_meetings.find_by(member_id: members(:mkr_student).id)
    questions = []
    questions << create_survey_question({:survey => survey})
    questions << create_survey_question({:survey => survey})
    questions << create_survey_question({
      :question_type => CommonQuestion::Type::SINGLE_CHOICE,
      :question_choices => "get,set,go", :survey => survey})

    answer_0 = create_survey_answer({:survey_question => questions[0], survey: survey, member_meeting_id: member_meeting.id})

    srds = SurveyResponsesDataService.new(survey, {})
    srds.get_page_data
    responses_hash = srds.responses_hash
    assert_equal 1, responses_hash.size
    assert_equal "Arbit Daily Topic", responses_hash[@mentor_answer_one.response_id][:meeting_name]
    assert_equal meeting, responses_hash[@mentor_answer_one.response_id][:meeting]
  end

  def test_total_count
    srds = SurveyResponsesDataService.new(@survey, {})
    assert_equal 2, srds.total_count
  end

  def test_filters_count
    srds = SurveyResponsesDataService.new(@survey, {response_ids: [1,2,3]})
    assert_equal 0, srds.filters_count

    srds = SurveyResponsesDataService.new(@survey, {})
    assert_equal 0, srds.filters_count

    # filters
    srds = SurveyResponsesDataService.new(@survey, {filter: {filters: {"0" => {"field" => "roles", "operator" => "whatever", "value" => "mentor"}}}})
    assert_equal 1, srds.filters_count

    srds = SurveyResponsesDataService.new(@survey, {filter: {filters: {"0" => {"field" => "roles", "operator" => "whatever", "value" => "mentor"}, "1" => {"field" => "answers#{@survey.survey_questions.first.id}", "operator" => "eq", "value" => "something"}}}})
    assert_equal 2, srds.filters_count

    srds = SurveyResponsesDataService.new(@survey, {filter: {filters: {"0" => {"field" => "roles", "operator" => "whatever", "value" => "mentor"}, "1" => {"field" => "answers#{@survey.survey_questions.first.id}", "operator" => "eq", "value" => "something"}, "2" => {"field" => "column#{profile_questions(:profile_questions_4).id}", "operator" => "eq", "value" => "somethingelse"}}}})
    assert_equal 3, srds.filters_count
  end

  def test_get_page_data
    srds = SurveyResponsesDataService.new(@survey, {})

    hash = {1 => @response1, 2 => @response2}
    assert_equal hash, srds.get_page_data

    srds = SurveyResponsesDataService.new(surveys(:progress_report), {page: 2, "pageSize" => 1})
    assert_equal [2], srds.get_page_data.keys

    srds = SurveyResponsesDataService.new(surveys(:progress_report), {page: 1, "pageSize" => 1})
    assert_equal [1], srds.get_page_data.keys
  end
end
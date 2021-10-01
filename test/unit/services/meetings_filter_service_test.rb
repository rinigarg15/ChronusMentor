require_relative "./../../test_helper.rb"

class MeetingsFilterServiceTest < ActiveSupport::TestCase

  def test_get_es_options_hash
    expected_result_hash = {not_cancelled: true, program_id: programs(:albers).id, active: true}
    assert_equal expected_result_hash, MeetingsFilterService.get_es_options_hash(programs(:albers))
  end

  def test_get_attendee_id
    meeting_ids = Meeting.pluck(:id)

    mfs = MeetingsFilterService.new(programs(:albers), {meeting_session: {attendee: "Some one who doesnt exist <2foh2gf34e@chronus.com>"}})
    assert_equal 0, mfs.get_attendee_id

    attendee = members(:f_mentor)
    assert attendee.meetings.present?
    mfs = MeetingsFilterService.new(programs(:albers), {meeting_session: {attendee: attendee.name_with_email}})
    assert_equal attendee.id, mfs.get_attendee_id
  end

  def test_apply_survey_filter
    meeting_ids = [1111,1112,1113,1114,1115,1116]
    program = programs(:albers)
    assert_equal meeting_ids, MeetingsFilterService.new(program, {}).apply_survey_filter(meeting_ids)
    assert_equal meeting_ids, MeetingsFilterService.new(program, {meeting_session: {attendee: "Michael Brian <iitm_mentor1@chronus.com>"}}).apply_survey_filter(meeting_ids)
    survey_id = program.surveys.of_meeting_feedback_type.first.id
    MeetingFeedbackSurvey.any_instance.stubs(:get_answered_meeting_ids).returns([1111,1112,1113])
    assert_equal [1111,1112,1113], MeetingsFilterService.new(program, {meeting_session: {survey: survey_id, survey_status: "#{Survey::Status::COMPLETED}"}}).apply_survey_filter(meeting_ids)
    assert_equal [], MeetingsFilterService.new(program, {meeting_session: {survey: survey_id, survey_status: "#{Survey::Status::OVERDUE}"}}).apply_survey_filter(meeting_ids)

    m_past_1 = create_meeting(start_time: "Thu, 10 Jan 2017".to_date.to_time + 24.hours, end_time: "Thu, 10 Jan 2017".to_date.to_time + 25.hours, force_non_group_meeting: true)
    m_past_1.meeting_request.update_attributes!(:status => AbstractRequest::Status::ACCEPTED)
    assert_equal [m_past_1.id], MeetingsFilterService.new(program, {meeting_session: {survey: survey_id, survey_status: "#{Survey::Status::OVERDUE}"}}).apply_survey_filter([m_past_1.id])
  end

  def test_apply_user_profile_filter
    program = programs(:albers)

    f_admin   = users(:f_admin)
    f_mentor  = users(:f_mentor)
    f_student = users(:mkr_student)
    f_student.profile_answers.map(&:destroy)
    question = profile_questions(:string_q)

    m_past_1 = create_meeting(start_time: "Thu, 10 Jan 2017".to_date.to_time + 24.hours, end_time: "Thu, 10 Jan 2017".to_date.to_time + 25.hours, force_non_group_meeting: true)
    m_past_1.meeting_request.update_attributes!(:status => AbstractRequest::Status::ACCEPTED)

    meeting_ids = [m_past_1.id]

    assert_equal meeting_ids, MeetingsFilterService.new(program, {:report => {:profile_questions => {"6ae3c7"=>{"field"=>"column#{question.id}", "operator"=>SurveyResponsesDataService::Operators::CONTAINS, "value"=>"Computer"}}}}).apply_user_profile_filter(meeting_ids)

    assert_equal meeting_ids, MeetingsFilterService.new(program, {:report => {:profile_questions => {"6ae3c7"=>{"field"=>"column#{question.id}", "operator"=>SurveyResponsesDataService::Operators::CONTAINS, "value"=>""}}}}).apply_user_profile_filter(meeting_ids)

    question = create_question(:question_choices => ["Test", "Tes", "Testing"], :question_type => ProfileQuestion::Type::MULTI_CHOICE)
    ordered_question = create_question(:question_choices => ["Test", "Tes", "Testing"], :question_type => ProfileQuestion::Type::ORDERED_OPTIONS, options_count: 3)

    # Multichoice
    f_student = users(:f_student)
    f_mentor.save_answer!(question, ["Test"])
    f_student.save_answer!(question, ["Test","Tes","Testing"])

    m_past_2 = create_meeting(start_time: "Thu, 10 Jan 2017".to_date.to_time + 23.hours, end_time: "Thu, 10 Jan 2017".to_date.to_time + 24.hours, force_non_group_meeting: true)
    m_past_2.meeting_request.update_attributes!(:status => AbstractRequest::Status::ACCEPTED)

    meeting_ids = [m_past_1.id, m_past_2.id]

    assert_equal [m_past_1.id, m_past_2.id], MeetingsFilterService.new(program, {:report => {:profile_questions => {"6ae3c7"=>{"field"=>"column#{question.id}", "operator"=>SurveyResponsesDataService::Operators::CONTAINS,"choice"=>"Test","value" => "" }}}}).apply_user_profile_filter(meeting_ids)

    assert_equal meeting_ids, MeetingsFilterService.new(program, {:report => {:profile_questions => {"6ae3c7"=>{"field"=>"column#{question.id}", "choice"=>"Tes", "operator"=>SurveyResponsesDataService::Operators::CONTAINS,"value" => ""}}}}).apply_user_profile_filter(meeting_ids)

    assert_equal [m_past_1.id, m_past_2.id], MeetingsFilterService.new(program, {:report => {:profile_questions => {"6ae3c7"=>{"field"=>"column#{question.id}", "choice"=>"", :operator=>SurveyResponsesDataService::Operators::CONTAINS,"value" => ""}}}}).apply_user_profile_filter(meeting_ids)
  end

  def test_get_filtered_meeting_ids
    program = programs(:albers)
    m_past_1 = create_meeting(start_time: "Thu, 11 Jan 2017".to_date.in_time_zone(Time.zone).to_time + 1.minute, end_time: "Thu, 11 Jan 2017".to_date.in_time_zone(Time.zone).to_time + 1.hours + 1.minute, force_non_group_meeting: true)
    m_past_1.meeting_request.update_attributes!(status: AbstractRequest::Status::ACCEPTED)
    m_past_2 = create_meeting(start_time: "Thu, 9 Jan 2017".to_date.in_time_zone(Time.zone).to_time + 1.hours, end_time: "Thu, 9 Jan 2017".to_date.in_time_zone(Time.zone).to_time + 2.hours, force_non_group_meeting: true)
    m_past_2.meeting_request.update_attributes!(status: AbstractRequest::Status::ACCEPTED)
    meeting_ids = Meeting.pluck(:id)
    Meeting.stubs(:get_meeting_ids_by_conditions).with({not_cancelled: true, program_id: program.id, active: true, "attendees.id": 0}).returns(meeting_ids)

    program.update_attributes(created_at: (MeetingsController::CalendarSessionConstants::DEFAULT_LIMIT.ago - 2.days))
    assert_equal [[meetings(:past_calendar_meeting).id, meetings(:completed_calendar_meeting).id, meetings(:cancelled_calendar_meeting).id], nil], MeetingsFilterService.new(program, {meeting_session: {attendee: "somename"}}).get_filtered_meeting_ids

    ReportsFilterService.stubs(:get_report_date_range).returns(["Thu, 1 Jan 2017".to_date, "Thu, 20 Jan 2017".to_date], MeetingsController::CalendarSessionConstants::DEFAULT_LIMIT.ago)
    assert_equal [[m_past_1.id, m_past_2.id],nil], MeetingsFilterService.new(program, {meeting_session: {attendee: "somename"}}).get_filtered_meeting_ids

    ReportsFilterService.stubs(:get_report_date_range).returns(["Thu, 10 Jan 2017".to_date, "Thu, 20 Jan 2017".to_date], MeetingsController::CalendarSessionConstants::DEFAULT_LIMIT.ago)
    assert_equal [[m_past_1.id],nil], MeetingsFilterService.new(program, {meeting_session: {attendee: "somename"}}).get_filtered_meeting_ids

    ReportsFilterService.stubs(:get_report_date_range).returns(["Thu, 1 Jan 2017".to_date, "Thu, 10 Jan 2017".to_date], MeetingsController::CalendarSessionConstants::DEFAULT_LIMIT.ago)
    assert_equal [[m_past_2.id],nil], MeetingsFilterService.new(program, {meeting_session: {attendee: "somename"}}).get_filtered_meeting_ids

    program.update_attributes!(created_at: "2017-01-09 11:30:20")
    ReportsFilterService.stubs(:get_report_date_range).returns(["Thu, 10 Jan 2017".to_date, "Thu, 10 Jan 2017".to_date], MeetingsController::CalendarSessionConstants::DEFAULT_LIMIT.ago)
    assert_equal [[], [m_past_2.id]], MeetingsFilterService.new(program, {meeting_session: {attendee: "somename"}}).get_filtered_meeting_ids

    ReportsFilterService.stubs(:get_report_date_range).returns(["Thu, 11 Jan 2017".to_date, "Thu, 11 Jan 2017".to_date], MeetingsController::CalendarSessionConstants::DEFAULT_LIMIT.ago)
    assert_equal [[m_past_1.id],[]], MeetingsFilterService.new(program, {meeting_session: {attendee: "somename"}}).get_filtered_meeting_ids
  end

  def test_get_meeting_ids
    program = programs(:albers)
    m_past_1 = create_meeting(start_time: "Thu, 11 Jan 2017".to_date.in_time_zone(Time.zone).to_time + 1.minute, end_time: "Thu, 11 Jan 2017".to_date.in_time_zone(Time.zone).to_time + 1.hours + 1.minute, force_non_group_meeting: true)
    m_past_1.meeting_request.update_attributes!(:status => AbstractRequest::Status::ACCEPTED)
    m_past_2 = create_meeting(start_time: "Thu, 9 Jan 2017".to_date.in_time_zone(Time.zone).to_time + 1.hours, end_time: "Thu, 9 Jan 2017".to_date.in_time_zone(Time.zone).to_time + 2.hours, force_non_group_meeting: true)
    m_past_2.meeting_request.update_attributes!(:status => AbstractRequest::Status::ACCEPTED)
    m_past_3 = create_meeting(start_time: "Thu, 9 Jan 2017".to_date.in_time_zone(Time.zone).to_time + 1.hours, end_time: "Thu, 9 Jan 2017".to_date.in_time_zone(Time.zone).to_time + 2.hours, force_non_group_meeting: true)
    m_past_4 = create_meeting(start_time: "Thu, 9 Jan 2017".to_date.in_time_zone(Time.zone).to_time + 1.hours, end_time: "Thu, 9 Jan 2017".to_date.in_time_zone(Time.zone).to_time + 2.hours)

    meeting_ids = Meeting.pluck(:id)
    start_date = "Thu, 9 Jan 2017"
    end_date = "Thu, 9 Jan 2017"
    assert_equal MeetingsFilterService.new(program, {}).get_meeting_ids(start_date, end_date, meeting_ids), [m_past_2.id]

    end_date = "Thu, 11 Jan 2017"
    assert_equal MeetingsFilterService.new(program, {}).get_meeting_ids(start_date, end_date, meeting_ids), [m_past_1.id, m_past_2.id]
  end

  def test_get_number_of_filters
    program = programs(:albers)
    assert_equal 0, MeetingsFilterService.new(program, {}).get_number_of_filters
    assert_equal 0, MeetingsFilterService.new(program, {meeting_session: {}}).get_number_of_filters
    assert_equal 1, MeetingsFilterService.new(program, {meeting_session: {survey: 1, survey_status: 1}}).get_number_of_filters
    assert_equal 1, MeetingsFilterService.new(program, {meeting_session: {attendee: 1}}).get_number_of_filters
    assert_equal 2, MeetingsFilterService.new(program, {meeting_session: {survey: 1, survey_status: 1, attendee: 1}}).get_number_of_filters
    assert_equal 2, MeetingsFilterService.new(program, {meeting_session: {survey: 1, survey_status: 1, attendee: 1}}).get_number_of_filters
    assert_equal 2, MeetingsFilterService.new(program, {meeting_session: {survey: 1, survey_status: 1, attendee: 1}}).get_number_of_filters
  end
end
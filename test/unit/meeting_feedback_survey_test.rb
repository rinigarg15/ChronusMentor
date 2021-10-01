require_relative './../test_helper.rb'

class MeetingFeedbackSurveyTest < ActiveSupport::TestCase
  def test_role_name_validation
    m = MeetingFeedbackSurvey.create(program_id: programs(:albers).id, name: "Something")
    assert_false m.valid?
    assert_equal ["can't be blank"], m.errors[:role_name]
  end

  def test_add_default_questions
    program = programs(:albers)
    cth = program.return_custom_term_hash
    cth[:_meeting] = "mEeting"
    cth[:_mentee] = "mEntee"
    m = MeetingFeedbackSurvey.create!(program_id: program.id, name: "Something", role_name: RoleConstants::MENTOR_NAME)
    assert_difference "SurveyQuestion.count", 4 do
      m.add_default_questions!(cth)
    end
    assert_equal 4, m.survey_questions.count
    assert_equal "How satisfying was your mEeting experience?", m.survey_questions[0].question_text
    assert_equal "How well did your mEntee utilize their time with you?", m.survey_questions[1].question_text
  end

  def test_get_user_for_campaign
    program = programs(:albers)
    s = program.surveys.of_meeting_feedback_type.first
    m = meetings(:f_mentor_mkr_student)
    mm = m.member_meetings.first
    assert_equal members(:f_mentor), mm.member
    assert_equal users(:f_mentor), s.get_user_for_campaign(mm)
  end

  def test_member_meetings_past_end_time
    Timecop.freeze(10.years.from_now) do
      program = programs(:albers)
      mentor_mfs = program.get_meeting_feedback_survey_for_role(RoleConstants::MENTOR_NAME)

      m_past = create_meeting(end_time: 20.minutes.ago, force_non_group_meeting: true)
      mms = m_past.member_meetings
      mentor_mm = mms.find{|mm| mm.member_id == users(:f_mentor).member_id}
      mentee_mm = mms.find{|mm| mm.member_id == users(:mkr_student).member_id}

      m_future = create_meeting(end_time: 20.minutes.from_now)
      m_future.update_attribute(:group_id, nil)
      m_past_group = create_meeting(end_time: 20.minutes.ago)

      mm_ids = mentor_mfs.member_meetings_past_end_time.collect(&:id)
      assert_equal 4, mm_ids.size

      m_past.meeting_request.update_status!(users(:f_mentor), AbstractRequest::Status::ACCEPTED, skip_meeting_update: true)

      mm_ids = mentor_mfs.reload.member_meetings_past_end_time.collect(&:id)
      assert_equal 5, mm_ids.size
      assert_false mm_ids.include?(nil)
      assert_false mm_ids.include?(m_future.member_meetings.first.id)
      assert_false mm_ids.include?(m_future.member_meetings.last.id)
      assert_false mm_ids.include?(m_past_group.member_meetings.first.id)
      assert_false mm_ids.include?(m_past_group.member_meetings.last.id)
      assert_false mm_ids.include?(mentee_mm.id)
      assert mm_ids.include?(mentor_mm.id)

      mentor_mm.update_attribute(:feedback_request_sent, true)
      mm_ids = mentor_mfs.reload.member_meetings_past_end_time
      assert_false mm_ids.include?(mentor_mm.id)
      assert_false mm_ids.empty?

      invalidate_albers_calendar_meetings
      mm_ids = mentor_mfs.reload.member_meetings_past_end_time
      assert_false mm_ids.include?(mentor_mm.id)
      assert mm_ids.empty?
    end
  end

  def test_date_filter_default
    program = programs(:albers)
    survey = MeetingFeedbackSurvey.create!(program_id: program.id, name: "Something", role_name: RoleConstants::MENTOR_NAME)
   
    time = 4.weeks.ago.change(:usec => 0)
    m1 = create_meeting({:program => program, :topic => "Arbit Topic", :start_time => time, :end_time => (time + 30.minutes), :location => "Chennai", :members => [members(:f_mentor), members(:mkr_student)], :owner_id => members(:f_mentor).id, :force_non_group_meeting => true})
    m1.meeting_request.update_attributes!(:status => AbstractRequest::Status::ACCEPTED)
    time = 3.weeks.ago.change(:usec => 0)
    user2 = members(:not_requestable_mentor).user_in_program(programs(:albers))
    m2 = create_meeting({:program => programs(:albers), :topic => "Arbit Topic2", :start_time => time, :end_time => (time + 30.minutes), :members => [members(:student_2), members(:not_requestable_mentor)], :requesting_student => users(:student_2), :requesting_mentor => user2, :force_non_group_meeting => true, owner_id: members(:student_2).id})
    m2.meeting_request.update_attributes!(:status => AbstractRequest::Status::ACCEPTED)
    total_member_meetings = survey.date_filter_applied(program.created_at, Time.now.utc.to_date.at_beginning_of_day)

    meeting_ids = program.meetings.non_group_meetings.with_endtime_in(program.created_at, Time.now.utc.to_date.at_beginning_of_day).pluck(:id)

    assert_equal_unordered total_member_meetings, MemberMeeting.where(:meeting_id => meeting_ids)
  end

  def test_date_filter_applied
    program = programs(:albers)
    survey = MeetingFeedbackSurvey.create!(program_id: program.id, name: "Something", role_name: RoleConstants::MENTOR_NAME)
    filter_params = {"0"=>{"field"=>"date", "operator"=>"eq", "value"=>"July 06, 2016"}, "1"=>{"field"=>"date", "operator"=>"eq", "value"=>1.minute.ago}}
    filter_params = SurveyResponsesDataService::FilterResponses.dynamic_filter_params({:filter => {:filters => filter_params}})
    time = 50.minutes.ago.change(:usec => 0)
    m1 = create_meeting({:program => program, :topic => "Arbit Topic", :start_time => time, :end_time => (time + 30.minutes), :location => "Chennai", :members => [members(:f_mentor), members(:mkr_student)], :requesting_student => users(:mkr_student), :force_non_group_meeting => true})
    m1.meeting_request.update_attributes!(:status => AbstractRequest::Status::ACCEPTED)
    time = 70.minutes.ago.change(:usec => 0)
    user2 = members(:not_requestable_mentor).user_in_program(programs(:albers))
    m2 = create_meeting({:program => programs(:albers), :topic => "Arbit Topic2", :start_time => time, :end_time => (time + 20.minutes), :members => [members(:student_2), members(:not_requestable_mentor)], :requesting_student => users(:student_2), :requesting_mentor => user2, :force_non_group_meeting => true, owner_id: members(:student_2).id})
    m2.meeting_request.update_attributes!(:status => AbstractRequest::Status::ACCEPTED)
    total_member_meetings = survey.date_filter_applied(filter_params[:date][0].to_time, filter_params[:date][1].to_time)

    meeting_ids = program.meetings.non_group_meetings.with_endtime_in(filter_params[:date][0].to_time, filter_params[:date][1].to_time).pluck(:id)
    
    assert_equal_unordered total_member_meetings, MemberMeeting.where(:meeting_id => meeting_ids)
  end

  def test_profile_field_filter_applied
    program =  programs(:albers)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, true)
    survey = MeetingFeedbackSurvey.create!(program_id: program.id, name: "Something", role_name: RoleConstants::MENTOR_NAME)
    time = 4.weeks.ago.change(:usec => 0)
    m1 = create_meeting({:program => program, :topic => "Arbit Topic", :start_time => time, :end_time => (time + 30.minutes), :location => "Chennai", :members => [members(:f_mentor), members(:mkr_student)], :owner_id => members(:f_mentor).id, :force_non_group_meeting => true})
    m1.meeting_request.update_attributes!(:status => AbstractRequest::Status::ACCEPTED)
    time = 3.weeks.ago.change(:usec => 0)
    user2 = members(:not_requestable_mentor).user_in_program(programs(:albers))
    m2 = create_meeting({:program => programs(:albers), :topic => "Arbit Topic2", :start_time => time, :end_time => (time + 20.minutes), :members => [members(:student_2), members(:not_requestable_mentor)], :requesting_student => users(:student_2), :requesting_mentor => user2, :force_non_group_meeting => true, owner_id: members(:student_2).id})
    m2.meeting_request.update_attributes!(:status => AbstractRequest::Status::ACCEPTED)
    user_ids = [user2.id]
    member_meeting_ids = survey.profile_field_filter_applied(user_ids)
    assert_equal_unordered member_meeting_ids, [m2.member_meetings.where(:member_id => members(:not_requestable_mentor).id).first.id, meetings(:student_2_not_req_mentor).member_meetings.where(:member_id => members(:not_requestable_mentor).id).first.id]

    user_ids = []
    member_meeting_ids = survey.profile_field_filter_applied(user_ids)
    assert_equal_unordered member_meeting_ids, []
  end

  def test_find_member_ids
    program = programs(:albers)
    m = MeetingFeedbackSurvey.create!(program_id: program.id, name: "Something", role_name: RoleConstants::MENTOR_NAME)
    user_ids = [users(:f_mentor).id, users(:mkr_student).id]
    member_ids = m.find_member_ids(user_ids)
    assert_equal member_ids, [members(:f_mentor).id, members(:mkr_student).id]

    user_ids = []
     member_ids = m.find_member_ids(user_ids)
    assert_equal member_ids, []
  end

  def test_get_object_count
    program = programs(:albers)
    survey = MeetingFeedbackSurvey.create!(program_id: program.id, name: "Something", role_name: RoleConstants::MENTOR_NAME)
   
    time = 4.weeks.ago.change(:usec => 0)
    m1 = create_meeting({:program => program, :topic => "Arbit Topic", :start_time => time, :end_time => (time + 30.minutes), :location => "Chennai", :members => [members(:f_mentor), members(:mkr_student)], :owner_id => members(:f_mentor).id, :force_non_group_meeting => true})
    m1.meeting_request.update_attributes!(:status => AbstractRequest::Status::ACCEPTED)
    time = 3.weeks.ago.change(:usec => 0)
    user2 = members(:not_requestable_mentor).user_in_program(programs(:albers))
    m2 = create_meeting({:program => programs(:albers), :topic => "Arbit Topic2", :start_time => time, :end_time => (time + 30.minutes), :members => [members(:student_2), members(:not_requestable_mentor)], :requesting_student => users(:student_2), :requesting_mentor => user2, :force_non_group_meeting => true, owner_id: members(:student_2).id})
    m2.meeting_request.update_attributes!(:status => AbstractRequest::Status::ACCEPTED)
    assert_equal survey.get_object_count(survey.survey_answers), 0

    question = create_survey_question({allow_other_option: true, :question_type => CommonQuestion::Type::MULTI_STRING, :question_text => "What is your name?", :survey => survey})
    create_survey_answer({:answer_text => "remove mentee", :response_id => 2, :user => users(:not_requestable_mentor), :last_answered_at => 2.weeks.ago, :member_meeting_id => m2.member_meetings.where(:member_id => members(:not_requestable_mentor).id).first.id, :survey_id => survey.id, :survey_question => question})

    assert_equal survey.get_object_count(survey.survey_answers), 1

    create_survey_answer({:answer_text => "remove mentee", :response_id => 2, :user => users(:mkr_student), :last_answered_at => 2.weeks.ago, :member_meeting_id => m1.member_meetings.where(:member_id => members(:mkr_student).id).first.id, :survey_id => survey.id, :survey_question => question})
    assert_equal survey.get_object_count(survey.survey_answers), 2
  end

  def test_get_answered_ids
    program = programs(:albers)
    survey = MeetingFeedbackSurvey.create!(program_id: program.id, name: "Something", role_name: RoleConstants::MENTOR_NAME)
   
    time = 4.weeks.ago.change(:usec => 0)
    m1 = create_meeting({:program => program, :topic => "Arbit Topic", :start_time => time, :end_time => (time + 30.minutes), :location => "Chennai", :members => [members(:f_mentor), members(:mkr_student)], :owner_id => members(:f_mentor).id, :force_non_group_meeting => true})
    m1.meeting_request.update_attributes!(:status => AbstractRequest::Status::ACCEPTED)
    time = 3.weeks.ago.change(:usec => 0)
    user2 = members(:not_requestable_mentor).user_in_program(programs(:albers))
    m2 = create_meeting({:program => programs(:albers), :topic => "Arbit Topic2", :start_time => time, :end_time => (time + 30.minutes), :members => [members(:student_2), members(:not_requestable_mentor)], :requesting_student => users(:student_2), :requesting_mentor => user2, :force_non_group_meeting => true, owner_id: members(:student_2).id})
    m2.meeting_request.update_attributes!(:status => AbstractRequest::Status::ACCEPTED)
    assert_equal survey.get_answered_ids, []

    question = create_survey_question({allow_other_option: true, :question_type => CommonQuestion::Type::MULTI_STRING, :question_text => "What is your name?", :survey => survey})
    create_survey_answer({:answer_text => "remove mentee", :response_id => 2, :user => users(:not_requestable_mentor), :last_answered_at => 2.weeks.ago, :member_meeting_id => m2.member_meetings.where(:member_id => members(:not_requestable_mentor).id).first.id, :survey_id => survey.id, :survey_question => question})

    assert_equal survey.get_answered_ids, [m2.member_meetings.where(:member_id => members(:not_requestable_mentor).id).first.id]

    create_survey_answer({:answer_text => "remove mentee", :response_id => 2, :user => users(:mkr_student), :last_answered_at => 2.weeks.ago, :member_meeting_id => m1.member_meetings.where(:member_id => members(:mkr_student).id).first.id, :survey_id => survey.id, :survey_question => question})
    assert_equal_unordered survey.get_answered_ids, [m1.member_meetings.where(:member_id => members(:mkr_student).id).first.id, m2.member_meetings.where(:member_id => members(:not_requestable_mentor).id).first.id ]
  end

  def test_get_answered_meeting_ids
    program = programs(:albers)
    survey = MeetingFeedbackSurvey.create!(program_id: program.id, name: "Something", role_name: RoleConstants::MENTOR_NAME)
   
    time = 4.weeks.ago.change(:usec => 0)
    m1 = create_meeting({:program => program, :topic => "Arbit Topic", :start_time => time, :end_time => (time + 30.minutes), :location => "Chennai", :members => [members(:f_mentor), members(:mkr_student)], :owner_id => members(:f_mentor).id, :force_non_group_meeting => true})
    m1.meeting_request.update_attributes!(:status => AbstractRequest::Status::ACCEPTED)
    time = 3.weeks.ago.change(:usec => 0)
    user2 = members(:not_requestable_mentor).user_in_program(programs(:albers))
    m2 = create_meeting({:program => programs(:albers), :topic => "Arbit Topic2", :start_time => time, :end_time => (time + 30.minutes), :members => [members(:student_2), members(:not_requestable_mentor)], :requesting_student => users(:student_2), :requesting_mentor => user2, :force_non_group_meeting => true, owner_id: members(:student_2).id})
    m2.meeting_request.update_attributes!(:status => AbstractRequest::Status::ACCEPTED)
    
    assert_equal survey.get_answered_meeting_ids, []

    question = create_survey_question({allow_other_option: true, :question_type => CommonQuestion::Type::MULTI_STRING, :question_text => "What is your name?", :survey => survey})
    create_survey_answer({:answer_text => "remove mentee", :response_id => 2, :user => users(:not_requestable_mentor), :last_answered_at => 2.weeks.ago, :member_meeting_id => m2.member_meetings.where(:member_id => members(:not_requestable_mentor).id).first.id, :survey_id => survey.id, :survey_question => question})

    assert_equal survey.get_answered_meeting_ids, [m2.id]

    create_survey_answer({:answer_text => "remove mentee", :response_id => 2, :user => users(:mkr_student), :last_answered_at => 2.weeks.ago, :member_meeting_id => m1.member_meetings.where(:member_id => members(:mkr_student).id).first.id, :survey_id => survey.id, :survey_question => question})
    assert_equal_unordered survey.get_answered_meeting_ids, [m1.id, m2.id]
  end

  def test_has_only_one_completed_question
    survey = MeetingFeedbackSurvey.where(role_name: RoleConstants::MENTOR_NAME).last
    survey.survey_questions.first(2).each {|q| q.destroy}
    survey.reload
    q1 = survey.survey_questions.first
    q2 = survey.survey_questions.last
    assert q2.send(:show_always?)
    assert q1.send(:show_only_if_meeting_cancelled?)
    assert survey.send(:has_only_one_completed_question?)

    q1.update_attribute(:condition, SurveyQuestion::Condition::COMPLETED)
    survey.reload
    assert_false survey.send(:has_only_one_completed_question?)
  end

  def test_has_only_one_cancelled_question
    survey = MeetingFeedbackSurvey.where(role_name: RoleConstants::MENTOR_NAME).last
    survey.survey_questions.first(2).each {|q| q.destroy}
    survey.reload
    q1 = survey.survey_questions.first
    q2 = survey.survey_questions.last
    assert q2.send(:show_always?)
    assert q1.send(:show_only_if_meeting_cancelled?)
    assert_false survey.send(:has_only_one_cancelled_question?)

    q1.update_attribute(:condition, SurveyQuestion::Condition::COMPLETED)
    survey.reload
    assert survey.send(:has_only_one_cancelled_question?)
  end
end
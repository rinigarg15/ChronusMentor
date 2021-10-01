require_relative './../../../test_helper'

class MeetingOutcomesReportTest < ActiveSupport::TestCase

  def setup
    super
    programs(:albers).update_attributes(created_at: (Time.now - 60.days))
    meetings(:f_mentor_mkr_student).update_attributes(group_id: nil)
    meetings(:f_mentor_mkr_student).update_attributes(mentee_id: members(:f_mentor).id)
    meetings(:student_2_not_req_mentor).update_attributes(group_id: nil)
    meetings(:student_2_not_req_mentor).update_attributes(mentee_id: members(:student_2).id)
  end

  def test_initialize_for_closed_meetings_from_start_of_program
    program = programs(:albers)
    time_now = Time.now.utc
    start_date = program.created_at.strftime("%b %d, %Y")
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"
    user_summary = {:name=>"Users", :count => (meetings(:f_mentor_mkr_student).members + meetings(:student_2_not_req_mentor).members).uniq.count, :change=>nil}

    mentor_role = program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    mentee_role = program.roles.find_by(name: RoleConstants::STUDENT_NAME)
    role_graph_color_mapping = OutcomesReportUtils::GraphColor.get_role_graph_color_mapping([mentor_role, mentee_role])
    enabled_status_mapping = {:users => true, mentor_role.id => false, mentee_role.id => false, :total_connections_or_meetings => true}

    owners = []
    owners << meetings(:f_mentor_mkr_student).owner
    owners << meetings(:student_2_not_req_mentor).owner
    owners << meetings(:past_calendar_meeting).owner
    owners << meetings(:completed_calendar_meeting).owner
    owners << meetings(:cancelled_calendar_meeting).owner
    owners = owners.uniq

    non_owners = meetings(:f_mentor_mkr_student).guests
    non_owners << meetings(:student_2_not_req_mentor).guests
    non_owners << meetings(:past_calendar_meeting).guests
    non_owners << meetings(:cancelled_calendar_meeting).guests
    non_owners << meetings(:completed_calendar_meeting).guests
    non_owners = non_owners.uniq

    rolewise_summary = [{:id=>"flash_mentor", :name=>mentor_role.customized_term.pluralized_term, :count=>non_owners.count, :change=>nil}, {:id=>"flash_student", :name=>mentee_role.customized_term.pluralized_term, :count=>owners.count, :change=>nil}]

    meeting_outcomes_report = MeetingOutcomesReport.new(program, date_range: date_range, type: MeetingOutcomesReport::Type::CLOSED)
    assert_equal program.created_at.strftime("%b %d, %Y").to_datetime, meeting_outcomes_report.startDate
    assert_equal (time_now + 1.day).strftime("%b %d, %Y").to_datetime, meeting_outcomes_report.endDate
    assert_equal 0, meeting_outcomes_report.startDayIndex
    assert_equal 5, meeting_outcomes_report.totalCount
    assert_equal role_graph_color_mapping, meeting_outcomes_report.roleGraphColorMapping
    assert_nil meeting_outcomes_report.overallChange
    assert_equal meeting_outcomes_report.startDateForGraph, meeting_outcomes_report.startDate.to_i*1000
    assert_false meeting_outcomes_report.getOldData
    assert_equal (meeting_outcomes_report.startDate - 1.day), meeting_outcomes_report.oldEndTime
    assert_equal meeting_outcomes_report.daysSpan, ((meeting_outcomes_report.endDate.utc.beginning_of_day.to_i - meeting_outcomes_report.startDate.utc.beginning_of_day.to_i)/1.day + 1)
    assert_equal (meeting_outcomes_report.startDate - meeting_outcomes_report.daysSpan.days), meeting_outcomes_report.oldStartTime   
    assert_equal user_summary, meeting_outcomes_report.userSummary
    assert_equal rolewise_summary, meeting_outcomes_report.rolewiseSummary
    assert_equal enabled_status_mapping, meeting_outcomes_report.enabledStatusMapping
  end

  def test_initialize_for_closed_meetings_from_start_of_program_with_filter
    program = programs(:albers)
    time_now = Time.now.utc
    start_date = program.created_at.strftime("%b %d, %Y")
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"

    cache_key = "123"
    member_ids_cache_data = MemberMeeting.pluck(:member_id)[0, 22].uniq
    Rails.cache.write(cache_key + "_members", member_ids_cache_data)

    user_summary = {:name=>"Users", :count => (meetings(:f_mentor_mkr_student).members + meetings(:student_2_not_req_mentor).members + meetings(:completed_calendar_meeting).members + meetings(:past_calendar_meeting).members + meetings(:cancelled_calendar_meeting).members + meetings(:completed_calendar_meeting).members).select{|member| member_ids_cache_data.include?(member.id)}.uniq.count, :change=>nil}

    mentor_role = program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    mentee_role = program.roles.find_by(name: RoleConstants::STUDENT_NAME)
    role_graph_color_mapping = OutcomesReportUtils::GraphColor.get_role_graph_color_mapping([mentor_role, mentee_role])
    enabled_status_mapping = {:users => true, mentor_role.id => false, mentee_role.id => false, :total_connections_or_meetings => true}

    owners = []
    owners << meetings(:f_mentor_mkr_student).owner
    owners << meetings(:student_2_not_req_mentor).owner
    owners << meetings(:past_calendar_meeting).owner
    owners << meetings(:completed_calendar_meeting).owner
    owners << meetings(:cancelled_calendar_meeting).owner
    owners = owners.select{|owner| member_ids_cache_data.include?(owner.id)}.uniq

    non_owners = meetings(:f_mentor_mkr_student).guests 
    non_owners << meetings(:student_2_not_req_mentor).guests
    non_owners << meetings(:past_calendar_meeting).guests
    non_owners << meetings(:cancelled_calendar_meeting).guests
    non_owners << meetings(:completed_calendar_meeting).guests
    non_owners = non_owners.flatten
    non_owners = non_owners.select{|member| member_ids_cache_data.include?(member.id)}.uniq

    rolewise_summary = [{:id=>"flash_mentor", :name=>mentor_role.customized_term.pluralized_term, :count=>non_owners.count, :change=>nil}, {:id=>"flash_student", :name=>mentee_role.customized_term.pluralized_term, :count=>owners.count, :change=>nil}]

    meeting_outcomes_report = MeetingOutcomesReport.new(program, date_range: date_range, type: MeetingOutcomesReport::Type::CLOSED, cache_key: cache_key)
    assert_equal program.created_at.strftime("%b %d, %Y").to_datetime, meeting_outcomes_report.startDate
    assert_equal (time_now + 1.day).strftime("%b %d, %Y").to_datetime, meeting_outcomes_report.endDate
    assert_equal 0, meeting_outcomes_report.startDayIndex
    assert_equal 5, meeting_outcomes_report.totalCount
    assert_equal role_graph_color_mapping, meeting_outcomes_report.roleGraphColorMapping
    assert_nil meeting_outcomes_report.overallChange
    assert_equal meeting_outcomes_report.startDateForGraph, meeting_outcomes_report.startDate.to_i*1000
    assert_false meeting_outcomes_report.getOldData
    assert_equal (meeting_outcomes_report.startDate - 1.day), meeting_outcomes_report.oldEndTime
    assert_equal meeting_outcomes_report.daysSpan, ((meeting_outcomes_report.endDate.utc.beginning_of_day.to_i - meeting_outcomes_report.startDate.utc.beginning_of_day.to_i)/1.day + 1)
    assert_equal (meeting_outcomes_report.startDate - meeting_outcomes_report.daysSpan.days), meeting_outcomes_report.oldStartTime   
    assert_equal user_summary, meeting_outcomes_report.userSummary
    assert_equal rolewise_summary, meeting_outcomes_report.rolewiseSummary
    assert_equal enabled_status_mapping, meeting_outcomes_report.enabledStatusMapping
  end

  def test_remove_meeting_with_one_participant
    program = programs(:albers)
    time_now = Time.now.utc
    start_date = program.created_at.strftime("%b %d, %Y")
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"

    member_meeting = meetings(:f_mentor_mkr_student).member_meetings.first
    member_meeting.update_attributes(attending: MemberMeeting::ATTENDING::NO)
    meeting_outcomes_report = MeetingOutcomesReport.new(program, date_range: date_range, type: MeetingOutcomesReport::Type::CLOSED)
    assert_equal 4, meeting_outcomes_report.totalCount
  end

  def test_only_non_group_meeting_adding_to_count
    program = programs(:albers)
    time_now = Time.now.utc
    start_date = program.created_at.strftime("%b %d, %Y")
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"

    meeting = meetings(:f_mentor_mkr_student)
    
    meeting_outcomes_report = MeetingOutcomesReport.new(program, date_range: date_range, type: MeetingOutcomesReport::Type::CLOSED)
    assert_equal 5, meeting_outcomes_report.totalCount

    meeting.update_attributes(group_id: Group.first.id)
    meeting_outcomes_report = MeetingOutcomesReport.new(program, date_range: date_range, type: MeetingOutcomesReport::Type::CLOSED)
    assert_equal 4, meeting_outcomes_report.totalCount
  end

  def test_only_meeting_within_date_range_considered
    program = programs(:albers)
    time_now = Time.now.utc
    start_date = program.created_at.strftime("%b %d, %Y")
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"

    meeting = meetings(:f_mentor_mkr_student)
    
    meeting_outcomes_report = MeetingOutcomesReport.new(program, date_range: date_range, type: MeetingOutcomesReport::Type::CLOSED)
    assert_equal 5, meeting_outcomes_report.totalCount

    meeting.update_attributes!(start_time: Time.now+5.days, end_time: Time.now+5.days+30.minutes)
    meeting_outcomes_report = MeetingOutcomesReport.new(program, date_range: date_range, type: MeetingOutcomesReport::Type::CLOSED)
    assert_equal 4, meeting_outcomes_report.totalCount
  end

  def test_proper_mentor_mentee_count
    program = programs(:albers)
    time_now = Time.now.utc
    start_date = program.created_at.strftime("%b %d, %Y")
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"

    meeting = meetings(:f_mentor_mkr_student)

    user_summary = {:name=>"Users", :count => (meetings(:f_mentor_mkr_student).members + meetings(:student_2_not_req_mentor).members + meetings(:completed_calendar_meeting).members + meetings(:completed_calendar_meeting).members + meetings(:past_calendar_meeting).members).uniq.count, :change=>nil}

    mentor_role = program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    mentee_role = program.roles.find_by(name: RoleConstants::STUDENT_NAME)
    role_graph_color_mapping = OutcomesReportUtils::GraphColor.get_role_graph_color_mapping([mentor_role, mentee_role])
    enabled_status_mapping = {:users => true, mentor_role.id => false, mentee_role.id => false, :total_connections_or_meetings => true}

    owners = []
    owners << meetings(:f_mentor_mkr_student).owner
    owners << meetings(:student_2_not_req_mentor).owner
    owners << meetings(:past_calendar_meeting).owner
    owners << meetings(:completed_calendar_meeting).owner
    owners << meetings(:cancelled_calendar_meeting).owner
    owners = owners.uniq

    non_owners = meetings(:f_mentor_mkr_student).guests
    non_owners << meetings(:student_2_not_req_mentor).guests
    non_owners << meetings(:past_calendar_meeting).guests
    non_owners << meetings(:cancelled_calendar_meeting).guests 
    non_owners << meetings(:completed_calendar_meeting).guests
    non_owners = non_owners.uniq

    rolewise_summary = [{:id=>"flash_mentor", :name=>mentor_role.customized_term.pluralized_term, :count=>non_owners.count, :change=>nil}, {:id=>"flash_student", :name=>mentee_role.customized_term.pluralized_term, :count=>owners.count, :change=>nil}]

    meeting_outcomes_report = MeetingOutcomesReport.new(program, date_range: date_range, type: MeetingOutcomesReport::Type::CLOSED)
    assert_equal rolewise_summary, meeting_outcomes_report.rolewiseSummary
    assert_equal enabled_status_mapping, meeting_outcomes_report.enabledStatusMapping
  end

  def test_proper_mentor_mentee_count_with_duplicate_mentee
    program = programs(:albers)
    time_now = Time.now.utc
    start_date = program.created_at.strftime("%b %d, %Y")
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"

    meeting = meetings(:f_mentor_mkr_student)

    user_summary = {:name=>"Users", :count => (meetings(:f_mentor_mkr_student).members + meetings(:student_2_not_req_mentor).members+ meetings(:completed_calendar_meeting).members + meetings(:completed_calendar_meeting).members + meetings(:past_calendar_meeting).members).uniq.count-1, :change=>nil}

    assert_equal users(:f_mentor).member_id, meetings(:f_mentor_mkr_student).mentee_id

    meeting1 = meetings(:student_2_not_req_mentor)
    owner_mm = meeting1.member_meetings.where("member_id = ?", meeting1.mentee_id).first

    #updating member meeting for non owner
    owner_mm.update_attributes!(member_id: users(:f_mentor).member_id)
    meeting1.update_attribute(:mentee_id, users(:f_mentor).member_id)
    mentor_role = program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    mentee_role = program.roles.find_by(name: RoleConstants::STUDENT_NAME)
    role_graph_color_mapping = OutcomesReportUtils::GraphColor.get_role_graph_color_mapping([mentor_role, mentee_role])
    enabled_status_mapping = {:users => true, mentor_role.id => false, mentee_role.id => false, :total_connections_or_meetings => true}

    meeting_outcomes_report = MeetingOutcomesReport.new(program, date_range: date_range, type: MeetingOutcomesReport::Type::CLOSED)

    assert_equal 5, meeting_outcomes_report.totalCount
    assert_equal user_summary, meeting_outcomes_report.userSummary

    #meeting has owner f_mentor, meeting1 has owner as f_mentor. Also, the owner for albers' calendar meetings is mkr_student. So count of mentee should increase
    rolewise_summary = [{:id=>"flash_mentor", :name=>mentor_role.customized_term.pluralized_term, :count=>3, :change=>nil}, {:id=>"flash_student", :name=>mentee_role.customized_term.pluralized_term, :count=>2, :change=>nil}]
    assert_equal rolewise_summary, meeting_outcomes_report.rolewiseSummary
    assert_equal enabled_status_mapping, meeting_outcomes_report.enabledStatusMapping
  end

  def test_proper_mentor_mentee_count_with_duplicate_mentor
    program = programs(:albers)
    time_now = Time.now.utc
    start_date = program.created_at.strftime("%b %d, %Y")
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"

    meeting = meetings(:f_mentor_mkr_student)

    user_summary = {:name=>"Users", :count => (meetings(:f_mentor_mkr_student).members + meetings(:student_2_not_req_mentor).members+ meetings(:completed_calendar_meeting).members + meetings(:completed_calendar_meeting).members + meetings(:past_calendar_meeting).members).uniq.count-1, :change=>nil}

    owner = meetings(:f_mentor_mkr_student).owner
    assert_equal users(:f_mentor).member, owner

    meeting1 = meetings(:student_2_not_req_mentor)
    mm = meeting1.member_meetings.where("member_id != ?", meeting1.mentee_id).first

    #updating member meeting for non owner
    mm.update_attributes!(member_id: users(:mkr_student).member_id)
    mentor_role = program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    mentee_role = program.roles.find_by(name: RoleConstants::STUDENT_NAME)
    role_graph_color_mapping = OutcomesReportUtils::GraphColor.get_role_graph_color_mapping([mentor_role, mentee_role])
    enabled_status_mapping = {:users => true, mentor_role.id => false, mentee_role.id => false, :total_connections_or_meetings => true}

    meeting_outcomes_report = MeetingOutcomesReport.new(program, date_range: date_range, type: MeetingOutcomesReport::Type::CLOSED)

    assert_equal 5, meeting_outcomes_report.totalCount
    assert_equal user_summary, meeting_outcomes_report.userSummary

    #meeting has non owner mkr_student, meeting1 has non owner as mkr_student. So count of mentee should increase
    rolewise_summary = [{:id=>"flash_mentor", :name=>mentor_role.customized_term.pluralized_term, :count=>2, :change=>nil}, {:id=>"flash_student", :name=>mentee_role.customized_term.pluralized_term, :count=>3, :change=>nil}]
    assert_equal rolewise_summary, meeting_outcomes_report.rolewiseSummary
    assert_equal enabled_status_mapping, meeting_outcomes_report.enabledStatusMapping
  end

  def test_proper_mentor_mentee_count_with_duplicate_user_but_distinct_mentor_mentee
    program = programs(:albers)
    time_now = Time.now.utc
    start_date = program.created_at.strftime("%b %d, %Y")
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"

    meeting = meetings(:f_mentor_mkr_student)

    user_summary = {:name=>"Users", :count => (meetings(:f_mentor_mkr_student).members + meetings(:student_2_not_req_mentor).members).count-1, :change=>nil}

    owner = meetings(:f_mentor_mkr_student).owner
    assert_equal users(:f_mentor).member, owner

    meeting1 = meetings(:student_2_not_req_mentor)
    mm = meeting1.member_meetings.where("member_id = ?", meeting1.mentee_id).first

    #updating member meeting for owner
    mm.update_attributes!(member_id: users(:f_mentor).member_id)
    mentor_role = program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    mentee_role = program.roles.find_by(name: RoleConstants::STUDENT_NAME)
    role_graph_color_mapping = OutcomesReportUtils::GraphColor.get_role_graph_color_mapping([mentor_role, mentee_role])
    enabled_status_mapping = {:users => true, mentor_role.id => false, mentee_role.id => false, :total_connections_or_meetings => true}

    meeting_outcomes_report = MeetingOutcomesReport.new(program, date_range: date_range, type: MeetingOutcomesReport::Type::CLOSED)

    assert_equal 5, meeting_outcomes_report.totalCount
    assert_equal user_summary, meeting_outcomes_report.userSummary

    #meeting has owner f_mentor, meeting1's owner is not f_mentor. Also, the owner for albers' calendar meetings is mkr_student.So count of mentor should increase
    rolewise_summary = [{:id=>"flash_mentor", :name=>mentor_role.customized_term.pluralized_term, :count=>3, :change=>nil}, {:id=>"flash_student", :name=>mentee_role.customized_term.pluralized_term, :count=>2, :change=>nil}]
    assert_equal rolewise_summary, meeting_outcomes_report.rolewiseSummary
    assert_equal enabled_status_mapping, meeting_outcomes_report.enabledStatusMapping
  end

  def test_initialize_with_past_data
    program = programs(:albers)
    time_now = Time.now.utc
    start_date = (time_now - 8.days).strftime("%b %d, %Y")
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"
    user_summary = {:name=>"Users", :count => 2, :change=>0.00}

    mentor_role = program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    mentee_role = program.roles.find_by(name: RoleConstants::STUDENT_NAME)
    role_graph_color_mapping = OutcomesReportUtils::GraphColor.get_role_graph_color_mapping([mentor_role, mentee_role])
    enabled_status_mapping = {:users => true, mentor_role.id => false, mentee_role.id => false, :total_connections_or_meetings => true}

    meeting = meetings(:f_mentor_mkr_student)

    meeting.update_attributes!(start_time: Time.now-10.days, end_time: (Time.now-10.days)+30.minutes)

    rolewise_summary = [{:id=>"flash_mentor", :name=>mentor_role.customized_term.pluralized_term, :count=>1, :change=>-50.0}, {:id=>"flash_student", :name=>mentee_role.customized_term.pluralized_term, :count=>1, :change=>-50.0}]

    meeting_outcomes_report = MeetingOutcomesReport.new(program, date_range: date_range, type: MeetingOutcomesReport::Type::CLOSED)
    assert_equal (time_now - 8.days).strftime("%b %d, %Y").to_datetime, meeting_outcomes_report.startDate
    assert_equal (time_now + 1.day).strftime("%b %d, %Y").to_datetime, meeting_outcomes_report.endDate
    assert_equal ((time_now.beginning_of_day - program.created_at.beginning_of_day)/1.day - 8), meeting_outcomes_report.startDayIndex
    assert_equal 1, meeting_outcomes_report.totalCount
    assert_equal role_graph_color_mapping, meeting_outcomes_report.roleGraphColorMapping
    assert_equal -75.0, meeting_outcomes_report.overallChange
    assert_equal meeting_outcomes_report.startDateForGraph, meeting_outcomes_report.startDate.to_i*1000
    assert meeting_outcomes_report.getOldData
    assert_equal (meeting_outcomes_report.startDate - 1.day), meeting_outcomes_report.oldEndTime
    assert_equal meeting_outcomes_report.daysSpan, ((meeting_outcomes_report.endDate.utc.beginning_of_day.to_i - meeting_outcomes_report.startDate.utc.beginning_of_day.to_i)/1.day + 1)
    assert_equal (meeting_outcomes_report.startDate - meeting_outcomes_report.daysSpan.days), meeting_outcomes_report.oldStartTime   
    assert_equal user_summary, meeting_outcomes_report.userSummary
    assert_equal rolewise_summary, meeting_outcomes_report.rolewiseSummary
    assert_equal enabled_status_mapping, meeting_outcomes_report.enabledStatusMapping
  end

  def test_initialize_for_closed_meetings_from_start_of_program_with_no_positive_outcome
    program = programs(:albers)
    time_now = Time.now.utc
    start_date = program.created_at.strftime("%b %d, %Y")
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"
    user_summary = {:name=>"Users", :count => 0, :change=>nil}

    mentor_role = program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    mentee_role = program.roles.find_by(name: RoleConstants::STUDENT_NAME)
    role_graph_color_mapping = OutcomesReportUtils::GraphColor.get_role_graph_color_mapping([mentor_role, mentee_role])
    enabled_status_mapping = {:users => true, mentor_role.id => false, mentee_role.id => false, :total_connections_or_meetings => true}

    owners = meetings(:f_mentor_mkr_student).members.where(id: meetings(:f_mentor_mkr_student).mentee_id)
    owners += meetings(:student_2_not_req_mentor).members.where(id: meetings(:student_2_not_req_mentor).mentee_id)
    owners = owners.uniq
    non_owners = (meetings(:f_mentor_mkr_student).members + meetings(:student_2_not_req_mentor).members).uniq - owners

    rolewise_summary = [{:id=>"positive_outcomes_mentor", :name=>mentor_role.customized_term.pluralized_term, :count=>0, :change=>nil}, {:id=>"positive_outcomes_student", :name=>mentee_role.customized_term.pluralized_term, :count=>0, :change=>nil}]

    meeting_outcomes_report = MeetingOutcomesReport.new(program, date_range: date_range, type: MeetingOutcomesReport::Type::POSITIVE_OUTCOMES)
    survey = program.surveys.of_meeting_feedback_type.first
    assert_equal program.created_at.strftime("%b %d, %Y").to_datetime, meeting_outcomes_report.startDate
    assert_equal (time_now + 1.day).strftime("%b %d, %Y").to_datetime, meeting_outcomes_report.endDate
    assert_equal 0, meeting_outcomes_report.startDayIndex
    assert_equal 0, meeting_outcomes_report.totalCount
    assert_equal role_graph_color_mapping, meeting_outcomes_report.roleGraphColorMapping
    assert_nil meeting_outcomes_report.overallChange
    assert_equal meeting_outcomes_report.startDateForGraph, meeting_outcomes_report.startDate.to_i*1000
    assert_false meeting_outcomes_report.getOldData
    assert_equal (meeting_outcomes_report.startDate - 1.day), meeting_outcomes_report.oldEndTime
    assert_equal meeting_outcomes_report.daysSpan, ((meeting_outcomes_report.endDate.utc.beginning_of_day.to_i - meeting_outcomes_report.startDate.utc.beginning_of_day.to_i)/1.day + 1)
    assert_equal (meeting_outcomes_report.startDate - meeting_outcomes_report.daysSpan.days), meeting_outcomes_report.oldStartTime   
    assert_equal user_summary, meeting_outcomes_report.userSummary
    assert_equal rolewise_summary, meeting_outcomes_report.rolewiseSummary
    assert_equal enabled_status_mapping, meeting_outcomes_report.enabledStatusMapping
  end

  def test_initialize_for_closed_meetings_from_start_of_program_with_one_positive_outcome
    program = programs(:albers)
    time_now = Time.now.utc
    start_date = program.created_at.strftime("%b %d, %Y")
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"
    user_summary = {:name=>"Users", :count => 1, :change=>nil}

    mentor_role = program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    mentee_role = program.roles.find_by(name: RoleConstants::STUDENT_NAME)
    role_graph_color_mapping = OutcomesReportUtils::GraphColor.get_role_graph_color_mapping([mentor_role, mentee_role])
    enabled_status_mapping = {:users => true, mentor_role.id => false, mentee_role.id => false, :total_connections_or_meetings => true}

    owners = meetings(:f_mentor_mkr_student).members.where(id: meetings(:f_mentor_mkr_student).mentee_id)
    owners += meetings(:student_2_not_req_mentor).members.where(id: meetings(:student_2_not_req_mentor).mentee_id)
    owners = owners.uniq
    non_owners = (meetings(:f_mentor_mkr_student).members + meetings(:student_2_not_req_mentor).members).uniq - owners

    rolewise_summary = [{:id=>"positive_outcomes_mentor", :name=>mentor_role.customized_term.pluralized_term, :count=>0, :change=>nil}, {:id=>"positive_outcomes_student", :name=>mentee_role.customized_term.pluralized_term, :count=>1, :change=>nil}]

    survey = program.surveys.of_meeting_feedback_type.first
    survey_question = survey.survey_questions.where(question_text: "How satisfying was your meeting experience?")[0]

    outcome_options = survey_question.question_choices.find_by(text: "Very satisfying").id.to_s
    survey_question.update_attribute(:positive_outcome_options, outcome_options)
    meetings(:student_2_not_req_mentor).member_meetings.first.survey_answers.create!({answer_value: {answer_text: "Very satisfying", question: survey_question}, user: meetings(:student_2_not_req_mentor).member_meetings.first.member.user_in_program(program), last_answered_at: Time.now.utc, :survey_question => survey_question})

    meeting_outcomes_report = MeetingOutcomesReport.new(program, date_range: date_range, type: MeetingOutcomesReport::Type::POSITIVE_OUTCOMES)

    assert_equal program.created_at.strftime("%b %d, %Y").to_datetime, meeting_outcomes_report.startDate
    assert_equal (time_now + 1.day).strftime("%b %d, %Y").to_datetime, meeting_outcomes_report.endDate
    assert_equal 0, meeting_outcomes_report.startDayIndex
    assert_equal 1, meeting_outcomes_report.totalCount
    assert_equal role_graph_color_mapping, meeting_outcomes_report.roleGraphColorMapping
    assert_nil meeting_outcomes_report.overallChange
    assert_equal meeting_outcomes_report.startDateForGraph, meeting_outcomes_report.startDate.to_i*1000
    assert_false meeting_outcomes_report.getOldData
    assert_equal (meeting_outcomes_report.startDate - 1.day), meeting_outcomes_report.oldEndTime
    assert_equal meeting_outcomes_report.daysSpan, ((meeting_outcomes_report.endDate.utc.beginning_of_day.to_i - meeting_outcomes_report.startDate.utc.beginning_of_day.to_i)/1.day + 1)
    assert_equal (meeting_outcomes_report.startDate - meeting_outcomes_report.daysSpan.days), meeting_outcomes_report.oldStartTime   
    assert_equal user_summary, meeting_outcomes_report.userSummary
    assert_equal rolewise_summary, meeting_outcomes_report.rolewiseSummary
    assert_equal enabled_status_mapping, meeting_outcomes_report.enabledStatusMapping

    assert_equal_hash ({positive: 1, total: 1}), MeetingOutcomesReport.new(nil, skip_init: true).get_satisfaction_stats_for_meetings_between(program.created_at, DateTime.current, program_ids: [program.id])
  end

  def test_initialize_for_closed_meetings_from_start_of_program_with_two_positive_outcome_from_same_connection
    program = programs(:albers)
    time_now = Time.now.utc
    start_date = program.created_at.strftime("%b %d, %Y")
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"
    user_summary = {:name=>"Users", :count => 2, :change=>nil}

    mentor_role = program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    mentee_role = program.roles.find_by(name: RoleConstants::STUDENT_NAME)
    role_graph_color_mapping = OutcomesReportUtils::GraphColor.get_role_graph_color_mapping([mentor_role, mentee_role])
    enabled_status_mapping = {:users => true, mentor_role.id => false, mentee_role.id => false, :total_connections_or_meetings => true}

    owners = meetings(:f_mentor_mkr_student).members.where(id: meetings(:f_mentor_mkr_student).mentee_id)
    owners += meetings(:student_2_not_req_mentor).members.where(id: meetings(:student_2_not_req_mentor).mentee_id)
    owners = owners.uniq
    non_owners = (meetings(:f_mentor_mkr_student).members + meetings(:student_2_not_req_mentor).members).uniq - owners

    rolewise_summary = [{:id=>"positive_outcomes_mentor", :name=>mentor_role.customized_term.pluralized_term, :count=>1, :change=>nil}, {:id=>"positive_outcomes_student", :name=>mentee_role.customized_term.pluralized_term, :count=>1, :change=>nil}]

    survey = program.surveys.of_meeting_feedback_type.first
    survey_question = survey.survey_questions.where(question_text: "How satisfying was your meeting experience?")[0]
    outcome_options = survey_question.question_choices.find_by(text: "Very satisfying").id.to_s + ","
    outcome_options += survey_question.question_choices.find_by(text: "Extremely satisfying").id.to_s
    survey_question.update_attribute(:positive_outcome_options, outcome_options)
    meetings(:student_2_not_req_mentor).member_meetings.first.survey_answers.create!({answer_value: {answer_text: "Very satisfying", question: survey_question}, user: meetings(:student_2_not_req_mentor).member_meetings.first.member.user_in_program(program), last_answered_at: Time.now.utc, :survey_question => survey_question})
    meetings(:student_2_not_req_mentor).member_meetings.last.survey_answers.create!({answer_value: {answer_text: "Extremely satisfying", question: survey_question}, user: meetings(:student_2_not_req_mentor).member_meetings.last.member.user_in_program(program), last_answered_at: Time.now.utc, :survey_question => survey_question})

    meeting_outcomes_report = MeetingOutcomesReport.new(program, date_range: date_range, type: MeetingOutcomesReport::Type::POSITIVE_OUTCOMES)

    assert_equal program.created_at.strftime("%b %d, %Y").to_datetime, meeting_outcomes_report.startDate
    assert_equal (time_now + 1.day).strftime("%b %d, %Y").to_datetime, meeting_outcomes_report.endDate
    assert_equal 0, meeting_outcomes_report.startDayIndex
    assert_equal 1, meeting_outcomes_report.totalCount
    assert_equal role_graph_color_mapping, meeting_outcomes_report.roleGraphColorMapping
    assert_nil meeting_outcomes_report.overallChange
    assert_equal meeting_outcomes_report.startDateForGraph, meeting_outcomes_report.startDate.to_i*1000
    assert_false meeting_outcomes_report.getOldData
    assert_equal (meeting_outcomes_report.startDate - 1.day), meeting_outcomes_report.oldEndTime
    assert_equal meeting_outcomes_report.daysSpan, ((meeting_outcomes_report.endDate.utc.beginning_of_day.to_i - meeting_outcomes_report.startDate.utc.beginning_of_day.to_i)/1.day + 1)
    assert_equal (meeting_outcomes_report.startDate - meeting_outcomes_report.daysSpan.days), meeting_outcomes_report.oldStartTime   
    assert_equal user_summary, meeting_outcomes_report.userSummary
    assert_equal rolewise_summary, meeting_outcomes_report.rolewiseSummary
    assert_equal enabled_status_mapping, meeting_outcomes_report.enabledStatusMapping

    assert_equal_hash ({positive: 2, total: 2}), MeetingOutcomesReport.new(nil, skip_init: true).get_satisfaction_stats_for_meetings_between(program.created_at, DateTime.current, program_ids: [program.id])
  end

  def test_initialize_for_closed_meetings_from_start_of_program_with_two_positive_outcome_from_diff_connection
    program = programs(:albers)
    time_now = Time.now.utc
    start_date = program.created_at.strftime("%b %d, %Y")
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"
    user_summary = {:name=>"Users", :count => 2, :change=>nil}

    mentor_role = program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    mentee_role = program.roles.find_by(name: RoleConstants::STUDENT_NAME)
    role_graph_color_mapping = OutcomesReportUtils::GraphColor.get_role_graph_color_mapping([mentor_role, mentee_role])
    enabled_status_mapping = {:users => true, mentor_role.id => false, mentee_role.id => false, :total_connections_or_meetings => true}

    owners = meetings(:f_mentor_mkr_student).members.where(id: meetings(:f_mentor_mkr_student).mentee_id)
    owners += meetings(:student_2_not_req_mentor).members.where(id: meetings(:student_2_not_req_mentor).mentee_id)
    owners = owners.uniq
    non_owners = (meetings(:f_mentor_mkr_student).members + meetings(:student_2_not_req_mentor).members).uniq - owners

    rolewise_summary = [{:id=>"positive_outcomes_mentor", :name=>mentor_role.customized_term.pluralized_term, :count=>1, :change=>nil}, {:id=>"positive_outcomes_student", :name=>mentee_role.customized_term.pluralized_term, :count=>1, :change=>nil}]

    survey = program.surveys.of_meeting_feedback_type.first
    survey_question = survey.survey_questions.where(question_text: "How satisfying was your meeting experience?")[0]
    outcome_options = survey_question.question_choices.find_by(text: "Extremely satisfying").id.to_s + ","
    outcome_options += survey_question.question_choices.find_by(text: "Very satisfying").id.to_s
    survey_question.update_attribute(:positive_outcome_options, outcome_options)
    meetings(:student_2_not_req_mentor).member_meetings.first.survey_answers.create!({answer_value: {answer_text: "Very satisfying", question: survey_question}, user: meetings(:student_2_not_req_mentor).member_meetings.first.member.user_in_program(program), last_answered_at: Time.now.utc, :survey_question => survey_question})
    survey_answer = meetings(:f_mentor_mkr_student).member_meetings.last.survey_answers.create!({answer_value: {answer_text: "Extremely satisfying", question: survey_question}, user: meetings(:f_mentor_mkr_student).member_meetings.last.member.user_in_program(program), last_answered_at: Time.now.utc, :survey_question => survey_question})

    meeting_outcomes_report = MeetingOutcomesReport.new(program, date_range: date_range, type: MeetingOutcomesReport::Type::POSITIVE_OUTCOMES)

    assert_equal program.created_at.strftime("%b %d, %Y").to_datetime, meeting_outcomes_report.startDate
    assert_equal (time_now + 1.day).strftime("%b %d, %Y").to_datetime, meeting_outcomes_report.endDate
    assert_equal 0, meeting_outcomes_report.startDayIndex
    assert_equal 2, meeting_outcomes_report.totalCount
    assert_equal role_graph_color_mapping, meeting_outcomes_report.roleGraphColorMapping
    assert_nil meeting_outcomes_report.overallChange
    assert_equal meeting_outcomes_report.startDateForGraph, meeting_outcomes_report.startDate.to_i*1000
    assert_false meeting_outcomes_report.getOldData
    assert_equal (meeting_outcomes_report.startDate - 1.day), meeting_outcomes_report.oldEndTime
    assert_equal meeting_outcomes_report.daysSpan, ((meeting_outcomes_report.endDate.utc.beginning_of_day.to_i - meeting_outcomes_report.startDate.utc.beginning_of_day.to_i)/1.day + 1)
    assert_equal (meeting_outcomes_report.startDate - meeting_outcomes_report.daysSpan.days), meeting_outcomes_report.oldStartTime   
    assert_equal user_summary, meeting_outcomes_report.userSummary
    assert_equal rolewise_summary, meeting_outcomes_report.rolewiseSummary
    assert_equal enabled_status_mapping, meeting_outcomes_report.enabledStatusMapping

    assert_equal_hash ({positive: 2, total: 2}), MeetingOutcomesReport.new(nil, skip_init: true).get_satisfaction_stats_for_meetings_between(program.created_at, DateTime.current, program_ids: [program.id])
  end

  def test_initialize_for_closed_meetings_from_start_of_program_with_two_positive_outcome_from_diff_connection_and_with_filter
    program = programs(:albers)
    time_now = Time.now.utc
    start_date = program.created_at.strftime("%b %d, %Y")
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"
    user_summary = {:name=>"Users", :count => 1, :change=>nil}

    cache_key = "123"
    member_ids_cache_data = MemberMeeting.pluck(:member_id)[0, 4].uniq
    Rails.cache.write(cache_key + "_members", member_ids_cache_data)

    mentor_role = program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    mentee_role = program.roles.find_by(name: RoleConstants::STUDENT_NAME)
    role_graph_color_mapping = OutcomesReportUtils::GraphColor.get_role_graph_color_mapping([mentor_role, mentee_role])
    enabled_status_mapping = {:users => true, mentor_role.id => false, mentee_role.id => false, :total_connections_or_meetings => true}

    owners = meetings(:f_mentor_mkr_student).members.where(id: meetings(:f_mentor_mkr_student).mentee_id)
    owners += meetings(:student_2_not_req_mentor).members.where(id: meetings(:student_2_not_req_mentor).mentee_id)
    owners = owners.uniq
    non_owners = (meetings(:f_mentor_mkr_student).members + meetings(:student_2_not_req_mentor).members).uniq - owners

    rolewise_summary = [{:id=>"positive_outcomes_mentor", :name=>mentor_role.customized_term.pluralized_term, :count=>1, :change=>nil}, {:id=>"positive_outcomes_student", :name=>mentee_role.customized_term.pluralized_term, :count=>0, :change=>nil}]

    survey = program.surveys.of_meeting_feedback_type.first
    survey_question = survey.survey_questions.where(question_text: "How satisfying was your meeting experience?")[0]
    outcome_options = survey_question.question_choices.find_by(text: "Extremely satisfying").id.to_s + ","
    outcome_options += survey_question.question_choices.find_by(text: "Very satisfying").id.to_s
    survey_question.update_attribute(:positive_outcome_options, outcome_options)
    meetings(:student_2_not_req_mentor).member_meetings.first.survey_answers.create!({answer_value: {answer_text: "Very satisfying", question: survey_question}, user: meetings(:student_2_not_req_mentor).member_meetings.first.member.user_in_program(program), last_answered_at: Time.now.utc, :survey_question => survey_question})
    meetings(:f_mentor_mkr_student).member_meetings.last.survey_answers.create!({answer_value: {answer_text: "Extremely satisfying", question: survey_question}, user: meetings(:f_mentor_mkr_student).member_meetings.last.member.user_in_program(program), last_answered_at: Time.now.utc, :survey_question => survey_question})

    meeting_outcomes_report = MeetingOutcomesReport.new(program, date_range: date_range, type: MeetingOutcomesReport::Type::POSITIVE_OUTCOMES, cache_key: cache_key)

    assert_equal program.created_at.strftime("%b %d, %Y").to_datetime, meeting_outcomes_report.startDate
    assert_equal (time_now + 1.day).strftime("%b %d, %Y").to_datetime, meeting_outcomes_report.endDate
    assert_equal 0, meeting_outcomes_report.startDayIndex
    assert_equal 1, meeting_outcomes_report.totalCount
    assert_equal role_graph_color_mapping, meeting_outcomes_report.roleGraphColorMapping
    assert_nil meeting_outcomes_report.overallChange
    assert_equal meeting_outcomes_report.startDateForGraph, meeting_outcomes_report.startDate.to_i*1000
    assert_false meeting_outcomes_report.getOldData
    assert_equal (meeting_outcomes_report.startDate - 1.day), meeting_outcomes_report.oldEndTime
    assert_equal meeting_outcomes_report.daysSpan, ((meeting_outcomes_report.endDate.utc.beginning_of_day.to_i - meeting_outcomes_report.startDate.utc.beginning_of_day.to_i)/1.day + 1)
    assert_equal (meeting_outcomes_report.startDate - meeting_outcomes_report.daysSpan.days), meeting_outcomes_report.oldStartTime   
    assert_equal user_summary, meeting_outcomes_report.userSummary
    assert_equal rolewise_summary, meeting_outcomes_report.rolewiseSummary
    assert_equal enabled_status_mapping, meeting_outcomes_report.enabledStatusMapping
  end

  def test_initialize_for_closed_meetings_from_start_of_program_with_two_positive_outcome_from_same_connection_one_wrong_one_right
    program = programs(:albers)
    time_now = Time.now.utc
    start_date = program.created_at.strftime("%b %d, %Y")
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"
    user_summary = {:name=>"Users", :count => 1, :change=>nil}

    mentor_role = program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    mentee_role = program.roles.find_by(name: RoleConstants::STUDENT_NAME)
    role_graph_color_mapping = OutcomesReportUtils::GraphColor.get_role_graph_color_mapping([mentor_role, mentee_role])
    enabled_status_mapping = {:users => true, mentor_role.id => false, mentee_role.id => false, :total_connections_or_meetings => true}

    owners = meetings(:f_mentor_mkr_student).members.where(id: meetings(:f_mentor_mkr_student).mentee_id)
    owners += meetings(:student_2_not_req_mentor).members.where(id: meetings(:student_2_not_req_mentor).mentee_id)
    owners = owners.uniq
    non_owners = (meetings(:f_mentor_mkr_student).members + meetings(:student_2_not_req_mentor).members).uniq - owners

    rolewise_summary = [{:id=>"positive_outcomes_mentor", :name=>mentor_role.customized_term.pluralized_term, :count=>0, :change=>nil}, {:id=>"positive_outcomes_student", :name=>mentee_role.customized_term.pluralized_term, :count=>1, :change=>nil}]

    survey = program.surveys.of_meeting_feedback_type.first
    survey_question = survey.survey_questions.where(question_text: "How satisfying was your meeting experience?")[0]
    outcome_options = survey_question.question_choices.find_by(text: "Extremely satisfying").id.to_s + ","
    outcome_options += survey_question.question_choices.find_by(text: "Very satisfying").id.to_s
    survey_question.update_attribute(:positive_outcome_options, outcome_options)
    meetings(:student_2_not_req_mentor).member_meetings.first.survey_answers.create!({answer_value: {answer_text: "Very satisfying", question: survey_question}, user: meetings(:student_2_not_req_mentor).member_meetings.first.member.user_in_program(program), last_answered_at: Time.now.utc, :survey_question => survey_question})
    meetings(:student_2_not_req_mentor).member_meetings.last.survey_answers.create!({answer_value: {answer_text: "Not at all satisfying", question: survey_question}, user: meetings(:student_2_not_req_mentor).member_meetings.last.member.user_in_program(program), last_answered_at: Time.now.utc, :survey_question => survey_question})

    meeting_outcomes_report = MeetingOutcomesReport.new(program, date_range: date_range, type: MeetingOutcomesReport::Type::POSITIVE_OUTCOMES)

    assert_equal program.created_at.strftime("%b %d, %Y").to_datetime, meeting_outcomes_report.startDate
    assert_equal (time_now + 1.day).strftime("%b %d, %Y").to_datetime, meeting_outcomes_report.endDate
    assert_equal 0, meeting_outcomes_report.startDayIndex
    assert_equal 1, meeting_outcomes_report.totalCount
    assert_equal role_graph_color_mapping, meeting_outcomes_report.roleGraphColorMapping
    assert_nil meeting_outcomes_report.overallChange
    assert_equal meeting_outcomes_report.startDateForGraph, meeting_outcomes_report.startDate.to_i*1000
    assert_false meeting_outcomes_report.getOldData
    assert_equal (meeting_outcomes_report.startDate - 1.day), meeting_outcomes_report.oldEndTime
    assert_equal meeting_outcomes_report.daysSpan, ((meeting_outcomes_report.endDate.utc.beginning_of_day.to_i - meeting_outcomes_report.startDate.utc.beginning_of_day.to_i)/1.day + 1)
    assert_equal (meeting_outcomes_report.startDate - meeting_outcomes_report.daysSpan.days), meeting_outcomes_report.oldStartTime   
    assert_equal user_summary, meeting_outcomes_report.userSummary
    assert_equal rolewise_summary, meeting_outcomes_report.rolewiseSummary
    assert_equal enabled_status_mapping, meeting_outcomes_report.enabledStatusMapping

    assert_equal_hash ({positive: 1, total: 2}), MeetingOutcomesReport.new(nil, skip_init: true).get_satisfaction_stats_for_meetings_between(program.created_at, DateTime.current, program_ids: [program.id])
  end

  def test_initialize_for_closed_meetings_from_start_of_program_with_two_positive_outcome_wrong_answer
    program = programs(:albers)
    time_now = Time.now.utc
    start_date = program.created_at.strftime("%b %d, %Y")
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"
    user_summary = {:name=>"Users", :count => 0, :change=>nil}

    mentor_role = program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    mentee_role = program.roles.find_by(name: RoleConstants::STUDENT_NAME)
    role_graph_color_mapping = OutcomesReportUtils::GraphColor.get_role_graph_color_mapping([mentor_role, mentee_role])
    enabled_status_mapping = {:users => true, mentor_role.id => false, mentee_role.id => false, :total_connections_or_meetings => true}

    owners = meetings(:f_mentor_mkr_student).members.where(id: meetings(:f_mentor_mkr_student).mentee_id)
    owners += meetings(:student_2_not_req_mentor).members.where(id: meetings(:student_2_not_req_mentor).mentee_id)
    owners = owners.uniq
    non_owners = (meetings(:f_mentor_mkr_student).members + meetings(:student_2_not_req_mentor).members).uniq - owners

    rolewise_summary = [{:id=>"positive_outcomes_mentor", :name=>mentor_role.customized_term.pluralized_term, :count=>0, :change=>nil}, {:id=>"positive_outcomes_student", :name=>mentee_role.customized_term.pluralized_term, :count=>0, :change=>nil}]

    survey = program.surveys.of_meeting_feedback_type.first
    survey_question = survey.survey_questions.where(question_text: "How satisfying was your meeting experience?")[0]
    outcome_options = survey_question.question_choices.find_by(text: "Extremely satisfying").id.to_s + ","
    outcome_options += survey_question.question_choices.find_by(text: "Very satisfying").id.to_s
    survey_question.update_attribute(:positive_outcome_options, outcome_options)
    meetings(:student_2_not_req_mentor).member_meetings.last.survey_answers.create!({answer_value: {answer_text: "Not at all satisfying", question: survey_question}, user: meetings(:student_2_not_req_mentor).member_meetings.last.member.user_in_program(program), last_answered_at: Time.now.utc, :survey_question => survey_question})

    meeting_outcomes_report = MeetingOutcomesReport.new(program, date_range: date_range, type: MeetingOutcomesReport::Type::POSITIVE_OUTCOMES)

    assert_equal program.created_at.strftime("%b %d, %Y").to_datetime, meeting_outcomes_report.startDate
    assert_equal (time_now + 1.day).strftime("%b %d, %Y").to_datetime, meeting_outcomes_report.endDate
    assert_equal 0, meeting_outcomes_report.startDayIndex
    assert_equal 0, meeting_outcomes_report.totalCount
    assert_equal role_graph_color_mapping, meeting_outcomes_report.roleGraphColorMapping
    assert_nil meeting_outcomes_report.overallChange
    assert_equal meeting_outcomes_report.startDateForGraph, meeting_outcomes_report.startDate.to_i*1000
    assert_false meeting_outcomes_report.getOldData
    assert_equal (meeting_outcomes_report.startDate - 1.day), meeting_outcomes_report.oldEndTime
    assert_equal meeting_outcomes_report.daysSpan, ((meeting_outcomes_report.endDate.utc.beginning_of_day.to_i - meeting_outcomes_report.startDate.utc.beginning_of_day.to_i)/1.day + 1)
    assert_equal (meeting_outcomes_report.startDate - meeting_outcomes_report.daysSpan.days), meeting_outcomes_report.oldStartTime   
    assert_equal user_summary, meeting_outcomes_report.userSummary
    assert_equal rolewise_summary, meeting_outcomes_report.rolewiseSummary
    assert_equal enabled_status_mapping, meeting_outcomes_report.enabledStatusMapping

    assert_equal_hash ({positive: 0, total: 1}), MeetingOutcomesReport.new(nil, skip_init: true).get_satisfaction_stats_for_meetings_between(program.created_at, DateTime.current, program_ids: [program.id])

    meetings(:student_2_not_req_mentor).member_meetings.first.survey_answers.create!({answer_value: {answer_text: "Not at all satisfying", question: survey_question}, user: meetings(:student_2_not_req_mentor).member_meetings.first.member.user_in_program(program), last_answered_at: Time.now.utc, :survey_question => survey_question})
    assert_equal_hash ({positive: 0, total: 2}), MeetingOutcomesReport.new(nil, skip_init: true).get_satisfaction_stats_for_meetings_between(program.created_at, DateTime.current, program_ids: [program.id])
  end

end

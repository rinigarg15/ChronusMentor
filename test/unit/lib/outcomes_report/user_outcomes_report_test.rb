require_relative './../../../test_helper'

class UserOutcomesReportTest < ActiveSupport::TestCase

  def setup
    super
    programs(:albers).update_attributes(created_at: (Time.now - 60.days))
  end

  def test_initialize_from_start_of_program
    program = programs(:albers)
    time_now = Time.now.utc
    start_date = program.created_at.strftime("%b %d, %Y")
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"
    mentor_role = roles("#{program.id}_#{RoleConstants::MENTOR_NAME}")
    mentee_role = roles("#{program.id}_#{RoleConstants::STUDENT_NAME}")
    role_graph_color_mapping = OutcomesReportUtils::GraphColor.get_role_graph_color_mapping([mentor_role, mentee_role])
    enabled_status_mapping = { users: true, mentor_role.id => true, mentee_role.id => true }

    rolewise_summary = [
      { id: "membership_mentor", name: mentor_role.customized_term.pluralized_term, count: 4, change: nil },
      { id: "membership_student", name: mentee_role.customized_term.pluralized_term, count: 3, change: nil }
    ]

    User.expects(:get_ids_of_users_active_between).once.with(program, start_date, end_date, ids: nil).returns(1..10)
    User.expects(:get_ids_of_users_active_between).once.with(program, start_date, end_date, ids: nil, role_ids: [mentor_role.id]).returns(1..4)
    User.expects(:get_ids_of_users_active_between).once.with(program, start_date, end_date, ids: nil, role_ids: [mentee_role.id]).returns(1..3)
    user_outcomes_report = UserOutcomesReport.new(program, date_range, data_side: OutcomesReportUtils::DataType::ALL_DATA, include_rolewise_summary: true)
    assert_equal program.id, user_outcomes_report.programId
    assert_equal program.created_at.strftime("%b %d, %Y").to_datetime, user_outcomes_report.startDate
    assert_equal (time_now + 1.day).strftime("%b %d, %Y").to_datetime, user_outcomes_report.endDate
    assert_equal 0, user_outcomes_report.startDayIndex
    assert_equal 10, user_outcomes_report.totalCount
    assert_nil user_outcomes_report.overallChange
    assert_equal program.created_at.strftime("%b %d, %Y").to_datetime.to_i * 1000, user_outcomes_report.startDateForGraph
    assert_equal rolewise_summary, user_outcomes_report.rolewiseSummary
    assert_equal role_graph_color_mapping, user_outcomes_report.roleGraphColorMapping
    assert_equal enabled_status_mapping, user_outcomes_report.enabledStatusMapping
  end

  def test_initialize_with_no_data
    program = programs(:albers)
    time_now = Time.now.utc
    start_date = program.created_at.strftime("%b %d, %Y")
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"
    mentor_role = roles("#{program.id}_#{RoleConstants::MENTOR_NAME}")
    mentee_role = roles("#{program.id}_#{RoleConstants::STUDENT_NAME}")
    role_graph_color_mapping = OutcomesReportUtils::GraphColor.get_role_graph_color_mapping([mentor_role, mentee_role])
    enabled_status_mapping = { users: true, mentor_role.id => true, mentee_role.id => true }

    rolewise_summary = [
      { id: "membership_mentor", name: mentor_role.customized_term.pluralized_term, count: 0, change: nil },
      { id: "membership_student", name: mentee_role.customized_term.pluralized_term, count: 0, change: nil }
    ]

    User.expects(:get_ids_of_users_active_between).once.with(program, start_date, end_date, ids: nil).returns([])
    User.expects(:get_ids_of_users_active_between).once.with(program, start_date, end_date, ids: nil, role_ids: [mentor_role.id]).returns([])
    User.expects(:get_ids_of_users_active_between).once.with(program, start_date, end_date, ids: nil, role_ids: [mentee_role.id]).returns([])
    user_outcomes_report = UserOutcomesReport.new(program, date_range, data_side: OutcomesReportUtils::DataType::ALL_DATA, include_rolewise_summary: true)
    assert_equal program.id, user_outcomes_report.programId
    assert_equal start_date.to_datetime, user_outcomes_report.startDate
    assert_equal end_date.to_datetime, user_outcomes_report.endDate
    assert_equal 0, user_outcomes_report.startDayIndex
    assert_equal 0, user_outcomes_report.totalCount
    assert_nil user_outcomes_report.overallChange
    assert_equal start_date.to_datetime.to_i*1000, user_outcomes_report.startDateForGraph
    assert_equal rolewise_summary, user_outcomes_report.rolewiseSummary
    assert_equal role_graph_color_mapping, user_outcomes_report.roleGraphColorMapping
    assert_equal enabled_status_mapping, user_outcomes_report.enabledStatusMapping
  end

  def test_initialize_with_zero_past_and_zero_present_data
    program = programs(:albers)
    time_now = Time.now.utc
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    start_date = (time_now - 3.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"
    old_start_time = start_date.to_datetime - 5.days
    old_end_time = end_date.to_datetime - 5.days
    mentor_role = roles("#{program.id}_#{RoleConstants::MENTOR_NAME}")
    mentee_role = roles("#{program.id}_#{RoleConstants::STUDENT_NAME}")
    role_graph_color_mapping = OutcomesReportUtils::GraphColor.get_role_graph_color_mapping([mentor_role, mentee_role])
    enabled_status_mapping = { users: true, mentor_role.id => true, mentee_role.id => true }

    rolewise_summary = [
      { id: "membership_mentor", name: mentor_role.customized_term.pluralized_term, count: 0, change: nil },
      { id: "membership_student", name: mentee_role.customized_term.pluralized_term, count: 0, change: nil }
    ]

    User.expects(:get_ids_of_users_active_between).once.with(program, start_date, end_date, ids: nil).returns([])
    User.expects(:get_ids_of_users_active_between).once.with(program, start_date, end_date, ids: nil, role_ids: [mentor_role.id]).returns([])
    User.expects(:get_ids_of_users_active_between).once.with(program, start_date, end_date, ids: nil, role_ids: [mentee_role.id]).returns([])
    User.expects(:get_ids_of_users_active_between).once.with(program, old_start_time, old_end_time, ids: nil).returns([])
    User.expects(:get_ids_of_users_active_between).once.with(program, old_start_time, old_end_time, ids: nil, role_ids: [mentor_role.id]).returns([])
    User.expects(:get_ids_of_users_active_between).once.with(program, old_start_time, old_end_time, ids: nil, role_ids: [mentee_role.id]).returns([])
    user_outcomes_report = UserOutcomesReport.new(program, date_range, data_side: OutcomesReportUtils::DataType::ALL_DATA, include_rolewise_summary: true)
    assert_equal program.id, user_outcomes_report.programId
    assert_equal start_date.to_datetime, user_outcomes_report.startDate
    assert_equal end_date.to_datetime, user_outcomes_report.endDate
    assert_equal (start_date.to_datetime.beginning_of_day.utc.to_i - program.created_at.utc.beginning_of_day.to_i) / 1.day, user_outcomes_report.startDayIndex
    assert_equal 0, user_outcomes_report.totalCount
    assert_nil user_outcomes_report.overallChange
    assert_equal start_date.to_datetime.to_i*1000, user_outcomes_report.startDateForGraph
    assert_equal rolewise_summary, user_outcomes_report.rolewiseSummary
    assert_equal role_graph_color_mapping, user_outcomes_report.roleGraphColorMapping
    assert_equal enabled_status_mapping, user_outcomes_report.enabledStatusMapping
  end

  def test_initialize_with_zero_past_and_some_present_data
    program = programs(:albers)
    time_now = Time.now.utc
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    start_date = (time_now - 3.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"
    old_start_time = start_date.to_datetime - 5.days
    old_end_time = end_date.to_datetime - 5.days
    mentor_role = roles("#{program.id}_#{RoleConstants::MENTOR_NAME}")
    mentee_role = roles("#{program.id}_#{RoleConstants::STUDENT_NAME}")
    role_graph_color_mapping = OutcomesReportUtils::GraphColor.get_role_graph_color_mapping([mentor_role, mentee_role])
    enabled_status_mapping = { users: true, mentor_role.id => true, mentee_role.id => true }

    rolewise_summary = [
      { id: "membership_mentor", name: mentor_role.customized_term.pluralized_term, count: 4, change: nil },
      { id: "membership_student", name: mentee_role.customized_term.pluralized_term, count: 3, change: nil }
    ]

    User.expects(:get_ids_of_users_active_between).once.with(program, start_date, end_date, ids: nil).returns(1..10)
    User.expects(:get_ids_of_users_active_between).once.with(program, start_date, end_date, ids: nil, role_ids: [mentor_role.id]).returns(1..4)
    User.expects(:get_ids_of_users_active_between).once.with(program, start_date, end_date, ids: nil, role_ids: [mentee_role.id]).returns(1..3)
    User.expects(:get_ids_of_users_active_between).once.with(program, old_start_time, old_end_time, ids: nil).returns([])
    User.expects(:get_ids_of_users_active_between).once.with(program, old_start_time, old_end_time, ids: nil, role_ids: [mentor_role.id]).returns([])
    User.expects(:get_ids_of_users_active_between).once.with(program, old_start_time, old_end_time, ids: nil, role_ids: [mentee_role.id]).returns([])
    user_outcomes_report = UserOutcomesReport.new(program, date_range, data_side: OutcomesReportUtils::DataType::ALL_DATA, include_rolewise_summary: true)
    assert_equal program.id, user_outcomes_report.programId
    assert_equal start_date.to_datetime, user_outcomes_report.startDate
    assert_equal end_date.to_datetime, user_outcomes_report.endDate
    assert_equal (start_date.to_datetime.beginning_of_day.utc.to_i - program.created_at.utc.beginning_of_day.to_i) / 1.day, user_outcomes_report.startDayIndex
    assert_equal 10, user_outcomes_report.totalCount
    assert_nil user_outcomes_report.overallChange
    assert_equal start_date.to_datetime.to_i*1000, user_outcomes_report.startDateForGraph
    assert_equal rolewise_summary, user_outcomes_report.rolewiseSummary
    assert_equal role_graph_color_mapping, user_outcomes_report.roleGraphColorMapping
    assert_equal enabled_status_mapping, user_outcomes_report.enabledStatusMapping
  end

  def test_initialize_with_past_and_present_data
    program = programs(:albers)
    time_now = Time.now.utc
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    start_date = (time_now - 3.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"
    old_start_time = start_date.to_datetime - 5.days
    old_end_time = end_date.to_datetime - 5.days
    mentor_role = roles("#{program.id}_#{RoleConstants::MENTOR_NAME}")
    mentee_role = roles("#{program.id}_#{RoleConstants::STUDENT_NAME}")
    role_graph_color_mapping = OutcomesReportUtils::GraphColor.get_role_graph_color_mapping([mentor_role, mentee_role])
    enabled_status_mapping = { users: true, mentor_role.id => true, mentee_role.id => true }

    rolewise_summary = [
      { id: "membership_mentor", name: mentor_role.customized_term.pluralized_term, count: 3, change: 50.0 },
      { id: "membership_student", name: mentee_role.customized_term.pluralized_term, count: 2, change: 0.0 }
    ]

    User.expects(:get_ids_of_users_active_between).once.with(program, start_date, end_date, ids: nil).returns(1..9)
    User.expects(:get_ids_of_users_active_between).once.with(program, start_date, end_date, ids: nil, role_ids: [mentor_role.id]).returns(1..3)
    User.expects(:get_ids_of_users_active_between).once.with(program, start_date, end_date, ids: nil, role_ids: [mentee_role.id]).returns([1, 2])
    User.expects(:get_ids_of_users_active_between).once.with(program, old_start_time, old_end_time, ids: nil).returns(1..3)
    User.expects(:get_ids_of_users_active_between).once.with(program, old_start_time, old_end_time, ids: nil, role_ids: [mentor_role.id]).returns([1, 2])
    User.expects(:get_ids_of_users_active_between).once.with(program, old_start_time, old_end_time, ids: nil, role_ids: [mentee_role.id]).returns([1, 2])
    user_outcomes_report = UserOutcomesReport.new(program, date_range, data_side: OutcomesReportUtils::DataType::ALL_DATA, include_rolewise_summary: true)
    assert_equal program.id, user_outcomes_report.programId
    assert_equal start_date.to_datetime, user_outcomes_report.startDate
    assert_equal end_date.to_datetime, user_outcomes_report.endDate
    assert_equal (start_date.to_datetime.beginning_of_day.utc.to_i - program.created_at.utc.beginning_of_day.to_i) / 1.day, user_outcomes_report.startDayIndex
    assert_equal 9, user_outcomes_report.totalCount
    assert_equal 200.0, user_outcomes_report.overallChange
    assert_equal start_date.to_datetime.to_i*1000, user_outcomes_report.startDateForGraph
    assert_equal rolewise_summary, user_outcomes_report.rolewiseSummary
    assert_equal role_graph_color_mapping, user_outcomes_report.roleGraphColorMapping
    assert_equal enabled_status_mapping, user_outcomes_report.enabledStatusMapping
  end

  def test_initialize_with_only_non_graph_data
    program = programs(:albers)
    time_now = Time.now.utc
    start_date = program.created_at.strftime("%b %d, %Y")
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"
    mentor_role = roles("#{program.id}_#{RoleConstants::MENTOR_NAME}")
    mentee_role = roles("#{program.id}_#{RoleConstants::STUDENT_NAME}")

    rolewise_summary = [
      { id: "membership_mentor", name: mentor_role.customized_term.pluralized_term, count: 0, change: nil },
      { id: "membership_student", name: mentee_role.customized_term.pluralized_term, count: 0, change: nil }
    ]

    User.expects(:get_ids_of_users_active_between).once.with(program, start_date, end_date, ids: nil).returns([])
    User.expects(:get_ids_of_users_active_between).once.with(program, start_date, end_date, ids: nil, role_ids: [mentor_role.id]).returns([])
    User.expects(:get_ids_of_users_active_between).once.with(program, start_date, end_date, ids: nil, role_ids: [mentee_role.id]).returns([])
    user_outcomes_report = UserOutcomesReport.new(program, date_range, data_side: OutcomesReportUtils::DataType::NON_GRAPH_DATA, include_rolewise_summary: true)
    assert_equal program.id, user_outcomes_report.programId
    assert_equal start_date.to_datetime, user_outcomes_report.startDate
    assert_equal end_date.to_datetime, user_outcomes_report.endDate
    assert_equal 0, user_outcomes_report.totalCount
    assert_equal rolewise_summary, user_outcomes_report.rolewiseSummary
    assert_nil user_outcomes_report.startDayIndex
    assert_nil user_outcomes_report.overallChange
    assert_nil user_outcomes_report.startDateForGraph
    assert_nil user_outcomes_report.roleGraphColorMapping
    assert_nil user_outcomes_report.graphData
  end

  def test_initialize_with_only_graph_data
    program = programs(:albers)
    time_now = Time.now.utc
    start_date = program.created_at.strftime("%b %d, %Y")
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"
    mentor_role = roles("#{program.id}_#{RoleConstants::MENTOR_NAME}")
    mentee_role = roles("#{program.id}_#{RoleConstants::STUDENT_NAME}")
    role_graph_color_mapping = OutcomesReportUtils::GraphColor.get_role_graph_color_mapping([mentor_role, mentee_role])
    enabled_status_mapping = { users: true, mentor_role.id => true, mentee_role.id => true }

    user_outcomes_report = UserOutcomesReport.new(program, date_range, data_side: OutcomesReportUtils::DataType::GRAPH_DATA)
    assert_equal program.id, user_outcomes_report.programId
    assert_equal program.created_at.strftime("%b %d, %Y").to_datetime, user_outcomes_report.startDate
    assert_equal (time_now + 1.day).strftime("%b %d, %Y").to_datetime, user_outcomes_report.endDate
    assert_equal 0, user_outcomes_report.startDayIndex
    assert_nil user_outcomes_report.totalCount
    assert_nil user_outcomes_report.overallChange
    assert_nil user_outcomes_report.rolewiseSummary
    assert_equal role_graph_color_mapping, user_outcomes_report.roleGraphColorMapping
    assert_equal enabled_status_mapping, user_outcomes_report.enabledStatusMapping
    assert_equal program.created_at.strftime("%b %d, %Y").to_datetime.to_i*1000, user_outcomes_report.startDateForGraph
    assert user_outcomes_report.graphData
  end

  def test_initialize_with_fetch_user_state
    program = programs(:albers)
    time_now = Time.now.utc
    start_date = program.created_at.strftime("%b %d, %Y")
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"
    mentor_role = roles("#{program.id}_#{RoleConstants::MENTOR_NAME}")
    mentee_role = roles("#{program.id}_#{RoleConstants::STUDENT_NAME}")
    role_graph_color_mapping = OutcomesReportUtils::GraphColor.get_role_graph_color_mapping([mentor_role, mentee_role])

    rolewise_summary = [
      { name: mentor_role.customized_term.pluralized_term, count: 4, change: nil, new_roles: 2, suspended_roles: 1 },
      { name: mentee_role.customized_term.pluralized_term, count: 3, change: nil, new_roles: 1, suspended_roles: 0 }
    ]

    User.expects(:get_ids_of_users_active_between).once.with(program, start_date, end_date, ids: nil).returns(1..10)
    User.expects(:get_ids_of_users_active_between).once.with(program, start_date, end_date, ids: nil, role_ids: [mentor_role.id]).returns(1..4)
    User.expects(:get_ids_of_users_active_between).once.with(program, start_date, end_date, ids: nil, role_ids: [mentee_role.id]).returns(1..3)
    User.expects(:get_ids_of_new_active_users).once.with(program, start_date, end_date, all_of(has_entry(ids: nil), has_key(:cache_source), Not(has_key(:role_ids)))).returns([1, 2])
    User.expects(:get_ids_of_new_active_users).once.with(program, start_date, end_date, all_of(has_entries(ids: nil, role_ids: [mentor_role.id]), has_key(:cache_source))).returns([1, 2])
    User.expects(:get_ids_of_new_active_users).once.with(program, start_date, end_date, all_of(has_entries(ids: nil, role_ids: [mentee_role.id]), has_key(:cache_source))).returns([1])
    User.expects(:get_ids_of_new_suspended_users).once.with(program, start_date, end_date, all_of(has_entry(ids: nil), has_key(:cache_source), Not(has_key(:role_ids)))).returns([1])
    User.expects(:get_ids_of_new_suspended_users).once.with(program, start_date, end_date, all_of(has_entries(ids: nil, role_ids: [mentor_role.id]), has_key(:cache_source))).returns([1])
    User.expects(:get_ids_of_new_suspended_users).once.with(program, start_date, end_date, all_of(has_entries(ids: nil, role_ids: [mentee_role.id]), has_key(:cache_source))).returns([])
    user_outcomes_report = UserOutcomesReport.new(program, date_range, data_side: OutcomesReportUtils::DataType::ALL_DATA, fetch_user_state: true, include_rolewise_summary: true)
    assert_equal program.id, user_outcomes_report.programId
    assert_equal program.created_at.strftime("%b %d, %Y").to_datetime, user_outcomes_report.startDate
    assert_equal (time_now + 1.day).strftime("%b %d, %Y").to_datetime, user_outcomes_report.endDate
    assert_equal 0, user_outcomes_report.startDayIndex
    assert_equal 10, user_outcomes_report.totalCount
    assert_equal 2, user_outcomes_report.userState[:new_users]
    assert_equal 1, user_outcomes_report.userState[:suspended_users]
    assert_nil user_outcomes_report.overallChange
    assert_equal program.created_at.strftime("%b %d, %Y").to_datetime.to_i*1000, user_outcomes_report.startDateForGraph
    assert_equal rolewise_summary, user_outcomes_report.rolewiseSummary
    assert_equal role_graph_color_mapping, user_outcomes_report.roleGraphColorMapping
  end
end
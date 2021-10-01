require_relative './../../../test_helper'

class ConnectionOutcomesReportTest < ActiveSupport::TestCase

  def setup
    super
    programs(:albers).update_attributes(created_at: (Time.now - 60.days))
  end

  def test_initialize_for_active_connection_from_start_of_program
    program = programs(:albers)
    time_now = Time.now.utc
    start_date = program.created_at.strftime("%b %d, %Y")
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"
    mentor_role = roles("#{program.id}_#{RoleConstants::MENTOR_NAME}")
    mentee_role = roles("#{program.id}_#{RoleConstants::STUDENT_NAME}")
    role_graph_color_mapping = OutcomesReportUtils::GraphColor.get_role_graph_color_mapping([mentor_role, mentee_role])
    enabled_status_mapping = { users: true, mentor_role.id => false, mentee_role.id => false, total_connections_or_meetings: true }
    start_time = Date.parse(start_date).to_datetime
    end_time = Date.parse(end_date).to_datetime

    User.expects(:get_ids_of_connected_users_active_between).with(program, start_time, end_time, ids: nil, role: nil).once.returns(1..10)
    User.expects(:get_ids_of_connected_users_active_between).with(program, start_time, end_time, ids: nil, role: mentor_role).once.returns(1..5)
    User.expects(:get_ids_of_connected_users_active_between).with(program, start_time, end_time, ids: nil, role: mentee_role).once.returns(1..5)
    Group.expects(:get_ids_of_groups_active_between).once.returns(1..10)
    ConnectionReportCommon.any_instance.expects(:computed_graph_data_for_users_of_ongoing_connections).returns(name: "Users", data: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 8, 8], color: "#434348", visibility: true)
    ConnectionReportCommon.any_instance.expects(:computed_graph_data_for_users_of_ongoing_connections_per_role).with(mentor_role).returns(name: "Mentors", data: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 4, 4], color: "#90ed7d", visibility: false)
    ConnectionReportCommon.any_instance.expects(:computed_graph_data_for_users_of_ongoing_connections_per_role).with(mentee_role).returns(name: "Students", data: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 4, 4], color: "#f7a35c", visibility: false)
    ConnectionReportCommon.any_instance.expects(:computed_graph_data_for_ongoing_connections).returns(name: "Mentoring Connections", data: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 12, 12, 12], color: "#7cb5ec", visibility: true)
    connection_outcomes_report = ConnectionOutcomesReport.new(program, date_range, data_side: OutcomesReportUtils::DataType::ALL_DATA)
    assert_equal Group::Status::ACTIVE, connection_outcomes_report.forStatus
    assert_equal program.created_at.strftime("%b %d, %Y").to_datetime, connection_outcomes_report.startDate
    assert_equal (time_now + 1.day).strftime("%b %d, %Y").to_datetime, connection_outcomes_report.endDate
    assert_equal 0, connection_outcomes_report.startDayIndex
    assert_equal 10, connection_outcomes_report.totalCount
    assert_equal role_graph_color_mapping, connection_outcomes_report.roleGraphColorMapping
    assert_equal enabled_status_mapping, connection_outcomes_report.enabledStatusMapping
    assert_nil connection_outcomes_report.overallChange
  end

  def test_initialize_for_active_connection_from_start_of_program_with_no_data
    program = programs(:albers)
    time_now = Time.now.utc
    start_date = program.created_at.strftime("%b %d, %Y")
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"
    mentor_role = roles("#{program.id}_#{RoleConstants::MENTOR_NAME}")
    mentee_role = roles("#{program.id}_#{RoleConstants::STUDENT_NAME}")
    role_graph_color_mapping = OutcomesReportUtils::GraphColor.get_role_graph_color_mapping([mentor_role, mentee_role])
    enabled_status_mapping = { users: true, mentor_role.id => false, mentee_role.id => false, total_connections_or_meetings: true }
    start_time = Date.parse(start_date).to_datetime
    end_time = Date.parse(end_date).to_datetime

    User.expects(:get_ids_of_connected_users_active_between).with(program, start_time, end_time, ids: nil, role: nil).once.returns(1..10)
    User.expects(:get_ids_of_connected_users_active_between).with(program, start_time, end_time, ids: nil, role: mentor_role).once.returns(1..5)
    User.expects(:get_ids_of_connected_users_active_between).with(program, start_time, end_time, ids: nil, role: mentee_role).once.returns(1..5)
    Group.expects(:get_ids_of_groups_active_between).once.returns([])
    ConnectionReportCommon.any_instance.expects(:computed_graph_data_for_users_of_ongoing_connections).returns(name: "Users", data: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 8, 8], color: "#434348", visibility: true)
    ConnectionReportCommon.any_instance.expects(:computed_graph_data_for_users_of_ongoing_connections_per_role).with(mentor_role).returns(name: "Mentors", data: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 4, 4], color: "#90ed7d", visibility: false)
    ConnectionReportCommon.any_instance.expects(:computed_graph_data_for_users_of_ongoing_connections_per_role).with(mentee_role).returns(name: "Students", data: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 4, 4], color: "#f7a35c", visibility: false)
    ConnectionReportCommon.any_instance.expects(:computed_graph_data_for_ongoing_connections).returns(name: "Mentoring Connections", data: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 12, 12, 12], color: "#7cb5ec", visibility: true)
    connection_outcomes_report = ConnectionOutcomesReport.new(program, date_range, data_side: OutcomesReportUtils::DataType::ALL_DATA)
    assert_equal Group::Status::ACTIVE, connection_outcomes_report.forStatus
    assert_equal program.created_at.strftime("%b %d, %Y").to_datetime, connection_outcomes_report.startDate
    assert_equal (time_now + 1.day).strftime("%b %d, %Y").to_datetime, connection_outcomes_report.endDate
    assert_equal 0, connection_outcomes_report.startDayIndex
    assert_equal 0, connection_outcomes_report.totalCount
    assert_equal role_graph_color_mapping, connection_outcomes_report.roleGraphColorMapping
    assert_equal enabled_status_mapping, connection_outcomes_report.enabledStatusMapping
    assert_nil connection_outcomes_report.overallChange
  end

  def test_initialize_for_active_connection_from_start_of_program_with_no_past_present_data
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
    enabled_status_mapping = { users: true, mentor_role.id => false, mentee_role.id => false, total_connections_or_meetings: true }
    start_time = Date.parse(start_date).to_datetime
    end_time = Date.parse(end_date).to_datetime

    User.expects(:get_ids_of_connected_users_active_between).with(program, start_time, end_time, ids: nil, role: nil).once.returns(1..10)
    User.expects(:get_ids_of_connected_users_active_between).with(program, start_time, end_time, ids: nil, role: mentor_role).once.returns(1..5)
    User.expects(:get_ids_of_connected_users_active_between).with(program, start_time, end_time, ids: nil, role: mentee_role).once.returns(1..5)
    User.expects(:get_ids_of_connected_users_active_between).with(program, old_start_time, old_end_time, ids: nil, role: nil).once.returns([])
    User.expects(:get_ids_of_connected_users_active_between).with(program, old_start_time, old_end_time, ids: nil, role: mentor_role).once.returns([])
    User.expects(:get_ids_of_connected_users_active_between).with(program, old_start_time, old_end_time, ids: nil, role: mentee_role).once.returns([])
    ConnectionReportCommon.any_instance.expects(:computed_graph_data_for_users_of_ongoing_connections).returns(name: "Users", data: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 8, 8], color: "#434348", visibility: true)
    ConnectionReportCommon.any_instance.expects(:computed_graph_data_for_users_of_ongoing_connections_per_role).with(mentor_role).returns(name: "Mentors", data: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 4, 4], color: "#90ed7d", visibility: false)
    ConnectionReportCommon.any_instance.expects(:computed_graph_data_for_users_of_ongoing_connections_per_role).with(mentee_role).returns(name: "Students", data: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 4, 4], color: "#f7a35c", visibility: false)
    ConnectionReportCommon.any_instance.expects(:computed_graph_data_for_ongoing_connections).returns(name: "Mentoring Connections", data: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 12, 12, 12], color: "#7cb5ec", visibility: true)
    Group.expects(:get_ids_of_groups_active_between).twice.returns([])
    connection_outcomes_report = ConnectionOutcomesReport.new(program, date_range, data_side: OutcomesReportUtils::DataType::ALL_DATA)
    assert_equal Group::Status::ACTIVE, connection_outcomes_report.forStatus
    assert_equal start_date.to_datetime, connection_outcomes_report.startDate
    assert_equal end_date.to_datetime, connection_outcomes_report.endDate
    assert_equal ((start_date.to_datetime.beginning_of_day.utc.to_i - program.created_at.utc.beginning_of_day.to_i) / 1.day), connection_outcomes_report.startDayIndex
    assert_equal 0, connection_outcomes_report.totalCount
    assert_equal role_graph_color_mapping, connection_outcomes_report.roleGraphColorMapping
    assert_equal enabled_status_mapping, connection_outcomes_report.enabledStatusMapping
    assert_nil connection_outcomes_report.overallChange
  end

  def test_initialize_for_active_connection_from_start_of_program_with_no_past_some_present_data
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
    enabled_status_mapping = { users: true, mentor_role.id => false, mentee_role.id => false, total_connections_or_meetings: true }
    start_time = Date.parse(start_date).to_datetime
    end_time = Date.parse(end_date).to_datetime

    User.expects(:get_ids_of_connected_users_active_between).with(program, start_time, end_time, ids: nil, role: nil).once.returns(1..10)
    User.expects(:get_ids_of_connected_users_active_between).with(program, start_time, end_time, ids: nil, role: mentor_role).once.returns(1..5)
    User.expects(:get_ids_of_connected_users_active_between).with(program, start_time, end_time, ids: nil, role: mentee_role).once.returns(1..5)
    User.expects(:get_ids_of_connected_users_active_between).with(program, old_start_time, old_end_time, ids: nil, role: nil).once.returns(0)
    User.expects(:get_ids_of_connected_users_active_between).with(program, old_start_time, old_end_time, ids: nil, role: mentor_role).once.returns([])
    User.expects(:get_ids_of_connected_users_active_between).with(program, old_start_time, old_end_time, ids: nil, role: mentee_role).once.returns([])
    Group.expects(:get_ids_of_groups_active_between).once.with(program, start_date, end_date, ids: nil).returns(1..10)
    Group.expects(:get_ids_of_groups_active_between).once.with(program, old_start_time, old_end_time, ids: nil).returns([])
    ConnectionReportCommon.any_instance.expects(:computed_graph_data_for_users_of_ongoing_connections).returns(name: "Users", data: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 8, 8], color: "#434348", visibility: true)
    ConnectionReportCommon.any_instance.expects(:computed_graph_data_for_users_of_ongoing_connections_per_role).with(mentor_role).returns(name: "Mentors", data: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 4, 4], color: "#90ed7d", visibility: false)
    ConnectionReportCommon.any_instance.expects(:computed_graph_data_for_users_of_ongoing_connections_per_role).with(mentee_role).returns(name: "Students", data: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 4, 4], color: "#f7a35c", visibility: false)
    ConnectionReportCommon.any_instance.expects(:computed_graph_data_for_ongoing_connections).returns(name: "Mentoring Connections", data: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 12, 12, 12], color: "#7cb5ec", visibility: true)
    connection_outcomes_report = ConnectionOutcomesReport.new(program, date_range, data_side: OutcomesReportUtils::DataType::ALL_DATA)
    assert_equal Group::Status::ACTIVE, connection_outcomes_report.forStatus
    assert_equal start_date.to_datetime, connection_outcomes_report.startDate
    assert_equal end_date.to_datetime, connection_outcomes_report.endDate
    assert_equal (start_date.to_datetime.beginning_of_day.utc.to_i - program.created_at.utc.beginning_of_day.to_i) / 1.day, connection_outcomes_report.startDayIndex
    assert_equal 10, connection_outcomes_report.totalCount
    assert_equal role_graph_color_mapping, connection_outcomes_report.roleGraphColorMapping
    assert_equal enabled_status_mapping, connection_outcomes_report.enabledStatusMapping
    assert_nil connection_outcomes_report.overallChange
  end

  def test_initialize_for_active_connection_from_start_of_program_with_past_some_present_data
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
    enabled_status_mapping = { users: true, mentor_role.id => false, mentee_role.id => false, total_connections_or_meetings: true }
    start_time = Date.parse(start_date).to_datetime
    end_time = Date.parse(end_date).to_datetime

    User.expects(:get_ids_of_connected_users_active_between).with(program, start_time, end_time, ids: nil, role: nil).once.returns(1..10)
    User.expects(:get_ids_of_connected_users_active_between).with(program, start_time, end_time, ids: nil, role: mentor_role).once.returns(1..5)
    User.expects(:get_ids_of_connected_users_active_between).with(program, start_time, end_time, ids: nil, role: mentee_role).once.returns(1..5)
    User.expects(:get_ids_of_connected_users_active_between).with(program, old_start_time, old_end_time, ids: nil, role: nil).once.returns([])
    User.expects(:get_ids_of_connected_users_active_between).with(program, old_start_time, old_end_time, ids: nil, role: mentor_role).once.returns([])
    User.expects(:get_ids_of_connected_users_active_between).with(program, old_start_time, old_end_time, ids: nil, role: mentee_role).once.returns([])
    Group.expects(:get_ids_of_groups_active_between).once.with(program, start_date, end_date, ids: nil).returns(1..10)
    Group.expects(:get_ids_of_groups_active_between).once.with(program, old_start_time, old_end_time, ids: nil).returns(1..2)
    ConnectionReportCommon.any_instance.expects(:computed_graph_data_for_users_of_ongoing_connections).returns(name: "Users", data: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 8, 8], color: "#434348", visibility: true)
    ConnectionReportCommon.any_instance.expects(:computed_graph_data_for_users_of_ongoing_connections_per_role).with(mentor_role).returns(name: "Mentors", data: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 4, 4], color: "#90ed7d", visibility: false)
    ConnectionReportCommon.any_instance.expects(:computed_graph_data_for_users_of_ongoing_connections_per_role).with(mentee_role).returns(name: "Students", data: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 4, 4], color: "#f7a35c", visibility: false)
    ConnectionReportCommon.any_instance.expects(:computed_graph_data_for_ongoing_connections).returns(name: "Mentoring Connections", data: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 12, 12, 12], color: "#7cb5ec", visibility: true)
    connection_outcomes_report = ConnectionOutcomesReport.new(program, date_range, data_side: OutcomesReportUtils::DataType::ALL_DATA)
    assert_equal Group::Status::ACTIVE, connection_outcomes_report.forStatus
    assert_equal start_date.to_datetime, connection_outcomes_report.startDate
    assert_equal end_date.to_datetime, connection_outcomes_report.endDate
    assert_equal (start_date.to_datetime.beginning_of_day.utc.to_i - program.created_at.utc.beginning_of_day.to_i)/1.day, connection_outcomes_report.startDayIndex
    assert_equal 10, connection_outcomes_report.totalCount
    assert_equal 400.0, connection_outcomes_report.overallChange
    assert_equal role_graph_color_mapping, connection_outcomes_report.roleGraphColorMapping
    assert_equal enabled_status_mapping, connection_outcomes_report.enabledStatusMapping
  end

  def test_initialize_for_active_connection_from_start_of_program_with_past_present_data
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
    enabled_status_mapping = { users: true, mentor_role.id => false, mentee_role.id => false, total_connections_or_meetings: true }
    start_time = Date.parse(start_date).to_datetime
    end_time = Date.parse(end_date).to_datetime

    User.expects(:get_ids_of_connected_users_active_between).with(program, start_time, end_time, ids: nil, role: nil).once.returns(1..10)
    User.expects(:get_ids_of_connected_users_active_between).with(program, start_time, end_time, ids: nil, role: mentor_role).once.returns(1..5)
    User.expects(:get_ids_of_connected_users_active_between).with(program, start_time, end_time, ids: nil, role: mentee_role).once.returns(1..5)
    User.expects(:get_ids_of_connected_users_active_between).with(program, old_start_time, old_end_time, ids: nil, role: nil).once.returns([])
    User.expects(:get_ids_of_connected_users_active_between).with(program, old_start_time, old_end_time, ids: nil, role: mentor_role).once.returns([])
    User.expects(:get_ids_of_connected_users_active_between).with(program, old_start_time, old_end_time, ids: nil, role: mentee_role).once.returns([])
    ConnectionReportCommon.any_instance.expects(:computed_graph_data_for_users_of_ongoing_connections).returns(name: "Users", data: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 8, 8], color: "#434348", visibility: true)
    ConnectionReportCommon.any_instance.expects(:computed_graph_data_for_users_of_ongoing_connections_per_role).with(mentor_role).returns(name: "Mentors", data: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 4, 4], color: "#90ed7d", visibility: false)
    ConnectionReportCommon.any_instance.expects(:computed_graph_data_for_users_of_ongoing_connections_per_role).with(mentee_role).returns(name: "Students", data: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 4, 4], color: "#f7a35c", visibility: false)
    ConnectionReportCommon.any_instance.expects(:computed_graph_data_for_ongoing_connections).returns(name: "Mentoring Connections", data: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 12, 12, 12], color: "#7cb5ec", visibility: true)
    Group.expects(:get_ids_of_groups_active_between).twice.returns([])
    connection_outcomes_report = ConnectionOutcomesReport.new(program, date_range, data_side: OutcomesReportUtils::DataType::ALL_DATA)
    assert_equal Group::Status::ACTIVE, connection_outcomes_report.forStatus
    assert_equal start_date.to_datetime, connection_outcomes_report.startDate
    assert_equal end_date.to_datetime, connection_outcomes_report.endDate
    assert_equal (start_date.to_datetime.beginning_of_day.utc.to_i - program.created_at.utc.beginning_of_day.to_i) / 1.day, connection_outcomes_report.startDayIndex
    assert_equal 0, connection_outcomes_report.totalCount
    assert_equal role_graph_color_mapping, connection_outcomes_report.roleGraphColorMapping
    assert_equal enabled_status_mapping, connection_outcomes_report.enabledStatusMapping
    assert_nil connection_outcomes_report.overallChange
  end

  def test_initialize_for_closed_connection
    program = programs(:albers)
    time_now = Time.now.utc
    date_range = "#{program.created_at.strftime("%b %d, %Y")} - #{(time_now + 1.day).strftime("%b %d, %Y")}"
    connection_outcomes_report = ConnectionOutcomesReport.new(program, date_range, {status: Group::Status::CLOSED})
    mentor_role = roles("#{program.id}_#{RoleConstants::MENTOR_NAME}")
    mentee_role = roles("#{program.id}_#{RoleConstants::STUDENT_NAME}")
    user_summary = {name: "Users", count: 2, change: nil}
    rolewise_summary = [{id: "ongoing_mentor", name: mentor_role.customized_term.pluralized_term, count: 1, change: nil}, {id: "ongoing_student", name: mentee_role.customized_term.pluralized_term, count: 1, change: nil}]
    role_graph_color_mapping = OutcomesReportUtils::GraphColor.get_role_graph_color_mapping([mentor_role, mentee_role])
    enabled_status_mapping = {users: true, mentor_role.id => false, mentee_role.id => false, total_connections_or_meetings: true}
    completed_connection = program.groups.closed.first
    total_days = ((time_now + 1.day).strftime("%b %d, %Y").to_datetime - program.created_at.strftime("%b %d, %Y").to_datetime).to_i + 1

    assert_equal Group::Status::CLOSED, connection_outcomes_report.forStatus
    assert_equal program.created_at.strftime("%b %d, %Y").to_datetime, connection_outcomes_report.startDate
    assert_equal (time_now + 1.day).strftime("%b %d, %Y").to_datetime, connection_outcomes_report.endDate
    assert_equal 1, connection_outcomes_report.totalCount
    assert_nil connection_outcomes_report.overallChange
    assert_equal user_summary, connection_outcomes_report.userSummary
    assert_equal_unordered rolewise_summary, connection_outcomes_report.rolewiseSummary
    assert_equal role_graph_color_mapping, connection_outcomes_report.roleGraphColorMapping
    assert_equal enabled_status_mapping, connection_outcomes_report.enabledStatusMapping

    start_month_index = program.created_at.utc.at_beginning_of_month.to_datetime.to_i
    end_month_index = (time_now + 1.day).utc.at_beginning_of_month.to_datetime.to_i
    month_index = program.created_at.utc.at_beginning_of_month.to_datetime
    connection_closed_at_month_index = completed_connection.closed_at.utc.at_beginning_of_month.to_datetime.to_i

    data1 = []
    data2 = []
    while(month_index.to_i <= end_month_index)
      if(month_index.to_i == connection_closed_at_month_index)
        data1 << [month_index.to_i*1000, 1]
        data2 << [month_index.to_i*1000, 2]
      else
        data1 << [month_index.to_i*1000, 0]
        data2 << [month_index.to_i*1000, 0]
      end
      month_index += 1.month
    end
    connection_graph_data = [{name: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).pluralized_term, data: data1, color: '#7cb5ec', visibility: true}]
    connection_graph_data << {name: "Users", data: data2, color: '#434348', visibility: true}
    connection_graph_data << {name: mentor_role.customized_term.pluralized_term, data: data1, color: '#90ed7d', visibility: false}
    connection_graph_data << {name: mentee_role.customized_term.pluralized_term, data: data1, color: '#f7a35c', visibility: false}
    assert_equal_unordered connection_graph_data, connection_outcomes_report.graphData
  end

  def test_initialize_for_closed_connection_with_graphs_enabled_disabled
    program = programs(:albers)
    time_now = Time.now.utc
    date_range = "#{program.created_at.strftime("%b %d, %Y")} - #{(time_now + 1.day).strftime("%b %d, %Y")}"
    connection_outcomes_report = ConnectionOutcomesReport.new(program, date_range, {status: Group::Status::CLOSED, enabled_status: "1010"})
    mentor_role = roles("#{program.id}_#{RoleConstants::MENTOR_NAME}")
    mentee_role = roles("#{program.id}_#{RoleConstants::STUDENT_NAME}")
    user_summary = {name: "Users", count: 2, change: nil}
    rolewise_summary = [{id: "ongoing_mentor", name: mentor_role.customized_term.pluralized_term, count: 1, change: nil}, {id: "ongoing_student", name: mentee_role.customized_term.pluralized_term, count: 1, change: nil}]
    role_graph_color_mapping = OutcomesReportUtils::GraphColor.get_role_graph_color_mapping([mentor_role, mentee_role])
    enabled_status_mapping = {users: true, mentor_role.id => false, mentee_role.id => true, total_connections_or_meetings: false}
    completed_connection = program.groups.closed.first
    total_days = ((time_now + 1.day).strftime("%b %d, %Y").to_datetime - program.created_at.strftime("%b %d, %Y").to_datetime).to_i + 1

    assert_equal Group::Status::CLOSED, connection_outcomes_report.forStatus
    assert_equal program.created_at.strftime("%b %d, %Y").to_datetime, connection_outcomes_report.startDate
    assert_equal (time_now + 1.day).strftime("%b %d, %Y").to_datetime, connection_outcomes_report.endDate
    assert_equal 1, connection_outcomes_report.totalCount
    assert_nil connection_outcomes_report.overallChange
    assert_equal user_summary, connection_outcomes_report.userSummary
    assert_equal_unordered rolewise_summary, connection_outcomes_report.rolewiseSummary
    assert_equal role_graph_color_mapping, connection_outcomes_report.roleGraphColorMapping
    assert_equal enabled_status_mapping, connection_outcomes_report.enabledStatusMapping

    start_month_index = program.created_at.utc.at_beginning_of_month.to_datetime.to_i
    end_month_index = (time_now + 1.day).utc.at_beginning_of_month.to_datetime.to_i
    month_index = program.created_at.utc.at_beginning_of_month.to_datetime
    connection_closed_at_month_index = completed_connection.closed_at.utc.at_beginning_of_month.to_datetime.to_i

    data1 = []
    data2 = []
    while(month_index.to_i <= end_month_index)
      if(month_index.to_i == connection_closed_at_month_index)
        data1 << [month_index.to_i*1000, 1]
        data2 << [month_index.to_i*1000, 2]
      else
        data1 << [month_index.to_i*1000, 0]
        data2 << [month_index.to_i*1000, 0]
      end
      month_index += 1.month
    end
    connection_graph_data = [{name: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).pluralized_term, data: data1, color: '#7cb5ec', visibility: false}]
    connection_graph_data << {name: "Users", data: data2, color: '#434348', visibility: true}
    connection_graph_data << {name: mentor_role.customized_term.pluralized_term, data: data1, color: '#90ed7d', visibility: false}
    connection_graph_data << {name: mentee_role.customized_term.pluralized_term, data: data1, color: '#f7a35c', visibility: true}
    assert_equal_unordered connection_graph_data, connection_outcomes_report.graphData
  end

  def test_initialize_for_closed_connection_with_no_data
    program = programs(:albers)
    completed_connection = program.groups.closed.first
    time_now = completed_connection.closed_at - 4.day
    date_range = "#{program.created_at.strftime("%b %d, %Y")} - #{(time_now).strftime("%b %d, %Y")}"
    connection_outcomes_report = ConnectionOutcomesReport.new(program, date_range, {status: Group::Status::CLOSED})

    mentor_role = roles("#{program.id}_#{RoleConstants::MENTOR_NAME}")
    mentee_role = roles("#{program.id}_#{RoleConstants::STUDENT_NAME}")
    user_summary = {name: "Users", count: 0, change: nil}
    rolewise_summary = [{id: "ongoing_mentor", name: mentor_role.customized_term.pluralized_term, count: 0, change: nil}, {id: "ongoing_student", name: mentee_role.customized_term.pluralized_term, count: 0, change: nil}]
    role_graph_color_mapping = OutcomesReportUtils::GraphColor.get_role_graph_color_mapping([mentor_role, mentee_role])
    enabled_status_mapping = {users: true, mentor_role.id => false, mentee_role.id => false, total_connections_or_meetings: true}

    start_month_index = program.created_at.utc.at_beginning_of_month.to_datetime.to_i
    end_month_index = time_now.utc.at_beginning_of_month.to_datetime.to_i
    month_index = program.created_at.utc.at_beginning_of_month.to_datetime

    data = []
    while(month_index.to_i <= end_month_index)
      data << [month_index.to_i*1000, 0]
      month_index += 1.month
    end

    assert_equal Group::Status::CLOSED, connection_outcomes_report.forStatus
    assert_equal program.created_at.strftime("%b %d, %Y").to_datetime, connection_outcomes_report.startDate
    assert_equal (time_now).strftime("%b %d, %Y").to_datetime, connection_outcomes_report.endDate
    assert_equal 0, connection_outcomes_report.totalCount
    assert_nil connection_outcomes_report.overallChange
    assert_equal user_summary, connection_outcomes_report.userSummary
    assert_equal_unordered rolewise_summary, connection_outcomes_report.rolewiseSummary
    assert_equal role_graph_color_mapping, connection_outcomes_report.roleGraphColorMapping
    assert_equal enabled_status_mapping, connection_outcomes_report.enabledStatusMapping

    connection_graph_data = [{name: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).pluralized_term, data: data, color: '#7cb5ec', visibility: true}]
    connection_graph_data << {name: "Users", data: data, color: '#434348', visibility: true}
    connection_graph_data << {name: mentor_role.customized_term.pluralized_term, data: data, color: '#90ed7d', visibility: false}
    connection_graph_data << {name: mentee_role.customized_term.pluralized_term, data: data, color: '#f7a35c', visibility: false}
    assert_equal_unordered connection_graph_data, connection_outcomes_report.graphData
  end

  def test_initialize_for_closed_connection_with_closed_but_incomplete_group
    program = programs(:albers)
    completed_connection = program.groups.closed.first
    incomplete_reason = (program.group_closure_reasons - program.group_closure_reasons.completed).first
    completed_connection.update_attribute(:closure_reason_id, incomplete_reason.id)
    time_now = (Time.now.utc + 1.day)
    date_range = "#{program.created_at.strftime("%b %d, %Y")} - #{(time_now).strftime("%b %d, %Y")}"
    connection_outcomes_report = ConnectionOutcomesReport.new(program, date_range, {status: Group::Status::CLOSED})

    mentor_role = roles("#{program.id}_#{RoleConstants::MENTOR_NAME}")
    mentee_role = roles("#{program.id}_#{RoleConstants::STUDENT_NAME}")
    user_summary = {name: "Users", count: 0, change: nil}
    rolewise_summary = [{id: "ongoing_mentor", name: mentor_role.customized_term.pluralized_term, count: 0, change: nil}, {id: "ongoing_student", name: mentee_role.customized_term.pluralized_term, count: 0, change: nil}]
    role_graph_color_mapping = OutcomesReportUtils::GraphColor.get_role_graph_color_mapping([mentor_role, mentee_role])
    enabled_status_mapping = {users: true, mentor_role.id => false, mentee_role.id => false, total_connections_or_meetings: true}

    start_month_index = program.created_at.utc.at_beginning_of_month.to_datetime.to_i
    end_month_index = time_now.utc.at_beginning_of_month.to_datetime.to_i
    month_index = program.created_at.utc.at_beginning_of_month.to_datetime

    data = []
    while(month_index.to_i <= end_month_index)
      data << [month_index.to_i*1000, 0]
      month_index += 1.month
    end

    assert_equal Group::Status::CLOSED, connection_outcomes_report.forStatus
    assert_equal program.created_at.strftime("%b %d, %Y").to_datetime, connection_outcomes_report.startDate
    assert_equal (time_now).strftime("%b %d, %Y").to_datetime, connection_outcomes_report.endDate
    assert_equal 0, connection_outcomes_report.totalCount
    assert_nil connection_outcomes_report.overallChange
    assert_equal user_summary, connection_outcomes_report.userSummary
    assert_equal_unordered rolewise_summary, connection_outcomes_report.rolewiseSummary
    assert_equal role_graph_color_mapping, connection_outcomes_report.roleGraphColorMapping
    assert_equal enabled_status_mapping, connection_outcomes_report.enabledStatusMapping

    connection_graph_data = [{name: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).pluralized_term, data: data, color: '#7cb5ec', visibility: true}]
    connection_graph_data << {name: "Users", data: data, color: '#434348', visibility: true}
    connection_graph_data << {name: mentor_role.customized_term.pluralized_term, data: data, color: '#90ed7d', visibility: false}
    connection_graph_data << {name: mentee_role.customized_term.pluralized_term, data: data, color: '#f7a35c', visibility: false}
    assert_equal_unordered connection_graph_data, connection_outcomes_report.graphData
  end

  def test_initialize_for_closed_connection_with_past_empty_data
    program = programs(:albers)
    completed_connection = program.groups.closed.first
    active_groups = program.groups.active
    time_now = (Time.now.utc + 1.day)
    start_time = time_now - 4.days
    date_range = "#{start_time.strftime("%b %d, %Y")} - #{(time_now).strftime("%b %d, %Y")}"
    connection_outcomes_report = ConnectionOutcomesReport.new(program, date_range, {status: Group::Status::CLOSED})

    mentor_role = roles("#{program.id}_#{RoleConstants::MENTOR_NAME}")
    mentee_role = roles("#{program.id}_#{RoleConstants::STUDENT_NAME}")
    user_summary = {name: "Users", count: 2, change: nil}
    rolewise_summary = [{id: "ongoing_mentor", name: mentor_role.customized_term.pluralized_term, count: 1, change: nil}, {id: "ongoing_student", name: mentee_role.customized_term.pluralized_term, count: 1, change: nil}]
    role_graph_color_mapping = OutcomesReportUtils::GraphColor.get_role_graph_color_mapping([mentor_role, mentee_role])
    enabled_status_mapping = {users: true, mentor_role.id => false, mentee_role.id => false, total_connections_or_meetings: true}

    assert_equal Group::Status::CLOSED, connection_outcomes_report.forStatus
    assert_equal start_time.strftime("%b %d, %Y").to_datetime, connection_outcomes_report.startDate
    assert_equal (time_now).strftime("%b %d, %Y").to_datetime, connection_outcomes_report.endDate
    assert_equal 1, connection_outcomes_report.totalCount
    assert_nil connection_outcomes_report.overallChange
    assert_equal user_summary, connection_outcomes_report.userSummary
    assert_equal_unordered rolewise_summary, connection_outcomes_report.rolewiseSummary
    assert_equal role_graph_color_mapping, connection_outcomes_report.roleGraphColorMapping
    assert_equal enabled_status_mapping, connection_outcomes_report.enabledStatusMapping

    start_month_index = start_time.utc.at_beginning_of_month.to_datetime.to_i
    end_month_index = time_now.utc.at_beginning_of_month.to_datetime.to_i
    month_index = start_time.utc.at_beginning_of_month.to_datetime
    connection_closed_at_month_index = completed_connection.closed_at.utc.at_beginning_of_month.to_datetime.to_i

    data1 = []
    data2 = []
    while(month_index.to_i <= end_month_index)
      if(month_index.to_i == connection_closed_at_month_index)
        data1 << [month_index.to_i*1000, 1]
        data2 << [month_index.to_i*1000, 2]
      else
        data1 << [month_index.to_i*1000, 0]
        data2 << [month_index.to_i*1000, 0]
      end
      month_index += 1.month
    end

    connection_graph_data = [{name: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).pluralized_term, data: data1, color: '#7cb5ec', visibility: true}]
    connection_graph_data << {name: "Users", data: data2, color: '#434348', visibility: true}
    connection_graph_data << {name: mentor_role.customized_term.pluralized_term, data: data1, color: '#90ed7d', visibility: false}
    connection_graph_data << {name: mentee_role.customized_term.pluralized_term, data: data1, color: '#f7a35c', visibility: false}
    assert_equal_unordered connection_graph_data, connection_outcomes_report.graphData
  end

  def test_initialize_for_closed_connection_with_past_data_no_change
    program = programs(:albers)
    completed_connection = program.groups.closed.first
    active_group = program.groups.active.last
    time_now = (Time.now.utc + 1.day)
    start_time = time_now - 4.days

    active_group.terminate!(users(:f_admin), "Test reason", program.group_closure_reasons.completed.first.id)
    active_group.update_attribute(:closed_at, (start_time - 2.day))
    date_range = "#{start_time.strftime("%b %d, %Y")} - #{(time_now).strftime("%b %d, %Y")}"
    connection_outcomes_report = ConnectionOutcomesReport.new(program, date_range, {status: Group::Status::CLOSED})

    mentor_role = roles("#{program.id}_#{RoleConstants::MENTOR_NAME}")
    mentee_role = roles("#{program.id}_#{RoleConstants::STUDENT_NAME}")
    user_summary = {name: "Users", count: 2, change: 0.0}
    rolewise_summary = [{id: "ongoing_mentor", name: mentor_role.customized_term.pluralized_term, count: 1, change: 0.0}, {id: "ongoing_student", name: mentee_role.customized_term.pluralized_term, count: 1, change: 0.0}]
    role_graph_color_mapping = OutcomesReportUtils::GraphColor.get_role_graph_color_mapping([mentor_role, mentee_role])
    enabled_status_mapping = {users: true, mentor_role.id => false, mentee_role.id => false, total_connections_or_meetings: true}

    assert_equal Group::Status::CLOSED, connection_outcomes_report.forStatus
    assert_equal start_time.strftime("%b %d, %Y").to_datetime, connection_outcomes_report.startDate
    assert_equal (time_now).strftime("%b %d, %Y").to_datetime, connection_outcomes_report.endDate
    assert_equal 1, connection_outcomes_report.totalCount
    assert_equal 0.0, connection_outcomes_report.overallChange
    assert_equal user_summary, connection_outcomes_report.userSummary
    assert_equal_unordered rolewise_summary, connection_outcomes_report.rolewiseSummary
    assert_equal role_graph_color_mapping, connection_outcomes_report.roleGraphColorMapping
    assert_equal enabled_status_mapping, connection_outcomes_report.enabledStatusMapping

    start_month_index = start_time.utc.at_beginning_of_month.to_datetime.to_i
    end_month_index = time_now.utc.at_beginning_of_month.to_datetime.to_i
    month_index = start_time.utc.at_beginning_of_month.to_datetime
    connection_closed_at_month_index = completed_connection.closed_at.utc.at_beginning_of_month.to_datetime.to_i

    data1 = []
    data2 = []
    while(month_index.to_i <= end_month_index)
      if(month_index.to_i == connection_closed_at_month_index)
        data1 << [month_index.to_i*1000, 1]
        data2 << [month_index.to_i*1000, 2]
      else
        data1 << [month_index.to_i*1000, 0]
        data2 << [month_index.to_i*1000, 0]
      end
      month_index += 1.month
    end
    connection_graph_data = [{name: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).pluralized_term, data: data1, color: '#7cb5ec', visibility: true}]
    connection_graph_data << {name: "Users", data: data2, color: '#434348', visibility: true}
    connection_graph_data << {name: mentor_role.customized_term.pluralized_term, data: data1, color: '#90ed7d', visibility: false}
    connection_graph_data << {name: mentee_role.customized_term.pluralized_term, data: data1, color: '#f7a35c', visibility: false}
    assert_equal_unordered connection_graph_data, connection_outcomes_report.graphData
  end

  def test_initialize_for_closed_connection_with_past_data_with_change
    program = programs(:albers)
    completed_connection = program.groups.closed.first
    active_group = program.groups.active.last
    time_now = (Time.now.utc + 1.day)
    start_time = time_now - 4.days

    active_group.terminate!(users(:f_admin), "Test reason", program.group_closure_reasons.completed.first.id)

    active_group.update_attribute(:closed_at, (start_time - 2.days))

    active_group = program.groups.active.last
    active_group.terminate!(users(:f_admin), "Test reason", program.group_closure_reasons.completed.first.id)
    active_group.update_attribute(:closed_at, (start_time - 2.days))

    active_group = program.groups.active.last
    active_group.terminate!(users(:f_admin), "Test reason", program.group_closure_reasons.completed.first.id)
    active_group.update_attribute(:closed_at, (start_time - 7.days))

    date_range = "#{start_time.strftime("%b %d, %Y")} - #{(time_now).strftime("%b %d, %Y")}"

    connection_outcomes_report = ConnectionOutcomesReport.new(program, date_range, {status: Group::Status::CLOSED})

    mentor_role = roles("#{program.id}_#{RoleConstants::MENTOR_NAME}")
    mentee_role = roles("#{program.id}_#{RoleConstants::STUDENT_NAME}")
    user_summary = {name: "Users", count: 2, change: -33.33}
    rolewise_summary = [{id: "ongoing_mentor", name: mentor_role.customized_term.pluralized_term, count: 1, change: -50.0}, {id: "ongoing_student", name: mentee_role.customized_term.pluralized_term, count: 1, change: 0.0}]
    role_graph_color_mapping = OutcomesReportUtils::GraphColor.get_role_graph_color_mapping([mentor_role, mentee_role])
    enabled_status_mapping = {users: true, mentor_role.id => false, mentee_role.id => false, total_connections_or_meetings: true}

    assert_equal Group::Status::CLOSED, connection_outcomes_report.forStatus
    assert_equal start_time.strftime("%b %d, %Y").to_datetime, connection_outcomes_report.startDate
    assert_equal (time_now).strftime("%b %d, %Y").to_datetime, connection_outcomes_report.endDate
    assert_equal 1, connection_outcomes_report.totalCount
    assert_equal -50.0, connection_outcomes_report.overallChange
    assert_equal user_summary, connection_outcomes_report.userSummary
    assert_equal_unordered rolewise_summary, connection_outcomes_report.rolewiseSummary
    assert_equal role_graph_color_mapping, connection_outcomes_report.roleGraphColorMapping
    assert_equal enabled_status_mapping, connection_outcomes_report.enabledStatusMapping

    start_month_index = start_time.utc.at_beginning_of_month.to_datetime.to_i
    end_month_index = time_now.utc.at_beginning_of_month.to_datetime.to_i
    month_index = start_time.utc.at_beginning_of_month.to_datetime
    connection_closed_at_month_index = completed_connection.closed_at.utc.at_beginning_of_month.to_datetime.to_i

    data1 = []
    data2 = []
    while(month_index.to_i <= end_month_index)
      if(month_index.to_i == connection_closed_at_month_index)
        data1 << [month_index.to_i*1000, 1]
        data2 << [month_index.to_i*1000, 2]
      else
        data1 << [month_index.to_i*1000, 0]
        data2 << [month_index.to_i*1000, 0]
      end
      month_index += 1.month
    end
    connection_graph_data = [{name: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).pluralized_term, data: data1, color: '#7cb5ec', visibility: true}]
    connection_graph_data << {name: "Users", data: data2, color: '#434348', visibility: true}
    connection_graph_data << {name: mentor_role.customized_term.pluralized_term, data: data1, color: '#90ed7d', visibility: false}
    connection_graph_data << {name: mentee_role.customized_term.pluralized_term, data: data1, color: '#f7a35c', visibility: false}

    assert_equal_unordered connection_graph_data, connection_outcomes_report.graphData
  end

  def test_initialize_for_positive_connection
    program = programs(:albers)
    closed_connection = program.groups.closed.first
    time_now = Time.now.utc
    date_range = "#{program.created_at.strftime("%b %d, %Y")} - #{(time_now + 1.day).strftime("%b %d, %Y")}"
    user = User.find(Connection::Membership.where(group_id: closed_connection.id).pluck(:user_id).first)

    survey = surveys(:two)
    survey_question = survey.survey_questions.where(question_text: "Where are you from?")[0]
    survey_question.update_attribute(:positive_outcome_options, survey_question.question_choices.find_by(text: "Earth").id.to_s)
    closed_connection.survey_answers.create({answer_value: {answer_text: "Earth", question: survey_question}, user: user, last_answered_at: Time.now.utc, survey_question: survey_question})

    ConnectionOutcomesReport.any_instance.stubs(:get_positive_outcomes_survey_response_rate_and_error_rate).with(groups(:group_4).members.pluck(:id)).once.returns(["responseRate", "marginError"])
    connection_outcomes_report = ConnectionOutcomesReport.new(program, date_range, {status: Group::Status::CLOSED, type: ConnectionOutcomesReport::POSITIVE_OUTCOMES})
    mentor_role = roles("#{program.id}_#{RoleConstants::MENTOR_NAME}")
    mentee_role = roles("#{program.id}_#{RoleConstants::STUDENT_NAME}")
    user_summary = {name: "Users", count: 1, change: nil}
    rolewise_summary = [{id: "positive_outcomes_mentor", name: mentor_role.customized_term.pluralized_term, count: 0, change: nil}, {id: "positive_outcomes_student", name: mentee_role.customized_term.pluralized_term, count: 1, change: nil}]
    role_graph_color_mapping = OutcomesReportUtils::GraphColor.get_role_graph_color_mapping([mentor_role, mentee_role])
    enabled_status_mapping = {users: true, mentor_role.id => false, mentee_role.id => false, total_connections_or_meetings: true}

    assert_equal Group::Status::CLOSED, connection_outcomes_report.forStatus
    assert_equal program.created_at.strftime("%b %d, %Y").to_datetime, connection_outcomes_report.startDate
    assert_equal (time_now + 1.day).strftime("%b %d, %Y").to_datetime, connection_outcomes_report.endDate
    assert_equal 1, connection_outcomes_report.totalCount
    assert_nil connection_outcomes_report.overallChange
    assert user.is_student?
    assert_equal user_summary, connection_outcomes_report.userSummary
    assert_equal_unordered rolewise_summary, connection_outcomes_report.rolewiseSummary
    assert_equal role_graph_color_mapping, connection_outcomes_report.roleGraphColorMapping
    assert_equal enabled_status_mapping, connection_outcomes_report.enabledStatusMapping
    assert_equal "responseRate", connection_outcomes_report.responseRate
    assert_equal "marginError", connection_outcomes_report.marginError

    start_month_index = program.created_at.utc.at_beginning_of_month.to_datetime.to_i
    end_month_index = (time_now + 1.day).utc.at_beginning_of_month.to_datetime.to_i
    month_index = program.created_at.utc.at_beginning_of_month.to_datetime
    connection_closed_at_month_index = closed_connection.closed_at.utc.at_beginning_of_month.to_datetime.to_i

    data1 = []
    data2 = []
    while(month_index.to_i <= end_month_index)
      if(month_index.to_i == connection_closed_at_month_index)
        data1 << [month_index.to_i*1000, 0]
        data2 << [month_index.to_i*1000, 1]
      else
        data1 << [month_index.to_i*1000, 0]
        data2 << [month_index.to_i*1000, 0]
      end
      month_index += 1.month
    end
    connection_graph_data = [{name: "Users", data: data2, color: '#434348', visibility: true}]
    connection_graph_data << {name: mentor_role.customized_term.pluralized_term, data: data1, color: '#90ed7d', visibility: false}
    connection_graph_data << {name: mentee_role.customized_term.pluralized_term, data: data2, color: '#f7a35c', visibility: false}
    connection_graph_data << {name: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).pluralized_term, data: data2, color: '#7cb5ec', visibility: true}
    assert_equal_unordered connection_graph_data, connection_outcomes_report.graphData
  end

  def test_get_positive_outcomes_survey_response_rate_and_error_rate
    program = programs(:albers)
    time_now = Time.now.utc
    date_range = "#{program.created_at.strftime("%b %d, %Y")} - #{(time_now + 1.day).strftime("%b %d, %Y")}"
    closed_connection = groups(:group_4)
    user1 = User.find(Connection::Membership.where(group_id: closed_connection.id).pluck(:user_id).first)
    user2 = User.find(Connection::Membership.where(group_id: closed_connection.id).pluck(:user_id).last)

    survey = surveys(:two)
    survey_question = survey.survey_questions.where(question_text: "Where are you from?")[0]
    survey_question.update_attribute(:positive_outcome_options, survey_question.question_choices.find_by(text: "Earth").id.to_s)
    closed_connection.survey_answers.create!({answer_value: {answer_text: "Earth", question: survey_question}, user: user1, last_answered_at: Time.now.utc, survey_question: survey_question})
    closed_connection.survey_answers.create!({answer_value: {answer_text: "Krypton", question: survey_question}, user: user2, last_answered_at: Time.now.utc, survey_question: survey_question})
    connection_outcomes_report = ConnectionOutcomesReport.new(program, date_range, {status: Group::Status::CLOSED, type: ConnectionOutcomesReport::POSITIVE_OUTCOMES})
    completed_user_ids = program.users.pluck(:id)
    Survey.stubs(:calculate_response_rate).with(2, completed_user_ids.size).returns('r')
    Survey.stubs(:percentage_error).with(2, completed_user_ids.size).returns('e')
    assert_equal ['r', 'e'], connection_outcomes_report.send(:get_positive_outcomes_survey_response_rate_and_error_rate, completed_user_ids)
  end

  def test_initialize_for_positive_connection_with_no_data
    program = programs(:albers)
    closed_connection = program.groups.closed.first
    time_now = closed_connection.closed_at - 4.day
    date_range = "#{program.created_at.strftime("%b %d, %Y")} - #{(time_now).strftime("%b %d, %Y")}"

    connection_outcomes_report = ConnectionOutcomesReport.new(program, date_range, {status: Group::Status::CLOSED, type: ConnectionOutcomesReport::POSITIVE_OUTCOMES})
    mentor_role = roles("#{program.id}_#{RoleConstants::MENTOR_NAME}")
    mentee_role = roles("#{program.id}_#{RoleConstants::STUDENT_NAME}")
    user_summary = {name: "Users", count: 0, change: nil}
    rolewise_summary = [{id: "positive_outcomes_mentor", name: mentor_role.customized_term.pluralized_term, count: 0, change: nil}, {id: "positive_outcomes_student", name: mentee_role.customized_term.pluralized_term, count: 0, change: nil}]
    role_graph_color_mapping = OutcomesReportUtils::GraphColor.get_role_graph_color_mapping([mentor_role, mentee_role])
    enabled_status_mapping = {users: true, mentor_role.id => false, mentee_role.id => false, total_connections_or_meetings: true}

    start_month_index = program.created_at.utc.at_beginning_of_month.to_datetime.to_i
    end_month_index = time_now.utc.at_beginning_of_month.to_datetime.to_i
    month_index = program.created_at.utc.at_beginning_of_month.to_datetime

    data = []
    while (month_index.to_i <= end_month_index)
      data << [month_index.to_i * 1000, 0]
      month_index += 1.month
    end

    assert_equal Group::Status::CLOSED, connection_outcomes_report.forStatus
    assert_equal program.created_at.strftime("%b %d, %Y").to_datetime, connection_outcomes_report.startDate
    assert_equal (time_now).strftime("%b %d, %Y").to_datetime, connection_outcomes_report.endDate
    assert_equal 0, connection_outcomes_report.totalCount
    assert_nil connection_outcomes_report.overallChange
    assert_equal user_summary, connection_outcomes_report.userSummary
    assert_equal_unordered rolewise_summary, connection_outcomes_report.rolewiseSummary
    assert_equal role_graph_color_mapping, connection_outcomes_report.roleGraphColorMapping
    assert_equal enabled_status_mapping, connection_outcomes_report.enabledStatusMapping

    connection_graph_data = [{name: "Users", data: data, color: '#434348', visibility: true}]
    connection_graph_data << {name: mentor_role.customized_term.pluralized_term, data: data, color: '#90ed7d', visibility: false}
    connection_graph_data << {name: mentee_role.customized_term.pluralized_term, data: data, color: '#f7a35c', visibility: false}
    connection_graph_data << {name: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).pluralized_term, data: data, color: '#7cb5ec', visibility: true}
    assert_equal_unordered connection_graph_data, connection_outcomes_report.graphData
  end


  def test_initialize_for_positive_connection_with_multiple_positive_survey_answers_from_group
    program = programs(:albers)
    closed_connection = program.groups.closed.first
    time_now = (Time.now.utc + 1.day)
    start_time = time_now - 4.days
    date_range = "#{start_time.strftime("%b %d, %Y")} - #{(time_now).strftime("%b %d, %Y")}"
    user1 = User.find(Connection::Membership.where(group_id: closed_connection.id).pluck(:user_id).first)
    user2 = User.find(Connection::Membership.where(group_id: closed_connection.id).pluck(:user_id).last)

    survey = surveys(:two)
    survey_question = survey.survey_questions.where(question_text: "Where are you from?")[0]
    survey_question.update_attribute(:positive_outcome_options, survey_question.question_choices.find_by(text: "Earth").id.to_s)
    closed_connection.survey_answers.create({answer_value: {answer_text: "Earth", question: survey_question}, user: user1, last_answered_at: Time.now.utc, survey_question: survey_question})
    closed_connection.survey_answers.create({answer_value: {answer_text: "Earth", question: survey_question}, user: user2, last_answered_at: Time.now.utc, survey_question: survey_question})

    connection_outcomes_report = ConnectionOutcomesReport.new(program, date_range, {status: Group::Status::CLOSED, type: ConnectionOutcomesReport::POSITIVE_OUTCOMES})
    mentor_role = roles("#{program.id}_#{RoleConstants::MENTOR_NAME}")
    mentee_role = roles("#{program.id}_#{RoleConstants::STUDENT_NAME}")
    user_summary = {name: "Users", count: 2, change: nil}
    rolewise_summary = [{id: "positive_outcomes_mentor", name: mentor_role.customized_term.pluralized_term, count: 1, change: nil}, {id: "positive_outcomes_student", name: mentee_role.customized_term.pluralized_term, count: 1, change: nil}]
    role_graph_color_mapping = OutcomesReportUtils::GraphColor.get_role_graph_color_mapping([mentor_role, mentee_role])
    enabled_status_mapping = {users: true, mentor_role.id => false, mentee_role.id => false, total_connections_or_meetings: true}

    assert_equal Group::Status::CLOSED, connection_outcomes_report.forStatus
    assert_equal start_time.strftime("%b %d, %Y").to_datetime, connection_outcomes_report.startDate
    assert_equal (time_now).strftime("%b %d, %Y").to_datetime, connection_outcomes_report.endDate
    assert_equal 1, connection_outcomes_report.totalCount
    assert_nil connection_outcomes_report.overallChange
    assert user1.is_student?
    assert_false user1.is_mentor?
    assert user2.is_mentor?
    assert_false user2.is_student?
    assert_equal user_summary, connection_outcomes_report.userSummary
    assert_equal_unordered rolewise_summary, connection_outcomes_report.rolewiseSummary
    assert_equal role_graph_color_mapping, connection_outcomes_report.roleGraphColorMapping
    assert_equal enabled_status_mapping, connection_outcomes_report.enabledStatusMapping

    start_month_index = start_time.utc.at_beginning_of_month.to_datetime.to_i
    end_month_index = time_now.utc.at_beginning_of_month.to_datetime.to_i
    month_index = start_time.utc.at_beginning_of_month.to_datetime
    connection_closed_at_month_index = closed_connection.closed_at.utc.at_beginning_of_month.to_datetime.to_i

    data1 = []
    data2 = []
    while (month_index.to_i <= end_month_index)
      if(month_index.to_i == connection_closed_at_month_index)
        data1 << [month_index.to_i*1000,1]
        data2 << [month_index.to_i*1000,2]
      else
        data1 << [month_index.to_i*1000,0]
        data2 << [month_index.to_i*1000,0]
      end
      month_index += 1.month
    end

    connection_graph_data = [{name: "Users", data: data2, color: '#434348', visibility: true}]
    connection_graph_data << {name: mentor_role.customized_term.pluralized_term, data: data1, color: '#90ed7d', visibility: false}
    connection_graph_data << {name: mentee_role.customized_term.pluralized_term, data: data1, color: '#f7a35c', visibility: false}
    connection_graph_data << {name: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).pluralized_term, data: data1, color: '#7cb5ec', visibility: true}
    assert_equal_unordered connection_graph_data, connection_outcomes_report.graphData
  end

  def test_initialize_for_positive_connection_with_past_empty_data
    program = programs(:albers)
    closed_connection = program.groups.closed.first
    time_now = (Time.now.utc + 1.day)
    start_time = time_now - 4.days
    date_range = "#{start_time.strftime("%b %d, %Y")} - #{(time_now).strftime("%b %d, %Y")}"
    user = User.find(Connection::Membership.where(group_id: closed_connection.id).pluck(:user_id).first)

    survey = surveys(:two)
    survey_question = survey.survey_questions.where(question_text: "Where are you from?")[0]
    survey_question.update_attribute(:positive_outcome_options, survey_question.question_choices.find_by(text: "Earth").id.to_s)
    closed_connection.survey_answers.create({answer_value: {answer_text: "Earth", question: survey_question}, user: user, last_answered_at: Time.now.utc, survey_question: survey_question})

    connection_outcomes_report = ConnectionOutcomesReport.new(program, date_range, {status: Group::Status::CLOSED, type: ConnectionOutcomesReport::POSITIVE_OUTCOMES})
    mentor_role = roles("#{program.id}_#{RoleConstants::MENTOR_NAME}")
    mentee_role = roles("#{program.id}_#{RoleConstants::STUDENT_NAME}")
    user_summary = {name: "Users", count: 1, change: nil}
    rolewise_summary = [{id: "positive_outcomes_mentor", name: mentor_role.customized_term.pluralized_term, count: 0, change: nil}, {id: "positive_outcomes_student", name: mentee_role.customized_term.pluralized_term, count: 1, change: nil}]
    role_graph_color_mapping = OutcomesReportUtils::GraphColor.get_role_graph_color_mapping([mentor_role, mentee_role])
    enabled_status_mapping = {users: true, mentor_role.id => false, mentee_role.id => false, total_connections_or_meetings: true}

    assert_equal Group::Status::CLOSED, connection_outcomes_report.forStatus
    assert_equal start_time.strftime("%b %d, %Y").to_datetime, connection_outcomes_report.startDate
    assert_equal (time_now).strftime("%b %d, %Y").to_datetime, connection_outcomes_report.endDate
    assert_equal 1, connection_outcomes_report.totalCount
    assert_nil connection_outcomes_report.overallChange
    assert user.is_student?
    assert_equal user_summary, connection_outcomes_report.userSummary
    assert_equal_unordered rolewise_summary, connection_outcomes_report.rolewiseSummary
    assert_equal role_graph_color_mapping, connection_outcomes_report.roleGraphColorMapping
    assert_equal enabled_status_mapping, connection_outcomes_report.enabledStatusMapping

    start_month_index = start_time.utc.at_beginning_of_month.to_datetime.to_i
    end_month_index = time_now.utc.at_beginning_of_month.to_datetime.to_i
    month_index = start_time.utc.at_beginning_of_month.to_datetime
    connection_closed_at_month_index = closed_connection.closed_at.utc.at_beginning_of_month.to_datetime.to_i

    data1 = []
    data2 = []
    while (month_index.to_i <= end_month_index)
      if(month_index.to_i == connection_closed_at_month_index)
        data1 << [month_index.to_i*1000,0]
        data2 << [month_index.to_i*1000,1]
      else
        data1 << [month_index.to_i*1000,0]
        data2 << [month_index.to_i*1000,0]
      end
      month_index += 1.month
    end

    connection_graph_data = [{name: "Users", data: data2, color: '#434348', visibility: true}]
    connection_graph_data << {name: mentor_role.customized_term.pluralized_term, data: data1, color: '#90ed7d', visibility: false}
    connection_graph_data << {name: mentee_role.customized_term.pluralized_term, data: data2, color: '#f7a35c', visibility: false}
    connection_graph_data << {name: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).pluralized_term, data: data2, color: '#7cb5ec', visibility: true}
    assert_equal_unordered connection_graph_data, connection_outcomes_report.graphData
  end

  def test_initialize_for_positive_connection_with_past_data_no_change
    program = programs(:albers)
    closed_connection = program.groups.closed.first
    time_now = (Time.now.utc + 1.day)
    start_time = time_now - 4.days
    date_range = "#{start_time.strftime("%b %d, %Y")} - #{(time_now).strftime("%b %d, %Y")}"
    user = User.find(Connection::Membership.where(group_id: closed_connection.id).pluck(:user_id).first)

    survey = surveys(:two)
    survey_question = survey.survey_questions.where(question_text: "Where are you from?")[0]
    survey_question.update_attribute(:positive_outcome_options, survey_question.question_choices.find_by(text: "Earth").id.to_s)
    closed_connection.survey_answers.create({answer_value: {answer_text: "Earth", question: survey_question}, user: user, last_answered_at: Time.now.utc, survey_question: survey_question})

    active_group = program.groups.active.last
    active_group.terminate!(users(:f_admin), "Test reason", program.group_closure_reasons.completed.first.id)
    active_group.update_attribute(:closed_at, (start_time - 2.day))
    user1 = User.find(Connection::Membership.where(group_id: active_group.id).pluck(:user_id).first)
    active_group.survey_answers.create({answer_value: {answer_text: "Earth", question: survey_question}, user: user1, last_answered_at: Time.now.utc, survey_question: survey_question})

    connection_outcomes_report = ConnectionOutcomesReport.new(program, date_range, {status: Group::Status::CLOSED, type: ConnectionOutcomesReport::POSITIVE_OUTCOMES})
    mentor_role = roles("#{program.id}_#{RoleConstants::MENTOR_NAME}")
    mentee_role = roles("#{program.id}_#{RoleConstants::STUDENT_NAME}")
    user_summary = {name: "Users", count: 1, change: 0.0}
    rolewise_summary = [{id: "positive_outcomes_mentor", name: mentor_role.customized_term.pluralized_term, count: 0, change: nil}, {id: "positive_outcomes_student", name: mentee_role.customized_term.pluralized_term, count: 1, change: 0.0}]
    role_graph_color_mapping = OutcomesReportUtils::GraphColor.get_role_graph_color_mapping([mentor_role, mentee_role])
    enabled_status_mapping = {users: true, mentor_role.id => false, mentee_role.id => false, total_connections_or_meetings: true}

    assert_equal Group::Status::CLOSED, connection_outcomes_report.forStatus
    assert_equal start_time.strftime("%b %d, %Y").to_datetime, connection_outcomes_report.startDate
    assert_equal (time_now).strftime("%b %d, %Y").to_datetime, connection_outcomes_report.endDate
    assert_equal 1, connection_outcomes_report.totalCount
    assert_equal 0.0, connection_outcomes_report.overallChange
    assert user.is_student?
    assert user1.is_student?
    assert_equal user_summary, connection_outcomes_report.userSummary
    assert_equal_unordered rolewise_summary, connection_outcomes_report.rolewiseSummary
    assert_equal role_graph_color_mapping, connection_outcomes_report.roleGraphColorMapping
    assert_equal enabled_status_mapping, connection_outcomes_report.enabledStatusMapping

    start_month_index = start_time.utc.at_beginning_of_month.to_datetime.to_i
    end_month_index = time_now.utc.at_beginning_of_month.to_datetime.to_i
    month_index = start_time.utc.at_beginning_of_month.to_datetime
    connection_closed_at_month_index = closed_connection.closed_at.utc.at_beginning_of_month.to_datetime.to_i

    data1 = []
    data2 = []
    while (month_index.to_i <= end_month_index)
      if(month_index.to_i == connection_closed_at_month_index)
        data1 << [month_index.to_i*1000, 0]
        data2 << [month_index.to_i*1000, 1]
      else
        data1 << [month_index.to_i*1000, 0]
        data2 << [month_index.to_i*1000, 0]
      end
      month_index += 1.month
    end

    connection_graph_data = [{name: "Users", data: data2, color: '#434348', visibility: true}]
    connection_graph_data << {name: mentor_role.customized_term.pluralized_term, data: data1, color: '#90ed7d', visibility: false}
    connection_graph_data << {name: mentee_role.customized_term.pluralized_term, data: data2, color: '#f7a35c', visibility: false}
    connection_graph_data << {name: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).pluralized_term, data: data2, color: '#7cb5ec', visibility: true}
    assert_equal_unordered connection_graph_data, connection_outcomes_report.graphData
  end

  def test_initialize_for_positive_connection_with_past_data_with_change
    program = programs(:albers)
    closed_connection = program.groups.closed.first
    time_now = (Time.now.utc + 1.day)
    start_time = time_now - 4.days
    date_range = "#{start_time.strftime("%b %d, %Y")} - #{(time_now).strftime("%b %d, %Y")}"
    user = User.find(Connection::Membership.where(group_id: closed_connection.id).pluck(:user_id).first)

    survey = surveys(:two)
    survey_question = survey.survey_questions.where(question_text: "Where are you from?")[0]
    survey_question.update_attribute(:positive_outcome_options, survey_question.question_choices.find_by(text: "Earth").id.to_s)
    closed_connection.survey_answers.create({answer_value: {answer_text: "Earth", question: survey_question}, user: user, last_answered_at: Time.now.utc, survey_question: survey_question})

    active_group = program.groups.active.last
    active_group.terminate!(users(:f_admin), "Test reason", program.group_closure_reasons.completed.first.id)
    active_group.update_attribute(:closed_at, (start_time - 2.days))
    user1 = User.find(Connection::Membership.where(group_id: active_group.id).pluck(:user_id).first)
    active_group.survey_answers.create({answer_value: {answer_text: "Earth", question: survey_question}, user: user1, last_answered_at: Time.now.utc, survey_question: survey_question})

    active_group = program.groups.active.last
    active_group.terminate!(users(:f_admin), "Test reason", program.group_closure_reasons.completed.first.id)
    active_group.update_attribute(:closed_at, (start_time - 2.days))
    user2 = User.find(Connection::Membership.where(group_id: active_group.id).pluck(:user_id).last)
    active_group.survey_answers.create({answer_value: {answer_text: "Earth", question: survey_question}, user: user2, last_answered_at: Time.now.utc, survey_question: survey_question})

    active_group = program.groups.active.last
    active_group.terminate!(users(:f_admin), "Test reason", program.group_closure_reasons.completed.first.id)
    active_group.update_attribute(:closed_at, (start_time - 7.days))
    user3 = User.find(Connection::Membership.where(group_id: active_group.id).pluck(:user_id).first)
    active_group.survey_answers.create({answer_value: {answer_text: "Earth", question: survey_question}, user: user3, last_answered_at: Time.now.utc, survey_question: survey_question})

    connection_outcomes_report = ConnectionOutcomesReport.new(program, date_range, {status: Group::Status::CLOSED, type: ConnectionOutcomesReport::POSITIVE_OUTCOMES})
    mentor_role = roles("#{program.id}_#{RoleConstants::MENTOR_NAME}")
    mentee_role = roles("#{program.id}_#{RoleConstants::STUDENT_NAME}")

    user_summary = {name: "Users", count: 1, change: -50.0}
    rolewise_summary = [{id: "positive_outcomes_mentor", name: mentor_role.customized_term.pluralized_term, count: 0, change: -100.0}, {id: "positive_outcomes_student", name: mentee_role.customized_term.pluralized_term, count: 1, change: 0.0}]
    role_graph_color_mapping = OutcomesReportUtils::GraphColor.get_role_graph_color_mapping([mentor_role, mentee_role])
    enabled_status_mapping = {users: true, mentor_role.id => false, mentee_role.id => false, total_connections_or_meetings: true}

    assert_equal Group::Status::CLOSED, connection_outcomes_report.forStatus
    assert_equal start_time.strftime("%b %d, %Y").to_datetime, connection_outcomes_report.startDate
    assert_equal (time_now).strftime("%b %d, %Y").to_datetime, connection_outcomes_report.endDate
    assert_equal 1, connection_outcomes_report.totalCount
    assert_equal -50.0, connection_outcomes_report.overallChange
    assert user.is_student?
    assert user1.is_student?
    assert user2.is_mentor?
    assert_equal user_summary, connection_outcomes_report.userSummary
    assert_equal_unordered rolewise_summary, connection_outcomes_report.rolewiseSummary
    assert_equal role_graph_color_mapping, connection_outcomes_report.roleGraphColorMapping
    assert_equal enabled_status_mapping, connection_outcomes_report.enabledStatusMapping

    start_month_index = start_time.utc.at_beginning_of_month.to_datetime.to_i
    end_month_index = time_now.utc.at_beginning_of_month.to_datetime.to_i
    month_index = start_time.utc.at_beginning_of_month.to_datetime
    connection_closed_at_month_index = closed_connection.closed_at.utc.at_beginning_of_month.to_datetime.to_i

    data1 = []
    data2 = []
    while (month_index.to_i <= end_month_index)
        if(month_index.to_i == connection_closed_at_month_index)
          data1 << [month_index.to_i*1000, 0]
          data2 << [month_index.to_i*1000, 1]
        else
          data1 << [month_index.to_i*1000, 0]
          data2 << [month_index.to_i*1000, 0]
        end
          month_index += 1.month
    end

    connection_graph_data = [{name: "Users", data: data2, color: '#434348', visibility: true}]
    connection_graph_data << {name: mentor_role.customized_term.pluralized_term, data: data1, color: '#90ed7d', visibility: false}
    connection_graph_data << {name: mentee_role.customized_term.pluralized_term, data: data2, color: '#f7a35c', visibility: false}
    connection_graph_data << {name: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).pluralized_term, data: data2, color: '#7cb5ec', visibility: true}
    assert_equal_unordered connection_graph_data, connection_outcomes_report.graphData
  end

  def test_initialize_for_active_connection_with_only_graph_data
    program = programs(:albers)
    time_now = Time.now.utc
    start_date = program.created_at.strftime("%b %d, %Y")
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"
    mentor_role = roles("#{program.id}_#{RoleConstants::MENTOR_NAME}")
    mentee_role = roles("#{program.id}_#{RoleConstants::STUDENT_NAME}")
    role_graph_color_mapping = OutcomesReportUtils::GraphColor.get_role_graph_color_mapping([mentor_role, mentee_role])
    enabled_status_mapping = { users: true, mentor_role.id => false, mentee_role.id => false, total_connections_or_meetings: true }

    ConnectionReportCommon.any_instance.expects(:computed_graph_data_for_users_of_ongoing_connections).returns(name: "Users", data: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 8, 8], color: "#434348", visibility: true)
    ConnectionReportCommon.any_instance.expects(:computed_graph_data_for_users_of_ongoing_connections_per_role).with(mentor_role).returns(name: "Mentors", data: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 4, 4], color: "#90ed7d", visibility: false)
    ConnectionReportCommon.any_instance.expects(:computed_graph_data_for_users_of_ongoing_connections_per_role).with(mentee_role).returns(name: "Students", data: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 4, 4], color: "#f7a35c", visibility: false)
    ConnectionReportCommon.any_instance.expects(:computed_graph_data_for_ongoing_connections).returns(name: "Mentoring Connections", data: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 12, 12, 12], color: "#7cb5ec", visibility: true)
    connection_outcomes_report = ConnectionOutcomesReport.new(program, date_range, data_side: OutcomesReportUtils::DataType::GRAPH_DATA)
    assert_equal Group::Status::ACTIVE, connection_outcomes_report.forStatus
    assert_equal program.created_at.strftime("%b %d, %Y").to_datetime, connection_outcomes_report.startDate
    assert_equal (time_now + 1.day).strftime("%b %d, %Y").to_datetime, connection_outcomes_report.endDate
    assert_equal 0, connection_outcomes_report.startDayIndex
    assert_nil connection_outcomes_report.overallChange
    assert_nil connection_outcomes_report.totalCount
    assert_nil connection_outcomes_report.userSummary
    assert_nil connection_outcomes_report.rolewiseSummary
    assert_not_nil connection_outcomes_report.graphData
    assert_equal role_graph_color_mapping, connection_outcomes_report.roleGraphColorMapping
    assert_equal enabled_status_mapping, connection_outcomes_report.enabledStatusMapping
  end

  def test_initialize_for_active_connection_with_only_non_graph_data
    program = programs(:albers)
    time_now = Time.now.utc
    start_date = program.created_at.strftime("%b %d, %Y")
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"
    mentor_role = roles("#{program.id}_#{RoleConstants::MENTOR_NAME}")
    mentee_role = roles("#{program.id}_#{RoleConstants::STUDENT_NAME}")
    start_time = Date.parse(start_date).to_datetime
    end_time = Date.parse(end_date).to_datetime

    User.expects(:get_ids_of_connected_users_active_between).with(program, start_time, end_time, ids: nil, role: nil).once.returns(1..10)
    User.expects(:get_ids_of_connected_users_active_between).with(program, start_time, end_time, ids: nil, role: mentor_role).once.returns(1..5)
    User.expects(:get_ids_of_connected_users_active_between).with(program, start_time, end_time, ids: nil, role: mentee_role).once.returns(1..5)
    Group.expects(:get_ids_of_groups_active_between).once.returns(1..10)
    connection_outcomes_report = ConnectionOutcomesReport.new(program, date_range, data_side: OutcomesReportUtils::DataType::NON_GRAPH_DATA)
    assert_equal Group::Status::ACTIVE, connection_outcomes_report.forStatus
    assert_equal program.created_at.strftime("%b %d, %Y").to_datetime, connection_outcomes_report.startDate
    assert_equal (time_now + 1.day).strftime("%b %d, %Y").to_datetime, connection_outcomes_report.endDate
    assert_equal 0, connection_outcomes_report.startDayIndex
    assert_equal 10, connection_outcomes_report.totalCount
    assert_nil connection_outcomes_report.overallChange
    assert_nil connection_outcomes_report.graphData
    assert_not_nil connection_outcomes_report.userSummary
    assert_not_nil connection_outcomes_report.rolewiseSummary
  end
end
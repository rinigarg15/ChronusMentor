require_relative './../../../test_helper'

class ConnectionDetailedReportTest < ActiveSupport::TestCase

  def setup
    super
    programs(:albers).update_attributes(created_at: (Time.now - 60.days))
  end

  def test_section_one_data
    program = programs(:albers)
    time_now = Time.now.utc
    start_date = program.created_at.utc.beginning_of_day
    end_date = (time_now + 1.day).utc.beginning_of_day

    Group.expects(:get_ids_of_groups_active_between).once.with(program, start_date, end_date, ids: nil).returns(1..10)
    User.expects(:get_ids_of_connected_users_active_between).once.with(program, start_date, end_date, ids: nil).returns(1..20)

    start_date = start_date.strftime("%b %d, %Y")
    end_date = end_date.strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"

    closed_connection = program.groups.closed.first
    user = User.find(Connection::Membership.where(group_id: closed_connection.id).pluck(:user_id).first)
    survey = surveys(:two)
    survey_question = survey.survey_questions.where(question_text: "Where are you from?")[0]
    survey_question.update_attribute(:positive_outcome_options,  survey_question.question_choices.find_by(text: "Earth").id.to_s)
    closed_connection.survey_answers.create({answer_value: {answer_text: "Earth", question: survey_question}, user: user, last_answered_at: Time.now.utc, :survey_question => survey_question})

    cdr = ConnectionDetailedReport.new(program.reload, date_range, section: ConnectionDetailedReport::Section::ONE)
    data = cdr.sectioneOneData

    assert_equal 10, data[:overall][:connections][:count]
    assert_nil data[:overall][:connections][:change]
    assert_equal 20, data[:overall][:users][:count]
    assert_nil data[:overall][:users][:change]

    assert_equal 9, data[:ongoing][:connections][:count]
    assert_nil data[:ongoing][:connections][:change]
    assert_equal 8, data[:ongoing][:users][:count]
    assert_nil data[:ongoing][:users][:change]

    assert_equal 1, data[:completed][:connections][:count]
    assert_nil data[:completed][:connections][:change]
    assert_equal 2, data[:completed][:users][:count]
    assert_nil data[:completed][:users][:change]

    assert_equal 0, data[:dropped][:connections][:count]
    assert_nil data[:dropped][:connections][:change]
    assert_equal 0, data[:dropped][:users][:count]
    assert_nil data[:dropped][:users][:change]

    assert_equal 1, data[:positive_outcomes][:connections][:count]
    assert_nil data[:positive_outcomes][:connections][:change]
    assert_equal 1, data[:positive_outcomes][:users][:count]
    assert_nil data[:positive_outcomes][:users][:change]
  end

  def test_positive_outcomes_for_reactivated_group
    program = programs(:albers)
    time_now = Time.now.utc
    start_date = program.created_at.utc.beginning_of_day
    end_date = (time_now + 1.day).utc.beginning_of_day

    Group.expects(:get_ids_of_groups_active_between).once.with(program, start_date, end_date, ids: nil).returns(1..10)
    User.expects(:get_ids_of_connected_users_active_between).once.with(program, start_date, end_date, ids: nil).returns(1..20)

    start_date = start_date.strftime("%b %d, %Y")
    end_date = end_date.strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"

    closed_connection = program.groups.closed.first
    user = User.find(Connection::Membership.where(group_id: closed_connection.id).pluck(:user_id).first)
    survey = surveys(:two)
    survey_question = survey.survey_questions.where(question_text: "Where are you from?")[0]
    survey_question.update_attribute(:positive_outcome_options, survey_question.question_choices.find_by(text: "Earth").id.to_s)
    closed_connection.survey_answers.create({answer_value: {answer_text: "Earth", question: survey_question}, user: user, last_answered_at: Time.now.utc, :survey_question => survey_question})

    expiry_time = (Time.now + 2.months).utc
    closed_connection.change_expiry_date(users(:f_admin), expiry_time, "Reactivating for test")
    assert closed_connection.reload.active?

    cdr = ConnectionDetailedReport.new(program.reload, date_range, section: ConnectionDetailedReport::Section::ONE)
    data = cdr.sectioneOneData

    assert_equal 0, data[:positive_outcomes][:connections][:count]
    assert_nil data[:positive_outcomes][:connections][:change]
    assert_equal 0, data[:positive_outcomes][:users][:count]
    assert_nil data[:positive_outcomes][:users][:change]
  end

  def test_section_one_data_with_old_data
    program = programs(:albers)
    time_now = Time.now.utc
    start_date = (time_now - 20.days).utc.beginning_of_day
    end_date = (time_now + 1.day).utc.beginning_of_day

    Group.expects(:get_ids_of_groups_active_between).once.with(program, start_date, end_date, ids: nil).returns(1..10)
    User.expects(:get_ids_of_connected_users_active_between).once.with(program, start_date, end_date, ids: nil).returns(1..20)
    Group.expects(:get_ids_of_groups_active_between).with(program, start_date-22.days, end_date-22.days, ids: nil).returns(1..5)
    User.expects(:get_ids_of_connected_users_active_between).with(program, start_date-22.days, end_date-22.days, ids: nil).returns(1..10)

    start_date = start_date.strftime("%b %d, %Y")
    end_date = end_date.strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"

    cdr = ConnectionDetailedReport.new(program.reload, date_range, section: ConnectionDetailedReport::Section::ONE)
    data = cdr.sectioneOneData

    assert_equal 10, data[:overall][:connections][:count]
    assert_equal 100.0, data[:overall][:connections][:change]
    assert_equal 20, data[:overall][:users][:count]
    assert_equal 100.0, data[:overall][:users][:change]

    assert_equal 9, data[:ongoing][:connections][:count]
    assert_equal 80.0, data[:ongoing][:connections][:change]
    assert_equal 8, data[:ongoing][:users][:count]
    assert_equal 300.0, data[:ongoing][:users][:change]

    assert_equal 1, data[:completed][:connections][:count]
    assert_nil data[:completed][:connections][:change]
    assert_equal 2, data[:completed][:users][:count]
    assert_nil data[:completed][:users][:change]

    assert_equal 0, data[:dropped][:connections][:count]
    assert_nil data[:dropped][:connections][:change]
    assert_equal 0, data[:dropped][:users][:count]
    assert_nil data[:dropped][:users][:change]

    assert_equal 0, data[:positive_outcomes][:connections][:count]
    assert_nil data[:positive_outcomes][:connections][:change]
    assert_equal 0, data[:positive_outcomes][:users][:count]
    assert_nil data[:positive_outcomes][:users][:change]
  end

  def test_section_one_data_only_mentors
    program = programs(:albers)
    time_now = Time.now.utc
    start_date = program.created_at.utc.beginning_of_day
    end_date = (time_now + 1.day).utc.beginning_of_day
    role = program.roles.find_by(name: RoleConstants::MENTOR_NAME)

    Group.expects(:get_ids_of_groups_active_between).at_least(2).with(program, start_date, end_date, ids: nil).returns(1..10)
    User.expects(:get_ids_of_connected_users_active_between).with(program, start_date, end_date, ids: nil, role: role).returns(1..20)

    start_date = start_date.strftime("%b %d, %Y")
    end_date = end_date.strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"

    closed_connection = program.groups.closed.first
    user = User.find(Connection::MentorMembership.where(group_id: closed_connection.id).pluck(:user_id).first)
    survey = surveys(:two)
    survey_question = survey.survey_questions.where(question_text: "Where are you from?")[0]
    survey_question.update_attribute(:positive_outcome_options, survey_question.question_choices.find_by(text: "Earth").id.to_s)
    closed_connection.survey_answers.create({answer_value: {answer_text: "Earth", question: survey_question}, user: user, last_answered_at: Time.now.utc, :survey_question => survey_question})

    cdr = ConnectionDetailedReport.new(program.reload, date_range, section: ConnectionDetailedReport::Section::ONE, role: role.id)
    data = cdr.sectioneOneData

    assert_equal 10, data[:overall][:connections][:count]
    assert_nil data[:overall][:connections][:change]
    assert_equal 20, data[:overall][:users][:count]
    assert_nil data[:overall][:users][:change]

    assert_equal 9, data[:ongoing][:connections][:count]
    assert_nil data[:ongoing][:connections][:change]
    assert_equal 4, data[:ongoing][:users][:count]
    assert_nil data[:ongoing][:users][:change]

    assert_equal 1, data[:completed][:connections][:count]
    assert_nil data[:completed][:connections][:change]
    assert_equal 1, data[:completed][:users][:count]
    assert_nil data[:completed][:users][:change]

    assert_equal 0, data[:dropped][:connections][:count]
    assert_nil data[:dropped][:connections][:change]
    assert_equal 0, data[:dropped][:users][:count]
    assert_nil data[:dropped][:users][:change]

    assert_equal 1, data[:positive_outcomes][:connections][:count]
    assert_nil data[:positive_outcomes][:connections][:change]
    assert_equal 1, data[:positive_outcomes][:users][:count]
    assert_nil data[:positive_outcomes][:users][:change]

    student_role = program.roles.find_by(name: RoleConstants::STUDENT_NAME)
    User.expects(:get_ids_of_connected_users_active_between).with(program, start_date, end_date, ids: nil, role: student_role).returns(1..20)
    cdr2 = ConnectionDetailedReport.new(program.reload, date_range, section: ConnectionDetailedReport::Section::ONE, role: student_role.id)
    data2 = cdr2.sectioneOneData

    assert_equal 1, data2[:positive_outcomes][:connections][:count]
    assert_nil data2[:positive_outcomes][:connections][:change]
    assert_equal 0, data2[:positive_outcomes][:users][:count]
    assert_nil data2[:positive_outcomes][:users][:change]
  end

  def test_section_one_data_only_mentors_with_old_data
    program = programs(:albers)
    time_now = Time.now.utc
    start_date = (time_now - 20.days).utc.beginning_of_day
    end_date = (time_now + 1.day).utc.beginning_of_day
    role = program.roles.find_by(name: RoleConstants::MENTOR_NAME)

    Group.expects(:get_ids_of_groups_active_between).with(program, start_date, end_date, ids: nil).returns(1..10)
    User.expects(:get_ids_of_connected_users_active_between).with(program, start_date, end_date, ids: nil, role: role).returns(1..20)
    Group.expects(:get_ids_of_groups_active_between).with(program, start_date-22.days, end_date-22.days, ids: nil).returns(1..5)
    User.expects(:get_ids_of_connected_users_active_between).with(program, start_date-22.days, end_date-22.days, ids: nil, role: role).returns(1..10)

    start_date = start_date.strftime("%b %d, %Y")
    end_date = end_date.strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"

    cdr = ConnectionDetailedReport.new(program.reload, date_range, section: ConnectionDetailedReport::Section::ONE, role: role.id)
    data = cdr.sectioneOneData

    assert_equal 10, data[:overall][:connections][:count]
    assert_equal 100.0, data[:overall][:connections][:change]
    assert_equal 20, data[:overall][:users][:count]
    assert_equal 100.0, data[:overall][:users][:change]

    assert_equal 9, data[:ongoing][:connections][:count]
    assert_equal 80.0, data[:ongoing][:connections][:change]
    assert_equal 4, data[:ongoing][:users][:count]
    assert_equal 300.0, data[:ongoing][:users][:change]

    assert_equal 1, data[:completed][:connections][:count]
    assert_nil data[:completed][:connections][:change]
    assert_equal 1, data[:completed][:users][:count]
    assert_nil data[:completed][:users][:change]

    assert_equal 0, data[:dropped][:connections][:count]
    assert_nil data[:dropped][:connections][:change]
    assert_equal 0, data[:dropped][:users][:count]
    assert_nil data[:dropped][:users][:change]

    assert_equal 0, data[:positive_outcomes][:connections][:count]
    assert_nil data[:positive_outcomes][:connections][:change]
    assert_equal 0, data[:positive_outcomes][:users][:count]
    assert_nil data[:positive_outcomes][:users][:change]
  end

  def test_groups_graph_data
    program = programs(:albers)
    time_now = Time.now.utc
    start_date = program.created_at.utc.beginning_of_day
    end_date = (time_now + 1.day).utc.beginning_of_day

    start_date = start_date.strftime("%b %d, %Y")
    end_date = end_date.strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"

    closed_connection = program.groups.closed.first
    user = User.find(Connection::Membership.where(group_id: closed_connection.id).pluck(:user_id).first)
    survey = surveys(:two)
    survey_question = survey.survey_questions.where(question_text: "Where are you from?")[0]
    survey_question.update_attribute(:positive_outcome_options, survey_question.question_choices.find_by(text: "Earth").id.to_s)
    closed_connection.survey_answers.create({answer_value: {answer_text: "Earth", question: survey_question}, user: user, last_answered_at: Time.now.utc, :survey_question => survey_question})
    ConnectionReportCommon.any_instance.expects(:computed_graph_data_for_ongoing_connections).returns({:name=>"Mentoring Connections", :data=>[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 12, 12, 12], :color=>"#7cb5ec", :visibility=>true})

    cdr = ConnectionDetailedReport.new(program.reload, date_range, section: ConnectionDetailedReport::Section::TWO, tab: ConnectionDetailedReport::Tab::GROUPS)

    positive_graph_data = cdr.positiveOutcomesGraphData
    completed_graph_data = cdr.completedConnectionGraphData
    ongoing_graph_data = cdr.ongoingConnectionsGraphData

    start_month_index = program.created_at.utc.at_beginning_of_month.to_datetime.to_i
    end_month_index = (time_now + 1.day).utc.at_beginning_of_month.to_datetime.to_i
    month_index = program.created_at.utc.at_beginning_of_month.to_datetime
    connection_closed_at_month_index = closed_connection.closed_at.utc.at_beginning_of_month.to_datetime.to_i
    data = []
    while(month_index.to_i <= end_month_index)
      if(month_index.to_i == connection_closed_at_month_index)
        data << [month_index.to_i*1000, 1]
      else
        data << [month_index.to_i*1000, 0]
      end
      month_index += 1.month
    end
    assert_equal_unordered [{:name=>"Mentoring Connections", :data=> data, :color=>"#7cb5ec", :visibility=>true}], positive_graph_data
  end

  def test_users_graph_data
    program = programs(:albers)
    time_now = Time.now.utc
    start_date = program.created_at.utc.beginning_of_day
    end_date = (time_now + 1.day).utc.beginning_of_day

    start_date = start_date.strftime("%b %d, %Y")
    end_date = end_date.strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"

    closed_connection = program.groups.closed.first
    user = User.find(Connection::Membership.where(group_id: closed_connection.id).pluck(:user_id).first)
    survey = surveys(:two)
    survey_question = survey.survey_questions.where(question_text: "Where are you from?")[0]
    survey_question.update_attribute(:positive_outcome_options, survey_question.question_choices.find_by(text: "Earth").id.to_s)
    closed_connection.survey_answers.create({answer_value: {answer_text: "Earth", question: survey_question}, user: user, last_answered_at: Time.now.utc, :survey_question => survey_question})

    cdr = ConnectionDetailedReport.new(program.reload, date_range, section: ConnectionDetailedReport::Section::TWO, tab: ConnectionDetailedReport::Tab::USERS)

    positive_graph_data = cdr.positiveOutcomesGraphData
    completed_graph_data = cdr.completedConnectionGraphData
    ongoing_graph_data = cdr.ongoingConnectionsGraphData

    start_month_index = program.created_at.utc.at_beginning_of_month.to_datetime.to_i
    end_month_index = (time_now + 1.day).utc.at_beginning_of_month.to_datetime.to_i
    month_index = program.created_at.utc.at_beginning_of_month.to_datetime
    connection_closed_at_month_index = closed_connection.closed_at.utc.at_beginning_of_month.to_datetime.to_i
    data = []
    while(month_index.to_i <= end_month_index)
      if(month_index.to_i == connection_closed_at_month_index)
        data << [month_index.to_i*1000, 1]
      else
        data << [month_index.to_i*1000, 0]
      end
      month_index += 1.month
    end
    assert_equal_unordered [{:name=>"Users", :data=> data, :color=>"#434348", :visibility=>true}], positive_graph_data
  end

  def test_role_users_graph_data
    program = programs(:albers)
    time_now = Time.now.utc
    start_date = program.created_at.utc.beginning_of_day
    end_date = (time_now + 1.day).utc.beginning_of_day
    role = program.roles.find_by(name: RoleConstants::MENTOR_NAME)

    start_date = start_date.strftime("%b %d, %Y")
    end_date = end_date.strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"

    closed_connection = program.groups.closed.first
    user = User.find(Connection::MentorMembership.where(group_id: closed_connection.id).pluck(:user_id).first)
    survey = surveys(:two)
    survey_question = survey.survey_questions.where(question_text: "Where are you from?")[0]
    survey_question.update_attribute(:positive_outcome_options,  survey_question.question_choices.find_by(text: "Earth").id.to_s)
    closed_connection.survey_answers.create({answer_value: {answer_text: "Earth", question: survey_question}, user: user, last_answered_at: Time.now.utc, :survey_question => survey_question})

    cdr = ConnectionDetailedReport.new(program.reload, date_range, section: ConnectionDetailedReport::Section::TWO, tab: ConnectionDetailedReport::Tab::USERS, role: role.id)

    positive_graph_data = cdr.positiveOutcomesGraphData
    completed_graph_data = cdr.completedConnectionGraphData
    ongoing_graph_data = cdr.ongoingConnectionsGraphData

    start_month_index = program.created_at.utc.at_beginning_of_month.to_datetime.to_i
    end_month_index = (time_now + 1.day).utc.at_beginning_of_month.to_datetime.to_i
    month_index = program.created_at.utc.at_beginning_of_month.to_datetime
    connection_closed_at_month_index = closed_connection.closed_at.utc.at_beginning_of_month.to_datetime.to_i

    data = []
    while(month_index.to_i <= end_month_index)
      if(month_index.to_i == connection_closed_at_month_index)
        data << [month_index.to_i*1000, 1]
      else
        data << [month_index.to_i*1000, 0]
      end
      month_index += 1.month
    end
    assert_equal_unordered [{:name=>"Mentors", :data=> data, :color=>"#90ed7d", :visibility=>false}], positive_graph_data
  end

  def test_get_satisfaction_stats_for_groups_between
    program = programs(:albers)
    start_time = program.created_at
    end_time = Time.now + 5.days

    assert_equal_hash ({positive: 0, total: 0}), ConnectionDetailedReport.new(nil, nil, {skip_init: true}).get_satisfaction_stats_for_groups_between(start_time, end_time, program_ids: [program.id])

    group = program.groups.first
    user = User.find(Connection::MentorMembership.where(group_id: group.id).pluck(:user_id).first)
    survey = surveys(:two)
    survey_question = survey.survey_questions.where(question_text: "Where are you from?").first
    survey_question.update_attribute(:positive_outcome_options,  survey_question.question_choices.find_by(text: "Earth").id.to_s)
    group.survey_answers.create({answer_value: {answer_text: "Earth", question: survey_question}, user: user, last_answered_at: Time.now.utc, :survey_question => survey_question})

    assert_equal_hash ({positive: 1, total: 1}), ConnectionDetailedReport.new(nil, nil, {skip_init: true}).get_satisfaction_stats_for_groups_between(start_time, end_time, program_ids: [program.id])
  end

end

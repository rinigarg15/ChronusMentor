require_relative './../../../test_helper'

class DetailedOutcomesReportTest < ActiveSupport::TestCase

  def test_initialize_for_user_details_from_start_of_program
    program = programs(:albers)
    time_now = Time.now.utc
    start_date = program.created_at.strftime("%b %d, %Y")
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"
    options = { date_range: date_range, page: 1, page_size: 5, sort_order: "asc", fetch_user_data: true}
    uids = program.users.first(options[:page_size]).collect(&:id)
    User.expects(:get_ids_of_users_active_between).once.returns(uids)
    detailed_outcomes_report = DetailedOutcomesReport.new(program, options)

    assert_equal program.id, detailed_outcomes_report.programId
    assert_equal program.created_at.strftime("%b %d, %Y").to_datetime, detailed_outcomes_report.startDate
    assert_equal (time_now + 1.day).strftime("%b %d, %Y").to_datetime, detailed_outcomes_report.endDate
    assert_equal uids.size, detailed_outcomes_report.userData.size
    assert_equal_unordered uids, detailed_outcomes_report.users.collect(&:id)
  end

  def test_initialize_for_user_details_from_start_of_program_with_user_ids
    program = programs(:albers)
    time_now = Time.now.utc
    start_date = program.created_at.strftime("%b %d, %Y")
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"

    cache_key = "123"
    user_ids_cache_data = program.users.first(3).collect(&:id)
    Rails.cache.write(cache_key, user_ids_cache_data)

    users = User.where(id: user_ids_cache_data).sort_by{|user| user.member.name}
    uids = users.collect(&:id)
    user_data = []
    users.each do |user|
      user_data << {id: user.member.id, first_name: user.first_name, last_name: user.last_name, roles: user.roles.collect{ |t| t.customized_term[:term]}.join(", "), created_at: user.created_at.strftime("%B #{user.created_at.day.ordinalize}, %Y "), email: user.email}
    end

    options = { date_range: date_range, page: 1, page_size: 5, sort_order: "asc", fetch_user_data: true, user_ids_cache_key: cache_key}
    detailed_outcomes_report = DetailedOutcomesReport.new(program, options)

    assert_equal program.id, detailed_outcomes_report.programId
    assert_equal program.created_at.strftime("%b %d, %Y").to_datetime, detailed_outcomes_report.startDate
    assert_equal (time_now + 1.day).strftime("%b %d, %Y").to_datetime, detailed_outcomes_report.endDate
    assert_equal user_ids_cache_data.size, detailed_outcomes_report.userData.size
    assert_equal uids, detailed_outcomes_report.users.collect(&:id)
    assert_equal user_data, detailed_outcomes_report.userData
  end

  def test_initialize_for_user_details_from_start_of_program_with_no_data
    program = programs(:albers)
    time_now = Time.now.utc
    start_date = program.created_at.strftime("%b %d, %Y")
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"
    options = { date_range: date_range, page: 1, page_size: 5, sort_order: "asc", fetch_user_data: true }
    User.expects(:get_ids_of_users_active_between).once.returns([])

    detailed_outcomes_report = DetailedOutcomesReport.new(program, options)

    assert_equal program.id, detailed_outcomes_report.programId
    assert_equal program.created_at.strftime("%b %d, %Y").to_datetime, detailed_outcomes_report.startDate
    assert_equal (time_now + 1.day).strftime("%b %d, %Y").to_datetime, detailed_outcomes_report.endDate
    assert_blank detailed_outcomes_report.userData
  end

  def test_initialize_for_connection_outcomes_report_for_group_data
    program = programs(:albers)
    time_now = Time.now.utc
    start_date = program.created_at.strftime("%b %d, %Y")
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"
    all_group_ids = [groups(:mygroup), groups(:group_2), groups(:group_inactive), groups(:old_group)].map(&:id)
    Group.expects(:get_ids_of_groups_active_between).twice.returns(all_group_ids)
    options = { date_range: date_range, group_table_cache_key: nil, profile_filter_cache_key: nil, fetch_group_data: true }

    # both group_table_cache_key, profile_filter_cache_key are nil
    detailed_outcomes_report = DetailedOutcomesReport.new(program, options)
    assert_equal [groups(:group_inactive), groups(:group_2), groups(:mygroup), groups(:old_group)].map(&:id), detailed_outcomes_report.groups.collect(&:id)
    assert_equal 6, detailed_outcomes_report.groupsTableHash.size
    field_array = detailed_outcomes_report.groupsTableHash.map { |column| column[:field] }
    assert_equal_unordered [
      DetailedOutcomesReport::GroupTableColumns::NAME,
      DetailedOutcomesReport::GroupTableColumns::STARTED_ON,
      DetailedOutcomesReport::GroupTableColumns::STATUS,
      DetailedOutcomesReport::GroupTableColumns::STUDENTS,
      DetailedOutcomesReport::GroupTableColumns::MENTORS,
      DetailedOutcomesReport::GroupTableColumns::TEMPLATE
    ], field_array

    # case when group_table_cache_key is present
    old_group_ids = detailed_outcomes_report.groups.map(&:id)
    options[:group_table_cache_key] = detailed_outcomes_report.groupsTableCacheKey
    detailed_outcomes_report = DetailedOutcomesReport.new(program, options)
    assert_equal old_group_ids, detailed_outcomes_report.groups.map(&:id)

    # case when profile_filter_cache_key is present
    cache_key = "123"
    profile_filter_cache_data = Group.where(id: all_group_ids).order("name asc").pluck(:id).last(2)
    Rails.cache.write(cache_key + "_groups", profile_filter_cache_data)
    options[:group_table_cache_key] = nil
    options[:profile_filter_cache_key] = cache_key
    detailed_outcomes_report = DetailedOutcomesReport.new(program, options)
    assert_equal [groups(:mygroup), groups(:old_group)].map(&:id), detailed_outcomes_report.groups.map(&:id)
  end

  def test_initialize_for_connection_outcomes_report_for_user_data
    program = programs(:albers)
    time_now = Time.now.utc
    start_date = program.created_at.strftime("%b %d, %Y")
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"

    all_user_ids = program.users.pluck(:id)
    User.expects(:get_ids_of_connected_users_active_between).times(3).returns(all_user_ids)
    options = {date_range: date_range, user_table_cache_key: nil, profile_filter_cache_key: nil, fetch_user_data_for_connection_report: true}

    # both user_table_cache_key, profile_filter_cache_key are nil
    detailed_outcomes_report = DetailedOutcomesReport.new(program, options)
    assert_equal DetailedOutcomesReport::DEFAULT_PAGE_SIZE, detailed_outcomes_report.userData.size
    assert_equal User.where(id: all_user_ids).joins('JOIN members ON users.member_id = members.id').order('members.first_name asc').limit(DetailedOutcomesReport::DEFAULT_PAGE_SIZE).pluck(:id), detailed_outcomes_report.users.collect(&:id)
    field_array = detailed_outcomes_report.usersTableHash.collect{|column| column[:field]}
    assert_equal_unordered [DetailedOutcomesReport::UserTableColumns::FIRST_NAME, DetailedOutcomesReport::UserTableColumns::LAST_NAME, DetailedOutcomesReport::UserTableColumns::ROLES, DetailedOutcomesReport::UserTableColumns::CREATED_AT, DetailedOutcomesReport::UserTableColumns::EMAIL], field_array

    old_user_ids = detailed_outcomes_report.users.collect(&:id)

    options[:sort_field] = DetailedOutcomesReport::UserTableColumns::EMAIL # Test email sort field
    options[:sort_type] = "desc"
    detailed_outcomes_report = DetailedOutcomesReport.new(program, options)
    assert_equal User.where(id: all_user_ids).joins('JOIN members ON users.member_id = members.id').order('members.email desc').limit(DetailedOutcomesReport::DEFAULT_PAGE_SIZE).pluck(:id), detailed_outcomes_report.users.collect(&:id)

    # case when user_table_cache_key is present
    options[:user_table_cache_key] = detailed_outcomes_report.usersTableCacheKey
    options[:sort_field] = DetailedOutcomesReport::UserTableColumns::FIRST_NAME
    options[:sort_type] = "desc"
    detailed_outcomes_report = DetailedOutcomesReport.new(program, options)
    assert_equal User.where(id: all_user_ids).joins('JOIN members ON users.member_id = members.id').order('members.first_name desc').limit(DetailedOutcomesReport::DEFAULT_PAGE_SIZE).pluck(:id), detailed_outcomes_report.users.collect(&:id)

    # case when profile_filter_cache_key is present
    cache_key = "123"
    profile_filter_cache_data = User.where(id: all_user_ids).pluck(:id)[5,10]
    Rails.cache.write(cache_key+"_users", profile_filter_cache_data)
    options[:user_table_cache_key] = nil
    options[:profile_filter_cache_key] = cache_key
    detailed_outcomes_report = DetailedOutcomesReport.new(program, options)
    assert_equal User.where(id: all_user_ids & profile_filter_cache_data).joins('JOIN members ON users.member_id = members.id').order('members.first_name desc').limit(DetailedOutcomesReport::DEFAULT_PAGE_SIZE).pluck(:id), detailed_outcomes_report.users.collect(&:id)
  end

  def test_initialize_for_connection_outcomes_report_for_user_data_with_role_filter
    program = programs(:albers)
    time_now = Time.now.utc
    start_date = program.created_at.strftime("%b %d, %Y")
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"
    user_ids = program.users.first(5).collect(&:id)
    role = program.roles.for_mentoring.first

    User.expects(:get_ids_of_connected_users_active_between).with(program, start_date, end_date, role: role).once.returns(user_ids)
    options = { date_range: date_range, user_table_cache_key: nil, profile_filter_cache_key: nil, fetch_user_data_for_connection_report: true, for_role: role.id }
    detailed_outcomes_report = DetailedOutcomesReport.new(program, options)
    assert_equal User.where(id: user_ids).joins('JOIN members ON users.member_id = members.id').order('members.first_name asc').limit(DetailedOutcomesReport::DEFAULT_PAGE_SIZE).pluck(:id), detailed_outcomes_report.users.collect(&:id)
  end
end
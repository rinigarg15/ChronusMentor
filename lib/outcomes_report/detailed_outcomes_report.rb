include ActionView::Helpers::DateHelper

class DetailedOutcomesReport
  attr_accessor :programId, :startDate, :endDate, :userData, :users, :groupsData, :groups, :groupsTableHash, :groupsTableCacheKey, :usersTableHash, :usersTableCacheKey

  include OutcomesReportUtils
  module GroupStatus
    ONGOING = "Ongoing"
    COMPLETED = "Completed"
    DROPPED = "Dropped"
  end

  module GroupTableColumns
    NAME = "name"
    MENTORS = "mentors"
    STUDENTS = "students"
    TEMPLATE = "template"
    STARTED_ON = "started_on"
    STATUS = "status"
  end

  module UserTableColumns
    FIRST_NAME = "first_name"
    LAST_NAME = "last_name"
    ROLES = "roles"
    CREATED_AT = "created_at"
    EMAIL = "email"
  end

  DEFAULT_PAGE_SIZE = 10
  DEFAULT_PAGE_NUMBER = 1
  DEFAULT_USER_SORT_FIELD = 'full_name_sort'
  DEFAULT_SORT_ORDER = 'asc'

  FULL_NAME_SORT = 'full_name_sort'
  LAST_NAME_SORT = 'last_name_sort'
  FIRST_NAME = 'first_name'
  LAST_NAME = 'last_name'
  EMAIL = 'email'

  def initialize(program, options = {})
    self.programId = program.id
    process_date_params(options[:date_range])
    self.userData = get_user_detail(program, self.startDate, self.endDate, options) if options[:fetch_user_data]
    initialize_group_data(program, options) if options[:fetch_group_data]
    initialize_user_data(program, options) if options[:fetch_user_data_for_connection_report]
  end

  private
  def get_group_details_for_connection_outcomes_report(program, start_date, end_date, options = {})
    if options[:group_table_cache_key].nil? || !Rails.cache.exist?(options[:group_table_cache_key])
      group_ids = Group.get_ids_of_groups_active_between(program, start_date, end_date)
      group_ids = group_ids & Rails.cache.read(options[:profile_filter_cache_key] + "_groups") if options[:profile_filter_cache_key].present?
      self.groupsTableCacheKey = Time.now.to_i.to_s + ((rand*1000).floor).to_s
      Rails.cache.write(groupsTableCacheKey, group_ids, :expires_in => OutcomesReportController::CacheConstants::TIME_TO_LIVE)
    else
      group_ids = Rails.cache.read(options[:group_table_cache_key])
    end
    self.groups = DetailedReports::GroupsFilterAndSortService.new(program,  group_ids, options).groups
    group_data = []
    self.groups.each do |group|
      group_data << {
        DetailedOutcomesReport::GroupTableColumns::NAME.to_sym => [group.name, group.id],
        DetailedOutcomesReport::GroupTableColumns::MENTORS.to_sym => group.mentors.collect{|user| [user.member.name, user.member.id]},
        DetailedOutcomesReport::GroupTableColumns::STUDENTS.to_sym => group.students.collect{|user| [user.member.name, user.member.id]},
        DetailedOutcomesReport::GroupTableColumns::STATUS.to_sym => getGroupStatusForEndUser(group.status, group.closure_reason),
        DetailedOutcomesReport::GroupTableColumns::TEMPLATE.to_sym => group.mentoring_model.try(:title),
        DetailedOutcomesReport::GroupTableColumns::STARTED_ON.to_sym => DateTime.localize(group.published_at, format: "%B #{group.published_at.day.ordinalize}, %Y")
      }
    end
    return group_data
  end

  def get_user_details_for_connection_outcomes_report(program, start_date, end_date, options)
    sort_field = options[:sort_field].present? ? options[:sort_field] : DEFAULT_USER_SORT_FIELD
    sort_type = options[:sort_type].present? ? options[:sort_type] : DEFAULT_SORT_ORDER
    page_number = options[:page] || DEFAULT_PAGE_NUMBER
    page_size = options[:page_size] || DEFAULT_PAGE_SIZE
    for_role = options[:for_role]
    if options[:user_table_cache_key].nil? || !Rails.cache.exist?(options[:user_table_cache_key])
      if (for_role.nil?)
        user_ids = User.get_ids_of_connected_users_active_between(program, start_date, end_date)
      else
        user_ids = User.get_ids_of_connected_users_active_between(program, start_date, end_date, role: program.roles.for_mentoring.find_by(id: for_role))
      end
      user_ids = user_ids & Rails.cache.read(options[:profile_filter_cache_key] + "_users") if options[:profile_filter_cache_key].present?
      self.usersTableCacheKey = Time.now.to_i.to_s + ((rand*1000).floor).to_s
      Rails.cache.write(usersTableCacheKey, user_ids, :time_to_live => OutcomesReportController::CacheConstants::TIME_TO_LIVE)
    else
      user_ids = Rails.cache.read(options[:user_table_cache_key])
    end
    self.users = sort_and_paginate_user_data(user_ids, sort_field, sort_type, page_number, page_size)
    user_data = []
    self.users.each do |user|
      user_data << {id: user.id, first_name: [user.first_name, user.member.id], last_name: [user.last_name, user.member.id], roles: user.roles.collect{ |t| t.customized_term[:term]}.join(", "), created_at: DateTime.localize(user.created_at, format: "%B #{user.created_at.day.ordinalize}, %Y"), email: user.email}
    end
    return user_data
  end

  def initialize_user_data(program, options)
    self.userData = get_user_details_for_connection_outcomes_report(program, self.startDate, self.endDate, options)
    self.usersTableHash = [
      {field: DetailedOutcomesReport::UserTableColumns::FIRST_NAME, title: "feature.outcomes_report.detailed_report.table.first_name".translate, sortable: true, link_to: :user},
      {field: DetailedOutcomesReport::UserTableColumns::LAST_NAME, title: "feature.outcomes_report.detailed_report.table.last_name".translate, sortable: true, link_to: :user},
      {field: DetailedOutcomesReport::UserTableColumns::ROLES, title: "feature.outcomes_report.detailed_report.table.role".translate, sortable: false},
      {field: DetailedOutcomesReport::UserTableColumns::CREATED_AT, title: "feature.outcomes_report.detailed_report.table.created_at".translate, sortable: true},
      {field: DetailedOutcomesReport::UserTableColumns::EMAIL, title: "feature.outcomes_report.detailed_report.table.email".translate, sortable: true}
    ]
  end

  def initialize_group_data(program, options)
    self.groupsData = get_group_details_for_connection_outcomes_report(program, self.startDate, self.endDate, options)
    # need to write translations for these strings
    self.groupsTableHash = [
      {field: DetailedOutcomesReport::GroupTableColumns::NAME, title: "feature.connection.header.connection_name".translate(Mentoring_Connection: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term), sortable: true, link_to: :group},
      {field: DetailedOutcomesReport::GroupTableColumns::MENTORS, title: program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).pluralized_term, sortable: true, link_to: :user},
      {field: DetailedOutcomesReport::GroupTableColumns::STUDENTS, title: program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).pluralized_term, sortable: true, link_to: :user},
      {field: DetailedOutcomesReport::GroupTableColumns::STATUS, title: "feature.outcomes_report.header.group_status".translate, sortable: false},
      {field: DetailedOutcomesReport::GroupTableColumns::TEMPLATE, title: "feature.outcomes_report.header.mentoring_template".translate, sortable: false},
      {field: DetailedOutcomesReport::GroupTableColumns::STARTED_ON, title: "feature.outcomes_report.header.started_on".translate, sortable: true}
    ]
  end

  def get_user_detail(program, start_date, end_date, options = {})
    userData=[]
    sort_field = options[:sort_field] || FULL_NAME_SORT
    sort_order = options[:sort_order] || DEFAULT_SORT_ORDER
    page_number = options[:page] || DEFAULT_PAGE_NUMBER
    page_size = options[:page_size] || DEFAULT_PAGE_SIZE

    if options[:user_ids_cache_key].nil? || !Rails.cache.exist?(options[:user_ids_cache_key])
      user_ids = User.get_ids_of_users_active_between(program, start_date, end_date)
      user_ids = user_ids & Rails.cache.read(options[:user_ids_cache_key] + "_users") if options[:user_ids_cache_key].present?
    else
      user_ids = Rails.cache.read(options[:user_ids_cache_key])
    end
    sort_and_paginate_user_data(user_ids, sort_field, sort_order, page_number, page_size)
    self.users.each do |user|
      userData << {id: user.member.id, first_name: user.first_name, last_name: user.last_name, roles: user.roles.collect{ |t| t.customized_term[:term]}.join(", "), created_at: DateTime.localize(user.created_at, format: "%B #{user.created_at.day.ordinalize}, %Y "), email: user.email}
    end
    userData
  end

  def sort_and_paginate_user_data(user_ids, sort_field, sort_order, page_number, page_size)
    return self.users = [] if !user_ids.present?
    sort_field = "name_only.sort" if sort_field.in?([FIRST_NAME, FULL_NAME_SORT])
    sort_field = ["last_name.sort", "first_name.sort"] if sort_field.in?([LAST_NAME, LAST_NAME_SORT])
    sort_field = "email.sort" if sort_field == EMAIL
    search_options = {page: page_number, per_page: page_size, with: {id: user_ids}, includes_list: [:member, [roles: :customized_term]], sort_field: sort_field, sort_order: sort_order}
    self.users = User.get_filtered_users("", search_options)
  end

  def getGroupStatusForEndUser(group_status, closure_reason)
    if group_status == Group::Status::ACTIVE || group_status == Group::Status::INACTIVE
      return DetailedOutcomesReport::GroupStatus::ONGOING
    elsif group_status == Group::Status::CLOSED && closure_reason.present?
      return DetailedOutcomesReport::GroupStatus::COMPLETED if closure_reason.is_completed
      return DetailedOutcomesReport::GroupStatus::DROPPED
    end
    return nil
  end

end
# == Schema Information
#
# Table name: feed_exporter_configurations
#
#  id                     :integer          not null, primary key
#  feed_exporter_id       :integer
#  enabled                :boolean          default(FALSE)
#  configuration_options  :text
#  type                   :string(255)

class FeedExporter::MemberConfiguration < FeedExporter::Configuration

  # All possible headers related to members for reverse sftp feed.
  module DefaultHeaders
    MEMBER_ID = "member_id"
    FIRST_NAME = "first_name"
    LAST_NAME = "last_name"
    EMAIL = "email"
    MEMBER_STATUS = "member_status"
    JOINED_ON = "joined_on"
    ACTIVE_CONNECTIONS_COUNT = "active_connections_count"
    LAST_SUSPENDED_ON = "last_suspended_on"
    PROGRAM = "program"
    ROLE_NAME = "role_name"
    ROLE_ID = "role_id"
    USER_STATUS = "user_status"
    LAST_DEACTIVATED_ON = "last_deactivated_on"
    RECENT_CONNECTION_STARTED_ON = "recent_connection_started_on"
    CONNECTION_PLAN_TEMPLATE_NAMES = "connection_plan_template_names"
    TAGS = "tags"

    # Possible options to build headers.
    # translation_key => translation key string to call translate method
    # terms => It is passed as a hash with key as term name and value as method_name. terms map will build and passed to translate method.
    # header_method => method name from which header text can be returned.
    LOCALE_MAP = {
      MEMBER_ID => {translation_key: "feature.member.content.member_id"},
      FIRST_NAME => {translation_key: "feature.admin_view.program_defaults.title.first_name"},
      LAST_NAME => {translation_key: "feature.admin_view.program_defaults.title.last_name"},
      EMAIL => {translation_key: "feature.admin_view.program_defaults.title.email"},
      MEMBER_STATUS =>  {translation_key: "feature.admin_view.label.member_status"},
      JOINED_ON => {translation_key: "feature.member.content.joined_on_date"},
      ACTIVE_CONNECTIONS_COUNT => {translation_key: "feature.member.content.active_connections_count"},
      LAST_SUSPENDED_ON => {translation_key: "feature.admin_view.program_defaults.title.last_suspended_at"},
      PROGRAM => {header_method: :get_program_term},
      ROLE_NAME => {translation_key: "display_string.Role"},
      ROLE_ID => {translation_key: "display_string.RoleId"},
      USER_STATUS => {translation_key: "feature.admin_view.program_defaults.title.state"},
      LAST_DEACTIVATED_ON => {translation_key: "feature.admin_view.program_defaults.title.last_deactivated_at_v1"},
      RECENT_CONNECTION_STARTED_ON => {translation_key: "feature.connection.header.Recent_connection_started_on", terms: {"connection" => :get_connection_term_downcase}},
      CONNECTION_PLAN_TEMPLATE_NAMES => {translation_key: "feature.multiple_templates.header.multiple_templates_title_v1", terms: {"Mentoring_Connection" => :get_connection_term}},
      TAGS => {translation_key: "display_string.Tags"}
    }

    # corresponding methods map for the header keys
    METHOD_MAP = {
      MEMBER_ID => :get_member_id,
      FIRST_NAME => :get_first_name,
      LAST_NAME => :get_last_name,
      EMAIL => :get_email,
      MEMBER_STATUS => :get_member_status,
      JOINED_ON => :get_joined_on_date,
      ACTIVE_CONNECTIONS_COUNT => :get_active_connections_count,
      LAST_SUSPENDED_ON => :get_last_suspended_at,
      PROGRAM => :get_program_name,
      ROLE_NAME => :get_role_name,
      ROLE_ID => :get_role_id,
      USER_STATUS => :get_user_status,
      LAST_DEACTIVATED_ON => :get_last_deactivated_on,
      RECENT_CONNECTION_STARTED_ON => :get_recent_connection_started_on,
      CONNECTION_PLAN_TEMPLATE_NAMES => :get_connection_plan_template_names,
      TAGS => :get_tags
    }

    PROGRAM_HEADERS = [PROGRAM, ROLE_NAME, ROLE_ID, USER_STATUS, LAST_DEACTIVATED_ON, RECENT_CONNECTION_STARTED_ON, CONNECTION_PLAN_TEMPLATE_NAMES, TAGS]
  end

  attr_accessor :role_status, :role, :program_name

  def get_file_name(timestamp)
    "#{timestamp}_#{'feature.admin_view.label.Members'.translate}.csv"
  end

  def get_data
    members = organization.members.where.not(email: SUPERADMIN_EMAIL)
    @member_ids = members.pluck(:id)
    profile_answers_map = prepare_profile_answers_map

    members.map do |member|
      @member = member
      default_fields = populate_default_fields
      answers_map = construct_profile_answers_map(profile_answers_map)
      program_to_role_status_map = prepare_program_to_role_status_map[member.id]
      format_member_data(default_fields, answers_map, program_to_role_status_map)
    end.flatten
  end

  private
  #################################################
  # DEFINITIONS FOR METHODS IN METHOD_MAP
  #################################################

  def get_member_id
    member.id
  end

  def get_first_name
    member.first_name
  end

  def get_last_name
    member.last_name
  end

  def get_email
    member.email
  end

  def get_member_status
    MembersHelper.state_to_string_map[member.state]
  end

  def get_joined_on_date
    DateTime.localize(member.created_at, format: :full_display_no_time)
  end

  def get_active_connections_count
    @active_groups_count_map ||= Member.get_groups_count_map_for_status(member_ids, Group::Status::ACTIVE_CRITERIA)
    @active_groups_count_map[member.id].to_i
  end

  def get_last_suspended_at
    DateTime.localize(member.last_suspended_at, format: :full_display_no_time)
  end

  def get_program_name
    @program_name
  end

  def get_role_name
    @role.split(UNDERSCORE_SEPARATOR)[0] || ""
  end

  def get_role_id
    @role.split(UNDERSCORE_SEPARATOR)[1] || ""
  end

  def get_user_status
    UsersHelper::STATE_TO_STRING_MAP[@role_status["status"]]
  end

  def get_last_deactivated_on
    DateTime.localize(@role_status['last_deactivated_at'], format: :full_display_no_time)
  end

  def get_recent_connection_started_on
    DateTime.localize(@role_status["recent_connection_started_on"], format: :date_range)
  end

  def get_connection_plan_template_names
    @role_status["connection_plan_template_names"]
  end

  def get_tags
    @role_status["tags"]
  end

  def default_header_keys
    @default_header_keys ||= (headers - DefaultHeaders::PROGRAM_HEADERS)
  end

  def program_header_keys
    @program_header_keys ||= (headers & DefaultHeaders::PROGRAM_HEADERS)
  end

  def has_program_headers?
    program_header_keys.any?
  end

  def prepare_program_to_role_status_map
    return {} unless has_program_headers?
    @program_to_role_statuses ||= prepare_program_to_tags_connection_details_map(Member.members_with_role_names_and_deactivation_dates(member_ids, organization, last_deactivated_at_needed: true, role_ids_needed: true))
  end

  def get_details_of_columns_to_select
    [
      { column_to_select: "MAX(groups.published_at) as recent_connection_started_on", hash_to_join: :groups },
      { column_to_select: "GROUP_CONCAT(DISTINCT(mentoring_model_translations.title)) as connection_plan_template_names", hash_to_join: { groups: { mentoring_model: :translations } }, filter: { mentoring_model_translations: { locale: I18n.default_locale } } },
      { column_to_select: "GROUP_CONCAT(DISTINCT(tags.name)) as tags", hash_to_join: :tags }
    ]
  end

  def prepare_program_to_tags_connection_details_map(program_to_role_statuses)
    program_id_program_map = Hash[Program::Translation.where(program_id: organization.program_ids, locale: I18n.default_locale).pluck(:program_id, :name)]
    get_details_of_columns_to_select.each do |column_details|
      join_and_load_user_data(column_details[:column_to_select], column_details[:hash_to_join], column_details[:filter]).each do |details_hash|
        program_to_role_statuses[details_hash["member_id"]][program_id_program_map[details_hash["program_id"]]].merge!(details_hash.except("member_id", "program_id"))
      end
    end
    program_to_role_statuses
  end

  def join_and_load_user_data(column_to_select, hash_to_join, filter)
    filter ||= {}
    filter.merge!(member_id: member_ids)
    sql_query = User.where(filter).joins(hash_to_join).select("member_id as member_id, users.program_id as program_id, #{column_to_select}").group("users.id").to_sql
    ActiveRecord::Base.connection.exec_query(sql_query)
  end

  def format_member_data(default_fields, answers_map, program_to_role_status_map)
    return default_fields.merge(get_role_fields(set_blank: true)).merge(answers_map) if program_to_role_status_map.blank?

    program_to_role_status_map.map do |program_name, role_status|
      @program_name = program_name
      @role_status = role_status
      @role_status["roles"].map do |role|
        @role = role || ""
        default_fields.merge(get_role_fields).merge(answers_map)
      end
    end
  end

  def get_role_fields(options = {})
    role_fields = {}
    program_header_keys.each do |program_header|
      header_text = get_header_text(program_header)
      role_fields[header_text] = options[:set_blank] ? "" : get_value(program_header)
    end
    role_fields
  end

end

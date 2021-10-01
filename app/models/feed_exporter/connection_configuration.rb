# == Schema Information
#
# Table name: feed_exporter_configurations
#
#  id                     :integer          not null, primary key
#  feed_exporter_id       :integer
#  enabled                :boolean          default(FALSE)
#  configuration_options  :text
#  type                   :string(255)

class FeedExporter::ConnectionConfiguration < FeedExporter::Configuration

  ROLE_SEPARATOR = "; "

  # All possible headers related to connections for reverse sftp feed.
  module DefaultHeaders
    GROUP_ID = "group_id"
    GROUP_NAME = "group_name"
    PROGRAM_ROOT = "program_root"
    PROGRAM_NAME = "program_name"
    ROLE_NAMES = "role_names"
    ROLE_IDS = "role_ids"
    GROUP_STATUS = "group_status"
    GROUP_NOTES = "group_notes"
    ACTIVE_SINCE = "active_since"
    LAST_ACTIVITY_AT = "last_activity_at"
    EXPIRES_ON = "expires_on"

    # Possible options to build headers.
    # translation_key => translation key string to call translate method
    # terms => It is passed as a hash with key as term name and value as method_name. terms map will build and passed to translate method.
    # header_method => method name from which header text can be returned.
    LOCALE_MAP = {
      GROUP_ID => {translation_key: "feature.connection.header.mentoring_connection_id", terms: {"Mentoring_Connection" => :get_connection_term}},
      GROUP_NAME => {header_method: :get_connection_term},
      PROGRAM_ROOT => {header_method: :get_program_term},
      PROGRAM_NAME => {translation_key: "program_settings_strings.label.program_name", terms: {"program" => :get_program_term}},
      ROLE_NAMES => {translation_key: "feature.connection.header.role", terms: {"Role" => :get_role_term}},
      ROLE_IDS => {translation_key: "feature.connection.header.role_id", terms: {"Role" => :get_role_term}},
      GROUP_STATUS => {translation_key: "feature.connection.header.status.Status"},
      GROUP_NOTES => {translation_key: "feature.connection.header.Notes"},
      ACTIVE_SINCE => {translation_key: "feature.connection.content.Active_since"},
      LAST_ACTIVITY_AT => {translation_key: "feature.connection.content.Last_activity"},
      EXPIRES_ON => {translation_key: "feature.connection.content.Expires_on"}
    }

    # corresponding methods map for the header keys
    METHOD_MAP = {
      GROUP_ID => :get_group_id,
      GROUP_NAME => :get_group_name,
      PROGRAM_ROOT => :get_program_root,
      PROGRAM_NAME => :get_program_name,
      ROLE_NAMES => :get_role_user_name,
      ROLE_IDS => :get_role_member_id,
      GROUP_STATUS => :get_group_status,
      GROUP_NOTES => :get_group_notes,
      ACTIVE_SINCE => :get_active_since,
      LAST_ACTIVITY_AT => :get_last_activity_at,
      EXPIRES_ON => :get_expiry_date
    }

    # Collective fields => data will fetched for all mentoring roles.
    ROLE_SPECIFIC_HEADERS = [ROLE_NAMES, ROLE_IDS]
    # Default fields
    DEFAULT_FIELDS = [GROUP_ID, GROUP_NAME, PROGRAM_ROOT, PROGRAM_NAME]
  end

  attr_accessor :program, :group, :role_name, :memberships

  def get_file_name(timestamp)
    "#{timestamp}_#{organization.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).pluralized_term}.csv"
  end

  def get_data
    programs = organization.programs
    programs.map do |program|
      @program = program
      groups = program.groups.includes(memberships: [:role, { user: :member } ])
      load_member_ids(groups)
      profile_answers_map = prepare_profile_answers_map
      groups.map { |group| format_group_data(group, programs, profile_answers_map) }
    end.flatten
  end

  private

  #################################################
  # DEFINITIONS FOR METHODS IN METHOD_MAP
  #################################################

  def get_group_id
    group.id
  end

  def get_group_name
    group.name
  end

  def get_program_root
    program.root
  end

  def get_program_name
    program.name
  end

  def get_group_status
    GroupsHelper.state_to_string_map[group.status]
  end

  def get_group_notes
    group.notes || ""
  end

  def get_active_since
    DateTime.localize(group.published_at, format: :date_range) || ""
  end

  def get_last_activity_at
    DateTime.localize(group.last_member_activity_at, format: :date_range) || ""
  end

  def get_expiry_date
    DateTime.localize(group.expiry_time, format: :date_range) || ""
  end

  def get_role_user_name
    (memberships || []).collect { |membership| membership.user.name(name_only: true) }.join(ROLE_SEPARATOR)
  end

  def get_role_member_id
    (memberships || []).collect { |membership| membership.user.member_id }.join(ROLE_SEPARATOR)
  end

  def default_header_keys
    @default_header_keys ||= (headers & DefaultHeaders::DEFAULT_FIELDS)
  end

  def role_specific_headers
    @role_specific_headers ||= (headers & DefaultHeaders::ROLE_SPECIFIC_HEADERS)
  end

  def remaining_header_keys
    @remaining_header_keys ||= (headers - default_header_keys - role_specific_headers)
  end

  def has_role_specific_headers?
    role_specific_headers.any?
  end

  def get_role_term
    role_name.titleize
  end

  def mentoring_role_names(programs)
    @mentoring_role_names ||= programs.select("roles.name as role_name").joins(:roles).where(roles: { for_mentoring: true } ).order("roles.id").collect(&:role_name).uniq
  end

  def format_group_data(group, programs, profile_answers_map)
    @group = group
    default_fields = populate_default_fields
    role_fields = construct_role_users_map(programs, profile_answers_map)
    remaining_fields = populate_remaining_fields

    default_fields.merge(role_fields).merge(remaining_fields)
  end

  def populate_remaining_fields
    remaining_fields = {}
    remaining_header_keys.each do |header|
      header_text = get_header_text(header)
      remaining_fields[header_text] = get_value(header)
    end
    remaining_fields
  end

  def construct_role_users_map(programs, profile_answers_map)
    return {} unless has_role_specific_headers?
    role_name_role_map = program.roles.index_by(&:name)
    role_users_map = {}
    mentoring_role_names(programs).each do |role_name|
      @role_name = role_name
      role = role_name_role_map[role_name]
      @memberships = group.memberships.select { |membership| membership.role_id == role.id } if role.present?
      role_specific_headers.each do |role_specific_header|
        header_text = get_header_text(role_specific_header)
        role_users_map[header_text] = get_value(role_specific_header)
      end
      populate_profile_answer_fields!(role_users_map, profile_answers_map) if profile_question_texts.present?
    end
    role_users_map
  end

  def load_member_ids(groups)
    @member_ids = Connection::Membership.joins(:user).where(group_id: groups.collect(&:id)).pluck("users.member_id")
  end

  # TODO: If organization with one to many mentoring mode is being configured for reverse sftp then display format for profile answers have be discussed.
  def populate_profile_answer_fields!(role_users_map, profile_answers_map)
    role_profile_fields_map = {}
    memberships.each do |membership|
      @member = membership.user.member
      answer_map = construct_profile_answers_map(profile_answers_map)
      answer_map.each do |question_text, answer|
        key = "#{get_role_term} - #{question_text}"
        role_profile_fields_map[key] ||= []
        role_profile_fields_map[key] << answer
      end
    end
    role_profile_fields_map.each{|key, value| role_profile_fields_map[key] = value.join(ROLE_SEPARATOR)}
    role_users_map.merge!(role_profile_fields_map)
  end

end


# == Schema Information
#
# Table name: group_views
#
#  id         :integer          not null, primary key
#  program_id :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class GroupView < ActiveRecord::Base
  belongs_to :program
  has_many :group_view_columns, -> { order(:ref_obj_type, :position, :id) }, dependent: :destroy

  validates :program_id, presence: true, uniqueness: true

  def create_default_columns
    default_columns = self.get_applicable_group_view_column_keys
    default_columns.each_with_index do |column_key, position|
      column_key, role_id = column_key.split(GroupViewColumn::COLUMN_SPLITTER)
      self.group_view_columns.create!(column_key: column_key, position: position, ref_obj_type: GroupViewColumn::ColumnType::NONE, role_id: role_id)
    end
  end

  def get_group_view_columns(tab_number)
    program = self.program
    all_columns = self.group_view_columns.includes(:group_view, :connection_question, profile_question: :translations)
    applicable_column_keys_with_role_id = self.get_applicable_group_view_column_keys
    invalid_columns = GroupViewColumn.get_invalid_column_keys(tab_number.to_i)
    role_id_question_ids_map = {}
    program.roles.for_mentoring.each do |role|
      role_id_question_ids_map[role.id] = self.profile_questions_for_role(role).collect(&:id)
    end

    applicable_valid_columns = all_columns.reject do |column|
      case column.ref_obj_type
      when GroupViewColumn::ColumnType::NONE
        column_key_with_role_id = [column.column_key, column.role_id].compact.join(GroupViewColumn::COLUMN_SPLITTER)
        invalid_columns.include?(column.column_key) || applicable_column_keys_with_role_id.exclude?(column_key_with_role_id)
      when GroupViewColumn::ColumnType::USER
        role_id_question_ids_map[column.role_id].exclude?(column.profile_question_id)
      end
    end
    applicable_valid_columns.select! { |column| column.ref_obj_type != GroupViewColumn::ColumnType::GROUP } unless program.connection_profiles_enabled?
    applicable_valid_columns
  end

  def get_applicable_group_view_column_keys
    program = self.program
    default_columns = GroupViewColumn::Columns::Defaults.all
    default_columns -= GroupViewColumn::Columns::Defaults::GROUP_MEETINGS_DEFAULTS unless program.mentoring_connection_meeting_enabled?
    default_columns -= GroupViewColumn::Columns::Defaults::GROUP_MESSAGING_DEFAULTS unless program.group_messaging_enabled?
    default_columns -= GroupViewColumn::Columns::Defaults::GROUP_FORUM_DEFAULTS unless program.group_forum_enabled?
    default_columns -= GroupViewColumn::Columns::Defaults::WITHDRAWN_DEFAULTS unless program.groups.withdrawn.exists?
    default_columns -= GroupViewColumn::Columns::Defaults::PROJECT_SLOT_COLUMNS unless program.project_based?
    default_columns -= GroupViewColumn::Columns::Defaults::PROJECT_BASED_COLUMNS unless program.project_based? && program.allow_circle_start_date?
    unless program.mentoring_connections_v2_enabled?
      default_columns -= GroupViewColumn::Columns::Defaults::MENTORING_MODEL_V2_DEFAULTS
      default_columns -= GroupViewColumn::Columns::Defaults::MULTIPLE_TEMPLATES_DEFAULTS
    end
    unless program.mentoring_roles_with_permission(RolePermission::PROPOSE_GROUPS).exists? || program.groups.where(status: [Group::Status::PROPOSED, Group::Status::REJECTED]).exists?
      default_columns -= GroupViewColumn::Columns::Defaults::PROPOSED_REJECTED_DEFAULTS
    end
    handle_role_based_default_columns(default_columns)
  end

  def handle_role_based_default_columns(default_columns)
    role_based_default_columns = default_columns & GroupViewColumn::Columns::Defaults::ROLE_BASED_COLUMNS
    if role_based_default_columns.present?
      program.roles.for_mentoring.each do |role|
        default_columns += role_based_default_columns.collect do |column|
          [column, role.id].join(GroupViewColumn::COLUMN_SPLITTER) unless GroupViewColumn::Columns::Defaults::PROJECT_SLOT_COLUMNS.include?(column) && !program.is_slot_config_enabled_for?(role)
        end.compact
      end
      default_columns -= role_based_default_columns
    end
    default_columns
  end

  def profile_questions_for_role(role)
    self.program.profile_questions_for(role.name, default: true, skype: false, fetch_all: true).reject(&:name_type?)
  end
end

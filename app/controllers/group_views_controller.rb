class GroupViewsController < ApplicationController
  allow user: :can_manage_connections?
  before_action :get_group_view

  module GroupViewColumnGroup
    DEFAULT = "default"
    CONNECTION = "connection"
  end

  def update
    group_view_columns = params[:group_view][:group_view_columns]
    columns_array = {}
    group_view_columns.each do |opt|
      key, val = opt.split(GroupViewColumn::COLUMN_SPLITTER, 2)
      (columns_array[key] ||= []) << val
    end
    save_group_view_columns!(@group_view, columns_array, params[:group_view][:tab])
    flash[:notice] = "flash_message.group_view_flash.updated".translate
    redirect_to groups_path(view: params[:group_view][:view], tab: params[:group_view][:tab])
  end

  private

  def get_group_view
    @group_view = @current_program.group_view
  end

  def save_group_view_columns!(group_view, columns_array, tab_number)
    roles = @current_program.roles.for_mentoring
    group_view_columns = group_view.group_view_columns
    old_default_columns = group_view_columns.default
    new_default_columns = columns_array[GroupViewColumnGroup::DEFAULT].to_a
    old_connection_profile_columns = group_view_columns.group_questions
    new_connection_profile_columns = columns_array[GroupViewColumnGroup::CONNECTION].to_a

    old_profile_columns = {}
    new_profile_columns = {}
    roles.each do |role|
      old_profile_columns[role.id] = group_view_columns.role_questions(role.id).to_a
      new_profile_columns[role.id] = columns_array[role.id.to_s].to_a
    end
    ActiveRecord::Base.transaction do
      create_update_columns(group_view, old_default_columns, new_default_columns, GroupViewColumn::ColumnType::NONE, tab_number)
      create_update_columns(group_view, old_connection_profile_columns, new_connection_profile_columns, GroupViewColumn::ColumnType::GROUP, tab_number)
      roles.each do |role|
        create_update_columns(group_view, old_profile_columns[role.id], new_profile_columns[role.id], GroupViewColumn::ColumnType::USER, tab_number, role_id: role.id)
      end
    end
  end

  def create_update_columns(group_view, old_columns, new_columns, ref_obj_type, tab_number, options = {})
    invalid_columns = GroupViewColumn.get_invalid_column_keys(tab_number.to_i)
    new_columns.each_with_index do |column_key, index|
      column_key, role_id = column_key.split(GroupViewColumn::COLUMN_SPLITTER)
      role_id ||= options[:role_id]
      column_object = GroupViewColumn.find_object(old_columns, column_key, ref_obj_type, role_id: role_id)
      if column_object.present?
        column_object.update_attributes!(position: index)
        old_columns -= [column_object]
      else
        attrs = { group_view: group_view, position: index, ref_obj_type: ref_obj_type }
        case ref_obj_type
        when GroupViewColumn::ColumnType::NONE
          attrs.merge!(column_key: column_key, role_id: role_id)
        when GroupViewColumn::ColumnType::GROUP
          attrs.merge!(connection_question_id: column_key.to_i)
        when GroupViewColumn::ColumnType::USER
          attrs.merge!(profile_question_id: column_key.to_i, role_id: role_id)
        end
        GroupViewColumn.create!(attrs)
      end
    end
    if ref_obj_type == GroupViewColumn::ColumnType::NONE
      old_columns.select { |column| invalid_columns.exclude?(column.key) }.map(&:destroy)
    else
      old_columns.map(&:destroy)
    end
  end
end

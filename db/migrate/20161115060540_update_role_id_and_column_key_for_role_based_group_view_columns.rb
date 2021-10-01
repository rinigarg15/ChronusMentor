class UpdateRoleIdAndColumnKeyForRoleBasedGroupViewColumns< ActiveRecord::Migration[4.2]
  def up
    mentor_invalid_keys = ["mentors", "mentor_meetings_activity", "mentor_messages_activity", "mentor_login_activity"]
    mentee_invalid_keys = ["mentees", "mentee_meetings_activity", "mentee_messages_activity", "mentee_login_activity"]

    role_name_keys = ["mentors", "mentees"]
    meetings_activity_keys = ["mentor_meetings_activity", "mentee_meetings_activity"]
    messages_activity_keys = ["mentor_messages_activity", "mentee_messages_activity"]
    login_activity_keys = ["mentor_login_activity", "mentee_login_activity"]

    invalid_keys = mentor_invalid_keys + mentee_invalid_keys

    group_view_ids = GroupViewColumn.where(column_key: invalid_keys).pluck(:group_view_id).uniq
    program_ids = GroupView.where(id: group_view_ids).pluck(:program_id).uniq
    program_mentor_role_hash = Role.where(program_id: program_ids).with_name(RoleConstants::MENTOR_NAME).index_by(&:program_id)
    program_mentee_role_hash = Role.where(program_id: program_ids).with_name(RoleConstants::STUDENT_NAME).index_by(&:program_id)

    GroupView.where(id: group_view_ids).each do |group_view|
      group_view_columns = group_view.group_view_columns
      ActiveRecord::Base.transaction do
        group_view_columns.where(column_key: mentor_invalid_keys).update_all(role_id: program_mentor_role_hash[group_view.program_id].id)
        group_view_columns.where(column_key: mentee_invalid_keys).update_all(role_id: program_mentee_role_hash[group_view.program_id].id)
        group_view_columns.where(column_key: role_name_keys).update_all(column_key: GroupViewColumn::Columns::Key::MEMBERS)
        group_view_columns.where(column_key: meetings_activity_keys).update_all(column_key: GroupViewColumn::Columns::Key::MEETINGS_ACTIVITY)
        group_view_columns.where(column_key: messages_activity_keys).update_all(column_key: GroupViewColumn::Columns::Key::MESSAGES_ACTIVITY)
        group_view_columns.where(column_key: login_activity_keys).update_all(column_key: GroupViewColumn::Columns::Key::LOGIN_ACTIVITY)
      end
    end
  end

  def down
    # Nothing
  end
end

class MigrateForRoleToRoleIdForGroupViewColumns< ActiveRecord::Migration[4.2]
  def up
    group_view_ids = GroupViewColumn.user_questions.pluck(:group_view_id).uniq
    program_ids = GroupView.where(id: group_view_ids).pluck(:program_id).uniq
    program_mentor_role_hash = Role.where(program_id: program_ids).with_name(RoleConstants::MENTOR_NAME).index_by(&:program_id)
    program_mentee_role_hash = Role.where(program_id: program_ids).with_name(RoleConstants::STUDENT_NAME).index_by(&:program_id)

    GroupView.where(id: group_view_ids).each do |group_view|
      group_view_columns_for_user_questions = group_view.group_view_columns.user_questions
      ActiveRecord::Base.transaction do
        group_view_columns_for_user_questions.where(for_role: 0).update_all(role_id: program_mentor_role_hash[group_view.program_id].id)
        group_view_columns_for_user_questions.where(for_role: 1).update_all(role_id: program_mentee_role_hash[group_view.program_id].id)
      end
    end
    remove_column :group_view_columns, :for_role
  end

  def down
    # Nothing
  end
end

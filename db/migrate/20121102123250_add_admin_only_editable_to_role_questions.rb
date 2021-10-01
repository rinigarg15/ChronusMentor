class AddAdminOnlyEditableToRoleQuestions< ActiveRecord::Migration[4.2]
  def change
    add_column :role_questions, :admin_only_editable, :boolean, default: false
  end
end

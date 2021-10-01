class AddIsAdminOnlyToCommonQuestion< ActiveRecord::Migration[4.2]
  def change
    add_column :common_questions, :is_admin_only, :boolean
  end
end

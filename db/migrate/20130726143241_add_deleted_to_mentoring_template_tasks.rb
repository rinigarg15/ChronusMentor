class AddDeletedToMentoringTemplateTasks< ActiveRecord::Migration[4.2]
  def change
    add_column :mentoring_template_tasks, :deleted, :boolean, default: false, null: false
  end
end
